import Flutter
import UIKit
import AVFoundation
import MediaPlayer
import Speech

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var voiceTriggerMethodChannel: FlutterMethodChannel?
  private var volumeButtonDetector: VolumeButtonDetector?
  private var volumeButtonEventChannel: FlutterEventChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    super.application(application, didFinishLaunchingWithOptions: launchOptions)
    
    // Configurer les callbacks du VoiceTriggerManager
    setupVoiceTriggerCallbacks()
    
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
  
  private func setupVoiceTriggerCallbacks() {
    let manager = VoiceTriggerManager.shared
    
    manager.onKeywordDetected = {
      print("🚨 iOS: Mot-clé détecté - déclenchement enregistrement")
      // Vibration haptique pour confirmer
      let generator = UINotificationFeedbackGenerator()
      generator.notificationOccurred(.warning)
    }
    
    manager.onRecordingStarted = {
      print("🔴 iOS: Enregistrement d'urgence démarré")
    }
    
    manager.onRecordingFinished = { url in
      print("⬛ iOS: Enregistrement sauvegardé: \(url.path)")
      // TODO: Notifier Flutter pour mettre à jour l'historique
    }
    
    manager.onError = { error in
      print("⚠️ iOS: Erreur VoiceTrigger: \(error.localizedDescription)")
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
      guard self != nil else {
        callback(FlutterError(code: "unavailable", message: "AppDelegate unavailable", details: nil))
        return
      }
      
      let manager = VoiceTriggerManager.shared

      switch call.method {
      case "startListening":
        do {
          // Parser les arguments
          if let payload = call.arguments as? [String: Any] {
            let keyword = payload["keyword"] as? String ?? ""
            let recordingDurationSec = payload["recordingDurationSec"] as? Int ?? 15
            
            print("📱 iOS startListening: keyword='\(keyword)', duration=\(recordingDurationSec)s")
            
            // Parser la configuration de plage horaire
            var scheduleConfig: ScheduleConfig? = nil
            if let scheduleData = payload["schedule"] as? [String: Any] {
              let enabled = scheduleData["enabled"] as? Bool ?? false
              print("📱 iOS schedule: enabled=\(enabled)")
              if enabled {
                scheduleConfig = ScheduleConfig(
                  enabled: true,
                  startHour: scheduleData["startHour"] as? Int ?? 22,
                  startMinute: scheduleData["startMinute"] as? Int ?? 0,
                  endHour: scheduleData["endHour"] as? Int ?? 7,
                  endMinute: scheduleData["endMinute"] as? Int ?? 0,
                  days: scheduleData["days"] as? [Int] ?? [0, 1, 2, 3, 4, 5, 6]
                )
              }
            }
            
            manager.configure(
              keyword: keyword,
              recordingDurationSec: recordingDurationSec,
              schedule: scheduleConfig
            )
            print("📱 iOS: VoiceTriggerManager configuré")
          }
          
          try manager.startListening()
          print("📱 iOS: startListening() réussi")
          callback(nil)
        } catch {
          print("📱 iOS: startListening() ERREUR: \(error)")
          callback(FlutterError(code: "start_failed", message: error.localizedDescription, details: nil))
        }
        
      case "stopListening":
        manager.stopListening()
        callback(nil)
        
      case "requestSpeechPermission":
        SFSpeechRecognizer.requestAuthorization { status in
          DispatchQueue.main.async {
            callback(status == .authorized)
          }
        }
        
      case "checkSpeechPermission":
        let status = SFSpeechRecognizer.authorizationStatus()
        callback(status == .authorized)
        
      case "isListening":
        callback(manager.isListening)
        
      case "isRecording":
        callback(manager.isRecording)
        
      default:
        callback(FlutterMethodNotImplemented)
      }
    }

    voiceTriggerMethodChannel = channel
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
