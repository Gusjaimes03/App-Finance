# Mi plata · Sistema de diseño "Llano de noche"

Una app de finanzas tranquila, nativa y centrada en los números. La cifra grande es la protagonista. Casi todo va plano sobre fondos agrupados, con **una sola tarjeta hero por pantalla**. El azul noche es la marca y el color interactivo. El amarillo sol es escaso: la cifra que importa, la barra de hoy y el CTA sobre oscuro. Mínimo iOS 16: todo lo de aquí funciona en iOS 16.

Galería viva (solo DEBUG): `xcrun simctl launch booted com.gusjaimes.GusBudget -galeriaDiseno YES [-galeriaParte 2|3]`
Abrir una pestaña: `-pestanaInicial inicio|movimientos|presupuesto|pagos|balance` · Abrir la hoja de registro: `-abrirRegistro YES`

---

## 1. Tokens

### Color (`Theme.*`, claro / oscuro)

| Token | Claro | Oscuro | Uso |
|---|---|---|---|
| `fondo` | F4F5F8 | 05070F | Fondo de cada pantalla (`.fondoPantalla()`) |
| `panel` = `superficie` | FFFFFF | 10152A | Tarjetas, grupos de filas |
| `elevada` | FFFFFF | 171D36 | Hojas, tooltips |
| `hundido` | ECEEF3 | 1A2140 | Campos, chips, mosaicos dentro de tarjetas, botones de ícono |
| `linea` | E3E6EE | 232B4A | Separadores de 0,5 pt |
| `pista` | E9ECF2 | 1C2342 | Pista de barras, anillos y donas |
| `texto` | 0E1428 | F2F4FA | Texto principal |
| `gris` | 5A637A | A3ABC2 | Secundario: subtítulos, fechas, etiquetas |
| `grisClaro` | 8A92A8 | 6B7391 | Terciario: marcadores, ejes. Nunca para información clave |
| `acento` | 2B48D8 | 8EA6FF | ÚNICO color interactivo: botones, enlaces, selección, gastos en gráficas |
| `acentoSuave` | E7ECFC | 1B2552 | Fondo de insignia o ícono con tinte |
| `sobreAcento` | FFFFFF | 0A1030 | Texto o ícono sobre `acento` |
| `heroInicio` → `heroFin` | 0C1433 → 1A2A6B | 0B1230 → 15225A | Degradado de marca (`heroGradient`, `FondoHero`) |
| `sol` / `solSuave` / `sobreSol` | FFB020 / FFF1D1 / 1A1200 | FFC247 / 3A2C0A | Cifra protagonista, barra de hoy, CTA sobre oscuro |
| `verde` / `verdeSuave` | 0B7D4C / E3F5EC | 4ED19A / 0F2A20 | Plata que ENTRA, estados buenos, "Pagado" |
| `ambar` / `ambarSuave` | 9A5B00 / FDF0DC | F5B651 / 33250C | "Ojo": pronto, del 80 al 100 % del presupuesto (texto) |
| `ambarRelleno` | F0A019 | F5B651 | Ámbar para rellenos (barras, anillos) |
| `rojo` / `rojoSuave` | D1342B / FCE6E4 | FF7A70 / 3A1614 | SOLO vencido, pasado del presupuesto, error, borrar |
| `sombra`, `sombraCercana`, `bordeTarjeta` | sombra 6 % / 4 % | sin sombra, borde blanco al 6 % | Elevación (ya incluida en `.panel()`) |

**Significados fijos:**
- Plata que SALE se escribe en `Theme.texto` con "−", nunca en rojo.
- Plata que ENTRA va en `verde` con "+".
- Rojo solo cuando algo está mal.
- `Theme.colorAvance(avance)` da el color de una barra de presupuesto: acento por debajo del 80 %, ámbar del 80 al 100 % y rojo por encima.
- Los colores de categoría (`Color(hex:)`) se aclaran solos en modo oscuro; el hex guardado no se toca. Para un color que no debe cambiar usa `Color(hex:, adaptar: false)`.

### Espacio (`Espacio.*`, base 4)
`xxs 4 · xs 8 · s 12 · m 16 · l 20 · xl 24 · seccion 28 · xxl 32 · margen 20 · titulo 10`

- Margen lateral de pantalla: 20 (`.contenidoPantalla()`).
- Entre secciones: 28.
- Del título de sección a su contenido: 10.
- Padding de tarjeta: 16 (hero: 20).
- Filas: alto mínimo de 60, con 12 de padding vertical.
- Del ícono al texto: 12.

