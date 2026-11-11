#!/bin/bash
#
# Compila GusBudget (Mi plata), la firma con tu Apple ID gratuito
# y la instala en el iPhone que tengas conectado al Mac.
#
#   ./tools/instalar-en-iphone.sh              # detecta tu equipo solo
#   ./tools/instalar-en-iphone.sh ABCDE12345   # o le pasas el Team ID
#   ./tools/instalar-en-iphone.sh --diagnostico  # muestra qué encuentra y no compila
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
BUNDLE_ID="${BUNDLE_ID:-}"

ARGUMENTO="${1:-}"
DIAGNOSTICO=0
if [ "$ARGUMENTO" = "--diagnostico" ] || [ "$ARGUMENTO" = "-d" ]; then
    DIAGNOSTICO=1
    ARGUMENTO=""
fi
EQUIPO="${ARGUMENTO:-${DEVELOPMENT_TEAM:-}}"

verde() { printf "\033[1;32m==>\033[0m %s\n" "$1"; }
gris()  { printf "    %s\n" "$1"; }
aviso() { printf "\033[1;33m!\033[0m   %s\n" "$1"; }
falla() { printf "\033[1;31m✗\033[0m %s\n" "$1" >&2; exit 1; }

# ---------------------------------------------------------------- Xcode

verde "Revisando Xcode"
command -v xcodebuild >/dev/null 2>&1 || falla "No encuentro xcodebuild. Instala Xcode desde la Mac App Store y ábrelo una vez."
xcode-select -p >/dev/null 2>&1 || falla "Xcode no está seleccionado. Corre: sudo xcode-select -s /Applications/Xcode.app"
gris "$(xcodebuild -version | head -1)"

# ---------------------------------------------------------------- Equipos

# Equipos de las cuentas con sesión iniciada en Xcode (lo que Xcode acepta para firmar).
equipos_de_xcode() {
    defaults read com.apple.dt.Xcode IDEProvisioningTeams 2>/dev/null \
        | sed -n 's/.*teamID[[:space:]]*=[[:space:]]*"\{0,1\}\([A-Z0-9][A-Z0-9]*\)"\{0,1\};.*/\1/p' \
        | sort -u || true
}

# Equipos de los certificados instalados: el Team ID va en el campo OU del certificado,
# NO en el paréntesis del nombre (eso es el id de usuario).
equipos_de_certificados() {
    local pem
    pem=$(security find-certificate -a -c "Apple Development" -p 2>/dev/null || true)
    [ -n "$pem" ] || return 0
    printf '%s' "$pem" | /usr/bin/python3 -c '
import re, subprocess, sys
datos = sys.stdin.read()
equipos = []
for bloque in re.findall(r"-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----", datos, re.S):
    try:
        salida = subprocess.run(["openssl", "x509", "-noout", "-subject"],
                                input=bloque, capture_output=True, text=True).stdout
    except Exception:
        continue
    encontrado = re.search(r"OU\s*=\s*([A-Z0-9]+)", salida)
    if encontrado and encontrado.group(1) not in equipos:
        equipos.append(encontrado.group(1))
print("\n".join(equipos))
' || true
}

CUENTAS=$(equipos_de_xcode)
CERTIFICADOS=$(equipos_de_certificados)

if [ $DIAGNOSTICO -eq 1 ]; then
    verde "Diagnóstico"
    gris "Equipos de cuentas en Xcode: ${CUENTAS:-ninguno}"
    gris "Equipos de certificados:     ${CERTIFICADOS:-ninguno}"
    echo
    gris "Identidades de firma:"
    security find-identity -v -p codesigning 2>/dev/null | sed 's/^/      /' || gris "      ninguna"
    echo
    gris "Dispositivos:"
    xcrun devicectl list devices 2>/dev/null | sed 's/^/      /' || gris "      devicectl no disponible"
    exit 0
fi

if [ -z "$EQUIPO" ]; then
    verde "Buscando tu Apple ID en Xcode"
    EQUIPO=$(printf '%s\n' "$CUENTAS" | head -1)
    [ -n "$EQUIPO" ] || EQUIPO=$(printf '%s\n' "$CERTIFICADOS" | head -1)
fi

if [ -z "$EQUIPO" ]; then
    cat >&2 <<'AYUDA'
✗ No hay ningún Apple ID con el que firmar.

  Hazlo una sola vez:
    1. Abre Xcode
    2. Menú Xcode › Settings…  (⌘,)  ›  pestaña Accounts
    3. Botón +  ›  Apple ID  ›  inicia sesión con tu Apple ID normal
    4. Cierra Xcode y vuelve a correr este script

  Para ver qué encuentra el script:
    ./tools/instalar-en-iphone.sh --diagnostico
AYUDA
    exit 1
fi

