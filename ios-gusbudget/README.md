# GusBudget · Mi plata

App de iPhone en SwiftUI que implementa la especificación de **Mi plata**: saber cuánto
puedes gastar hoy sin quedarte corto para lo que viene, registrar gastos en 3 pasos,
llevar el presupuesto del mes y controlar cajitas, cobros y deudas.

Todo en pesos colombianos, en español y **guardado solo en el teléfono**: sin cuentas,
sin servidores, sin anuncios.

---

## Pantallas

| Pestaña | Qué trae |
|---|---|
| **Inicio** | "Hoy puedes gastar" con la frase que explica de dónde sale, mosaicos de plata libre / cajitas / esta semana, avisos, registro en 3 pasos con sugerencias por hábito, pagos de los próximos 7 días y la dona del mes. |
| **Movimientos** | Navegador de mes, KPIs (Entró · Salió · Diferencia), nota de lo gastado con Guamacard, dona por categoría, barras por día con la línea del presupuesto diario, franjas horarias, "lo que más repites" y la lista filtrable por tipo, texto y categoría. |
| **Presupuesto** | Tabla Presupuesto \| Real hasta hoy (sueldos, extras, plata prestada, fijos, pagos únicos, día a día y el resultado), día a día por categoría con barras, gastos fijos y suscripciones con "Ya pagué" por el valor real, y los ajustes de presupuesto, fijos y TRM. |
| **Pagos** | Pendientes agrupados en vencidos · próximos 7 días · resto del mes · más adelante · sin fecha, con "Ya pagué"/"Ya me llegó" por el valor real, formulario para agregar y la lista de "ya hechos" con deshacer. |
| **Balance** | "Lo tuyo, en plata", cajitas de ahorro con guardar/sacar/quitar, "Me deben" con abonos parciales y "Lo que debo" con abonos. |

Las reglas de cálculo son las de la especificación (secciones 4.1 a 4.7): plata libre,
obligaciones generadas mes a mes desde los gastos fijos, "Hoy puedes gastar" como el
mínimo entre lo que permite la plata y lo que permite el presupuesto, presupuesto contra
real, enlaces automáticos con las deudas y hábitos por hora.

En *Ajustes › Revisar las cuentas* la app corre las **pruebas mínimas** de la
especificación sobre datos de mentira y muestra cuáles pasan.

## Datos con los que arranca

Vienen cargados los de la sección 6: categorías con su presupuesto, gastos fijos
(arriendo, servicios, Guamacard, ahorro del carro, cuota del carro), suscripciones en
dólares con TRM, ingresos esperados de Comfacasanare, CLI y Unitrópico, las tres cajitas,
las deudas y lo que te deben. Todo es editable desde la app.

Lo único que **no** viene es el histórico de lo ya recibido y pagado: eso se registra con
"Ya me llegó" y "Ya pagué" para que la plata libre empiece a cuadrar con el banco.

## Instalar en el iPhone

Dos caminos, explicados paso a paso en **[docs/INSTALAR-EN-IPHONE.md](docs/INSTALAR-EN-IPHONE.md)**:

1. **Con un Mac**: con el iPhone conectado y tu Apple ID ya en Xcode, basta con
   `./tools/instalar-en-iphone.sh`, que compila, firma, instala y abre la app.
   También se puede a mano: abrir `GusBudget.xcodeproj`, elegir el equipo en
   *Signing & Capabilities* y darle a ▶︎. La firma gratuita dura 7 días.
2. **Sin Mac**: cada push compila la app en un Mac de GitHub Actions y deja un
   `.ipa` **sin firmar** como artefacto. Ese archivo se instala desde Windows o Mac con
   **AltStore** o **Sideloadly**, que lo firman con tu propio Apple ID y lo renuevan solos.

## Estructura

```
ios-gusbudget/
├── GusBudget.xcodeproj         Generado por script (tools/generate_xcodeproj.py)
├── GusBudget/
│   ├── GusBudgetApp.swift
│   ├── Models/                 Categorías, fijos, gastos, agenda, cajitas, deudas, semilla
│   ├── Store/                  FinanceStore, cálculos, hábitos, acciones, autopruebas
│   ├── Utils/                  Tema, formato de pesos, fechas, Face ID, recordatorio
│   ├── Views/                  Las 5 pestañas, hojas y componentes
│   └── Assets.xcassets         Icono y color de acento
├── tools/                      Generador del proyecto y del icono
└── docs/                       Guía de instalación
```

Si agregas o quitas archivos Swift:

```bash
python3 tools/generate_xcodeproj.py
```

## Decisiones que conviene saber

- **iOS 16** como mínimo; se evita todo lo que solo existe en versiones más nuevas.
- Las gráficas (dona y barras) están dibujadas a mano, sin Swift Charts ni dependencias.
- Las fuentes de la versión web (Bricolage Grotesque y Plus Jakarta Sans) todavía no están
  empaquetadas: se usa la tipografía del sistema con números redondeados. Los colores sí
  son exactamente los de la especificación, en claro y en oscuro.
- La zona horaria está fijada en `America/Bogota` para que los días no se corran.
