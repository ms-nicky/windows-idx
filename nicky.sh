#!/usr/bin/env bash
set -e

################
# KONFIGURASI
################
KALI_IMG_URL="https://cdimage.kali.org/kali-2024.4/kali-linux-2024.4-qemu-amd64.7z"
KALI_ARCHIVE="kali.7z"
DISK_FILE="/var/kali-linux.qcow2"

RAM="8G"
CORES="4"
VNC_DISPLAY=":0"

WORKDIR="$HOME/kali-vm"

################
# NGROK
################
NGROK_TOKEN="397SgaYKNFpMZm5uoG8i8Hv7b2M_4QmcRWnfiPAq89LugCpk2"
NGROK_DIR="$HOME/.ngrok"
NGROK_BIN="$NGROK_DIR/ngrok"
NGROK_CFG="$NGROK_DIR/ngrok.yml"
NGROK_LOG="$NGROK_DIR/ngrok.log"

################
# CEK SISTEM
################
[ -e /dev/kvm ] || { echo "❌ /dev/kvm tidak ada"; exit 1; }
command -v qemu-system-x86_64 >/dev/null || { echo "❌ qemu belum terinstall"; exit 1; }

################
# PERSIAPAN
################
mkdir -p "$WORKDIR"
cd "$WORKDIR"

################
# DOWNLOAD KALI
################
if [ ! -f "$DISK_FILE" ]; then
  echo "⬇️ Download Kali Linux image..."
  apt update
  apt install -y p7zip-full wget

  wget -O "$KALI_ARCHIVE" "$KALI_IMG_URL"
  7z x "$KALI_ARCHIVE"

  mv kali-linux-*.qcow2 "$DISK_FILE"
  rm -f "$KALI_ARCHIVE"
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

echo "🌍 VNC PUBLIK : $VNC_ADDR"
echo "🌍 SSH PUBLIK : $SSH_ADDR"
echo "🔐 Login Kali → user: kali | pass: kali"

################
# JALANKAN QEMU
################
qemu-system-x86_64 \
  -enable-kvm \
  -cpu host \
  -smp "$CORES" \
  -m "$RAM" \
  -machine q35 \
  -drive file="$DISK_FILE",format=qcow2 \
  -netdev user,id=net0,hostfwd=tcp::22-:22 \
  -device e1000,netdev=net0 \
  -vnc "$VNC_DISPLAY" \
  -usb -device usb-tablet
