# Carritos Kids: control de alquiler de carros para niños

Aplicación web para manejar un negocio de alquiler de carros para niños:

- **Cronómetro automático por carro**: al alquilar, el tiempo empieza a correr. Faltando 1 minuto la tarjeta se pone amarilla. Cuando se acaba, se pone roja, suena una alarma, vibra y llega una notificación.
- **Tiempo mínimo de 10 minutos**, cobrado en bloques de 10 minutos.
- **Precios**: **$10.000** por bloque si se monta **1 niño** y **$15.000** si se montan **2 niños**. Se pueden cambiar en *Ajustes*.
- **Control de pago**: cada alquiler queda como *Pagado*, *Pendiente*, *Abono* (pago parcial) o *No pagó*, con su medio de pago (efectivo, Nequi, Daviplata, transferencia o tarjeta).
- **Contabilidad del día**: producido, recaudado, cuentas por cobrar, gastos, utilidad, cierre de caja, libro diario de partida doble y balance de comprobación.

Funciona sin internet, guarda los datos en el mismo dispositivo y se puede instalar en el celular o la tablet como una app.

## Cómo se usa

### 0. Agregar tus carros por nombre
La primera vez la app no tiene carros. En **Pista** toca **+ Agregar carro**, escribe el nombre de cada carro (por ejemplo *Rayo McQueen*, *Ferrari rojo*, *Jeep rosado*) y elige su color. Con **Agregar y seguir con otro** (o la tecla Enter) puedes registrar todos tus carros seguidos.
- No se permiten dos carros con el mismo nombre.
- Para cambiar el nombre o el color, toca el lápiz ✎ en la tarjeta del carro o ve a **Ajustes → Carros**.
- Los reportes muestran lo producido por cada carro con su nombre. Si cambias un nombre, el historial anterior conserva el nombre que tenía.

### 1. Pista (operación diaria)
1. Toca **Alquilar** en un carro disponible.
2. Elige **1 o 2 niños** y el **tiempo** (10, 20, 30 o 60 minutos, u *Otro*). El total se calcula solo.
3. Escribe el nombre del niño o del acudiente si quieres (es opcional).
4. Marca **Pagó ahora** (con el medio de pago) o **Paga al final**.
5. Toca **Iniciar tiempo**.

Mientras el carro está en pista puedes:
- **+10 min**: agregar tiempo. Se cobra otro bloque, que se puede pagar ahora o al final.
- **Cobrar**: registrar el pago si quedó pendiente.
- **Finalizar**: deja el carro libre. Si el niño se pasó del tiempo más allá de la tolerancia (2 min por defecto), la app sugiere cobrar el tiempo extra. Si hay saldo pendiente, pide cobrarlo o dejarlo como deuda.

> Mantén la app abierta en pantalla mientras haya carros en pista. La app intenta dejar la pantalla encendida. Toca la pantalla una vez para que el navegador permita el sonido de la alarma, y acepta el permiso de notificaciones.

### 2. Registro
- Lista de todos los alquileres del día, con hora, carro, niños, tiempo, cliente, total, pagado, saldo y estado.
- **Cartera pendiente**: todos los que deben plata, de cualquier día, con un botón para cobrar.
- **Ver**: muestra el detalle y los movimientos. Desde ahí se puede **anular** un alquiler (por un error o una devolución) o marcar que el cliente **no pagó** (se contabiliza como pérdida).
- Exportar a CSV (se abre en Excel).

### 3. Contabilidad
Elige un día o un rango (Hoy, Ayer, 7 días, Este mes):
- **Producido (ventas)**: todo lo que se cobró en alquileres, tiempo adicional y tiempo extra.
- **Recaudado**: el dinero que entró, separado en efectivo y digital, con el detalle por medio de pago.
- **Por cobrar**: lo que quedó pendiente de ese periodo, y el total de la cartera.
- **Gastos**: carga de baterías, mantenimiento, trabajadores, arriendo, transporte y otros.
- **Utilidad neta** y **flujo de caja**.
- Producido **por carro** y **por número de niños**, y **por día** cuando se elige un rango.
- **Cierre de caja**: base inicial + efectivo recibido − gastos en efectivo = efectivo que debe haber. Se escribe lo contado y la app muestra si sobra o falta. La diferencia queda contabilizada.
- **Libro diario** (partida doble) y **balance de comprobación**. Las sumas siempre cuadran.
- **Imprimir** el reporte o exportar el libro diario a CSV.

#### Cuentas contables usadas (PUC Colombia, como referencia)
| Movimiento | Débito | Crédito |
|---|---|---|
| Alquiler / tiempo adicional / tiempo extra | 1305 Clientes | 4155 Ingresos por alquiler |
| Pago en efectivo | 1105 Caja | 1305 Clientes |
| Pago digital (Nequi, Daviplata, transferencia, tarjeta) | 1110 Bancos | 1305 Clientes |
| Cliente no pagó | 5199 Cartera no cobrada | 1305 Clientes |
| Gasto | 51xx según la categoría | 1105 Caja / 1110 Bancos |
| Faltante de caja | 5395 Faltantes | 1105 Caja |
| Sobrante de caja | 1105 Caja | 4295 Sobrantes |

Valida los códigos con tu contador si los vas a llevar a la contabilidad formal.

### 4. Ajustes
- Agregar carros por nombre, renombrarlos, cambiar el color, desactivarlos o eliminarlos.
- Cambiar precios, minutos por bloque, tiempo mínimo, opciones de tiempo, tolerancia y alarma.
- **Respaldo**: descarga un archivo `.json` con todos los datos y restáuralo en otro dispositivo. Hazlo seguido, porque si se borran los datos del navegador se pierde la información.

## Cómo abrirla

- **Lo más fácil**: abre `index.html` con doble clic en Chrome o Edge. Así funciona todo menos la instalación como app y el modo sin internet.
- **Publicarla con GitHub Pages** para usarla desde el celular: en el repositorio ve a *Settings → Pages*, elige la rama y la carpeta raíz (`/`). Abre el enlace en el celular y usa *Agregar a la pantalla de inicio*.
- **En local con servidor**: `npm start` y abre http://localhost:8080.

Los datos quedan guardados en el navegador del dispositivo donde se usa la app. Cada dispositivo tiene sus propios datos.

## Desarrollo

```
js/core.js    Lógica de negocio: precios, tiempos, pagos, reportes y libro diario (sin dependencias)
js/store.js   Guardado en localStorage y respaldos
js/app.js     Interfaz
css/styles.css
sw.js         Service worker para el modo sin internet
tests/        Pruebas de la lógica (node --test)
```

Pruebas: `npm test` (requiere Node 18 o superior; no hay dependencias que instalar).
