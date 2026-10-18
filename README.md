# pi-vector

A packaged **wire-pod** (escape-pod) voice server for Anki Vector, built as an
arm64 Debian package for a Raspberry Pi appliance. Voice-only (Vosk STT, no LLM);
serves a real Vector on the LAN via `escapepod.local`.

## Install on a Pi (Raspberry Pi OS / Debian arm64)
```sh
curl -fsSL -o wirepod.deb \
  "$(curl -fsSL https://api.github.com/repos/aylmerbritto/pi-vector/releases/latest \
     | grep -oE 'https[^"]*wirepod_[^"]*_arm64\.deb')"
sudo apt install -y ./wirepod.deb        # pulls deps (jq, libopus0, …)
```
Installs to `/opt/wirepod`, runs `wirepod.service`, and arms `wirepod-update.timer`
(daily) which self-updates from this repo's latest Release.

## What's in the package
- `/opt/wirepod/chipper/chipper` — prebuilt arm64 binary (no Go/compile on device)
- `/opt/wirepod/lib/libvosk.so`, `/opt/wirepod/vosk/models/en-US` — STT
- `wirepod.service` (voice-only, escape-pod mode, port 443)
- `wirepod-update` + `wirepod-update.timer` — pull-based auto-update from GitHub Releases
- `/etc/wirepod/update.conf` — points the updater at this repo (public, no token)

## Releasing a new version
Tag it: `git tag v1.2.3 && git push --tags`. The GitHub Actions workflow builds the
arm64 `.deb` (installing `binutils-gold` — required for cgo on Debian arm64) and
attaches it to the Release. Pis pick it up on their next timer run.

## Roadmap
- Headless WiFi provisioning for remote (friend's-place) deployment
- Custom VicOS OTA served via the pod