### Radios (`Radio.*`, siempre `.continuous`)
`hero 28 · tarjeta 20 (= Theme.radio) · mosaico 14 · campo 12`. Chips y botones son cápsulas.

### Tipografía
Usa solo estilos de texto de Dynamic Type. No uses `.system(size:)` por debajo de 11 pt.

| Rol | Fuente |
|---|---|
| Cifra hero | `CifraPlata(estilo: .hero)`: 48 pt, redondeada, bold, escalable |
| Cifra titular | `CifraPlata(estilo: .titular)`: 28 pt |
| Cifra de dato o KPI | `.cifraMedia` (title3, redondeada, semibold) |
| Cifra de fila | `.cifra` (body, redondeada, semibold) |
| Cifra pequeña | `.cifraPequena` (subheadline) |
| Título de pantalla | Título grande nativo: `.navigationBarTitleDisplayMode(.large)` |
| Título de sección (fuera de tarjeta) | `.title3.weight(.semibold)`, con `EncabezadoSeccion` |
| Título dentro de tarjeta | `.headline`, con `TituloSeccion` |
| Título de fila | `.body.weight(.medium)` |
| Subtítulo de fila | `.subheadline` + `Theme.gris` |
| Meta, notas al pie | `.footnote` |
| Sobrelínea de grupo | `.sobrelinea` en mayúsculas con tracking 0,6, con `Sobrelinea` |
| Ejes de gráficas | `.caption2` (mínimo absoluto) |

Todas las cifras llevan `.monospacedDigit()`; `CifraPlata` ya lo aplica. El "$" va más tenue y más pequeño que el número.

### Elevación
- **Tarjetas:** sin bordes en claro. Llevan una sombra doble muy suave en claro y un filo blanco del 6 % en oscuro. Ya está incluido en `.panel()` y `FondoTarjeta`.
- **Hero:** `FondoHero` (degradado + resplandor tenue de sol + sombra azul en claro).
- **Toast y botón flotante:** sombra negra del 18 %, radio 16, y 6.

### Movimiento
- Cambios de estado: `spring(response: 0.35, dampingFraction: 0.85)`.
- Respeta siempre `@Environment(\.accessibilityReduceMotion)`: si está activo, usa la animación `nil`.
- Las cifras usan `.contentTransition(.numericText())` (iOS 16), ya incluido en `CifraPlata`. Para que se anime, cambia el valor dentro de `withAnimation`.
- No hay animaciones en bucle.

### Hápticos
- `Haptics.seleccion()`: chips, categorías, cambio de mes. Ya está incluido en `Chip`, `MosaicoCategoria` y `MesNavegador`.
- `Haptics.tap()`: botón flotante, `BotonCheck`.
- `Haptics.success()`: lo dispara `store.avisar` al guardar.
- `Haptics.warning()`: antes de confirmar algo destructivo.

---

## 2. Componentes

### Ya existentes (mantienen su API y fueron re-estilizados)

