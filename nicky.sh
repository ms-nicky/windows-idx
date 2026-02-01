#!/usr/bin/env bash
set -e

################
# KONFIGURASI
################
ISO_URL="https://go.microsoft.com/fwlink/p/?LinkID=2195443"
ISO_FILE="win11-gamer.iso"   # nama bebas, isi Windows Server 2012 R2

DISK_FILE="/var/win11.qcow2"
DISK_SIZE="64G"

RAM="8G"
CORES="4"

VNC_DISPLAY=":0"
RDP_PORT="3389"

FLAG_FILE="installed.flag"
WORKDIR="$HOME/windows-server-bios"

################
# CEK SISTEM
################
[ -e /dev/kvm ] || { echo "❌ VPS bukan KVM"; exit 1; }
command -v qemu-system-x86_64 >/dev/null || { echo "❌ QEMU tidak ada"; exit 1; }

################
# PERSIAPAN
################
mkdir -p "$WORKDIR"
cd "$WORKDIR"

if [ ! -f "$DISK_FILE" ]; then
  qemu-img create -f qcow2 "$DISK_FILE" "$DISK_SIZE"
fi

if [ ! -f "$ISO_FILE" ]; then
  wget --no-check-certificate -O "$ISO_FILE" "$ISO_URL"
fi

################
# INSTALL WINDOWS (BIOS)
################
if [ ! -f "$FLAG_FILE" ]; then
  echo "⚠️ MODE INSTALL WINDOWS SERVER 2012 R2 (BIOS)"
  echo "👉 INSTALL SAMPAI MASUK DESKTOP, BARU KETIK: xong"

  qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp "$CORES" \
    -m "$RAM" \
    -machine pc \
    -drive file="$DISK_FILE",format=qcow2 \
    -drive file="$ISO_FILE",media=cdrom \
    -boot order=d \
    -netdev user,id=net0,hostfwd=tcp::3389-:3389 \
    -device e1000,netdev=net0 \
    -vnc "$VNC_DISPLAY" \
    -usb -device usb-tablet &

  QEMU_PID=$!

  while true; do
    read -rp "👉 Ketik 'xong': " DONE
    if [ "$DONE" = "xong" ]; then
      touch "$FLAG_FILE"
      kill "$QEMU_PID"
      rm -f "$ISO_FILE"
      echo "✅ INSTALL SELESAI. REBOOT SERVER AMAN."
      exit 0
    fi
  done
fi

################
# BOOT NORMAL (SETELAH RESTART)
################
echo "✅ BOOT NORMAL WINDOWS SERVER (BIOS)"

qemu-system-x86_64 \
  -enable-kvm \
  -cpu host \
  -smp "$CORES" \
  -m "$RAM" \
  -machine pc \
  -drive file="$DISK_FILE",format=qcow2 \
  -boot order=c \
  -netdev user,id=net0,hostfwd=tcp::3389-:3389 \
  -device e1000,netdev=net0 \
  -vnc "$VNC_DISPLAY" \
  -usb -device usb-tablet
