#!/usr/bin/env bash
# Монтирует ISO и проверяет, что flight-данные на месте и не побиты.
set -eu
cd "$(dirname "$0")/.."
ISO=${1:-simple-desktop-guix.iso}
MNT=${2:-check_iso}
mkdir -p "$MNT"
mountpoint -q "$MNT" || sudo mount -o loop,ro "$ISO" "$MNT"
trap 'sudo umount "$MNT" 2>/dev/null || true' EXIT

FD=$(ls -d "$MNT"/gnu/store/*-flight-data-installer-*/share/guix-offline 2>/dev/null | head -n1)
[ -n "$FD" ] || { echo "НЕТ flight-data-installer в store ISO"; exit 1; }
fail=0
for p in nars channels/guix-shallow channels/nonguix-shallow config/configuration.scm scripts/flight signing-key-nonguix.pub; do
  [ -e "$FD/$p" ] && echo "  OK  $p" || { echo "  НЕТ $p"; fail=1; }
done
# bin/flight в самом пакете
BIN=$(dirname "$(dirname "$FD")")/bin/flight
[ -x "$BIN" ] && echo "  OK  bin/flight" || { echo "  НЕТ bin/flight (или не исполняемый)"; fail=1; }
# целостность частей nar внутри ISO
tmp=$(mktemp -d); trap 'rm -rf "$tmp"; sudo umount "$MNT" 2>/dev/null || true' EXIT
cat "$FD"/nars/system-closure.nar.xz.part-* > "$tmp/system-closure.nar.xz"
(cd "$tmp" && sha256sum -c "$FD/nars/system-closure.nar.xz.sha256") || fail=1
[ $fail -eq 0 ] && echo "CHECK-ISO: OK" || { echo "CHECK-ISO: ПРОВАЛ"; exit 1; }