```swift
IconoCuadro(simbolo:, color:, lado: CGFloat = 40, relleno: Bool = false)
// Cuadro con 14 % del color (22 % en oscuro). Oculto para VoiceOver. Escala con Dynamic Type.

MesNavegador(mes: Binding<Date>, compacto: Bool = false)
// Flechas de 44 pt, deslizar a los lados cambia el mes, ajustable con VoiceOver.
// compacto: true para .toolbar { ToolbarItem(placement: .principal) { MesNavegador(mes: $mes, compacto: true) } }

Mosaico(titulo:, valor: String, color: Color = Theme.texto, sobreOscuro: Bool = false)
// Para datos nuevos prefiere ResumenDatos.

BarraProgreso(avance: Double, color: Color = Theme.acento, alto: CGFloat = 10, etiqueta: String? = nil)
// Cápsula sobre pista. Usa color: Theme.colorAvance(avance). VoiceOver lee el porcentaje.

CampoPlata(texto: Binding<String>, marcador: "0", grande: false, alineacion: .leading,
           etiqueta: "Valor en pesos", enfocarAlAparecer: false)
// grande: 48 pt redondeada. alineacion: .center para hojas.

Toast(texto:, accionTitulo: String? = nil, accion: (() -> Void)? = nil)
// Lo pinta RootView; las pantallas NO lo usan directamente.

Vacio(simbolo:, texto:)                   // Vacío pequeño dentro de una tarjeta
TituloSeccion(texto:, detalle: String?)   // Título DENTRO de una tarjeta (.headline)
.panel(padding: CGFloat = 16)             // Tarjeta. Para grupos de filas: .panel(padding: 0)
.columna()                                // Ancho máximo de 576

TramoDona(id:, valor: Double, color:, nombre:)
Dona(tramos:, total:, grosor: CGFloat? = nil, lado: CGFloat = 140, etiquetaCentro: "en el mes", resaltado: String? = nil)
LeyendaDona(tramos:, total:, resaltado: Binding<String?>? = nil, compacta: Bool = false)
BarrasPorDia(dias: [TotalDia], presupuestoDiario: Decimal, alto: CGFloat = 140)
// Barras de tope redondeado. La de hoy va en sol y las que pasan el presupuesto en rojo.
// La línea punteada es gris con la etiqueta "Diario $X". Tocar una barra muestra su valor.
// Tiene resumen para VoiceOver.

SolicitudValor(titulo:, pregunta:, montoSugerido:, fechaSugerida:, accion: (Decimal, Date) -> Void)
HojaValorReal(solicitud:)
// Cifra grande centrada, fecha y botón principal. Detents .medium y .large.

FilaObligacion(obligacion:, alHacer: () -> Void, alQuitar: (() -> Void)? = nil)
// Estilo Recordatorios: BotonCheck a la izquierda, nombre, insignia Vencido/Pronto,
// ícono + fecha, valor a la derecha (+verde si es ingreso).
// Menú contextual: "Ya pagué"/"Ya me llegó" y "Borrar".
// Dentro de una List, desliza a la derecha = hecho y a la izquierda = Borrar.
// NO agregues un botón "Quitar" aparte: usa alQuitar.

HojaCompartir(elementos:)
ArchivoCompartido(url:)
```

### Nuevos

