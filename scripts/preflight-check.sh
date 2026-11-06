#!/usr/bin/env bash
# Проверка полноты for_flight перед сборкой ISO.
set -eu
cd "$(dirname "$0")/.."
F=for_flight
fail=0
need() { [ -e "$1" ] && echo "  OK  $1" || { echo "  НЕТ $1"; fail=1; }; }

echo "== структура for_flight =="
need "$F/channels.scm"
need "$F/signing-key-nonguix.pub"
need "$F/config/configuration.scm"
need "$F/repos/guix/.guix-channel"
need "$F/repos/nonguix/.guix-channel"
need "$F/scripts/flight"
need "$F/scripts/common.sh"
for s in 10-cow-store 20-import 30-channels 31-pull 32-check-offline \
         40-check-disks 50-install 60-swapfile 70-windows-boot; do
  need "$F/scripts/$s.sh"
done
need "$F/nars/$NAR.sha256" 2>/dev/null || true
NAR=system-closure.nar.xz
need "$F/nars/$NAR.sha256"

echo "== целостность nar =="
if ls "$F/nars/$NAR".part-* >/dev/null 2>&1; then
  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
  cat "$F/nars/$NAR".part-* > "$tmp/$NAR"
  (cd "$tmp" && sha256sum -c "$OLDPWD/$F/nars/$NAR.sha256") || fail=1
  if ls "$F/nars"/*.par2 >/dev/null 2>&1; then
    cp "$F/nars"/*.par2 "$tmp"/ && (cd "$tmp" && par2 verify *.par2 "$NAR") || fail=1
  fi
else
  echo "  НЕТ частей $NAR.part-*"; fail=1
fi

echo "== VERSIONS (соответствие guix ISO/замыкания) =="
need "$F/nars/VERSIONS"; cat "$F/nars/VERSIONS" 2>/dev/null || true

[ $fail -eq 0 ] && echo "PREFLIGHT: OK" || { echo "PREFLIGHT: ПРОВАЛ"; exit 1; }
