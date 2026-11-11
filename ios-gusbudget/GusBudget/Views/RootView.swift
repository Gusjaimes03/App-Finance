import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject private var store: FinanceStore
    @StateObject private var bloqueo = AppLock()
    @Environment(\.scenePhase) private var fase
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    enum Pestana: String, Hashable, CaseIterable {
        case inicio, movimientos, presupuesto, pagos, balance
    }

    @State private var pestana: Pestana
    @State private var mostrarRegistro = false
    @State private var tecladoVisible = false
    /// Acción "Deshacer" que acompaña al aviso actual.
    @State private var deshacer: (() -> Void)?
    /// Texto del aviso para el que se ofreció `deshacer`. Si llega otro aviso, el deshacer ya no aplica.
    @State private var avisoDeshacer: String?
    @State private var mostrarGaleria = false

    init() {
        var inicial = Pestana.inicio
        #if DEBUG
        // Para capturas: xcrun simctl launch booted com.gusjaimes.GusBudget -pestanaInicial pagos
        // (las capturas de GitHub Actions usan -pestana pagos).
        let defaults = UserDefaults.standard
        if let valor = defaults.string(forKey: "pestanaInicial") ?? defaults.string(forKey: "pestana"),
           let elegida = Pestana(rawValue: valor) {
            inicial = elegida
        }
        #endif
        _pestana = State(initialValue: inicial)
    }

    private var accionDeshacer: AccionDeshacer {
        AccionDeshacer { texto, accion in
            if let texto { store.aviso = texto }
            deshacer = accion
            avisoDeshacer = accion == nil ? nil : store.aviso
        }
    }

    private var animacion: Animation? {
        reducirMovimiento ? nil : .spring(response: 0.35, dampingFraction: 0.85)
    }

    var body: some View {
        TabView(selection: $pestana) {
            InicioView()
                .modifier(BarraInferior(activa: pestana == .inicio, contenido: barraInferior))
                .tabItem { Label("Inicio", systemImage: "house") }
                .tag(Pestana.inicio)

            MovimientosView()
                .modifier(BarraInferior(activa: pestana == .movimientos, contenido: barraInferior))
                .tabItem { Label("Movimientos", systemImage: "list.bullet.rectangle") }
                .tag(Pestana.movimientos)

            PresupuestoView()
                .modifier(BarraInferior(activa: pestana == .presupuesto, contenido: barraInferior))
                .tabItem { Label("Presupuesto", systemImage: "chart.pie") }
                .tag(Pestana.presupuesto)

            PagosView()
                .modifier(BarraInferior(activa: pestana == .pagos, contenido: barraInferior))
                .tabItem { Label("Pagos", systemImage: "calendar") }
                .tag(Pestana.pagos)

            BalanceView()
                .modifier(BarraInferior(activa: pestana == .balance, contenido: barraInferior))
                .tabItem { Label("Balance", systemImage: "dollarsign.circle") }
                .tag(Pestana.balance)
        }
        .tint(Theme.acento)
        .environment(\.abrirRegistro, AccionAbrirRegistro { mostrarRegistro = true })
        .environment(\.ofrecerDeshacer, accionDeshacer)
        .environment(\.irAPestana, AccionIrAPestana { destino in
            withAnimation(animacion) { pestana = destino }
        })
        .sheet(isPresented: $mostrarRegistro) {
            // La hoja se presenta fuera de los .environment de arriba: se le pasa explícito
            // para que "Deshacer" funcione después de guardar desde el "+".
            HojaRegistrar()
                .environmentObject(store)
                .environment(\.ofrecerDeshacer, accionDeshacer)
        }
        #if DEBUG
        .fullScreenCover(isPresented: $mostrarGaleria) {
            GaleriaDiseno()
        }
        #endif
        .task(id: "\(store.aviso ?? "")#\(avisoDeshacer ?? "")#\(deshacerVigente == nil ? 0 : 1)") {
            guard store.aviso != nil else { return }
            var segundos: Double = deshacerVigente == nil ? 2.8 : 5
            if UIAccessibility.isVoiceOverRunning { segundos *= 2 }
            try? await Task.sleep(nanoseconds: UInt64(segundos * 1_000_000_000))
            if !Task.isCancelled {
                withAnimation(animacion) {
                    store.aviso = nil
                    deshacer = nil
                    avisoDeshacer = nil
                }
            }
        }
        .onChange(of: store.aviso) { nuevo in
            if let nuevo {
                UIAccessibility.post(notification: .announcement, argument: nuevo)
            }
            // Un aviso distinto al que ofreció el deshacer lo invalida.
            if nuevo != avisoDeshacer {
                deshacer = nil
                avisoDeshacer = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            tecladoVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            tecladoVisible = false
        }
        .overlay {
            if bloqueo.isLocked {
                PantallaBloqueo(bloqueo: bloqueo)
                    .transition(.opacity)
            }
        }
        .onAppear {
            bloqueo.lockIfNeeded(enabled: store.data.ajustes.bloqueoActivo)
            if bloqueo.isLocked { bloqueo.unlock() }
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "abrirRegistro") { mostrarRegistro = true }
            if UserDefaults.standard.bool(forKey: "galeriaDiseno") { mostrarGaleria = true }
            #endif
        }
        // Las hojas abiertas quedan por encima del overlay: el bloqueo también va en una
        // ventana propia sobre todo, para que no se vean cifras en el selector de apps.
        .onChange(of: bloqueo.isLocked) { bloqueado in
            if bloqueado {
                VentanaBloqueo.mostrar(PantallaBloqueo(bloqueo: bloqueo))
            } else {
                VentanaBloqueo.ocultar()
            }
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

    /// El deshacer solo vale para el aviso que lo ofreció.
    private var deshacerVigente: (() -> Void)? {
        guard let deshacer, let aviso = store.aviso, aviso == avisoDeshacer else { return nil }
        return deshacer
    }

    // MARK: Barra inferior (toast + botón flotante)

    /// Lo que flota sobre la barra de pestañas: el aviso a la izquierda y el "+" a la derecha.
    @ViewBuilder
    private func barraInferior(activa: Bool) -> some View {
        let aviso = activa ? store.aviso : nil
        let undo = deshacerVigente
        if tecladoVisible && aviso == nil {
            EmptyView()
        } else {
            HStack(alignment: .bottom, spacing: Espacio.s) {
                ZStack(alignment: .bottomLeading) {
                    Color.clear.frame(height: 1)
                    if let aviso {
                        Toast(
                            texto: aviso,
                            accionTitulo: undo == nil ? nil : "Deshacer",
                            accion: undo == nil ? nil : {
                                withAnimation(animacion) {
                                    deshacer = nil
                                    avisoDeshacer = nil
                                    store.aviso = nil
                                }
                                Haptics.tap()
                                undo?()
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !tecladoVisible {
                    BotonFlotante { mostrarRegistro = true }
                }
            }
            .padding(.horizontal, Espacio.m)
            .padding(.bottom, Espacio.s)
            .animation(animacion, value: aviso)
        }
    }

}

// MARK: - Bloqueo

/// Pantalla de bloqueo con Face ID / código. Se usa como overlay y en `VentanaBloqueo`.
private struct PantallaBloqueo: View {
    @ObservedObject var bloqueo: AppLock

    var body: some View {
        ZStack {
            FondoHero(radio: 0)
                .ignoresSafeArea()

            VStack(spacing: Espacio.l) {
                Spacer()
                ZStack {
                    Circle()
                        .fill(Theme.sol.opacity(0.16))
                        .frame(width: 112, height: 112)
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 84, height: 84)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(Theme.sol)
                }
                .accessibilityHidden(true)

                VStack(spacing: Espacio.xs) {
                    Text("Mi plata")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                    Text("Tus cuentas están protegidas")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.72))
                }
                Spacer()

                VStack(spacing: Espacio.s) {
                    Button {
                        bloqueo.unlock()
                    } label: {
                        Label("Desbloquear con \(AppLock.methodName)",
                              systemImage: AppLock.methodName == "Face ID" ? "faceid" : "lock.open.fill")
                    }
                    .buttonStyle(.principal(Theme.sol, texto: Theme.sobreSol))

                    if let error = bloqueo.lastError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.72))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, Espacio.xxl)
                .padding(.bottom, Espacio.xl)
            }
        }
        .environment(\.colorScheme, .dark)
    }
}

/// Ventana encima de todo (incluidas las hojas) mientras la app está bloqueada.
private enum VentanaBloqueo {
    private static var ventana: UIWindow?

    static func mostrar<V: View>(_ vista: V) {
        guard ventana == nil,
              let escena = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState != .unattached }) else { return }
        let nueva = UIWindow(windowScene: escena)
        let host = UIHostingController(rootView: vista)
        host.view.backgroundColor = .clear
        nueva.rootViewController = host
        nueva.windowLevel = .alert + 1
        nueva.isHidden = false
        ventana = nueva
    }

    static func ocultar() {
        ventana?.isHidden = true
        ventana = nil
    }
}

/// Inserta la barra inferior (toast + botón flotante) como margen seguro de la pestaña,
/// así el contenido con scroll nunca queda tapado por el botón.
private struct BarraInferior<Barra: View>: ViewModifier {
    let activa: Bool
    let contenido: (Bool) -> Barra

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            contenido(activa)
        }
    }
}