```swift
// Utilidades de layout
.contenidoPantalla()   // columna + margen de 20 + 8 arriba + 24 abajo + centrado. Aplícalo al VStack dentro del ScrollView.
.fondoPantalla()       // Theme.fondo hasta los bordes
FondoTarjeta(radio: 20, color: Theme.superficie)   // fondo de tarjeta suelto
FondoHero(radio: 28)

// Cifras
CifraPlata(valor: Decimal, estilo: .hero|.titular|.media|.normal|.pequena = .normal,
           signo: .ninguno|.entrada|.salida|.automatico = .automatico,
           color: Color? = nil, escalaMinima: CGFloat? = nil)
// .entrada → "+$ 1.000" verde · .salida → "−$ 18.000" en color de texto
// .automatico → si es negativo, "−" en rojo · VoiceOver lee "menos 18.000 pesos"
CifraPlata.textoAccesible(_ valor:, signo:) -> String

// Hero
TarjetaHero(espaciado: 12) { … }
// Tarjeta de marca. Su contenido se dibuja en esquema OSCURO, así que Theme.texto y
// Theme.gris quedan claros solos. Una sola por pantalla.
ResumenDatos(datos: [DatoResumen], sobreOscuro: Bool = false)
// 2 o 3 datos separados por líneas verticales; se apilan en tamaños de accesibilidad.
DatoResumen(titulo:, valor: Decimal, signo: .automatico, color: Color? = nil)

// Estructura
EncabezadoSeccion(titulo:, detalle: String? = nil, accionTitulo: String? = nil, accion: (() -> Void)? = nil)
// Título FUERA de la tarjeta, con enlace opcional "Ver todos"
Sobrelinea(texto:, color: Theme.gris)   // "VENCIDOS" (color de estado opcional)
SeparadorFila(sangria: 68)              // entre filas de un grupo (0,5 pt, alineado al texto)
FilaLista(simbolo:, color:, titulo:, subtitulo: String? = nil, insignia: Insignia? = nil) { derecha }
FilaLista(simbolo:, color:, titulo:, subtitulo:, insignia:, valor: Decimal, signo: .automatico)
// Alto mínimo de 60, ícono de 40, título body medium, subtítulo subheadline gris.

// Estados y avisos
enum Tono { neutro, tinte, positivo, aviso, negativo, sol }   // .color y .suave
Insignia(texto:, tono: .neutro, simbolo: String? = nil)       // cápsula .caption semibold sobre fondo suave
BannerAviso(simbolo: "exclamationmark.triangle.fill", titulo:, mensaje: String? = nil, tono: .aviso, accion: (() -> Void)? = nil)
EstadoVacio(simbolo:, titulo:, mensaje: String? = nil, accionTitulo: String? = nil, accion: (() -> Void)? = nil)

// Controles
Chip(titulo:, simbolo: String? = nil, seleccionado: Bool = false, accion:)
// 36 pt de alto (44 pt de área táctil), relleno de tinte cuando está seleccionado, rasgo isSelected
MosaicoCategoria(simbolo:, color:, nombre:, seleccionado: Bool = false, accion:)
// Opción de cuadrícula; todas miden igual
// Grid: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing 10
Button("…") {}.buttonStyle(.principal)               // cápsula de 52 pt a todo el ancho, .headline. UNO por pantalla u hoja
Button("…") {}.buttonStyle(.principal(Theme.verde))  // otro color (texto blanco por defecto)
Button("…") {}.buttonStyle(.secundario)              // cápsula con tinte al 12 %, 44 pt de alto, .subheadline semibold
Button("Borrar") {}.buttonStyle(.secundario(Theme.rojo, anchoCompleto: true))
Button { } label: { … }.buttonStyle(.presionable)    // filas o tarjetas tocables (se encogen al presionar)
BotonIcono(simbolo:, etiqueta:, color: Theme.acento, relleno: true, accion:)   // 44 × 44
MenuMas(etiqueta: "Más opciones") { Button…; Button(role: .destructive)… }     // menú ••• de 44 × 44 para acciones secundarias
BotonCheck(hecho: false, color: Theme.acento, etiqueta: "Ya pagué: Arriendo", accion:)   // check circular de 44 pt
BotonFlotante(simbolo: "plus", etiqueta:, accion:)   // ya lo pone RootView

// Gráficas
DonaConLeyenda(tramos:, total:, lado: 128, etiquetaCentro: "en el mes")
// Dona con la leyenda compacta al lado; tocar una fila resalta su tramo; se apila con letra grande.
AnilloProgreso(avance:, color:, lado: 56, grosor: nil)            // anillo simple
AnilloProgreso(conPorcentaje: avance, color:, lado:)              // con el % al centro
AnilloProgreso(avance:, color:, lado:, grosor:) { centro }        // con contenido propio al centro
UnevenCapsula(radio:)                                             // Shape de barra con el tope redondeado

// Hojas
HojaRegistrar()
// Envuelve RegistrarView en un NavigationStack ("Registrar", botón Cerrar).
// Se cierra sola al guardar un gasto o un ingreso.

// Entorno (lo pone RootView)
@Environment(\.abrirRegistro) var abrirRegistro          // abrirRegistro() abre la hoja de registro
@Environment(\.ofrecerDeshacer) var ofrecerDeshacer      // ofrecerDeshacer("texto opcional") { acción inversa }
@Environment(\.irAPestana) var irAPestana                // irAPestana(.pagos)
@Environment(\.alTerminarRegistro) var alTerminar        // (() -> Void)? : RegistrarView puede llamarlo tras guardar
.conBotonAjustes()   // engranaje en la barra de navegación + hoja de AjustesView. Va DENTRO del NavigationStack.
Haptics.seleccion()
```

---

## 3. Estructura global (RootView)

- **Pestañas (TabView del sistema; en iOS 26 se ve como Liquid Glass):** Inicio `house` · Movimientos `list.bullet.rectangle` · Presupuesto `chart.pie` · Pagos `calendar` · Balance `dollarsign.circle`. Tinte: `Theme.acento`.
- **Botón flotante "+":** abajo a la derecha, encima de la barra de pestañas, en todas las pestañas. Abre `HojaRegistrar`. Se esconde mientras el teclado está abierto. Va en un `safeAreaInset` inferior, así que **el contenido con scroll de cada pantalla ya deja el espacio necesario; no agregues padding extra abajo.**
- **Toast:** abajo a la izquierda, al lado del "+".
  - Dura 2,8 s, o 5 s si lleva "Deshacer"; el doble con VoiceOver activo.
  - VoiceOver lo anuncia.
  - Para ofrecer deshacer: llama a la acción del store (que pone su aviso) y después `ofrecerDeshacer { inversa }`.
  - Acciones inversas que ya existen en el store: `borrarGasto`, `deshacerAgenda`, `deshacerPagoFijo`, etc.
- **Bloqueo:** pantalla completa con `FondoHero`, candado sobre un halo de sol, "Mi plata" en largeTitle redondeada y un botón principal sol "Desbloquear con Face ID".

---

## 4. Reglas de layout por tipo de pantalla

