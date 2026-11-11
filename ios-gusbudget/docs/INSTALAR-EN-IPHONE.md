# Instalar GusBudget (Mi plata) en tu iPhone

Hay dos caminos. El **A** necesita un Mac. El **B** no: la app se compila sola en un Mac
de GitHub y tú solo instalas el archivo desde tu computador, sea Windows o Mac.

En los dos casos la firma es con **Apple ID gratuito**, así que la app **caduca a los 7 días**
y hay que renovarla. La diferencia es que AltStore y Sideloadly pueden renovarla solos.

---

## Camino A · Con un Mac y Xcode

### 1. Lo que necesitas
- Mac con **Xcode 14.1 o superior** (gratis en la Mac App Store, ~10 GB).
- iPhone con **iOS 16 o superior** y su cable.
- Tu Apple ID de siempre (no hace falta pagar los 99 USD al año).

### 2. Bajar el proyecto
```bash
git clone --branch claude/gusbudget-income-expenses-app-u3pb6j \
  https://github.com/Gusjaimes03/App-Finance.git ~/GusBudget
cd ~/GusBudget/ios-gusbudget
```

> La rama importa: la rama por defecto del repositorio es la de la app de los carros
> y ahí no está la carpeta `ios-gusbudget`.

### 2.1 Atajo: un solo comando

Si ya tienes tu Apple ID en Xcode (paso 3) y el iPhone conectado, esto compila,
firma e instala sin tocar la interfaz:

```bash
./tools/instalar-en-iphone.sh
```

El script busca solo tu Team ID y el iPhone emparejado, compila, firma, instala y abre
la app. Si el identificador está ocupado, se le pasa otro:

```bash
BUNDLE_ID=com.tunombre.miplata ./tools/instalar-en-iphone.sh
```

Para renovar a los 7 días es el mismo comando. Si prefieres hacerlo a mano, sigue leyendo.

### 2.2 Abrir el proyecto en Xcode
```bash
open GusBudget.xcodeproj
```

### 3. Poner tu Apple ID
1. **Xcode › Settings… › Accounts › +** → Apple ID → inicia sesión.
   Queda un equipo llamado *"Tu Nombre (Personal Team)"*.
2. En la barra lateral, clic en el proyecto azul **GusBudget** → en **TARGETS**, **GusBudget**.
3. Pestaña **Signing & Capabilities**:
   - marca **Automatically manage signing**,
   - en **Team** elige tu *(Personal Team)*,
   - si Xcode se queja del **Bundle Identifier**, cámbialo por `com.tunombre.miplata`.

### 4. Preparar el iPhone
1. Conéctalo y toca **Confiar** en "¿Confiar en este ordenador?".
2. **Ajustes › Privacidad y seguridad › Modo de desarrollador** → activar → el iPhone se reinicia.
   (Si no aparece, pulsa ▶︎ una vez en Xcode y vuelve a mirar.)

### 5. Instalar
1. Arriba en Xcode elige **tu iPhone** como destino y pulsa **▶︎ Run** (`⌘R`).
2. La primera vez el iPhone dirá *"Desarrollador no verificado"*:
   **Ajustes › General › VPN y gestión de dispositivos** → tu Apple ID → **Confiar**.
3. Vuelve a pulsar **▶︎**. Listo, ya puedes desconectar el cable.

### 6. Renovar cada 7 días
Conecta el iPhone y corre `./tools/instalar-en-iphone.sh`, o abre el proyecto y pulsa **▶︎**.
Otros 7 días.

**Tus datos se conservan** mientras no borres la app del iPhone. Si la borras, se van con ella.

---

## Camino B · Sin Mac, con AltStore o Sideloadly

Cada vez que se sube un cambio, GitHub compila la app en un Mac suyo y deja un
`.ipa` **sin firmar** listo para descargar.

### 1. Descargar el .ipa
1. Entra a **[Actions](https://github.com/Gusjaimes03/App-Finance/actions)** en el repositorio.
2. Abre la última ejecución de **GusBudget iOS** que tenga el chulo verde.
3. Abajo, en **Artifacts**, descarga **GusBudget-sin-firmar**.
4. Descomprime el ZIP: adentro está `GusBudget-sin-firmar.ipa`.

> Para descargar artefactos hay que estar con la sesión de GitHub iniciada.

### 2. Instalarlo
Elige una de las dos herramientas. Las dos firman el `.ipa` con **tu** Apple ID gratuito.

**Sideloadly** (lo más simple, Windows o Mac) — <https://sideloadly.io>
1. Instala Sideloadly y iTunes (en Windows, la versión de Apple, no la de la Microsoft Store).
2. Conecta el iPhone, abre Sideloadly, arrastra el `.ipa`, escribe tu Apple ID y dale **Start**.
3. En el iPhone: **Ajustes › General › VPN y gestión de dispositivos** → **Confiar**.

**AltStore / SideStore** (se renueva solo) — <https://altstore.io>
1. Instala **AltServer** en el computador y **AltStore** en el iPhone siguiendo su guía.
2. En el iPhone, dentro de AltStore: **+** → elige el `.ipa`.
3. Deja el computador encendido y en la misma red Wi-Fi: AltStore **renueva la firma solo**
   antes de que se cumplan los 7 días. Eso evita tener que reinstalar a mano.

### 3. Ojo con el Apple ID
Si usas tu Apple ID principal y te preocupa, crea uno gratis solo para esto.
Sideloadly y AltStore piden la contraseña para pedirle a Apple un certificado de desarrollo;
si tienes verificación en dos pasos, te pedirán una **contraseña específica de app**
(se crea en <https://account.apple.com>).

---

## Lo que la app te ayuda a recordar

En **Ajustes** (el engranaje arriba a la derecha en Inicio):
- **Marcar como reinstalada hoy**: guarda la fecha de la firma.
- **Caduca**: te dice cuántos días quedan.
- **Avisarme 1 día antes**: notificación local el día 6.
- **Guardar respaldo (.json)**: mándatelo por AirDrop o correo antes de reinstalar.
- **Restaurar respaldo**: para volver a cargar tus datos si algo pasó.

---

## Límites de la firma gratuita

| Límite | Valor |
|---|---|
| Duración de la firma | 7 días |
| Apps firmadas a la vez con el mismo Apple ID | 3 |
| Identificadores nuevos | 10 cada 7 días |
| Notificaciones push remotas, iCloud, widgets compartidos | No disponibles |

La app está hecha para caber ahí: no usa iCloud, ni push remotas, ni servicios de pago.
Las notificaciones que usa son **locales**, que sí funcionan con firma gratuita.

---

## Problemas frecuentes

| Mensaje | Qué hacer |
|---|---|
| *"Signing for GusBudget requires a development team"* | Elige tu Team en Signing & Capabilities. |
| *"Failed to register bundle identifier"* | Cambia el Bundle Identifier por uno único tuyo. |
| *"Desarrollador no verificado"* | Confía en tu perfil desde Ajustes del iPhone. |
| *"Unable to install… device not eligible"* | Activa el Modo de desarrollador. |
| La app se cierra sola a los pocos días | Caducó la firma: reinstálala (o deja AltStore refrescándola). |
| *"maximum number of apps for free development profiles"* | Borra otra app firmada gratis; el límite es 3. |
| Sideloadly: *"Please sign in with an app-specific password"* | Crea una en <https://account.apple.com> y úsala ahí. |
