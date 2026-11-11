import Foundation
import UserNotifications

/// Las apps firmadas con un Apple ID gratuito caducan a los 7 días.
/// Esto programa un aviso local para volver a instalarla antes de que pase.
enum RenewalReminder {
    static let identifier = "gusbudget.renewal"
    /// Días de validez de un perfil de aprovisionamiento gratuito.
    static let validityDays = 7

    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Programa el aviso un día antes de que caduque la firma.
    static func schedule(signedOn date: Date) async {
        cancel()

        let expiry = Calendar.app.date(byAdding: .day, value: validityDays, to: date) ?? date
        guard let fireDate = Calendar.app.date(byAdding: .day, value: -1, to: expiry),
              fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "GusBudget caduca mañana"
        content.body = "Vuelve a instalarla para no perder el acceso. Tus datos se quedan en el teléfono."
        content.sound = .default

        var components = Calendar.app.dateComponents([.year, .month, .day], from: fireDate)
        components.hour = 10
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// Días que faltan para que caduque la firma (nil si no se registró la fecha).
    static func daysRemaining(signedOn date: Date?) -> Int? {
        guard let date else { return nil }
        let expiry = Calendar.app.date(byAdding: .day, value: validityDays, to: date) ?? date
        return expiry.days(since: Date())
    }
}
