#!/bin/sh
. "$(dirname "$0")/common.sh"
[ -d "$REPOS/guix" ]    || die "нет $REPOS/guix (в for_flight должны быть снимки репозиториев!)"
[ -d "$REPOS/nonguix" ] || die "нет $REPOS/nonguix"
[ -f "$REPOS/guix/.guix-channel" ] || die "$REPOS/guix не похож на канал (нет .guix-channel)"

mkdir -p /etc/guix
cat > /etc/guix/channels.scm <<EOF
;; Сгенерировано flight channels. Каналы = локальные снимки коммитов (без .git).
(list (channel (name 'guix)    (url "$REPOS/guix"))
      (channel (name 'nonguix) (url "$REPOS/nonguix")))
EOF
say "CHANNELS: /etc/guix/channels.scm записан"
cat /etc/guix/channels.scm
