import SwiftUI

@main
struct GusBudgetApp: App {
    @StateObject private var store = FinanceStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environment(\.locale, Fmt.locale)
                .tint(Theme.acento)
        }
    }
}
