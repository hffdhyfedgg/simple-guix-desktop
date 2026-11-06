#!/bin/sh
. "$(dirname "$0")/common.sh"
G=$(pulled_guix)

ROOT_DEV=$(findfs LABEL=guix-root) || die "нет LABEL=guix-root"
if ! mountpoint -q "$TARGET"; then mkdir -p "$TARGET"; mount "$ROOT_DEV" "$TARGET"; fi
detect_esp
mkdir -p "$TARGET/boot/efi"
mountpoint -q "$TARGET/boot/efi" || mount "$ESP_DEV" "$TARGET/boot/efi"

say "guix system init (без подстановок)..."
"$G" system init --no-substitutes "$CFG" "$TARGET"

say "перенос снимков каналов на целевую систему (для будущих guix pull)..."
mkdir -p "$TARGET/var/guix/flight-channels" "$TARGET/root/.config/guix"
cp -a "$REPOS/." "$TARGET/var/guix/flight-channels/"
cat > "$TARGET/root/.config/guix/channels.scm" <<EOF
(list (channel (name 'guix)    (url "/var/guix/flight-channels/guix"))
      (channel (name 'nonguix) (url "/var/guix/flight-channels/nonguix")))
EOF

say "INSTALL: OK. Далее: flight swapfile, flight windows-boot, затем reboot"
