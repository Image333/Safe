import Flutter
import UIKit
import AVFoundation
import MediaPlayer

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

/// Détecte les appuis hardware volume via KVO sur `outputVolume`.
/// Remet le volume au milieu après chaque appui pour que Volume+ reste
/// détectable même quand le volume système est déjà à fond.
private final class VolumeButtonDetector: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var volumeView: MPVolumeView?
  private var volumeObservation: NSKeyValueObservation?
  private var baselineVolume: Float = 0.5
  private var isResettingVolume = false
  private var isObserving = false
  private var attachAttempts = 0
  private let maxAttachAttempts = 20

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
    guard !isObserving else { return }
    isObserving = true
    attachAttempts = 0

    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
      try session.setActive(true)
    } catch {
      print("⚠️ VolumeButtonDetector: session audio — \(error)")
    }

    baselineVolume = sanitizedVolume(session.outputVolume)

    // La fenêtre Flutter peut ne pas être prête immédiatement
    DispatchQueue.main.async { [weak self] in
      self?.attachVolumeViewAndObserve()
    }
  }

  private func attachVolumeViewAndObserve() {
    guard isObserving else { return }

    if volumeView == nil {
      setupVolumeView()
    }

    // Le slider interne de MPVolumeView apparaît parfois avec un léger délai
    if volumeSlider() == nil {
      attachAttempts += 1
      if attachAttempts >= maxAttachAttempts {
        // Observe quand même : la détection marche sans reset de volume
        print("⚠️ VolumeButtonDetector: slider indisponible, KVO seul")
        startVolumeObservation()
        return
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
        self?.attachVolumeViewAndObserve()
      }
      return
    }

    setSystemVolume(baselineVolume)
    startVolumeObservation()
  }

  private func startVolumeObservation() {
    guard volumeObservation == nil else { return }
    let session = AVAudioSession.sharedInstance()
    volumeObservation = session.observe(\.outputVolume, options: [.new, .old]) { [weak self] _, change in
      self?.handleVolumeChange(change: change)
    }
  }

  private func stopListening() {
    volumeObservation?.invalidate()
    volumeObservation = nil
    volumeView?.removeFromSuperview()
    volumeView = nil
    isObserving = false
    isResettingVolume = false
    attachAttempts = 0
  }

  private func setupVolumeView() {
    guard let hostView = keyWindow()?.rootViewController?.view ?? keyWindow() else {
      print("⚠️ VolumeButtonDetector: aucune fenêtre disponible")
      return
    }

    let view = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
    view.alpha = 0.01
    view.isUserInteractionEnabled = false
    view.showsRouteButton = false
    hostView.addSubview(view)
    volumeView = view
  }

  private func keyWindow() -> UIWindow? {
    let scenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }

    for scene in scenes {
      if let key = scene.windows.first(where: \.isKeyWindow) {
        return key
      }
    }
    return scenes.flatMap(\.windows).first
  }

  private func handleVolumeChange(change: NSKeyValueObservedChange<Float>) {
    guard let newValue = change.newValue else { return }

    if isResettingVolume {
      // Ignore le changement provoqué par notre reset programmatique
      if abs(newValue - baselineVolume) < 0.001 {
        isResettingVolume = false
      }
      return
    }

    let oldValue = change.oldValue ?? baselineVolume
    guard abs(newValue - oldValue) > 0.001 else { return }

    let direction = newValue > oldValue ? "up" : "down"
    DispatchQueue.main.async { [weak self] in
      self?.eventSink?(direction)
    }

    // Remet le volume au milieu pour pouvoir détecter les appuis suivants
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
      self?.resetVolumeToBaseline()
    }
  }

  private func resetVolumeToBaseline() {
    isResettingVolume = true
    setSystemVolume(baselineVolume)
  }

  private func setSystemVolume(_ value: Float) {
    guard let slider = volumeSlider() else { return }
    // setValue sans animation + un petit nudge force iOS à appliquer la valeur
    slider.value = value
    slider.sendActions(for: .touchUpInside)
  }

  private func volumeSlider() -> UISlider? {
    volumeView?.subviews.first(where: { $0 is UISlider }) as? UISlider
  }

  /// Évite 0 et 1 : à ces bornes, un appui volume ne change plus `outputVolume`.
  private func sanitizedVolume(_ volume: Float) -> Float {
    min(max(volume, 0.05), 0.95)
  }
}
