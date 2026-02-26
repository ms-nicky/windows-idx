#!/usr/bin/env bash
set -e

################
# KONFIGURASI
################
ISO_URL="https://cdimage.kali.org/kali-2025.4/kali-linux-2025.4-installer-amd64.iso"
ISO_FILE="$HOME/windows-idx/kali-linux.iso"

DISK_FILE="/var/kali.qcow2"
DISK_SIZE="40G"

RAM="4G"
CORES="2"

WORKDIR="$HOME/windows-idx"
FLAG_FILE="installed.flag"

NGROK_TOKEN="ISI_TOKEN_NGROK_KAMU"

################
# CEK SISTEM
################
[ -e /dev/kvm ] || { echo "/dev/kvm tidak ditemukan"; exit 1; }
command -v qemu-system-x86_64 >/dev/null || { echo "QEMU belum terinstall"; exit 1; }

################
# PERSIAPAN
################
mkdir -p "$WORKDIR"
cd "$WORKDIR"

[ -f "$DISK_FILE" ] || qemu-img create -f qcow2 "$DISK_FILE" "$DISK_SIZE"
[ -f "$ISO_FILE" ] || wget -O "$ISO_FILE" "$ISO_URL"

################
# BUAT PRESEED
################
cat > preseed.cfg <<EOF
d-i debian-installer/locale string en_US
d-i keyboard-configuration/xkb-keymap select us
d-i netcfg/choose_interface select auto
d-i netcfg/get_hostname string kali
d-i netcfg/get_domain string local

d-i mirror/country string manual
d-i mirror/http/hostname string http.kali.org
d-i mirror/http/directory string /kali

d-i passwd/root-login boolean false
d-i passwd/user-fullname string kali
d-i passwd/username string kali
d-i passwd/user-password password kali
d-i passwd/user-password-again password kali
d-i user-setup/allow-password-weak boolean true

d-i clock-setup/utc boolean true
d-i time/zone string UTC

d-i partman-auto/method string lvm
d-i partman-lvm/device_remove_lvm boolean true
d-i partman-auto/choose_recipe select atomic
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true

tasksel tasksel/first multiselect standard, ssh-server
d-i pkgsel/include string openssh-server sudo
d-i pkgsel/upgrade select none

d-i finish-install/reboot_in_progress note
EOF

################
# START HTTP SERVER
################
python3 -m http.server 8000 >/dev/null 2>&1 &
HTTP_PID=$!

HOST_IP=$(ip route get 1 | awk '{print $7; exit}')

echo "Preseed URL:"
echo "http://$HOST_IP:8000/preseed.cfg"

################
# START NGROK
################
mkdir -p "$HOME/.ngrok"

if [ ! -f "$HOME/.ngrok/ngrok" ]; then
  curl -sL https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz \
  | tar -xz -C "$HOME/.ngrok"
  chmod +x "$HOME/.ngrok/ngrok"
fi

cat > "$HOME/.ngrok/ngrok.yml" <<EOF
version: "2"
authtoken: $NGROK_TOKEN
tunnels:
  ssh:
    proto: tcp
    addr: 22
EOF

pkill -f ngrok 2>/dev/null || true
"$HOME/.ngrok/ngrok" start --all --config "$HOME/.ngrok/ngrok.yml" \
  --log=stdout > ngrok.log 2>&1 &

sleep 5
SSH_ADDR=$(grep -oE 'tcp://[^ ]+' ngrok.log | head -n1)

echo "SSH PUBLIK: $SSH_ADDR"
echo "Login nanti: kali / kali"

################
# JALANKAN QEMU
################
if [ ! -f "$FLAG_FILE" ]; then

  echo ""
  echo "=== AUTO INSTALL MODE ==="
  echo "Saat menu installer muncul:"
  echo "1. Tekan 'e'"
  echo "2. Tambahkan di akhir baris linux:"
  echo "   auto priority=critical url=http://$HOST_IP:8000/preseed.cfg"
  echo "3. Tekan Ctrl+X"
  echo ""

  qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp "$CORES" \
    -m "$RAM" \
    -machine q35 \
    -drive file="$DISK_FILE",format=qcow2 \
    -cdrom "$ISO_FILE" \
    -boot d \
    -netdev user,id=net0,hostfwd=tcp::22-:22 \
    -device e1000,netdev=net0 \
    -vnc :0 \
    -usb -device usb-tablet

  touch "$FLAG_FILE"
  kill $HTTP_PID
  rm -f "$ISO_FILE"

else

  echo "=== BOOT NORMAL ==="

  qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp "$CORES" \
    -m "$RAM" \
    -machine q35 \
    -drive file="$DISK_FILE",format=qcow2 \
    -boot c \
    -netdev user,id=net0,hostfwd=tcp::22-:22 \
    -device e1000,netdev=net0 \
    -vnc :0

fi
