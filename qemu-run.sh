sudo qemu-system-x86_64 \
  -enable-kvm \
  -drive if=pflash,format=raw,unit=0,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,unit=1,file=/usr/share/edk2/x64/OVMF_VARS.4m.fd \
  -cpu host \
  -smp cores=2 \
  -m 2048 \
  -drive file=./install_test.qcow2,format=qcow2,if=none,id=main_disk \
  -device virtio-blk-pci,drive=main_disk,bootindex=2 \
  -drive file=sd-image.iso,format=raw,media=cdrom,readonly=on,if=none,id=cdrom_iso \
  -device ide-cd,drive=cdrom_iso,bootindex=1 \
  -net nic,model=e1000 \
  -net user \

