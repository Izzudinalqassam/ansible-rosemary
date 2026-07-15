# 💾 Ansible Swap Increase

Ansible playbook untuk **cek dan upgrade swap memory** secara otomatis di seluruh server.

> ⚡ **Smart threshold** — Hanya server dengan swap ≤ 8 GB yang akan di-upgrade ke 64 GB. Server yang sudah punya swap cukup akan otomatis di-skip.

---

## 🔄 Alur Kerja

```
Untuk setiap server:
│
├── CEK — Baca swap saat ini
│   └── Bandingkan dengan threshold (default: 8 GB)
│
├── SKIP — Swap sudah ≥ threshold
│   └── Tidak ada perubahan
│
└── UPGRADE — Swap ≤ threshold
    ├── Matikan swap lama (swapoff)
    ├── Hapus swapfile lama
    ├── Buat swapfile baru (default: 64 GB)
    ├── Set permission 600
    ├── Format sebagai swap (mkswap)
    ├── Aktifkan swap baru (swapon)
    ├── Update /etc/fstab
    └── Tampilkan ringkasan memory
```

---

## 📁 Struktur Project

```
ansible-swap-increase/
├── ansible.cfg                    # Konfigurasi Ansible
├── inventory/
│   ├── hosts.ini                  # Daftar server → EDIT DI SINI
│   └── hosts.ini.example         # Contoh format inventory
├── playbooks/
│   └── manage_swap.yml           # Playbook utama
└── roles/
    └── swap_manager/
        └── tasks/main.yml        # Logic cek & upgrade swap
```

---

## ⚙️ Variabel

| Variabel | Default | Keterangan |
|---|---|---|
| `swap_threshold_gb` | `8` | Swap di bawah ini akan di-upgrade |
| `swap_target_gb` | `64` | Ukuran swap baru |
| `swapfile_path` | `/swapfile` | Lokasi swapfile |

Variabel bisa diubah di `playbooks/manage_swap.yml` atau lewat extra vars:

```bash
ansible-playbook playbooks/manage_swap.yml \
  -e "swap_target_gb=32 swap_threshold_gb=4"
```

---

## 🚀 Cara Penggunaan

### 1. Isi inventory

```bash
cp inventory/hosts.ini.example inventory/hosts.ini
# Edit hosts.ini, isi IP server dan credential
```

### 2. Jalankan

```bash
# Semua server
ansible-playbook playbooks/manage_swap.yml

# Server tertentu
ansible-playbook playbooks/manage_swap.yml --limit server01

# Dry run (cek dulu tanpa eksekusi)
ansible-playbook playbooks/manage_swap.yml --check --diff
```

---

## 🩺 Troubleshooting

| Error | Penyebab | Solusi |
|---|---|---|
| `Permission denied` | User bukan sudoer | Pastikan `ansible_become=true` dan `ansible_become_pass` benar |
| `No space left on device` | Disk penuh | Cek disk space: `df -h /` |
| Swap tidak aktif setelah reboot | Belum di-set di fstab | Playbook sudah handle ini, cek `/etc/fstab` |

---

## 📝 Catatan

- Playbook **idempotent** — aman dijalankan berkali-kali
- Server yang swap-nya sudah cukup akan **otomatis di-skip**
- Setelah selesai, akan tampil ringkasan `free -h` dari semua server
