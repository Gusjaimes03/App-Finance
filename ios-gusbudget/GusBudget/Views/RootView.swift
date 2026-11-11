import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: FinanceStore
    @StateObject private var bloqueo = AppLock()
    @Environment(\.scenePhase) private var fase

    enum Pestana: Hashable {
        case inicio, movimientos, presupuesto, pagos, balance

        /// Permite abrir la app en una pestaña concreta con -pestana <nombre>.
        /// Lo usan las capturas automáticas; en uso normal siempre es Inicio.
        static var inicial: Pestana {
            switch UserDefaults.standard.string(forKey: "pestana") {
            case "movimientos": return .movimientos
            case "presupuesto": return .presupuesto
            case "pagos": return .pagos
            case "balance": return .balance
            default: return .inicio
            }
        }
    }

    @State private var pestana: Pestana = .inicial

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $pestana) {
                InicioView()
                    .tabItem { Label("Inicio", systemImage: "house.fill") }
                    .tag(Pestana.inicio)

                MovimientosView()
                    .tabItem { Label("Movimientos", systemImage: "list.bullet.rectangle") }
                    .tag(Pestana.movimientos)

                PresupuestoView()
                    .tabItem { Label("Presupuesto", systemImage: "chart.pie") }
                    .tag(Pestana.presupuesto)

                PagosView()
                    .tabItem { Label("Pagos", systemImage: "calendar") }
                    .tag(Pestana.pagos)

                BalanceView()
                    .tabItem { Label("Balance", systemImage: "creditcard") }
                    .tag(Pestana.balance)
            }

            if let aviso = store.aviso {
                Toast(texto: aviso)
                    .padding(.bottom, 54)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.aviso)
        .task(id: store.aviso) {
            guard store.aviso != nil else { return }
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            if !Task.isCancelled { store.aviso = nil }
        }
        .overlay {
            if bloqueo.isLocked {
                pantallaBloqueo
            }
        }
        .onAppear {
            bloqueo.lockIfNeeded(enabled: store.data.ajustes.bloqueoActivo)
            if bloqueo.isLocked { bloqueo.unlock() }
        }
        .onChange(of: fase) { nueva in
            switch nueva {
            case .background:
                bloqueo.lockIfNeeded(enabled: store.data.ajustes.bloqueoActivo)
            case .active:
                if bloqueo.isLocked { bloqueo.unlock() }
            default:
                break
            }
        }
    }

    private var pantallaBloqueo: some View {
        ZStack {
            Theme.heroGradient.ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(Theme.sol)
                Text("Mi plata está cerrada")
                    .font(.headline)
                    .foregroundStyle(.white)
                Button("Desbloquear con \(AppLock.methodName)") {
                    bloqueo.unlock()
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.sol)
                .foregroundStyle(Theme.heroInicio)
                if let error = bloqueo.lastError {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
        }
    }
}
