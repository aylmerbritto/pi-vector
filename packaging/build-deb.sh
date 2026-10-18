#!/bin/bash
# Assemble wirepod_<VER>_arm64.deb from a built wire-pod tree + this repo's packaging files.
# Env: VERSION, WIREPOD (path to cloned+built kercre123/wire-pod), VOSKLIB (libvosk.so),
#      PKG (this repo's packaging/ dir), OUT (output .deb path). Needs sudo/root for dpkg-deb owners.
set -euo pipefail
export LC_ALL=C
: "${VERSION:?set VERSION}"; : "${WIREPOD:?set WIREPOD}"; : "${VOSKLIB:?set VOSKLIB}"
: "${PKG:?set PKG}"; : "${OUT:=wirepod_${VERSION}_arm64.deb}"
STAGE=$(mktemp -d)/wirepod_${VERSION}_arm64
P=$STAGE/opt/wirepod
mkdir -p "$P/chipper" "$P/vosk/models" "$P/lib" \
         "$STAGE/DEBIAN" "$STAGE/lib/systemd/system" "$STAGE/usr/bin" "$STAGE/etc/wirepod"

cp "$WIREPOD/chipper/chipper"            "$P/chipper/chipper"
cp "$VOSKLIB"                            "$P/lib/libvosk.so"
cp -r "$WIREPOD/vosk/models/en-US"       "$P/vosk/models/en-US"
cp -r "$WIREPOD/chipper/intent-data"     "$P/chipper/intent-data"
cp -r "$WIREPOD/chipper/webroot"         "$P/chipper/webroot"
cp -r "$WIREPOD/chipper/epod"            "$P/chipper/epod"
cp    "$WIREPOD/chipper/weather-map.json" "$P/chipper/" 2>/dev/null || true
cp    "$WIREPOD/chipper/stttest.pcm"      "$P/chipper/" 2>/dev/null || true
mkdir -p "$P/chipper/certs" "$P/chipper/jdocs" "$P/chipper/session-certs"
cp -r "$WIREPOD/chipper/certs/." "$P/chipper/certs/" 2>/dev/null || true
cp "$PKG/apiConfig.default.json" "$P/chipper/apiConfig.json.default"

cp "$PKG/wirepod.service"        "$STAGE/lib/systemd/system/wirepod.service"
cp "$PKG/wirepod-update.service" "$STAGE/lib/systemd/system/wirepod-update.service"
cp "$PKG/wirepod-update.timer"   "$STAGE/lib/systemd/system/wirepod-update.timer"
cp "$PKG/wirepod-update"         "$STAGE/usr/bin/wirepod-update"; chmod +x "$STAGE/usr/bin/wirepod-update"
cp "$PKG/update.conf"            "$STAGE/etc/wirepod/update.conf"
cp "$PKG/wirepod-setwifi"     "$STAGE/usr/bin/wirepod-setwifi"; chmod +x "$STAGE/usr/bin/wirepod-setwifi"

INSTSIZE=$(du -sk "$STAGE/opt" | cut -f1)
cat > "$STAGE/DEBIAN/control" <<CTL
Package: wirepod
Version: $VERSION
Section: sound
Priority: optional
Architecture: arm64
Depends: libopus0, libatomic1, libsodium23, avahi-daemon, curl, jq
Installed-Size: $INSTSIZE
Maintainer: aylmer <aylmerdummy@gmail.com>
Homepage: https://github.com/aylmerbritto/pi-vector
Description: wire-pod (escape pod) voice server for Anki Vector - Pi appliance
 Prebuilt arm64, voice-only (Vosk STT, no LLM). Serves a real Vector on the LAN
 via escapepod.local. Self-updates from GitHub Releases via wirepod-update.timer.
CTL
echo "/etc/wirepod/update.conf" > "$STAGE/DEBIAN/conffiles"

cat > "$STAGE/DEBIAN/postinst" <<'PI'
#!/bin/bash
set -e
[ -f /opt/wirepod/chipper/apiConfig.json ] || cp /opt/wirepod/chipper/apiConfig.json.default /opt/wirepod/chipper/apiConfig.json
systemctl daemon-reload || true
systemctl enable wirepod.service wirepod-update.timer || true
systemctl restart wirepod.service || true
systemctl start wirepod-update.timer || true
exit 0
PI
cat > "$STAGE/DEBIAN/prerm" <<'PR'
#!/bin/bash
set -e
if [ "$1" = remove ] || [ "$1" = purge ]; then
  systemctl stop wirepod.service wirepod-update.timer || true
  systemctl disable wirepod.service wirepod-update.timer || true
fi
exit 0
PR
chmod +x "$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/prerm" "$P/chipper/chipper"

dpkg-deb -Zgzip -z1 --build --root-owner-group "$STAGE" "$OUT"
echo "built $OUT"
