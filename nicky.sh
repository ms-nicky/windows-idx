#!/usr/bin/env bash
set -e

### CONFIG ###
ISO_URL="https://go.microsoft.com/fwlink/p/?LinkID=2195443"
ISO_FILE="win-server.iso"

DISK_FILE="$HOME/win11.qcow2"     # ✅ PERSISTENT
DISK_SIZE="64G"

RAM="8G"
CORES="4"

VNC_DISPLAY=":0"
RDP_PORT="3389"

FLAG_FILE="$HOME/installed.flag" # ✅ SEJALUR DENGAN DISK
WORKDIR="$HOME/windows-idx"

### CHECK ###
[ -e /dev/kvm ] || { echo "❌ /dev/kvm tidak ada"; exit 1; }
command -v qemu-system-x86_64 >/dev/null || { echo "❌ qemu tidak ada"; exit 1; }

### PREP ###
mkdir -p "$WORKDIR"
cd "$WORKDIR"

[ -f "$DISK_FILE" ] || qemu-img create -f qcow2 "$DISK_FILE" "$DISK_SIZE"

if [ ! -f "$FLAG_FILE" ]; then
  [ -f "$ISO_FILE" ] || wget --no-check-certificate -O "$ISO_FILE" "$ISO_URL"
fi

#################
# RUN QEMU
#################
if [ ! -f "$FLAG_FILE" ]; then
  echo "⚠️ MODE INSTALL WINDOWS SERVER 2012 R2 (BIOS)"
  echo "👉 Install sampai MASUK DESKTOP, lalu shutdown Windows"

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

  touch "$FLAG_FILE"
  echo "✅ INSTALL SELESAI – DATA AMAN SAAT RESTART"
  exit 0
fi

echo "✅ BOOT NORMAL WINDOWS (DATA TETAP ADA)"

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
