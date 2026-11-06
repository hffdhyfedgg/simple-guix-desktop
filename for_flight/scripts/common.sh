# common.sh — подключается всеми полётными скриптами. POSIX sh, KISS.
set -eu

FLIGHT_ROOT="${FLIGHT_ROOT:-}"
if [ -z "$FLIGHT_ROOT" ]; then
  FLIGHT_ROOT=$(ls -d /gnu/store/*-flight-data-installer-*/share/guix-offline 2>/dev/null | sort | tail -n1)
fi
[ -n "$FLIGHT_ROOT" ] || { echo "flight: в /gnu/store нет flight-data-installer" >&2; exit 1; }

NARS="$FLIGHT_ROOT/nars"
REPOS="$FLIGHT_ROOT/repos"
CFG="${CFG:-$FLIGHT_ROOT/config/configuration.scm}"
TARGET="${TARGET:-/mnt}"
NAR_BASE="system-closure.nar.xz"

die() { echo "flight: $*" >&2; exit 1; }
say() { echo "==> $*"; }

pulled_guix() {
  p=$(readlink -f "$HOME/.config/guix/current" 2>/dev/null || true)
  [ -n "$p" ] && [ -x "$p/bin/guix" ] || die "нет результата pull (~/.config/guix/current). Сначала: flight channels && flight pull"
  echo "$p/bin/guix"
}

# Находит ESP с загрузчиком Windows; устанавливает ESP_DEV и ESP_UUID.
detect_esp() {
  ESP_DEV=""; ESP_UUID=""
  mkdir -p /tmp/espchk
  for p in $(lsblk -rno NAME,TYPE | awk '$2=="part"{print "/dev/"$1}'); do
    [ "$(blkid -o value -s TYPE "$p" 2>/dev/null || true)" = vfat ] || continue
    if mount -o ro "$p" /tmp/espchk 2>/dev/null; then
      if [ -f /tmp/espchk/EFI/Microsoft/Boot/bootmgfw.efi ]; then
        ESP_DEV="$p"; ESP_UUID=$(blkid -o value -s UUID "$p")
      fi
      umount /tmp/espchk
    fi
    [ -n "$ESP_DEV" ] && break
  done
  [ -n "$ESP_DEV" ] || die "ESP (vfat) с /EFI/Microsoft/Boot/bootmgfw.efi не найден"
}
