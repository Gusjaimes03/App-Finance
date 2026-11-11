import SwiftUI

/// Lo tuyo en plata: cajitas, lo que te deben y lo que debes (sección 2.5).
struct BalanceView: View {
    @EnvironmentObject private var store: FinanceStore

    @State private var solicitud: SolicitudValor?
    @State private var nuevaCajita = ""
    @State private var nuevaCajitaMeta = ""
    @State private var mostrarPrestamo = false
    @State private var mostrarDeuda = false
    @State private var quitandoCajita: Cajita?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    patrimonio
                    cajitas
                    meDeben
                    debo
                }
                .columna()
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.fondo)
            .navigationTitle("Balance")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $solicitud) { peticion in
                HojaValorReal(solicitud: peticion)
            }
            .sheet(isPresented: $mostrarPrestamo) {
                HojaPrestamo().environmentObject(store)
            }
            .sheet(isPresented: $mostrarDeuda) {
                HojaNuevaDeuda().environmentObject(store)
            }
            .confirmationDialog(
                "¿Quitar la cajita?",
                isPresented: Binding(get: { quitandoCajita != nil }, set: { if !$0 { quitandoCajita = nil } }),
                titleVisibility: .visible
            ) {
                if let cajita = quitandoCajita {
                    Button("Quitar · los \(Fmt.plata(cajita.guardado)) vuelven a tu plata libre", role: .destructive) {
                        store.quitarCajita(cajita)
                        quitandoCajita = nil
                    }
                }
                Button("Cancelar", role: .cancel) { quitandoCajita = nil }
            }
        }
    }

    // MARK: Patrimonio

    private var patrimonio: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Lo tuyo, en plata")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))

            Text(Fmt.plata(store.patrimonio))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.sol)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            HStack(spacing: 8) {
                Mosaico(titulo: "Plata libre", valor: Fmt.plata(store.libre),
                        color: store.libre < 0 ? Theme.rojo : .white, sobreOscuro: true)
                Mosaico(titulo: "En cajitas", valor: Fmt.plata(store.enCajitas), color: .white, sobreOscuro: true)
                Mosaico(titulo: "Me deben", valor: Fmt.plata(store.totalMeDeben), color: .white, sobreOscuro: true)
            }
            HStack(spacing: 8) {
                Mosaico(titulo: "Debo", valor: Fmt.plata(store.totalDebo), color: .white, sobreOscuro: true)
                Mosaico(titulo: "Pagas a cuotas", valor: Fmt.plata(store.valorDeBienes), color: .white, sobreOscuro: true)
            }

            Text("No incluye la moto ni el ganado.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.heroGradient)
        )
    }

    // MARK: Cajitas

    private var cajitas: some View {
        VStack(alignment: .leading, spacing: 14) {
            TituloSeccion(texto: "Cajitas de ahorro", detalle: "Plata apartada para algo")

            ForEach(store.data.cajitas.sorted(by: { $0.orden < $1.orden })) { cajita in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(cajita.nombre)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Theme.texto)
                            if !cajita.nota.isEmpty {
                                Text(cajita.nota)
                                    .font(.caption2)
                                    .foregroundStyle(Theme.gris)
                            }
                        }
                        Spacer(minLength: 4)
                        Text("\(Fmt.plata(cajita.guardado)) de \(Fmt.plata(cajita.meta))")
                            .font(.caption)
                            .foregroundStyle(Theme.gris)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }

                    BarraProgreso(avance: cajita.avance, color: cajita.color)

                    Text(cajita.completa
                         ? "¡Completa!"
                         : "Te faltan \(Fmt.plata(cajita.falta)) (\(Fmt.porcentaje(cajita.avance)))")
                        .font(.caption2)
                        .foregroundStyle(cajita.completa ? Theme.verde : Theme.gris)

                    HStack(spacing: 8) {
                        Button("Guardar plata") {
                            let sugerido = min(cajita.falta, max(0, store.libre))
                            solicitud = SolicitudValor(
                                titulo: cajita.nombre,
                                pregunta: "¿Cuánto guardas?",
                                montoSugerido: sugerido
                            ) { monto, _ in
                                store.guardarEnCajita(cajita, monto: monto)
                            }
                        }
                        .font(.caption2.weight(.semibold))
                        .buttonStyle(.borderedProminent)
                        .tint(cajita.color)
                        .controlSize(.mini)

                        Button("Sacar") {
                            solicitud = SolicitudValor(
                                titulo: cajita.nombre,
                                pregunta: "¿Cuánto sacas?",
                                montoSugerido: cajita.guardado
                            ) { monto, _ in
                                store.sacarDeCajita(cajita, monto: monto)
                            }
                        }
                        .font(.caption2)
                        .buttonStyle(.bordered)
                        .controlSize(.mini)

                        Spacer()

                        Button("Quitar") { quitandoCajita = cajita }
                            .font(.caption2)
                            .foregroundStyle(Theme.rojo)
                    }
                }
                .padding(.vertical, 3)
            }

            Divider()

            VStack(spacing: 8) {
                TextField("Nombre de la cajita", text: $nuevaCajita)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Text("Meta")
                        .font(.subheadline)
                        .foregroundStyle(Theme.gris)
                    CampoPlata(texto: $nuevaCajitaMeta, alineacion: .trailing)
                    Button("Crear") {
                        store.crearCajita(
                            nombre: nuevaCajita.trimmingCharacters(in: .whitespaces),
                            meta: Fmt.leerPlata(nuevaCajitaMeta) ?? 0
                        )
                        nuevaCajita = ""
                        nuevaCajitaMeta = ""
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(nuevaCajita.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .panel()
    }

    // MARK: Me deben

    private var meDeben: some View {
        VStack(alignment: .leading, spacing: 12) {
            TituloSeccion(texto: "Me deben", detalle: Fmt.plata(store.totalMeDeben))

            if store.cobrosPendientes.isEmpty {
                Vacio(simbolo: "hand.thumbsup", texto: "Nadie te debe nada.")
            } else {
                ForEach(store.cobrosPendientes) { cobro in
                    HStack(spacing: 10) {
                        IconoCuadro(simbolo: cobro.simbolo, color: Theme.verde, lado: 32)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(cobro.persona ?? cobro.nombre)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Theme.texto)
                            Text("Prestaste \(Fmt.plata(cobro.montoOriginal ?? cobro.monto))"
                                 + (cobro.nota.map { " · \($0)" } ?? ""))
                                .font(.caption2)
                                .foregroundStyle(Theme.gris)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(Fmt.plata(cobro.monto))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.texto)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Button("Me pagó") {
                                solicitud = SolicitudValor(
                                    titulo: cobro.persona ?? cobro.nombre,
                                    pregunta: "¿Cuánto te pagó?",
                                    montoSugerido: cobro.monto
                                ) { monto, fecha in
                                    store.registrarCobro(cobro, monto: monto, fecha: fecha)
                                }
                            }
                            .font(.caption2.weight(.semibold))
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.verde)
                            .controlSize(.mini)
                        }
                    }
                }
            }

            Button {
                mostrarPrestamo = true
            } label: {
                Label("Presté plata", systemImage: "arrow.up.right.circle")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .panel()
    }

    // MARK: Lo que debo

    private var debo: some View {
        VStack(alignment: .leading, spacing: 12) {
            TituloSeccion(texto: "Lo que debo", detalle: Fmt.plata(store.totalDebo))

            ForEach(store.data.deudas.sorted(by: { $0.orden < $1.orden })) { deuda in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(deuda.nombre)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Theme.texto)
                            if !deuda.nota.isEmpty {
                                Text(deuda.nota)
                                    .font(.caption2)
                                    .foregroundStyle(Theme.gris)
                                    .lineLimit(2)
                            }
                        }
                        Spacer(minLength: 4)
                        if deuda.pagada {
                            Text("Pagada")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Theme.verde.opacity(0.15)))
                                .foregroundStyle(Theme.verde)
                        } else {
                            Text(Fmt.plata(deuda.saldo))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.texto)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }

                    BarraProgreso(avance: deuda.avance, color: Theme.acento, alto: 6)
                    Text("Llevas pagado \(Fmt.plata(deuda.pagado)) de \(Fmt.plata(deuda.original))")
                        .font(.caption2)
                        .foregroundStyle(Theme.gris)

                    HStack(spacing: 8) {
                        Spacer()
                        if deuda.pagada {
                            Button("Quitar") { store.quitarDeuda(deuda) }
                                .font(.caption2)
                                .foregroundStyle(Theme.rojo)
                        } else {
                            Button("Abonar") {
                                solicitud = SolicitudValor(
                                    titulo: deuda.nombre,
                                    pregunta: "¿Cuánto abonas?",
                                    montoSugerido: deuda.cuota ?? deuda.saldo
                                ) { monto, fecha in
                                    store.abonarDeuda(deuda, monto: monto, fecha: fecha)
                                }
                            }
                            .font(.caption2.weight(.semibold))
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.acento)
                            .controlSize(.mini)
                        }
                    }
                }
                .padding(.vertical, 3)
            }

            Button {
                mostrarDeuda = true
            } label: {
                Label("Agregar una deuda", systemImage: "plus.circle")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .panel()
    }
}

