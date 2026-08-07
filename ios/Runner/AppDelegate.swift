import Flutter
import UIKit
import AVFoundation
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