gris "Equipo: $EQUIPO"
if [ -n "$CUENTAS" ] && ! printf '%s\n' "$CUENTAS" | grep -qx "$EQUIPO"; then
    aviso "Ese equipo no aparece entre las cuentas de Xcode (${CUENTAS//$'\n'/, })."
    aviso "Si falla, prueba con una de esas: ./tools/instalar-en-iphone.sh <TEAM_ID>"
fi

# ---------------------------------------------------------------- iPhone

verde "Buscando el iPhone conectado"
LISTA=$(mktemp -t gusbudget-devices)
trap 'rm -f "$LISTA"' EXIT

xcrun devicectl list devices --json-output "$LISTA" >/dev/null 2>&1 \
    || falla "No pude listar dispositivos. Necesitas Xcode 15 o superior; con uno más viejo, abre $PROYECTO y dale a ▶︎."

DISPOSITIVO=$(/usr/bin/python3 -c '
import json, sys
datos = json.load(open(sys.argv[1]))
for aparato in datos.get("result", {}).get("devices", []):
    if aparato.get("hardwareProperties", {}).get("platform") != "iOS":
        continue
    conexion = aparato.get("connectionProperties", {})
    if conexion.get("pairingState") not in (None, "paired"):
        continue
    identificador = aparato.get("identifier", "")
    nombre = aparato.get("deviceProperties", {}).get("name", "iPhone")
    print(identificador + "\t" + nombre)
    break
' "$LISTA" || true)

UDID="${DISPOSITIVO%%	*}"
NOMBRE="${DISPOSITIVO##*	}"

if [ -z "$UDID" ]; then
    cat >&2 <<'AYUDA'
✗ No veo ningún iPhone emparejado.

  Revisa:
    · que esté conectado con el cable y desbloqueado
    · que hayas tocado "Confiar" en el iPhone
    · que el Modo de desarrollador esté activo:
      Ajustes › Privacidad y seguridad › Modo de desarrollador › activar
AYUDA
    exit 1
fi
gris "$NOMBRE ($UDID)"

# ---------------------------------------------------------------- Compilar

verde "Compilando y firmando (la primera vez tarda un par de minutos)"
mkdir -p "$SALIDA"
REGISTRO="$SALIDA/ultima-compilacion.log"

ARGS=(
    -project "$PROYECTO"
    -scheme "$ESQUEMA"
    -configuration "$CONFIG"
    -destination "id=$UDID"
    -derivedDataPath "$SALIDA"
    -allowProvisioningUpdates
    CODE_SIGN_STYLE=Automatic
    "DEVELOPMENT_TEAM=$EQUIPO"
)
if [ -n "$BUNDLE_ID" ]; then
    ARGS+=("PRODUCT_BUNDLE_IDENTIFIER=$BUNDLE_ID")
    gris "Bundle ID: $BUNDLE_ID"
fi

set +e
xcodebuild "${ARGS[@]}" build 2>&1 | tee "$REGISTRO"
RESULTADO=${PIPESTATUS[0]}
set -e

if [ $RESULTADO -ne 0 ]; then
    echo >&2
    if grep -q "No Account for Team" "$REGISTRO"; then
        cat >&2 <<AYUDA
✗ Xcode no tiene una cuenta para el equipo $EQUIPO.

  Casi siempre es porque falta iniciar sesión:
    Xcode › Settings… (⌘,) › Accounts › +  › Apple ID

  Si ya iniciaste sesión, mira qué equipos conoce tu Xcode y pásale el correcto:
    ./tools/instalar-en-iphone.sh --diagnostico
    ./tools/instalar-en-iphone.sh <TEAM_ID>
AYUDA
    elif grep -q "Failed to register bundle identifier" "$REGISTRO"; then
        cat >&2 <<'AYUDA'
✗ Ese identificador ya lo usó otra cuenta. Usa uno tuyo:
    BUNDLE_ID=com.tunombre.miplata ./tools/instalar-en-iphone.sh
AYUDA
    elif grep -q "maximum number of apps" "$REGISTRO"; then
        cat >&2 <<'AYUDA'
✗ Llegaste al límite de 3 apps firmadas con Apple ID gratuito.
  Borra del iPhone otra app instalada así y vuelve a intentar.
AYUDA
    else
        cat >&2 <<AYUDA
✗ La compilación falló. El registro completo quedó en:
    $REGISTRO
  Cópiame las últimas líneas y lo corrijo.
AYUDA
    fi
    exit $RESULTADO
fi

APP="$SALIDA/Build/Products/$CONFIG-iphoneos/$ESQUEMA.app"
[ -d "$APP" ] || falla "No encuentro la app compilada en $APP"

# ---------------------------------------------------------------- Instalar

verde "Instalando en $NOMBRE"
xcrun devicectl device install app --device "$UDID" "$APP" \
    || falla "No pude instalarla. Revisa que el iPhone esté desbloqueado y con el Modo de desarrollador activo."

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

FIN
