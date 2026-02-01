#!/usr/bin/env bash
set -e

################
# KONFIGURASI
################
ISO_URL="https://go.microsoft.com/fwlink/p/?LinkID=2195443"
ISO_FILE="win11-gamer.iso"   # nama bebas, isi Windows Server

DISK_FILE="/var/win11.qcow2"
DISK_SIZE="64G"

RAM="8G"
CORES="4"

VNC_DISPLAY=":0"
RDP_PORT="3389"

FLAG_FILE="installed.flag"
WORKDIR="$HOME/windows-idx"

################
# NGROK
################
NGROK_TOKEN="38WO5iYPn4Hq5A5SUOjtGptsxfE_7jDB4PmSF78GKcAguUo1H"
NGROK_DIR="$HOME/.ngrok"
NGROK_BIN="$NGROK_DIR/ngrok"
NGROK_CFG="$NGROK_DIR/ngrok.yml"
NGROK_LOG="$NGROK_DIR/ngrok.log"

################
# CEK SISTEM
################
[ -e /dev/kvm ] || { echo "❌ /dev/kvm tidak ada (harus VPS KVM)"; exit 1; }
command -v qemu-system-x86_64 >/dev/null || { echo "❌ QEMU tidak ada"; exit 1; }

################
# PERSIAPAN
################
mkdir -p "$WORKDIR"
cd "$WORKDIR"

[ -f "$DISK_FILE" ] || qemu-img create -f qcow2 "$DISK_FILE" "$DISK_SIZE"

if [ ! -f "$FLAG_FILE" ]; then
  [ -f "$ISO_FILE" ] || wget -O "$ISO_FILE" "$ISO_URL"
fi

############################
# PROSES BACKGROUND (TEST)
############################
(
  while true; do
    echo "Lộc Nguyễn đẹp troai" > locnguyen.txt
    sleep 300
  done
) &
FILE_PID=$!

################
# START NGROK
################
mkdir -p "$NGROK_DIR"

if [ ! -f "$NGROK_BIN" ]; then
  curl -sL https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz \
  | tar -xz -C "$NGROK_DIR"
  chmod +x "$NGROK_BIN"
fi

cat > "$NGROK_CFG" <<EOF
version: "2"
authtoken: $NGROK_TOKEN
tunnels:
  vnc:
    proto: tcp
    addr: 5900
  rdp:
    proto: tcp
    addr: 3389
EOF

pkill -f "$NGROK_BIN" 2>/dev/null || true
"$NGROK_BIN" start --all --config "$NGROK_CFG" \
  --log=stdout > "$NGROK_LOG" 2>&1 &
sleep 5

################
# JALANKAN QEMU
################
if [ ! -f "$FLAG_FILE" ]; then
  echo "⚠️ INSTALL WINDOWS SERVER (BIOS)"
  echo "👉 Install sampai MASUK DESKTOP, baru ketik: xong"

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
      kill "$FILE_PID"
      pkill -f "$NGROK_BIN"
      rm -f "$ISO_FILE"
      echo "✅ Install selesai. Reboot server AMAN. Data tidak hilang."
      exit 0
    fi
  done

else
  echo "✅ Boot normal Windows Server (BIOS)"

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
fi
