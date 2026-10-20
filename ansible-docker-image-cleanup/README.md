# ansible-docker-image-cleanup

Playbook Ansible untuk membersihkan Docker image yang tidak digunakan di semua server secara aman.

---

## 📋 Overview

Playbook ini bekerja dalam **3 tahap**:

1. **Scan** — Cek semua Docker image yang ada di setiap host
2. **Pisahkan** — Identifikasi image mana yang *used* (sedang dipakai container) vs *unused*
3. **Cleanup** — Hapus hanya image yang *unused*, skip yang masih dipakai

> Image yang masih dipakai container manapun (running **maupun** stopped) **tidak akan dihapus**.

---

## 📁 Struktur Folder

```
ansible-docker-image-cleanup/
├── ansible.cfg
├── inventory/
│   ├── hosts.ini              # inventory asli (jangan di-commit ke git publik)
│   └── hosts.ini.example      # template tanpa credential
├── playbooks/
│   ├── cleanup_images.yml     # main playbook: scan + cleanup
│   └── scan_only.yml          # dry-run: scan saja, tidak hapus apapun
├── roles/
│   ├── 00_scan_images/        # Step 1 & 2: scan & categorize images
│   │   └── tasks/main.yml
│   └── 01_cleanup_unused_images/  # Step 3: hapus unused images
│       └── tasks/main.yml
└── README.md
```

---

## 🚀 Cara Pakai

### 1. Setup inventory

Edit `inventory/hosts.ini` sesuai server target:

```ini
[servers]
server01 ansible_host=10.x.x.x

[servers:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_user=your_user
ansible_ssh_pass=your_password
ansible_become_pass=your_become_password
```

### 2. Dry-run dulu (scan saja, tidak hapus apapun)

```bash
ansible-playbook playbooks/scan_only.yml
```

Output akan menampilkan:
- Semua image yang ditemukan di tiap host
- ✅ Image yang **USED** (tidak akan dihapus)
- 🗑️ Image yang **UNUSED** (kandidat untuk dihapus)

### 3. Jalankan cleanup

Setelah yakin dengan hasil scan:

```bash
ansible-playbook playbooks/cleanup_images.yml
```

### 4. Target host tertentu saja

```bash
# Hanya server01
ansible-playbook playbooks/cleanup_images.yml --limit server01

# Hanya beberapa server
ansible-playbook playbooks/cleanup_images.yml --limit "server01,server02,server03"
```

---

## 🔒 Logika Keamanan

| Kondisi Image | Aksi |
|---|---|
| Dipakai container **running** | ✅ Skip — tidak dihapus |
| Dipakai container **stopped** | ✅ Skip — tidak dihapus |
| Tidak dipakai container manapun | 🗑️ Dihapus |
| Dangling image (`<none>:<none>`) | 🧹 Dihapus (layer orphan) |
| Gagal dihapus (masih ada dep) | ❌ Logged — tidak force remove |

> **Catatan:** Playbook menggunakan `docker ps -a` (bukan hanya `docker ps`) sehingga container yang *stopped* sekalipun tetap melindungi image-nya.

---

## 📊 Contoh Output

```
TASK [00_scan_images : 📊 Ringkasan Scan Docker Images — server01] *****
ok: [server01] => {
    "msg": "════════════════════════════════════════\nHost     : server01 (10.200.168.41)\nTotal    : 5 image\n✅ Used   : 3 image\n🗑️  Unused: 2 image\n════════════════════════════════════════\n"
}

TASK [01_cleanup_unused_images : 📋 Summary Cleanup — server01] *****
ok: [server01] => {
    "msg": "════════════════════════════════════════\nHost         : server01 (10.200.168.41)\nUnused Found : 2 image\n✅ Dihapus   : 2 image\n❌ Gagal     : 0 image\n════════════════════════════════════════\n"
}
```

---

## ⚠️ Catatan Penting

- Jalankan `scan_only.yml` terlebih dahulu sebelum `cleanup_images.yml`
- Playbook berjalan `serial: 1` (host satu per satu) agar mudah dimonitor
- Credential di `hosts.ini` jangan di-push ke repository publik
- Tambahkan `hosts.ini` ke `.gitignore` jika diperlukan
