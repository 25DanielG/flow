#!/bin/bash
# self-signed identity in login keychain so TCC grants survive rebuilds
# (adhoc signing changes identity every build)
#
# run in a real terminal, codesign will prompt "Always Allow"
# safe to re-run
#
#   ./Tools/create-signing-identity.sh

set -euo pipefail

IDENTITY_NAME="Flow Dev Signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

if security find-identity -v -p codesigning "$KEYCHAIN" 2>/dev/null | grep -q "$IDENTITY_NAME"; then
    echo "Signing identity '$IDENTITY_NAME' already exists in $KEYCHAIN — nothing to do."
    exit 0
fi

# clear stale untrusted identity
security delete-identity -c "$IDENTITY_NAME" "$KEYCHAIN" >/dev/null 2>&1 || true

echo "Generating self-signed code-signing certificate '$IDENTITY_NAME'..."
openssl req -x509 -newkey rsa:2048 \
    -keyout "$WORKDIR/flow-signing.key" \
    -out "$WORKDIR/flow-signing.crt" \
    -days 3650 -nodes \
    -subj "/CN=$IDENTITY_NAME" \
    -addext "extendedKeyUsage=codeSigning" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "basicConstraints=critical,CA:false"

openssl pkcs12 -export -legacy \
    -out "$WORKDIR/flow-signing.p12" \
    -inkey "$WORKDIR/flow-signing.key" \
    -in "$WORKDIR/flow-signing.crt" \
    -passout pass:flow-temp-import

echo "Importing into $KEYCHAIN (you may see a keychain access prompt)..."
security import "$WORKDIR/flow-signing.p12" \
    -k "$KEYCHAIN" \
    -P flow-temp-import \
    -T /usr/bin/codesign \
    -T /usr/bin/security

echo "Granting codesign access to the imported key's partition list..."
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" "$KEYCHAIN" >/dev/null 2>&1 || \
    echo "  (partition-list step needs your login keychain password — re-run if codesign later fails with 'errSecInternalComponent')"

echo "Marking the certificate trusted for code signing (self-signed certs aren't trusted by default)..."
security add-trusted-cert -p codeSign -k "$KEYCHAIN" "$WORKDIR/flow-signing.crt"

echo
echo "Done. Verify with:"
echo "  security find-identity -v -p codesigning"
echo
echo "You should see '$IDENTITY_NAME' listed. Tools/bundle-app.sh uses this identity by name."
