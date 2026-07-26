import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let screenAwakeChannel = FlutterMethodChannel(
        name: "singlist/screen_awake",
        binaryMessenger: controller.binaryMessenger
      )
      screenAwakeChannel.setMethodCallHandler { call, result in
        guard call.method == "setEnabled" else {
          result(FlutterMethodNotImplemented)
          return
        }
        UIApplication.shared.isIdleTimerDisabled = call.arguments as? Bool ?? false
        result(nil)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
