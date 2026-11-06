;; installer.scm
(use-modules (gnu)
             (gnu system install)
             (gnu packages disk)
             (gnu packages package-management) ; для guix-for-channels
             (guix packages)
             (guix gexp)
             (guix channels)                   ; для channel и %default-channels
             (guix build-system copy))

(use-package-modules
 linux package-management file-systems admin networking vim tmux backup compression)

;;; ── Список каналов, которые должен «знать» Guix внутри образа ──
;;; Он должен полностью совпадать с содержимым for_flight/channels.scm.
(define my-channels
  (list (channel
         (name 'nonguix)
         (url "https://gitlab.com/nonguix/nonguix")
         (branch "master")
         (commit "c241d19ff840dc75556f722b231760d119b6adea")
         (introduction
          (make-channel-introduction
           "897c1a470da759236cc11798f4e0a5f7d4d59fbc"
           (openpgp-fingerprint
            "2A39 3FFF 68F4 EF7A 3D29  12AF 6F51 20A0 22FB B2D5"))))
        (channel
         (name 'guix)
         (url "https://codeberg.org/guix/guix.git")
         (branch "master")
         (commit "94233f99b9c3c2d39e70374774f4bd357eee86ee")
         (introduction
          (make-channel-introduction
           "9edb3f66fd807b096b48283debdcddccfea34bad"
           (openpgp-fingerprint
            "BBB0 2DDF 2CEA F6A8 0D1D  E643 A2A0 6DF2 A33A 54FA"))))))

;;; ── Пакет с офлайн-данными ──────────────────────────────
(define flight-data-installer
  (package
    (name "flight-data-installer")
    (version "1.0")
    (source (local-file "for_flight" #:recursive? #t))
    (build-system copy-build-system)
    (arguments
     (list #:install-plan
           #~'(("channels.scm"            "share/guix-offline/channels.scm")
              ("signing-key-nonguix.pub"  "share/guix-offline/signing-key-nonguix.pub")
              ("nars"                     "share/guix-offline/nars")
              ("config"                   "share/guix-offline/config")
              ("scripts"                  "share/guix-offline/scripts")
              ("scripts/flight"           "bin/flight"))))
    (synopsis "Offline data for Guix installer")
    (home-page "https://example.com")
    (description "Embeds channels, keys and NARs into the installer ISO.")
    (license #f)))

;;; ── Система ─────────────────────────────────────────────
(operating-system
  (inherit installation-os)

  (host-name "guix-installer")
  (timezone "Europe/Moscow")
  (locale "ru_RU.utf8")
  (keyboard-layout (keyboard-layout "us,ru"
                                    #:options '("grp:alt_shift_toggle")))

  (packages
   (append
    (list parted gptfdisk dosfstools e2fsprogs btrfs-progs
          util-linux iproute vim tmux par2cmdline
          flight-data-installer efibootmgr xz)
    %base-packages))

  ;; ▸▸▸ Исправлено: используем operating-system-user-services ▸▸▸
  (services
   (modify-services (operating-system-user-services installation-os)
     (guix-service-type
      config => (guix-configuration
                 (inherit config)
                 ;; 1. Пакет guix, собранный с учётом my-channels:
                 (guix (guix-for-channels my-channels))
                 ;; 2. Файл /etc/guix/channels.scm с теми же каналами:
                 (channels my-channels))))))
