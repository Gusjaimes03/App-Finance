import Foundation
import LocalAuthentication

/// Bloqueo opcional de la app con Face ID, Touch ID o el código del iPhone.
final class AppLock: ObservableObject {
    /// `true` cuando hay que pedir autenticación antes de mostrar los datos.
    @Published var isLocked = false
    @Published var lastError: String?

    /// ¿El dispositivo puede autenticar de alguna forma?
    static var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    /// Nombre del método disponible, para mostrarlo en Ajustes.
    static var methodName: String {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
            return "código"
        }
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "código"
        }
    }

    func lockIfNeeded(enabled: Bool) {
        if enabled { isLocked = true }
    }

    func unlock() {
        let context = LAContext()
        context.localizedCancelTitle = "Cancelar"

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
            // Sin código ni biometría configurados no tiene sentido mantener el bloqueo.
            isLocked = false
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Desbloquea GusBudget para ver tus finanzas"
        ) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.isLocked = false
                    self?.lastError = nil
                } else {
                    self?.lastError = error?.localizedDescription
                }
            }
        }
    }
}
