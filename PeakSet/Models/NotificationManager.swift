import Foundation
import UserNotifications
import SwiftUI

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var permissionStatus: UNAuthorizationStatus = .notDetermined
    
    private init() {
        checkPermissionStatus()
    }
    
    func checkPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.permissionStatus = settings.authorizationStatus
                // Sync UserDefaults with actual permission status
                UserDefaults.standard.set(settings.authorizationStatus == .authorized, forKey: "notificationsEnabled")
                let statusString: String
                switch self.permissionStatus {
                case .notDetermined: statusString = "notDetermined"
                case .denied: statusString = "denied"
                case .authorized: statusString = "authorized"
                case .provisional: statusString = "provisional"
                case .ephemeral: statusString = "ephemeral"
                @unknown default: statusString = "unknown"
                }
                print("🔔 NotificationManager: Permission status: \(statusString) (\(self.permissionStatus.rawValue))")
            }
        }
    }
    
    func requestPermission() {
        // Only request if permission is not determined
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                    DispatchQueue.main.async {
                        if granted {
                            self.permissionStatus = .authorized
                            UserDefaults.standard.set(true, forKey: "notificationsEnabled")
                        } else {
                            self.permissionStatus = .denied
                            UserDefaults.standard.set(false, forKey: "notificationsEnabled")
                        }
                    }
                }
            } else {
                // Permission already determined, just update status
                DispatchQueue.main.async {
                    self.permissionStatus = settings.authorizationStatus
                    UserDefaults.standard.set(settings.authorizationStatus == .authorized, forKey: "notificationsEnabled")
                }
            }
        }
    }
    
    func sendWorkoutFeedbackNotification() {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled") else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🎯 Workout Analysis Complete"
        content.body = "Rex has analyzed your workout form. Check your feedback!"
        content.sound = .default
        content.badge = 1
        
        let request = UNNotificationRequest(
            identifier: "workout_feedback_\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send notification: \(error)")
            } else {
                print("✅ Workout feedback notification sent")
            }
        }
    }
    
    func sendFormAnalysisNotification() {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled") else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🏋️ Form Analysis Complete"
        content.body = "Your exercise form has been analyzed. Great work!"
        content.sound = .default
        content.badge = 1
        
        let request = UNNotificationRequest(
            identifier: "form_analysis_\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send notification: \(error)")
            } else {
                print("✅ Form analysis notification sent")
            }
        }
    }
    
}
