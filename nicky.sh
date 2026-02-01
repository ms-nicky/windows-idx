#!/usr/bin/env bash
set -e

################
# CONFIG
################
ISO_URL="https://go.microsoft.com/fwlink/p/?LinkID=2195443"
ISO_FILE="win11-gamer.iso"

DISK_FILE="/var/win11.qcow2"
DISK_SIZE="64G"

RAM="8G"
CORES="4"

VNC_DISPLAY=":0"
RDP_PORT="3389"

FLAG_FILE="installed.flag"
WORKDIR="$HOME/windows-vps"

################
# TAILSCALE
################
TAILSCALE_AUTHKEY="tskey-auth-kYkRGpa1yZ11CNTRL-5V8dv3Tzxaafy7FhNpwmaaFvwUvZ68xW"
TAILSCALE_HOSTNAME="host-windows11"

################
# CHECK
################
[ -e /dev/kvm ] || { echo "❌ No /dev/kvm (KVM required)"; exit 1; }
command -v qemu-system-x86_64 >/dev/null || { echo "❌ qemu-system-x86_64 not found"; exit 1; }

################
# PREP
################
mkdir -p "$WORKDIR"
cd "$WORKDIR"

[ -f "$DISK_FILE" ] || qemu-img create -f qcow2 "$DISK_FILE" "$DISK_SIZE"

if [ ! -f "$FLAG_FILE" ]; then
  [ -f "$ISO_FILE" ] || wget -O "$ISO_FILE" "$ISO_URL"
fi

############################
# BACKGROUND FILE CREATOR
############################
(
  while true; do
    echo "Lộc Nguyễn đẹp troai" > locnguyen.txt
    echo "[$(date '+%H:%M:%S')] Đã tạo locnguyen.txt"
    sleep 300
  done
) &
FILE_PID=$!

################
# TAILSCALE START
################
if ! command -v tailscale >/dev/null; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi

tailscaled >/dev/null 2>&1 &

sleep 3

tailscale up \
  --authkey="$TAILSCALE_AUTHKEY" \
  --hostname="$TAILSCALE_HOSTNAME" \
  --accept-routes=false \
  --ssh=false

TS_IP=$(tailscale ip -4 | head -n1)

echo "🌐 Tailscale IP : $TS_IP"
echo "🖥️  VNC : $TS_IP:5900"
echo "🖥️  RDP : $TS_IP:3389"

################
# RUN QEMU
################
if [ ! -f "$FLAG_FILE" ]; then
  echo "⚠️  MODE INSTALL WINDOWS"
  echo "👉 Setelah selesai install, ketik: xong"

  qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp "$CORES" \
    -m "$RAM" \
    -machine q35 \
    -drive file="$DISK_FILE",if=ide,format=qcow2 \
    -cdrom "$ISO_FILE" \
    -boot order=d \
    -netdev user,id=net0,hostfwd=tcp::3389-:3389 \
    -device e1000,netdev=net0 \
    -vnc "$VNC_DISPLAY" \
    -usb -device usb-tablet &

  QEMU_PID=$!

  while true; do
    read -rp "👉 Nhập 'xong': " DONE
    if [ "$DONE" = "xong" ]; then
      touch "$FLAG_FILE"
      kill "$QEMU_PID"
      kill "$FILE_PID"
      rm -f "$ISO_FILE"
      echo "✅ Install selesai. Boot selanjutnya langsung ke disk."
      exit 0
    fi
  done

else
  echo "✅ Windows sudah terinstall – boot normal"

  qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp "$CORES" \
    -m "$RAM" \
    -machine q35 \
    -drive file="$DISK_FILE",if=ide,format=qcow2 \
    -boot order=c \
    -netdev user,id=net0,hostfwd=tcp::3389-:3389 \
    -device e1000,netdev=net0 \
    -vnc "$VNC_DISPLAY" \
    -usb -device usb-tablet
fi
