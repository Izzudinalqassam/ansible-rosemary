# 🔄 Ansible Compose Update

Ansible playbook untuk **cek image**, **update image version** di `docker-compose.yaml`, dan **restart node** secara otomatis di seluruh server.

> ⚡ **Smart update** — Node yang sudah pakai image versi terbaru akan **otomatis di-skip**, tidak di-replace maupun di-restart.

---

## 🔄 Alur Kerja

```
Untuk setiap server:
│
├── CHECK — Cek Image (playbook terpisah, read-only)
│   ├── Tampilkan node yang dicek
│   ├── Cek compose file exists
│   └── Tampilkan image aktif per node
│
├── PHASE 1 — Update Image (smart skip)
│   ├── Cek image versi sekarang di tiap node
│   ├── Bandingkan dengan new_image di playbook
│   ├── ✅ Image sudah sesuai → SKIP (tidak diubah)
│   ├── 🔄 Image berbeda → Backup .bak + Replace image
│   ├── Verifikasi image sudah terganti
│   └── Simpan daftar node yang diupdate → PHASE 2
│
└── PHASE 2 — Restart Compose (hanya node yang berubah)
    ├── Tidak ada node berubah → SKIP seluruh restart
    ├── docker-compose down  (hanya node yang diupdate)
    ├── Jeda 5 detik
    ├── docker-compose up -d (hanya node yang diupdate)
    ├── Tunggu 10 detik startup
    └── Cek status container
```

---

## 📁 Struktur Project

```
ansible-compose-update/
├── ansible.cfg
├── inventory/
│   └── hosts.ini
├── playbooks/
│   ├── check_images.yml        ← Cek image (read-only, aman)
│   └── compose_update.yml      ← Update + restart (smart skip)
└── roles/
    ├── 00_check_image/          ← Role: cek image saat ini
    │   └── tasks/main.yml
    ├── 01_update_image/         ← Role: cek & ganti image (skip jika sama)
    │   └── tasks/main.yml
    └── 02_restart_compose/      ← Role: restart (hanya node yang berubah)
        └── tasks/main.yml
```

---

## ⚙️ Mapping Server & Node

| Server | IP | Nodes |
|---|---|---|
| server01 | 10.200.168.41 | v4-node-1, v4-node-26 (Portainer Cikeas) |
| server02 | 10.200.168.42 | v4-node-2, v4-node-25 (V4 Riot 1) |
| server03 | 10.200.168.43 | v4-node-3, v4-node-24 (V4 Riot 2) |
| server04 | 10.200.168.44 | v4-node-4, v4-node-14 |
| server05 | 10.200.168.45 | v4-node-5, v4-node-15 |
| server06 | 10.200.168.33 | v4-node-6, v4-node-16 |
| server07 | 10.200.168.47 | v4-node-7, v4-node-17 |
| server08 | 10.200.168.48 | v4-node-8, v4-node-18 |
| server09 | 10.200.168.49 | v4-node-9, v4-node-19 |
| server10 | 10.200.168.50 | v4-node-10, v4-node-20 |
| server11 | 10.200.168.51 | v4-node-11, v4-node-21 |
| server12 | 10.200.168.52 | v4-node-12, v4-node-22 |
| server13 | 10.200.168.53 | v4-node-13, v4-node-23 |

---

## 🚀 Cara Penggunaan

### 🔍 Cek image yang sedang dipakai (read-only, aman)

```bash
# Cek semua server
ansible-playbook playbooks/check_images.yml

# Cek server tertentu
ansible-playbook playbooks/check_images.yml --limit server01

# Cek beberapa server
ansible-playbook playbooks/check_images.yml --limit server01,server02,server03
```

> 💡 Playbook ini **read-only**, tidak mengubah file apapun. Aman dijalankan kapan saja untuk audit.

---

### 🔄 Update image & restart (full flow)

#### Langkah 1 — Set versi image baru

Edit `playbooks/compose_update.yml`, ubah `new_image` di **PHASE 1 dan PHASE 2**:

```yaml
vars:
  new_image: "registry.gitlab.com/nodefluxio/visionaire4:4.57.51-rc1"  # ← ganti di sini
```

Atau pakai **extra vars** (lebih fleksibel, tidak perlu edit file):

```bash
ansible-playbook playbooks/compose_update.yml \
  -e "new_image=registry.gitlab.com/nodefluxio/visionaire4:4.57.51-rc1"
```

#### Langkah 2 — Syntax check (opsional tapi direkomendasikan)

```bash
ansible-playbook playbooks/compose_update.yml --syntax-check
```

#### Langkah 3 — Jalankan

```bash
# Semua server
ansible-playbook playbooks/compose_update.yml

# Satu server saja
ansible-playbook playbooks/compose_update.yml --limit server02

# Beberapa server tertentu
ansible-playbook playbooks/compose_update.yml --limit server02,server03,server04
```

> ⚡ Node yang **sudah pakai image yang sama** dengan `new_image` akan **otomatis di-skip** — tidak di-replace, tidak di-backup, tidak di-restart.

---

### 🎯 Jalankan sebagian (tags)

```bash
# Hanya update image (tanpa restart)
ansible-playbook playbooks/compose_update.yml --tags phase1

# Hanya restart node yang belum sesuai (tanpa update file)
ansible-playbook playbooks/compose_update.yml --tags phase2
```

> 📌 Jika `--tags phase2` dijalankan sendiri tanpa PHASE 1, role akan **otomatis cek image** dan hanya restart node yang berbeda dari `new_image`.

---

## 🩺 Troubleshooting

| Error | Penyebab | Solusi |
|---|---|---|
| `Compose file tidak ditemukan` | Path node salah di inventory | Cek `compose_nodes` dan `compose_base_dir` di `hosts.ini` |
| `docker-compose: not found` | docker-compose belum install | `apt install -y docker-compose-plugin` |
| Container tidak mau UP | Image belum di-pull | Jalankan playbook `docker_distribute.yml` dulu |
| Image tidak terganti | Format image di compose berbeda | Cek regex di role `01_update_image` (match `visionaire4:*`) |
| Semua node di-skip | Image sudah sesuai semua | Cek `check_images.yml` untuk konfirmasi |

---

## 📝 Catatan

- Playbook berjalan **serial 13 server sekaligus** (PHASE 1) dan **serial 5** (PHASE 2)
- `max_fail_percentage: 0` — jika 1 server gagal, eksekusi berhenti
- File `docker-compose.yaml` di-**backup otomatis** ke `.bak` sebelum diubah (hanya node yang diupdate)
- Untuk rollback: `cp /data/compose/v4-node-X/docker-compose.yaml.bak /data/compose/v4-node-X/docker-compose.yaml`
- Regex replace hanya match baris `image:` yang mengandung `visionaire4:` — service lain tidak terpengaruh