import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let voiceTriggerCoordinator = VoiceTriggerCoordinator()
  private var voiceTriggerMethodChannel: FlutterMethodChannel?
  private var volumeButtonDetector: VolumeButtonDetector?
  private var volumeButtonEventChannel: FlutterEventChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    super.application(application, didFinishLaunchingWithOptions: launchOptions)
    return true
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    let pluginRegistry = engineBridge.pluginRegistry
    GeneratedPluginRegistrant.register(with: pluginRegistry)

    if let registrar = pluginRegistry.registrar(forPlugin: "VoiceTriggerChannel") {
      let messenger = registrar.messenger()
      setUpVoiceTriggerChannel(binaryMessenger: messenger)
      setUpVolumeButtonChannel(binaryMessenger: messenger)
    }
  }

  private func setUpVolumeButtonChannel(binaryMessenger: FlutterBinaryMessenger) {
    let eventChannel = FlutterEventChannel(
      name: "safe/volume_button",
      binaryMessenger: binaryMessenger
    )
    
    let detector = VolumeButtonDetector()
    eventChannel.setStreamHandler(detector)
    
    volumeButtonDetector = detector
    volumeButtonEventChannel = eventChannel
  }

  private func setUpVoiceTriggerChannel(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "safe/voice_trigger",
      binaryMessenger: binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, callback in
      guard let self else {
        callback(FlutterError(code: "unavailable", message: "AppDelegate unavailable", details: nil))
        return
      }

      switch call.method {
      case "startListening":
        do {
          try self.voiceTriggerCoordinator.startListening(arguments: call.arguments)
          callback(nil)
        } catch {
          callback(FlutterError(code: "start_failed", message: error.localizedDescription, details: nil))
        }
      case "stopListening":
        self.voiceTriggerCoordinator.stopListening()
        callback(nil)
      default:
        callback(FlutterMethodNotImplemented)
      }
    }

    voiceTriggerMethodChannel = channel
  }
}

private final class VoiceTriggerCoordinator {
  private var isListening = false
  private let minRecordingDurationSec = 5
  private let maxRecordingDurationSec = 600
  private var recordingDurationSec = 15
  private var keyword: String = ""

  func startListening(arguments: Any?) throws {
    guard !isListening else { return }

    if let payload = arguments as? [String: Any] {
      if let value = payload["recordingDurationSec"] as? Int {
        recordingDurationSec = min(max(value, minRecordingDurationSec), maxRecordingDurationSec)
      }

      if let value = payload["keyword"] as? String {
        keyword = value
      }
    }

    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playAndRecord, options: [.mixWithOthers, .allowBluetooth])
    try session.setActive(true)

    isListening = true
  }

  func stopListening() {
    guard isListening else { return }
    isListening = false

    let session = AVAudioSession.sharedInstance()
    try? session.setActive(false, options: [.notifyOthersOnDeactivation])
  }
}

// MARK: - Volume Button Detector

private final class VolumeButtonDetector: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var volumeView: UIView?
  private var audioSession: AVAudioSession?
  private var initialVolume: Float = 0.5
  
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    startListening()
    return nil
  }
  
  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stopListening()
    self.eventSink = nil
    return nil
  }
  
  private func startListening() {
    audioSession = AVAudioSession.sharedInstance()
    
    // Configure audio session
    do {
      try audioSession?.setActive(true)
    } catch {
      print("⚠️ Error activating audio session: \(error)")
    }
    
    // Get initial volume
    initialVolume = audioSession?.outputVolume ?? 0.5
    
    // Observe volume changes
    audioSession?.addObserver(self, forKeyPath: "outputVolume", options: [.new, .old], context: nil)
    
    // Create hidden volume view to enable volume button detection
    setupVolumeView()
  }
  
  private func setupVolumeView() {
    guard let window = UIApplication.shared.windows.first else { return }
    
    // Create an MPVolumeView and hide it
    let volumeView = UIView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
    window.addSubview(volumeView)
    self.volumeView = volumeView
  }
  
  private func stopListening() {
    audioSession?.removeObserver(self, forKeyPath: "outputVolume")
    volumeView?.removeFromSuperview()
    volumeView = nil
    
    // Reset volume to initial value
    // Note: Can't programmatically set volume on iOS directly
  }
  
  override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
    if keyPath == "outputVolume" {
      guard let newValue = change?[.newKey] as? Float,
            let oldValue = change?[.oldKey] as? Float else {
        return
      }
      
      // Detect volume button press
      if newValue != oldValue {
        let direction = newValue > oldValue ? "up" : "down"
        eventSink?(direction)
        
        // Try to reset volume to prevent actual volume change
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
          guard let self = self else { return }
          // Note: MPVolumeView slider manipulation would go here
          // but it's increasingly restricted in newer iOS versions
        }
      }
    }
  }
}
