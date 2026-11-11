import SwiftUI

@main
struct GusBudgetApp: App {
    @StateObject private var store = FinanceStore()

    init() {
        #if DEBUG
        // Con -autopruebas 1 imprime el resultado de las autopruebas en la consola.
        if UserDefaults.standard.bool(forKey: "autopruebas") {
            for prueba in Autopruebas.correr() {
                print("AUTOPRUEBA \(prueba.pasa ? "OK " : "FALLA") \(prueba.nombre): \(prueba.detalle)")
            }
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environment(\.locale, Fmt.locale)
                .tint(Theme.acento)
        }
    }
}