**Esqueleto de cada pestaña:**
```swift
NavigationStack {
    ScrollView {
        VStack(alignment: .leading, spacing: Espacio.seccion) {
            // 1 hero (opcional, máximo uno)
            // secciones: EncabezadoSeccion + tarjeta o grupo
        }
        .contenidoPantalla()
    }
    .scrollDismissesKeyboard(.interactively)
    .fondoPantalla()
    .navigationTitle("Pagos")
    .navigationBarTitleDisplayMode(.large)
    .conBotonAjustes()            // o un botón propio en la barra
}
```
Si la pantalla es casi solo una lista con acciones de deslizar, usa `List` con `.listStyle(.insetGrouped)`, `.scrollContentBackground(.hidden)` y `.fondoPantalla()`. Agrega `.listRowBackground(Theme.superficie)` a las filas. Así funcionan `swipeActions` (fuera de una `List` no funcionan).

**Sección = encabezado afuera + un grupo adentro:**
```swift
VStack(alignment: .leading, spacing: Espacio.titulo) {
    EncabezadoSeccion(titulo: "Próximos pagos", accionTitulo: "Ver todos") { irAPestana(.pagos) }
    VStack(spacing: 0) {
        ForEach(items.indices, id: \.self) { i in
            if i > 0 { SeparadorFila() }
            FilaLista(…)
        }
    }
    .panel(padding: 0)
}
```
Cuando las filas vienen de `FilaObligacion` (que no trae padding horizontal), usa `.panel(padding: 0)` con `.padding(.horizontal, Espacio.m)` en cada fila y `SeparadorFila(sangria: 56)`.

**Por pantalla (recomendaciones de las auditorías):**
- **Inicio:**
  1. `TarjetaHero` con "Hoy puedes gastar" en `.subheadline` gris, la cifra `.hero` en `Theme.sol` (si es negativa: blanca, con la insignia "Te pasaste" en `.negativo`), una sola línea de contexto ("Hasta que llegue X · quedan N días") y `ResumenDatos` con "Plata libre", "Ahorrado" y "Gastado esta semana". La explicación larga va detrás de un `BotonIcono("info.circle")` que abre una hoja.
  2. **Un solo** `BannerAviso`, el más importante, con "+N avisos más".
  3. "Próximos 7 días": hasta 3 `FilaObligacion` y "Ver todos" → `irAPestana(.pagos)`.
  4. `DonaConLeyenda` del mes.

  Si no hay datos: `EstadoVacio("Registra tu primer gasto")` → `abrirRegistro()`. El registro incrustado puede salir de Inicio, porque ya existe el "+".
- **Movimientos:** la lista va primero. `MesNavegador(compacto: true)` en la barra (`.principal`), `.searchable`, y los filtros como `Chip` en una fila con scroll horizontal o en un `Menu` de la barra. Agrupa por día con `Sobrelinea(Fmt.encabezadoDia)` y el total del día a la derecha. Cada fila es `FilaLista` con `CifraPlata(signo: .salida/.entrada)`. Los análisis (dona, barras, horarios, hábitos) van en un "Resumen del mes" plegable o en un segmento aparte.
- **Presupuesto:**
  - Hero o tarjeta: "Este mes te debería sobrar" en `.titular`, con "Real hasta hoy" como dato secundario.
  - Debajo, filas clave-valor: cifra real grande y "de $plan" en `.footnote` gris, en lugar de la tabla de 3 columnas.
  - Categorías: `FilaLista` + `BarraProgreso(color: Theme.colorAvance(x))`.
  - Fijos: estado ✓ o pendiente, con "Corregir valor" y "Deshacer" en un `MenuMas` o menú contextual.
  - "Ajustar" va en la barra (`slider.horizontal.3`).
- **Pagos:** grupos con `Sobrelinea` de color (Vencidos en rojo, Esta semana en ámbar, el resto en gris) y un grupo de `FilaObligacion` debajo de cada una. "+ Nuevo pago" en la barra. "Ya hechos" con deshacer y borrar en un menú contextual o por deslizamiento.
- **Balance:**
  - `TarjetaHero` con el patrimonio en `.hero` blanco y `ResumenDatos` (Libre, Ahorrado · Me deben, Debo, en 2 filas de 2). "Bienes a cuotas" va como nota al pie.
  - Cajitas: tarjetas con `AnilloProgreso`, cifra y `Button("Guardar plata").buttonStyle(.secundario)`. Sacar y Borrar van en `MenuMas`. "+ Nueva cajita" abre una hoja, en vez de un formulario incrustado.
  - Me deben y Debo: grupos de `FilaLista` con una acción principal visible y el resto en el menú.
