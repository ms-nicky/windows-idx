#!/usr/bin/env bash
set -e

################
# KONFIGURASI
################
ISO_URL="https://go.microsoft.com/fwlink/p/?LinkID=2195443"
ISO_FILE="$HOME/win-server.iso"   # Windows Server 2012 R2

DISK_FILE="$HOME/win11.qcow2"
DISK_SIZE="64G"

RAM="8G"
CORES="4"

VNC_DISPLAY=":0"
RDP_PORT="3389"

WORKDIR="$HOME/windows-idx"

################
# CEK SISTEM
################
[ -e /dev/kvm ] || { echo "❌ /dev/kvm tidak ada"; exit 1; }
command -v qemu-system-x86_64 >/dev/null || { echo "❌ qemu-system-x86_64 tidak ada"; exit 1; }

################
# PERSIAPAN
################
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# BUAT DISK JIKA BELUM ADA
if [ ! -f "$DISK_FILE" ]; then
  echo "📀 Membuat disk $DISK_FILE"
  qemu-img create -f qcow2 "$DISK_FILE" "$DISK_SIZE"
fi

# DOWNLOAD ISO JIKA BELUM ADA
if [ ! -f "$ISO_FILE" ]; then
  echo "⬇️ Download ISO Windows Server 2012 R2"
  wget --no-check-certificate -O "$ISO_FILE" "$ISO_URL"
fi

################
# DETEKSI MODE
################
if [ -f "$ISO_FILE" ]; then
  MODE="install"
else
  MODE="boot"
fi

################
# MODE INSTALL
################
if [ "$MODE" = "install" ]; then
  echo "⚠️ MODE INSTALL WINDOWS SERVER 2012 R2 (BIOS)"
  echo "ℹ️ Windows akan restart sendiri beberapa kali"
  echo "ℹ️ SETELAH masuk desktop, shutdown Windows dari dalam VM"
  echo "ℹ️ Script akan lanjut ke mode boot normal otomatis"

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

  echo "🧹 Menghapus ISO (install selesai)"
  rm -f "$ISO_FILE"

  echo "✅ INSTALL SELESAI – JALANKAN ULANG SCRIPT UNTUK BOOT NORMAL"
  exit 0
fi

################
# MODE BOOT NORMAL
################
echo "✅ MODE BOOT NORMAL WINDOWS SERVER (BIOS)"

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
