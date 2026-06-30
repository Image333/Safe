import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let voiceTriggerCoordinator = VoiceTriggerCoordinator()
  private var voiceTriggerMethodChannel: FlutterMethodChannel?

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
    }
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
