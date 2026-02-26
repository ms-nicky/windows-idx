#!/usr/bin/env bash
set -e

################
# KONFIGURASI
################
ISO_URL="https://cdimage.kali.org/kali-2025.4/kali-linux-2025.4-installer-amd64.iso"
ISO_FILE="kali-linux.iso"

DISK_FILE="/var/kali.qcow2"
DISK_SIZE="40G"

RAM="4G"
CORES="2"

VNC_DISPLAY=":0"
SSH_PORT="22"

FLAG_FILE="installed.flag"
WORKDIR="$HOME/kali-idx"

################
# NGROK
################
NGROK_TOKEN="ISI_TOKEN_NGROK_KAMU"
NGROK_DIR="$HOME/.ngrok"
NGROK_BIN="$NGROK_DIR/ngrok"
NGROK_CFG="$NGROK_DIR/ngrok.yml"
NGROK_LOG="$NGROK_DIR/ngrok.log"

################
# CEK SISTEM
################
[ -e /dev/kvm ] || { echo "/dev/kvm tidak ditemukan (KVM wajib)"; exit 1; }
command -v qemu-system-x86_64 >/dev/null || { echo "QEMU belum terinstall"; exit 1; }

################
# PERSIAPAN
################
mkdir -p "$WORKDIR"
cd "$WORKDIR"

[ -f "$DISK_FILE" ] || qemu-img create -f qcow2 "$DISK_FILE" "$DISK_SIZE"

if [ ! -f "$FLAG_FILE" ]; then
  [ -f "$ISO_FILE" ] || wget -O "$ISO_FILE" "$ISO_URL"
fi

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
  ssh:
    proto: tcp
    addr: 22
EOF

pkill -f "$NGROK_BIN" 2>/dev/null || true
"$NGROK_BIN" start --all --config "$NGROK_CFG" \
  --log=stdout > "$NGROK_LOG" 2>&1 &
sleep 5

VNC_ADDR=$(grep -oE 'tcp://[^ ]+' "$NGROK_LOG" | sed -n '1p')
SSH_ADDR=$(grep -oE 'tcp://[^ ]+' "$NGROK_LOG" | sed -n '2p')

echo "VNC PUBLIK : $VNC_ADDR"
echo "SSH PUBLIK : $SSH_ADDR"

################
# JALANKAN QEMU
################
if [ ! -f "$FLAG_FILE" ]; then
  echo "MODE INSTALL KALI LINUX"
  echo "Setelah instalasi selesai dan SSH aktif, ketik: xong"

  qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp "$CORES" \
    -m "$RAM" \
    -machine q35 \
    -drive file="$DISK_FILE",format=qcow2 \
    -drive file="$ISO_FILE",media=cdrom \
    -boot order=d \
    -netdev user,id=net0,hostfwd=tcp::22-:22 \
    -device e1000,netdev=net0 \
    -vnc "$VNC_DISPLAY" \
    -usb -device usb-tablet &

  QEMU_PID=$!

  while true; do
    read -rp "Ketik 'xong' jika sudah selesai: " DONE
    if [ "$DONE" = "xong" ]; then
      touch "$FLAG_FILE"
      kill "$QEMU_PID"
      pkill -f "$NGROK_BIN"
      rm -f "$ISO_FILE"
      echo "Instalasi selesai. Boot selanjutnya langsung dari disk."
      exit 0
    fi
  done

else
  echo "Kali sudah terpasang – boot normal"

  qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp "$CORES" \
    -m "$RAM" \
    -machine q35 \
    -drive file="$DISK_FILE",format=qcow2 \
    -boot order=c \
    -netdev user,id=net0,hostfwd=tcp::22-:22 \
    -device e1000,netdev=net0 \
    -vnc "$VNC_DISPLAY" \
    -usb -device usb-tablet
fi
