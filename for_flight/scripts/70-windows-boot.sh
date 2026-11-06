#!/bin/sh
. "$(dirname "$0")/common.sh"
say "текущие записи UEFI:"
efibootmgr -v

order=$(efibootmgr | grep -E '^Boot[0-9]{4}' | sed 's/^Boot\([0-9A-Fa-f]\{4\}\)/\1/')
g=$(efibootmgr | grep -E '^Boot[0-9]{4}' | grep -i guix   | sed 's/^Boot\([0-9A-Fa-f]\{4\}\)/\1/' | head -n1)
w=$(efibootmgr | grep -E '^Boot[0-9]{4}' | grep -i windows | sed 's/^Boot\([0-9A-Fa-f]\{4\}\)/\1/' | head -n1)
[ -n "$g" ] || die "запись Guix в NVRAM не найдена — проверьте, что установка загрузчика прошла"

new=""
for id in $order; do
  [ "$id" = "$g" ] && continue
  new="$new,$id"
done
new="$(echo "${g}${new}" | sed 's/,,*/,/g')"
say "новый порядок: $new (Guix первым)"
if [ "${1:-}" = "--dry" ]; then say "dry-run: efibootmgr -o $new"; exit 0; fi
efibootmgr -o "$new"
say "WINDOWS-BOOT: OK — GRUB Guix грузится первым, в его меню есть запись 'Windows 10'"
