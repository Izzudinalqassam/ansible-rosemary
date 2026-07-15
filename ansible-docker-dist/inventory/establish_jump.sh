#!/bin/bash
# Tujuan      : Pre-establish SSH ControlMaster ke server01 Cikeas (jumphost Bali)
# Caller      : Jalankan sebelum ansible-playbook yang target bali_servers
# Dependensi  : sshpass, ssh
# Side Effects: Buka persistent SSH connection ke server01, socket di /tmp/ansible-jump-cikeas01

JUMP_HOST="10.200.168.41"
JUMP_USER="bhayangkara"
JUMP_PASS="Bug4Root26"
SOCKET="/tmp/ansible-jump-cikeas01"

# Cek apakah socket sudah aktif
if ssh -o ControlMaster=no -o ControlPath="$SOCKET" -O check "$JUMP_USER@$JUMP_HOST" 2>/dev/null; then
  echo "✅ Jumphost tunnel sudah aktif: $SOCKET"
  exit 0
fi

echo "🔗 Membuka SSH ControlMaster ke jumphost $JUMP_HOST ..."
sshpass -p "$JUMP_PASS" ssh \
  -o ControlMaster=yes \
  -o ControlPath="$SOCKET" \
  -o ControlPersist=300s \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -N -f \
  "$JUMP_USER@$JUMP_HOST"

if [ $? -eq 0 ]; then
  echo "✅ Jumphost tunnel aktif (300s), socket: $SOCKET"
else
  echo "❌ Gagal establish jumphost tunnel"
  exit 1
fi
