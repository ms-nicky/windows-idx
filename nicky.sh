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
WORKDIR="$HOME/windows-idx"

################
# OVMF (UEFI)
################
OVMF_CODE=$(ls /nix/store/*OVMF*/FV/OVMF_CODE.fd | head -n1)
OVMF_VARS_SRC=$(ls /nix/store/*OVMF*/FV/OVMF_VARS.fd | head -n1)
OVMF_VARS="$WORKDIR/OVMF_VARS.fd"

################
# NGROK
################
NGROK_TOKEN="38WO5iYPn4Hq5A5SUOjtGptsxfE_7jDB4PmSF78GKcAguUo1H"
NGROK_DIR="$HOME/.ngrok"
NGROK_BIN="$NGROK_DIR/ngrok"
NGROK_CFG="$NGROK_DIR/ngrok.yml"
NGROK_LOG="$NGROK_DIR/ngrok.log"

################
# CHECK
################
[ -e /dev/kvm ] || { echo "❌ No /dev/kvm"; exit 1; }
command -v qemu-system-x86_64 >/dev/null || { echo "❌ No qemu"; exit 1; }
[ -f "$OVMF_CODE" ] || { echo "❌ OVMF_CODE.fd not found"; exit 1; }

################
# PREP
################
mkdir -p "$WORKDIR"
cd "$WORKDIR"

[ -f "$DISK_FILE" ] || qemu-img create -f qcow2 "$DISK_FILE" "$DISK_SIZE"
[ -f "$OVMF_VARS" ] || cp "$OVMF_VARS_SRC" "$OVMF_VARS"

if [ ! -f "$FLAG_FILE" ]; then
  [ -f "$ISO_FILE" ] || wget --no-check-certificate -O "$ISO_FILE" "$ISO_URL"
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
# NGROK START
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

VNC_ADDR=$(grep -oE 'tcp://[^ ]+' "$NGROK_LOG" | sed -n '1p')
RDP_ADDR=$(grep -oE 'tcp://[^ ]+' "$NGROK_LOG" | sed -n '2p')

echo "🌍 VNC PUBLIC : $VNC_ADDR"
echo "🌍 RDP PUBLIC : $RDP_ADDR"

################
# RUN QEMU
################
if [ ! -f "$FLAG_FILE" ]; then
  echo "⚠️  MODE INSTALL WINDOWS (UEFI)"
  echo "👉 Setelah selesai install, ketik: xong"

  qemu-system-x86_64 \
    -enable-kvm \
    -machine q35 \
    -cpu host \
    -smp "$CORES" \
    -m "$RAM" \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
    -drive if=pflash,format=raw,file="$OVMF_VARS" \
    -drive file="$DISK_FILE",if=virtio,format=qcow2 \
    -cdrom "$ISO_FILE" \
    -boot menu=on \
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
      pkill -f "$NGROK_BIN"
      rm -f "$ISO_FILE"
      echo "✅ Install selesai — boot UEFI normal"
      exit 0
    fi
  done

else
  echo "✅ Windows sudah terpasang — boot UEFI"

  qemu-system-x86_64 \
    -enable-kvm \
    -machine q35 \
    -cpu host \
    -smp "$CORES" \
    -m "$RAM" \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
    -drive if=pflash,format=raw,file="$OVMF_VARS" \
    -drive file="$DISK_FILE",if=virtio,format=qcow2 \
    -boot order=c \
    -netdev user,id=net0,hostfwd=tcp::3389-:3389 \
    -device e1000,netdev=net0 \
    -vnc "$VNC_DISPLAY" \
    -usb -device usb-tablet
fi
