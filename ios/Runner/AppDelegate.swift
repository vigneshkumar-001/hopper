import UIKit
import Flutter
import GoogleMaps
import Firebase
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, UNUserNotificationCenterDelegate {

  override func application(
      _ application: UIApplication,
      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Initialize Google Maps
    GMSServices.provideAPIKey("AIzaSyCvU6g43_aujUMDTTHpCtg1wkHszDhdC28") // Replace with your key

    // Initialize Firebase
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }

    // Set UNUserNotificationCenter delegate
    UNUserNotificationCenter.current().delegate = self

    // Request push notification permissions
    let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
    UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
      if let error = error {
        print("Push permission error: \(error.localizedDescription)")
      } else {
        print("Push permission granted: \(granted)")
      }
    }

    // Register for remote notifications
    application.registerForRemoteNotifications()

    // Register Flutter plugins
    GeneratedPluginRegistrant.register(with: self)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - Foreground notification handling
  override func userNotificationCenter(
      _ center: UNUserNotificationCenter,
      willPresent notification: UNNotification,
      withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // Show notification even when app is in foreground
    completionHandler([.alert, .badge, .sound])
  }

  // MARK: - Notification tap handling
  override func userNotificationCenter(
      _ center: UNUserNotificationCenter,
      didReceive response: UNNotificationResponse,
      withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    // You can read response.notification.request.content.userInfo here
    completionHandler()
  }
}



// import Flutter
// import UIKit
//
// @main
// @objc class AppDelegate: FlutterAppDelegate {
//   override func application(
//     _ application: UIApplication,
//     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
//   ) -> Bool {
//     GeneratedPluginRegistrant.register(with: self)
//     return super.application(application, didFinishLaunchingWithOptions: launchOptions)
//   }
// }
// import UIKit
// import Flutter
// import GoogleMaps
// import Firebase
//
// @main
// @objc class AppDelegate: FlutterAppDelegate {
//
//   override func application(
//       _ application: UIApplication,
//       didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
//   ) -> Bool {
//
//     // Initialize Google Maps SDK with your API key
//     GMSServices.provideAPIKey("AIzaSyCvU6g43_aujUMDTTHpCtg1wkHszDhdC28")
//
//     // Initialize Firebase (if needed for native plugins)
//     if FirebaseApp.app() == nil {
//       FirebaseApp.configure()
//     }
//
//     // Register Flutter plugins
//     GeneratedPluginRegistrant.register(with: self)
//
//     return super.application(application, didFinishLaunchingWithOptions: launchOptions)
//   }
// }
