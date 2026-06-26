import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let voiceTriggerCoordinator = VoiceTriggerCoordinator()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "safe/voice_trigger",
        binaryMessenger: controller.binaryMessenger
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
    }

    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

private final class VoiceTriggerCoordinator {
  private var isListening = false

  func startListening(arguments: Any?) throws {
    guard !isListening else { return }

    _ = arguments as? [String: Any]

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
