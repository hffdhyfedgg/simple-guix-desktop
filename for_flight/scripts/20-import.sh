#!/bin/sh
. "$(dirname "$0")/common.sh"
touch /gnu/store/.flight-wtest && rm -f /gnu/store/.flight-wtest \
  || die "/gnu/store только для чтения. Сначала: flight cow-store"

WORK=$(mktemp -d /tmp/flight-import.XXXXXX)
trap 'cd /; rm -rf "$WORK"' EXIT

say "сборка $NAR_BASE из частей..."
cat "$NARS"/$NAR_BASE.part-* > "$WORK/$NAR_BASE"

say "проверка sha256..."
expected=$(cut -d ' ' -f 1 "$NARS/$NAR_BASE.sha256")
actual=$(sha256sum "$WORK/$NAR_BASE" | cut -d ' ' -f 1)
[ -n "$expected" ] || die "sha256-файл пуст или повреждён"
[ "$actual" = "$expected" ] || die "sha256 не сошёлся: ожидалось $expected, получено $actual"

if ls "$NARS"/*.par2 >/dev/null 2>&1; then
  say "проверка par2..."
  cp "$NARS"/*.par2 "$WORK"/
  (cd "$WORK" && par2 verify *.par2 "$NAR_BASE") || die "par2: архив повреждён"
fi

if [ -f "$FLIGHT_ROOT/signing-key-nonguix.pub" ]; then
  say "авторизация ключа nonguix (пригодится после установки)..."
  guix archive --authorize < "$FLIGHT_ROOT/signing-key-nonguix.pub" || true
fi

say "импорт в /gnu/store (это надолго)..."
guix archive --import < "$WORK/$NAR_BASE"
say "IMPORT: OK"
