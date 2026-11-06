#!/bin/sh
. "$(dirname "$0")/common.sh"
export LC_ALL=C   # детерминированный парсинг сообщений guix
G=$(pulled_guix)
fail=0

scan() { # scan <вывод> — ищет признаки недостающих сборок/загрузок
  if echo "$1" | grep -Eq "will be built|will be downloaded|would be built"; then
    echo "$1"; fail=1
  fi
}

say "проверка замыкания ОС: $CFG"
out=$("$G" system build --no-substitutes --dry-run "$CFG" 2>&1) || { echo "$out"; fail=1; }
scan "$out"

say "проверка того, что guix system init достраивает сверх системы (bootloader)"
out=$("$G" build --no-substitutes --dry-run grub-efi efibootmgr 2>&1) || { echo "$out"; fail=1; }
scan "$out"

[ "$fail" -eq 0 ] || die "OFFLINE-CHECK: НЕ ПРОЙДЕН — чего-то не хватает в store"
say "OFFLINE-CHECK: OK — установка возможна полностью без сети"
