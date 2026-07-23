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
├── PHASE 2 — Restart Compose (hanya node yang berubah)
│   ├── Tidak ada node berubah → SKIP seluruh restart
│   ├── docker-compose down  (hanya node yang diupdate)
│   ├── Jeda 5 detik
│   ├── docker-compose up -d (hanya node yang diupdate)
│   ├── Tunggu 10 detik startup
│   └── Cek status container
│
├── RESTART NODE — Rolling restart (playbook terpisah)
│   ├── Serial: 1 server at a time
│   ├── docker-compose down  (SEMUA node di server)
│   ├── Jeda 5 detik
│   ├── docker-compose up -d (SEMUA node di server)
│   ├── Tunggu 10 detik startup
│   ├── Cek status container
│   └── ⏳ Jeda 2 menit sebelum lanjut ke server berikutnya
│
└── SCHEDULED RESTART — Toggle --scheduled-restart (playbook terpisah)
    ├── Cek status saat ini (active / commented / absent)
    ├── Enable  → Tambah atau uncomment --scheduled-restart
    ├── Disable → Comment out --scheduled-restart
    ├── Backup .bak sebelum edit
    └── Verifikasi hasil
```

---

## 📁 Struktur Project

```
ansible-compose-update/
├── ansible.cfg
├── inventory/
│   └── hosts.ini
├── playbooks/
│   ├── check_images.yml             ← Cek image (read-only, aman)
│   ├── check_scheduled_restart.yml   ← Cek status --scheduled-restart (read-only)
│   ├── compose_update.yml           ← Update + restart (smart skip)
│   ├── restart_nodes.yml            ← Rolling restart 1 server/waktu, jeda 2 menit
│   └── scheduled_restart.yml        ← Toggle --scheduled-restart (enable/disable)
└── roles/
    ├── 00_check_image/          ← Role: cek image saat ini
    │   └── tasks/main.yml
    ├── 01_update_image/         ← Role: cek & ganti image (skip jika sama)
    │   └── tasks/main.yml
    ├── 02_restart_compose/      ← Role: restart (hanya node yang berubah)
    │   └── tasks/main.yml
    ├── 03_restart_node/         ← Role: restart semua node per server
    │   └── tasks/main.yml
    └── 04_scheduled_restart/    ← Role: toggle --scheduled-restart
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

### 🔁 Rolling Restart Node (1 server at a time, jeda 2 menit)

Restart semua container node tanpa mengubah image version. Berguna saat ingin restart bersih tanpa update.

```bash
# Restart semua server (1 per 1, jeda 2 menit antar server)
ansible-playbook playbooks/restart_nodes.yml

# Restart server tertentu saja
ansible-playbook playbooks/restart_nodes.yml --limit server01,server05

# Dry-run (cek dulu tanpa eksekusi)
ansible-playbook playbooks/restart_nodes.yml --check
```

> ⏳ Setiap server akan di-restart satu per satu. Setelah semua node di server selesai restart dan verified running, playbook akan **jeda 2 menit** sebelum lanjut ke server berikutnya.

---

### ⏰ Toggle `--scheduled-restart` (enable / disable)

Tambah atau hapus (comment/uncomment) flag `--scheduled-restart` di section `command:` docker-compose.yaml.
Waktu di-stagger otomatis per node (selang 5 menit berdasarkan nomor node):

| Node | Waktu (default) |
|---|---|
| node-1 | `02:00:0` |
| node-2 | `02:05:0` |
| node-3 | `02:10:0` |
| ... | +5 menit per node |
| node-26 | `04:05:0` |

**Playbook berjalan 2 fase:**
1. **PHASE 1** — Edit docker-compose.yaml (semua server paralel)
2. **PHASE 2** — Rolling restart: 1 server at a time, 2 menit jeda antar node

```bash
# Enable --scheduled-restart di SEMUA server (base 02:00, interval 5 menit)
ansible-playbook playbooks/scheduled_restart.yml

# Enable di server tertentu saja
ansible-playbook playbooks/scheduled_restart.yml --limit server01,server05

# Disable (comment out) di SEMUA server
ansible-playbook playbooks/scheduled_restart.yml -e "scheduled_restart_action=disable"

# Disable di server tertentu
ansible-playbook playbooks/scheduled_restart.yml -e "scheduled_restart_action=disable" --limit server02,server03

# Custom base time & interval
ansible-playbook playbooks/scheduled_restart.yml \
  -e "scheduled_restart_base_hour=3" \
  -e "scheduled_restart_base_minute=0" \
  -e "scheduled_restart_interval=10"

# Hanya edit TANPA restart
ansible-playbook playbooks/scheduled_restart.yml --tags phase1

# Hanya restart TANPA edit
ansible-playbook playbooks/scheduled_restart.yml --tags phase2

# Dry-run (preview perubahan tanpa eksekusi)
ansible-playbook playbooks/scheduled_restart.yml --check --diff
```

> ⏰ **Enable** = tambah/uncomment `--scheduled-restart` dengan waktu staggered per node. **Disable** = comment out dengan `#`. Backup `.bak` otomatis. Down & up 1 server per waktu, 2 menit jeda antar node.

---

### 🔍 Cek Status `--scheduled-restart` (read-only)

Validasi apakah setiap node sudah punya command `--scheduled-restart` dan lihat nilainya. **Read-only**, tidak mengubah file apapun.

```bash
# Cek semua server
ansible-playbook playbooks/check_scheduled_restart.yml

# Cek server tertentu
ansible-playbook playbooks/check_scheduled_restart.yml --limit server01,server05
```

Output per node:
- ✅ **ACTIVE** — `--scheduled-restart` ada dan aktif (beserta nilainya)
- 💤 **COMMENTED** — ada tapi di-comment (`#`)
- ❌ **ABSENT** — belum ada sama sekali

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