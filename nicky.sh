#!/usr/bin/env bash
set -e

################
# KONFIGURASI
################
ISO_URL="https://go.microsoft.com/fwlink/p/?LinkID=2195443"
ISO_FILE="$HOME/win-server.iso"

DISK_FILE="$HOME/win11.qcow2"
DISK_SIZE="64G"

RAM="8G"
CORES="4"
VNC_DISPLAY=":0"

################
# CEK SISTEM
################
[ -e /dev/kvm ] || { echo "❌ /dev/kvm tidak ada"; exit 1; }
command -v qemu-system-x86_64 >/dev/null || { echo "❌ qemu tidak ada"; exit 1; }

################
# PERSIAPAN
################
mkdir -p "$HOME/windows-idx"
cd "$HOME/windows-idx"

[ -f "$DISK_FILE" ] || qemu-img create -f qcow2 "$DISK_FILE" "$DISK_SIZE"
[ -f "$ISO_FILE" ] || wget --no-check-certificate -O "$ISO_FILE" "$ISO_URL"

DISK_MB=$(du -m "$DISK_FILE" | cut -f1)

################
# MODE INSTALL
################
if [ "$DISK_MB" -lt 2000 ]; then
  echo "⚠️ MODE INSTALL WINDOWS SERVER 2012 R2"
  echo "ℹ️ Jangan tutup QEMU"
  echo "ℹ️ Biarkan Windows reboot sendiri"

  qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp "$CORES" \
    -m "$RAM" \
    -machine pc \
    \
    -device ich9-ahci,id=ahci \
    -drive file="$DISK_FILE",format=qcow2,if=none,id=drive0,cache=writeback \
    -device ide-hd,drive=drive0,bus=ahci.0 \
    \
    -drive file="$ISO_FILE",media=cdrom \
    -boot order=d \
    \
    -netdev user,id=net0,hostfwd=tcp::3389-:3389 \
    -device e1000,netdev=net0 \
    \
    -vnc "$VNC_DISPLAY" \
    -usb -device usb-tablet

  exit 0
fi

################
# MODE BOOT NORMAL
################
echo "✅ MODE BOOT NORMAL WINDOWS SERVER"

qemu-system-x86_64 \
  -enable-kvm \
  -cpu host \
  -smp "$CORES" \
  -m "$RAM" \
  -machine pc \
  \
  -device ich9-ahci,id=ahci \
  -drive file="$DISK_FILE",format=qcow2,if=none,id=drive0,cache=writeback \
  -device ide-hd,drive=drive0,bus=ahci.0 \
  \
  -boot order=c \
  \
  -netdev user,id=net0,hostfwd=tcp::3389-:3389 \
  -device e1000,netdev=net0 \
  \
  -vnc "$VNC_DISPLAY" \
  -usb -device usb-tablet
