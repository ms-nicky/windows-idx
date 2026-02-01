#!/usr/bin/env bash
set -e

################
# KONFIGURASI
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
# NGROK
################
NGROK_TOKEN="38WO5iYPn4Hq5A5SUOjtGptsxfE_7jDB4PmSF78GKcAguUo1H"
NGROK_DIR="$HOME/.ngrok"
NGROK_BIN="$NGROK_DIR/ngrok"
NGROK_CFG="$NGROK_DIR/ngrok.yml"
NGROK_LOG="$NGROK_DIR/ngrok.log"

################
# OVMF (UEFI)
################
OVMF_CODE="/usr/share/OVMF/OVMF_CODE.fd"
OVMF_VARS="/var/OVMF_VARS.fd"

################
# CEK SISTEM
################
[ -e /dev/kvm ] || { echo "❌ /dev/kvm tidak ditemukan (KVM wajib)"; exit 1; }
command -v qemu-system-x86_64 >/dev/null || { echo "❌ QEMU belum terinstall"; exit 1; }
[ -f "$OVMF_CODE" ] || { echo "❌ OVMF belum terinstall (sudo apt install ovmf)"; exit 1; }

################
# PERSIAPAN
################
mkdir -p "$WORKDIR"
cd "$WORKDIR"

[ -f "$DISK_FILE" ] || qemu-img create -f qcow2 "$DISK_FILE" "$DISK_SIZE"
[ -f "$OVMF_VARS" ] || cp /usr/share/OVMF/OVMF_VARS.fd "$OVMF_VARS"

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

VNC_ADDR=$(grep -oE 'tcp://[^ ]+' "$NGROK_LOG" | sed -n '1p')
RDP_ADDR=$(grep -oE 'tcp://[^ ]+' "$NGROK_LOG" | sed -n '2p')

echo "🌍 VNC PUBLIK : $VNC_ADDR"
echo "🌍 RDP PUBLIK : $RDP_ADDR"

################
# JALANKAN QEMU
################
if [ ! -f "$FLAG_FILE" ]; then
  echo "⚠️ MODE INSTALL WINDOWS"
  echo "👉 Setelah masuk desktop Windows, ketik: xong"

  qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp "$CORES" \
    -m "$RAM" \
    -machine q35 \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
    -drive if=pflash,format=raw,file="$OVMF_VARS" \
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
      echo "✅ Instalasi selesai. Aman untuk reboot."
      exit 0
    fi
  done

else
  echo "✅ Windows sudah terpasang – boot normal"

  qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp "$CORES" \
    -m "$RAM" \
    -machine q35 \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
    -drive if=pflash,format=raw,file="$OVMF_VARS" \
    -drive file="$DISK_FILE",format=qcow2 \
    -boot order=c \
    -netdev user,id=net0,hostfwd=tcp::3389-:3389 \
    -device e1000,netdev=net0 \
    -vnc "$VNC_DISPLAY" \
    -usb -device usb-tablet
fi