- **Hojas y formularios:** `Form` nativo para editar o configurar, con `.scrollContentBackground(.hidden)` y `.background(Theme.elevada)` si quieres. Las hojas para ingresar una cifra llevan arriba `CampoPlata(grande: true, alineacion: .center, enfocarAlAparecer: true)`. Usa `.presentationDetents([.medium, .large])`, nunca `.height(…)` fijo. Confirmar en la barra (`.confirmationAction`, semibold) y/o un `.principal` abajo.

---

## 5. Interacción y accesibilidad

- **Áreas táctiles de 44 × 44 como mínimo.** Prohibido `.controlSize(.mini)`. No uses botones de texto `caption2`.
- **Una acción principal visible por fila.** Las secundarias van en `MenuMas`, en el menú contextual o al deslizar.
- **Lo destructivo nunca es inmediato.** Usa `.confirmationDialog` con `Haptics.warning()`, o haz la acción y ofrece `ofrecerDeshacer`. Nada de "toca otra vez para borrar".
- **VoiceOver:**
  - Usa `.accessibilityElement(children: .combine)` en filas compuestas (`FilaLista`, `Mosaico` y `ResumenDatos` ya lo traen).
  - Los íconos decorativos van ocultos (`IconoCuadro` ya lo está).
  - Chips y categorías seleccionados llevan el rasgo `.isSelected`.
  - Pasos de un flujo: `.accessibilityLabel("Paso 2 de 3")`.
  - Cifras: `CifraPlata` ya lee "menos/más N pesos". Para textos propios usa `CifraPlata.textoAccesible`.
- **Dynamic Type:**
  - Sin anchos fijos para columnas de texto.
  - Usa `@ScaledMetric` para tamaños de íconos y celdas.
  - En `dynamicTypeSize.isAccessibilitySize` apila en vertical.
  - Las cifras no se encogen por debajo de 0,6 (hero) u 0,8 (resto).
- **Teclado:** `.scrollDismissesKeyboard(.interactively)` en todo ScrollView o Form que tenga campos.

---

## 6. Tono y vocabulario

- Español de Colombia, cercano, en tú y en frases cortas. Plata, no dinero.
- **Glosario único:** Gasto · Ingreso · Pago · Cajita · Deuda · Préstamo.
- **Borrar** para eliminar. **Deshacer** solo para revertir ("Ya pagué" o el toast). No uses "Quitar".
- **Botones** con verbo y corto: "Guardar gasto", "+ Nuevo pago", "+ Nueva cajita", "Ya pagué", "Ya me llegó", "Ver todos".
- **Grupos de pagos:** "Atrasados", "Esta semana", "Resto del mes", "Más adelante", "Sin fecha". Renómbralos en la vista, no en el modelo.
- **Estados vacíos:** un título con acción ("Registra tu primer gasto") y una línea de por qué sirve. No escondas secciones enteras en silencio.
- **Números:** siempre con `Fmt.plata` o `CifraPlata`, con "$" y puntos de miles. Porcentajes con `Fmt.porcentaje`.

---

## 7. Sí / No

| ✅ Sí | ❌ No |
|---|---|
| Una hero por pantalla y el resto plano | Varias tarjetas oscuras o de colores |
| Títulos de sección fuera de las tarjetas | `.headline` dentro de cada tarjeta como único jerarquizador |
| Un grupo de filas por tarjeta con `SeparadorFila` | Una tarjeta por cada fila |
| `Theme.acento` para todo lo tocable | Azul para decorar, verde o rojo para botones normales |
| Gasto en color de texto con "−" | Gastos en rojo |
| Sol solo en la cifra protagonista y en "hoy" | Sol como color de texto general o de barras normales |
| `.buttonStyle(.principal)` una vez por pantalla | Varios `borderedProminent` compitiendo |
| `CifraPlata` para toda la plata | `Text(Fmt.plata(x)).font(.system(size: 15))` |
| Estilos de texto y `@ScaledMetric` | `.system(size: 9/10/12)` |
| `List` cuando hay swipe | `.swipeActions` en un `VStack` |
| Confirmación o "Deshacer" en lo destructivo | Borrar al primer toque |
| `.presentationDetents([.medium, .large])` | `.height(260)` |
| `#available(iOS 17, *)` para APIs nuevas | `.sensoryFeedback`, `.fontDesign`, `numericText(value:)` sin guarda |
