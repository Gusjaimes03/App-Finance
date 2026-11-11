#!/bin/bash
#
# Compila GusBudget (Mi plata), la firma con tu Apple ID gratuito
# y la instala en el iPhone que tengas conectado al Mac.
#
#   ./tools/instalar-en-iphone.sh            # detecta tu equipo solo
#   ./tools/instalar-en-iphone.sh ABCDE12345 # o le pasas el Team ID
#
# Variables opcionales:
#   BUNDLE_ID=com.tunombre.miplata ./tools/instalar-en-iphone.sh
#
set -euo pipefail

cd "$(dirname "$0")/.."

PROYECTO="GusBudget.xcodeproj"
ESQUEMA="GusBudget"
CONFIG="Debug"
SALIDA="build"
EQUIPO="${1:-${DEVELOPMENT_TEAM:-}}"
BUNDLE_ID="${BUNDLE_ID:-}"

verde()  { printf "\033[1;32m==>\033[0m %s\n" "$1"; }
gris()   { printf "    %s\n" "$1"; }
falla()  { printf "\033[1;31m✗\033[0m %s\n" "$1" >&2; exit 1; }

# ---------------------------------------------------------------- Xcode

verde "Revisando Xcode"
command -v xcodebuild >/dev/null 2>&1 || falla "No encuentro xcodebuild. Instala Xcode desde la Mac App Store y ábrelo una vez."
if ! xcode-select -p >/dev/null 2>&1; then
    falla "Xcode está instalado pero no seleccionado. Corre: sudo xcode-select -s /Applications/Xcode.app"
fi
gris "$(xcodebuild -version | head -1)"

# ---------------------------------------------------------------- Equipo

if [ -z "$EQUIPO" ]; then
    verde "Buscando tu Apple ID en Xcode"
    EQUIPO=$(security find-identity -v -p codesigning 2>/dev/null \
        | sed -n 's/.*"Apple Development: .*(\([A-Z0-9]\{10\}\))".*/\1/p' | head -1 || true)
fi

if [ -z "$EQUIPO" ]; then
    EQUIPO=$(defaults read com.apple.dt.Xcode IDEProvisioningTeams 2>/dev/null \
        | sed -n 's/.*teamID = "\{0,1\}\([A-Z0-9]\{10\}\)"\{0,1\};.*/\1/p' | head -1 || true)
fi

if [ -z "$EQUIPO" ]; then
    cat >&2 <<'AYUDA'
✗ No encontré ningún Apple ID configurado para firmar.

  Hazlo una sola vez:
    1. Abre Xcode
    2. Menú Xcode › Settings… › Accounts
    3. Botón +  ›  Apple ID  ›  inicia sesión con tu Apple ID normal
    4. Vuelve a correr este script

  Si sabes tu Team ID, también puedes pasarlo directo:
    ./tools/instalar-en-iphone.sh ABCDE12345
AYUDA
    exit 1
fi
gris "Equipo: $EQUIPO"

# ---------------------------------------------------------------- iPhone

verde "Buscando el iPhone conectado"
LISTA=$(mktemp -t gusbudget-devices)
trap 'rm -f "$LISTA"' EXIT

if ! xcrun devicectl list devices --json-output "$LISTA" >/dev/null 2>&1; then
    falla "No pude listar dispositivos. Necesitas Xcode 15 o superior; si tienes uno más viejo, abre $PROYECTO y dale a ▶︎."
fi

LEER_UDID=$(cat <<'PY'
import json, sys
datos = json.load(open(sys.argv[1]))
for aparato in datos.get("result", {}).get("devices", []):
    hardware = aparato.get("hardwareProperties", {})
    if hardware.get("platform") != "iOS":
        continue
    conexion = aparato.get("connectionProperties", {})
    if conexion.get("pairingState") not in (None, "paired"):
        continue
    nombre = aparato.get("deviceProperties", {}).get("name", "iPhone")
    print(f'{aparato.get("identifier", "")}\t{nombre}')
    break
PY
)
DISPOSITIVO=$(/usr/bin/python3 -c "$LEER_UDID" "$LISTA" || true)
UDID="${DISPOSITIVO%%	*}"
NOMBRE="${DISPOSITIVO##*	}"

if [ -z "$UDID" ]; then
    cat >&2 <<'AYUDA'
✗ No veo ningún iPhone emparejado.

  Revisa:
    · que esté conectado con el cable y desbloqueado
    · que hayas tocado "Confiar" en el iPhone
    · que el Modo de desarrollador esté activo:
      Ajustes › Privacidad y seguridad › Modo de desarrollador › activar (el iPhone se reinicia)
AYUDA
    exit 1
fi
gris "$NOMBRE ($UDID)"

# ---------------------------------------------------------------- Compilar

verde "Compilando y firmando (la primera vez tarda un par de minutos)"
EXTRA=()
if [ -n "$BUNDLE_ID" ]; then
    EXTRA+=("PRODUCT_BUNDLE_IDENTIFIER=$BUNDLE_ID")
    gris "Bundle ID: $BUNDLE_ID"
fi

set +e
xcodebuild \
    -project "$PROYECTO" \
    -scheme "$ESQUEMA" \
    -configuration "$CONFIG" \
    -destination "id=$UDID" \
    -derivedDataPath "$SALIDA" \
    -allowProvisioningUpdates \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM="$EQUIPO" \
    build
RESULTADO=$?
set -e

if [ $RESULTADO -ne 0 ]; then
    cat >&2 <<AYUDA

✗ La compilación falló. Lo más común:

  · "Failed to register bundle identifier"
      Ese identificador ya lo usó otra cuenta. Corre:
        BUNDLE_ID=com.tunombre.miplata ./tools/instalar-en-iphone.sh

  · "Unable to log in with account"
      Vuelve a entrar en Xcode › Settings… › Accounts.

  · Cualquier otro error: cópiame las últimas líneas de arriba.
AYUDA
    exit $RESULTADO
fi

APP="$SALIDA/Build/Products/$CONFIG-iphoneos/$ESQUEMA.app"
[ -d "$APP" ] || falla "No encuentro la app compilada en $APP"

# ---------------------------------------------------------------- Instalar

verde "Instalando en $NOMBRE"
if ! xcrun devicectl device install app --device "$UDID" "$APP"; then
    falla "No pude instalarla. Revisa que el iPhone esté desbloqueado y con el Modo de desarrollador activo."
fi

IDENTIFICADOR=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP/Info.plist" 2>/dev/null || echo "")

verde "Abriéndola"
if [ -n "$IDENTIFICADOR" ]; then
    xcrun devicectl device process launch --device "$UDID" "$IDENTIFICADOR" >/dev/null 2>&1 || true
fi

cat <<FIN

✓ Listo. GusBudget quedó instalada en $NOMBRE.

  Si el iPhone dice "Desarrollador no verificado":
    Ajustes › General › VPN y gestión de dispositivos › tu Apple ID › Confiar

  La firma gratuita dura 7 días. Para renovarla, conecta el iPhone y corre
  este mismo script otra vez. Tus datos se conservan mientras no borres la app.

  Dentro de la app, en Ajustes (el engranaje de Inicio), marca
  "Marcar como reinstalada hoy" y activa el aviso del día 6.

FIN
