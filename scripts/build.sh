#!/usr/bin/env zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/macOS_sucks.app"
INSTALL="$HOME/Applications/macOS_sucks.app"
SDK="$(xcrun --show-sdk-path --sdk macosx)"
HOST_SOURCES=("$ROOT"/Sources/*.swift "$ROOT"/Sources/Shared/*.swift)
EXT_SOURCES=("$ROOT"/Sources/FinderSync/*.swift "$ROOT"/Sources/Shared/*.swift)
APPEX="$APP/Contents/PlugIns/AutoTextFinderSync.appex"
CERT_DIR="$ROOT/.certs"
KEYCHAIN="$CERT_DIR/autotext.keychain-db"
PASSWORD="autotext-dev"
IDENTITY="AutoText"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APPEX/Contents/MacOS" "$CERT_DIR" "$HOME/Applications"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
cp "$ROOT/Resources/FinderSync-Info.plist" "$APPEX/Contents/Info.plist"
printf 'XPC!????' > "$APPEX/Contents/PkgInfo"

swiftc \
  -parse-as-library \
  -swift-version 5 \
  -O \
  -target arm64-apple-macos14.0 \
  -sdk "$SDK" \
  -o "$APP/Contents/MacOS/macOS_sucks" \
  "${HOST_SOURCES[@]}" \
  -framework SwiftUI \
  -framework AppKit \
  -framework Carbon \
  -framework ApplicationServices \
  -framework CoreGraphics \
  -framework Combine \
  -framework FinderSync \
  -framework ServiceManagement

swiftc \
  -parse-as-library \
  -swift-version 5 \
  -O \
  -target arm64-apple-macos14.0 \
  -sdk "$SDK" \
  -Xlinker -e -Xlinker _NSExtensionMain \
  -o "$APPEX/Contents/MacOS/AutoTextFinderSync" \
  "${EXT_SOURCES[@]}" \
  -framework Cocoa \
  -framework FinderSync \
  -framework AppKit

if [[ ! -f "$KEYCHAIN" ]]; then
  security create-keychain -p "$PASSWORD" "$KEYCHAIN"
fi
security set-keychain-settings -lut 21600 "$KEYCHAIN" >/dev/null 2>&1 || true
security unlock-keychain -p "$PASSWORD" "$KEYCHAIN"

if ! security find-identity -p codesigning -v "$KEYCHAIN" 2>/dev/null | grep -q "$IDENTITY"; then
  openssl req -new -newkey rsa:2048 -x509 -days 3650 -nodes \
    -subj "/CN=AutoText/O=AutoText/" \
    -addext "extendedKeyUsage=codeSigning" \
    -addext "keyUsage=digitalSignature" \
    -keyout "$CERT_DIR/autotext.key" \
    -out "$CERT_DIR/autotext.crt"
  openssl pkcs12 -export -out "$CERT_DIR/autotext.p12" \
    -inkey "$CERT_DIR/autotext.key" -in "$CERT_DIR/autotext.crt" \
    -passout pass:"$PASSWORD" -name "$IDENTITY"
  security import "$CERT_DIR/autotext.p12" -k "$KEYCHAIN" -P "$PASSWORD" \
    -T /usr/bin/codesign -T /usr/bin/security -A >/dev/null
  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$PASSWORD" "$KEYCHAIN" >/dev/null
  security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$CERT_DIR/autotext.crt" >/dev/null || true
fi

orig_keychains=("${(@f)$(security list-keychains -d user | sed 's/^[[:space:]]*//; s/"//g')}")
if (( ${#orig_keychains[@]} == 0 )); then
  orig_keychains=("$HOME/Library/Keychains/login.keychain-db")
fi

restore_keychains() {
  security list-keychains -d user -s "${orig_keychains[@]}" >/dev/null || true
}
trap restore_keychains EXIT

security list-keychains -d user -s "$KEYCHAIN" "${orig_keychains[@]}" >/dev/null
security unlock-keychain -p "$PASSWORD" "$KEYCHAIN"

codesign --force --sign "$IDENTITY" --identifier local.autotext.FinderSync \
  --entitlements "$ROOT/Resources/FinderSync.entitlements" \
  "$APPEX"

codesign --force --sign "$IDENTITY" --identifier local.autotext \
  --entitlements "$ROOT/Resources/AutoText.entitlements" \
  "$APP"

restore_keychains
trap - EXIT

xattr -cr "$APP" 2>/dev/null || true
rm -rf "$INSTALL" "$HOME/Applications/AutoText.app"
ditto "$APP" "$INSTALL"
xattr -cr "$INSTALL" 2>/dev/null || true

echo "Built $APP"
echo "Installed $INSTALL"
