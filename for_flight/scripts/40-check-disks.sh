#!/bin/sh
. "$(dirname "$0")/common.sh"
say "карта дисков:"
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,PARTLABEL,UUID
echo

ROOT_DEV=$(findfs LABEL=guix-root 2>/dev/null || true)
[ -n "$ROOT_DEV" ] || die "раздел с LABEL=guix-root не найден"
[ "$(blkid -o value -s TYPE "$ROOT_DEV")" = ext4 ] || die "$ROOT_DEV: ожидался ext4"
say "корень: $ROOT_DEV (ext4) OK"

detect_esp
say "ESP: $ESP_DEV UUID=$ESP_UUID, bootmgfw.efi Windows на месте OK"

say "текущие записи UEFI:"
efibootmgr -v || true

if mountpoint -q "$TARGET"; then say "ВНИМАНИЕ: $TARGET уже смонтирован"; fi
say "DISK-CHECK: OK"
