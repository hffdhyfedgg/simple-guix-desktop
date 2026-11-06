#!/bin/sh
. "$(dirname "$0")/common.sh"
mountpoint -q "$TARGET" || die "$TARGET не смонтирован. Сначала: mount LABEL=guix-root $TARGET"
say "cow-store -> $TARGET (записи пойдут на целевой диск, не в RAM)"
herd start cow-store "$TARGET"
touch /gnu/store/.flight-wtest && rm -f /gnu/store/.flight-wtest \
  || die "/gnu/store не доступен на запись — cow-store не запустился"
say "COW-STORE: OK"
