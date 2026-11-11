#if DEBUG
import SwiftUI

/// Catálogo de componentes para revisar el sistema de diseño en el simulador.
/// Se abre con: xcrun simctl launch booted com.gusjaimes.GusBudget -galeriaDiseno YES
struct GaleriaDiseno: View {
    @State private var texto = "18.000"
    @State private var chip = "Todo"
    @State private var categoria = "comida"
    @State private var mes = Date()
    /// -galeriaParte 2 o 3 muestra solo esa parte (para capturas sin scroll).
    private let parte = UserDefaults.standard.integer(forKey: "galeriaParte")

    private let tramos = [
        TramoDona(id: "comida", valor: 420_000, color: Color(hex: "e8930c"), nombre: "Comida y mercado"),
        TramoDona(id: "salidas", valor: 180_000, color: Color(hex: "db3f8c"), nombre: "Salidas y planes"),
        TramoDona(id: "gasolina", valor: 120_000, color: Color(hex: "e0443a"), nombre: "Gasolina"),
        TramoDona(id: "otras", valor: 60_000, color: Theme.gris, nombre: "Otras")
    ]

    private var dias: [TotalDia] {
        (0..<30).map { indice in
            let fecha = Calendar.app.date(byAdding: .day, value: indice - 9, to: Date()) ?? Date()
            let valor = indice > 9 ? 0 : Decimal([12_000, 48_000, 0, 23_000, 61_000, 8_000, 0, 35_000, 19_000, 27_000][indice])
            return TotalDia(fecha: fecha, total: valor)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Espacio.seccion) {
                    if parte <= 1 {
                    TarjetaHero {
                        Text("Hoy puedes gastar")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.gris)
                        CifraPlata(valor: 54_300, estilo: .hero, color: Theme.sol)
                        Text("Hasta el 15 · quedan 6 días")
                            .font(.subheadline)
                            .foregroundStyle(Theme.gris)
                        ResumenDatos(datos: [
                            DatoResumen(titulo: "Plata libre", valor: 1_250_000),
                            DatoResumen(titulo: "Ahorrado", valor: 300_000),
                            DatoResumen(titulo: "Gastado esta semana", valor: 182_000)
                        ], sobreOscuro: true)
                        .padding(.top, Espacio.xs)
                    }

                    BannerAviso(titulo: "Comida y mercado va en 92 %", mensaje: "+2 avisos más", tono: .aviso) {}

                    VStack(alignment: .leading, spacing: Espacio.titulo) {
                        EncabezadoSeccion(titulo: "Próximos pagos", accionTitulo: "Ver todos") {}
                        VStack(spacing: 0) {
                            FilaLista(simbolo: "house.fill", color: Theme.acento, titulo: "Arriendo",
                                      subtitulo: "28 de nov", insignia: Insignia(texto: "Pronto", tono: .aviso),
                                      valor: 1_000_000, signo: .ninguno)
                            SeparadorFila()
                            FilaLista(simbolo: "fork.knife", color: Color(hex: "e8930c"), titulo: "Almuerzo",
                                      subtitulo: "Comida · 12:30", valor: 18_000, signo: .salida)
                            SeparadorFila()
                            FilaLista(simbolo: "plus.circle.fill", color: Theme.verde, titulo: "Freelance",
                                      subtitulo: "Ingreso", valor: 450_000, signo: .entrada)
                        }
                        .panel(padding: 0)
                    }
                    }

                    if parte <= 2 {
                    VStack(alignment: .leading, spacing: Espacio.titulo) {
                        EncabezadoSeccion(titulo: "En qué se va tu plata", detalle: Fmt.mes(Date()))
                        DonaConLeyenda(tramos: tramos, total: 780_000).panel()
                    }

                    VStack(alignment: .leading, spacing: Espacio.titulo) {
                        EncabezadoSeccion(titulo: "Día por día")
                        BarrasPorDia(dias: dias, presupuestoDiario: 30_000).panel()
                    }

                    VStack(alignment: .leading, spacing: Espacio.s) {
                        MesNavegador(mes: $mes)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Espacio.xs) {
                                ForEach(["Todo", "Gastos", "Ingresos", "Pagos"], id: \.self) { titulo in
                                    Chip(titulo: titulo, seleccionado: chip == titulo) { chip = titulo }
                                }
                            }
                        }
                        HStack {
                            Insignia(texto: "Vencido", tono: .negativo)
                            Insignia(texto: "Pronto", tono: .aviso)
                            Insignia(texto: "Pagado", tono: .positivo, simbolo: "checkmark")
                            Insignia(texto: "Fijo", tono: .tinte)
                        }
                        HStack(spacing: Espacio.m) {
                            AnilloProgreso(conPorcentaje: 0.72)
                            AnilloProgreso(conPorcentaje: 0.93, color: Theme.ambar)
                            VStack(spacing: Espacio.s) {
                                BarraProgreso(avance: 0.45, color: Theme.colorAvance(0.45))
                                BarraProgreso(avance: 0.86, color: Theme.colorAvance(0.86))
                                BarraProgreso(avance: 1.2, color: Theme.colorAvance(1.2))
                            }
                        }
                    }
                    .panel()
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 10) {
                        ForEach(Semilla.categorias.prefix(6)) { c in
                            MosaicoCategoria(simbolo: c.simbolo, color: c.color, nombre: c.nombre,
                                             seleccionado: c.id == categoria) { categoria = c.id }
                        }
                    }

                    VStack(spacing: Espacio.s) {
                        CampoPlata(texto: $texto, grande: true, alineacion: .center)
                        Button("Guardar gasto") {}.buttonStyle(.principal)
                        Button("Siguiente") {}.buttonStyle(.principal).disabled(true)
                        HStack {
                            Button("Guardar plata") {}.buttonStyle(.secundario)
                            Button("Borrar") {}.buttonStyle(.secundario(Theme.rojo))
                            Spacer()
                            BotonCheck(etiqueta: "Ya pagué") {}
                            BotonCheck(hecho: true, etiqueta: "Pagado") {}
                            MenuMas { Button("Borrar", role: .destructive) {} }
                        }
                    }
                    .panel()

                    EstadoVacio(simbolo: "sparkles", titulo: "Registra tu primer gasto",
                                mensaje: "Así sabrás cuánto puedes gastar cada día.",
                                accionTitulo: "Registrar gasto") {}
                        .panel()

                    Toast(texto: "Gasto guardado", accionTitulo: "Deshacer") {}
                }
                .contenidoPantalla()
            }
            .fondoPantalla()
            .navigationTitle("Diseño")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
#endif