/// "Presté plata": registra la salida y deja el cobro pendiente.
struct HojaPrestamo: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var cerrar

    @State private var persona = ""
    @State private var texto = ""
    @State private var nota = ""
    @State private var fecha = Date()
    @State private var conPlazo = false
    @State private var plazo = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("¿A quién?") {
                    TextField("Nombre", text: $persona)
                }
                Section("¿Cuánto?") {
                    CampoPlata(texto: $texto, alineacion: .trailing)
                }
                Section("¿Cuándo se lo diste?") {
                    DatePicker("Fecha", selection: $fecha, displayedComponents: .date)
                        .environment(\.locale, Fmt.locale)
                }
                Section("¿Cuándo te paga?") {
                    Toggle("Tiene fecha", isOn: $conPlazo)
                    if conPlazo {
                        DatePicker("Fecha", selection: $plazo, displayedComponents: .date)
                            .environment(\.locale, Fmt.locale)
                    }
                }
                Section("Nota") {
                    TextField("Opcional", text: $nota)
                }
            }
            .navigationTitle("Presté plata")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        if let monto = Fmt.leerPlata(texto) {
                            store.prestarPlata(
                                persona: persona.trimmingCharacters(in: .whitespaces),
                                monto: monto,
                                fecha: fecha,
                                cuandoPaga: conPlazo ? plazo : nil,
                                nota: nota
                            )
                        }
                        cerrar()
                    }
                    .fontWeight(.semibold)
                    .disabled(persona.trimmingCharacters(in: .whitespaces).isEmpty || Fmt.leerPlata(texto) == nil)
                }
            }
        }
    }
}

struct HojaNuevaDeuda: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var cerrar

    @State private var nombre = ""
    @State private var saldo = ""
    @State private var cuota = ""
    @State private var nota = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("¿A quién le debes?") {
                    TextField("Nombre", text: $nombre)
                }
                Section("Saldo") {
                    CampoPlata(texto: $saldo, alineacion: .trailing)
                }
                Section("Cuota (opcional)") {
                    CampoPlata(texto: $cuota, alineacion: .trailing)
                }
                Section("Nota") {
                    TextField("Opcional", text: $nota)
                }
            }
            .navigationTitle("Nueva deuda")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Agregar") {
                        if let valor = Fmt.leerPlata(saldo) {
                            store.agregarDeuda(
                                nombre: nombre.trimmingCharacters(in: .whitespaces),
                                saldo: valor,
                                cuota: Fmt.leerPlata(cuota),
                                nota: nota
                            )
                        }
                        cerrar()
                    }
                    .fontWeight(.semibold)
                    .disabled(nombre.trimmingCharacters(in: .whitespaces).isEmpty || Fmt.leerPlata(saldo) == nil)
                }
            }
        }
    }
}
