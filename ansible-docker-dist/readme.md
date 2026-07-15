# 🐳 Ansible Docker Distribute

Ansible playbook untuk **pull sekali, distribute ke semua server** secara otomatis.  
Image di-pull di server01 Cikeas, disimpan sebagai `tar.gz`, lalu didistribusikan ke:
- **14 server Cikeas** — langsung dari laptop via Ansible
- **19 server Bali (Polda Bali)** — laptop tidak bisa SSH ke Bali, semua operasi Bali dijalankan oleh **server01 Cikeas sebagai perantara**

---

## 🗺️ Arsitektur Jaringan

```
┌──────────────────────────────────────────────────────┐
│  Laptop / WSL (Ansible Control Node)                 │
└────────────┬─────────────────────────────────────────┘
             │
             │ SSH langsung (password)
             │
     ┌───────▼────────────────────────────────────────┐
     │  Server Cikeas — 14 server                     │
     │  server01  10.200.168.41  ← SOURCE + JUMPHOST  │
     │  server02  10.200.168.42                       │
     │  ...                                           │
     │  server14  10.200.168.54                       │
     └───────┬────────────────────────────────────────┘
             │
             │ SSH dari server01 (password)
             │ Laptop TIDAK BISA akses Bali langsung
             │
     ┌───────▼────────────────────────────────────────┐
     │  Server Bali (Polda Bali) — 19 server          │
     │  bali01  10.18.200.201                         │
     │  bali02  10.18.200.202                         │
     │  ...                                           │
     │  bali19  10.18.200.96                          │
     └────────────────────────────────────────────────┘
```

---

## 🔄 Alur Distribusi Image

```
PHASE 1 & 2 — di server01 Cikeas
  docker pull [image]
  docker save → /tmp/docker_images/[image].tar.gz

PHASE 3a & 4a — ke server Cikeas (dari laptop)
  Laptop ──SCP──→ server02-14 Cikeas : copy tar.gz
  Laptop ──SSH──→ server02-14 Cikeas : docker load

PHASE 3b & 4b — ke server Bali (server01 yang kerja)
  server01 ──SCP──→ bali01-19 : copy tar.gz
  server01 ──SSH──→ bali01-19 : docker load
  (Laptop hanya orchestrate via Ansible delegate_to)
```

---

## 📋 Daftar Isi

- [Prasyarat](#-prasyarat)
- [Struktur Project](#-struktur-project)
- [Inventory & Konfigurasi](#-inventory--konfigurasi)
- [Quick Start](#-quick-start)
- [Skenario Penggunaan](#-skenario-penggunaan)
  - [Distribute ke SEMUA server](#1-distribute-ke-semua-server-cikeas--bali)
  - [Distribute ke Cikeas saja](#2-distribute-ke-cikeas-saja)
  - [Distribute ke Bali saja](#3-distribute-ke-bali-saja)
  - [Test koneksi semua server](#4-test-koneksi-semua-server)
  - [Ganti image / versi baru](#5-ganti-image--versi-baru)
  - [Jalankan per phase](#6-jalankan-per-phase-bertahap)
- [Variabel](#-variabel)
- [Troubleshooting](#-troubleshooting)

---

## 🛠 Prasyarat

| Kebutuhan | Di mana | Keterangan |
|---|---|---|
| Ansible ≥ 2.12 | Laptop / WSL | Control node |
| `sshpass` | **Laptop** | Untuk auth SSH via password ke Cikeas |
| `sshpass` | **server01 Cikeas** | Untuk server01 push ke server Bali |
| Docker | Semua server | Source & target |
| Akses internet | server01 Cikeas saja | Untuk `docker pull` |
| Disk `/tmp` di server01 | ≥ ukuran image | Menyimpan tar.gz sementara |
| Disk `/data` di target | ≥ ukuran image | Tujuan copy tar.gz |

### Install sshpass di laptop (sekali saja)
```bash
sudo apt install -y sshpass
```

### Install sshpass di server01 Cikeas (sekali saja)
```bash
# Jalankan dari laptop:
sshpass -p 'Bug4Root26' ssh bhayangkara@10.200.168.41 \
  "sudo apt install -y sshpass"
```

---

## 📁 Struktur Project

```
ansible-docker-dist/
├── ansible.cfg                          # Konfigurasi Ansible global
├── inventory/
│   ├── hosts.ini                        # Daftar semua server (Cikeas + Bali)
│   ├── group_vars/
│   │   ├── cikeas_servers.yml           # Credential SSH server Cikeas
│   │   └── bali_servers.yml            # Credential SSH server Bali
│   ├── bali_ssh.cfg                     # (tidak dipakai, bisa dihapus)
│   └── establish_jump.sh               # (tidak dipakai, bisa dihapus)
├── playbooks/
│   ├── docker_distribute.yml           # Playbook utama distribusi image
│   └── ping_all.yml                    # Playbook test koneksi semua server
└── roles/
    ├── 01_pull_image/tasks/main.yml    # docker pull di server01
    ├── 02_save_image/tasks/main.yml    # docker save → tar.gz di server01
    ├── 03_distribute_image/tasks/main.yml  # SCP tar.gz ke Cikeas
    └── 04_load_image/tasks/main.yml    # docker load di Cikeas
```

---

## ⚙️ Inventory & Konfigurasi

### `inventory/hosts.ini`

```ini
[source_server]
server01 ansible_host=10.200.168.41       # Pull & save image di sini

[cikeas_servers]                           # Bisa diakses langsung dari laptop
server01 ansible_host=10.200.168.41
server02 ansible_host=10.200.168.42
...
server14 ansible_host=10.200.168.54

[bali_servers]                             # Hanya bisa diakses dari server01
bali01  ansible_host=10.18.200.201
bali02  ansible_host=10.18.200.202
...
bali19  ansible_host=10.18.200.96

[target_servers:children]                  # Gabungan Cikeas + Bali
cikeas_servers
bali_servers

[all:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_user=bhayangkara
```

### `inventory/group_vars/cikeas_servers.yml`

```yaml
ansible_ssh_pass: "password_cikeas"
ansible_become_pass: "password_cikeas"
```

### `inventory/group_vars/bali_servers.yml`

```yaml
ansible_ssh_pass: "password_bali"       # Dipakai server01 saat push ke Bali
ansible_become_pass: "password_bali"
ansible_user: bhayangkara
```

> **Catatan:** Laptop tidak pernah SSH langsung ke Bali. Credential Bali dipakai oleh **server01** lewat `sshpass` saat menjalankan task `delegate_to: server01`.

---

## 🚀 Quick Start

```bash
# Clone project
git clone <repo-url>
cd ansible-docker-dist

# 1. Test koneksi semua server dulu
ansible-playbook playbooks/ping_all.yml

# 2. Syntax check
ansible-playbook playbooks/docker_distribute.yml --syntax-check

# 3. Distribute ke semua server (Cikeas + Bali)
ansible-playbook playbooks/docker_distribute.yml
```

---

## 📖 Skenario Penggunaan

---

### 1. Distribute ke SEMUA server (Cikeas + Bali)

Jalankan semua phase sekaligus — pull, save, distribute, dan load ke 14 Cikeas + 19 Bali.

```bash
ansible-playbook playbooks/docker_distribute.yml
```

**Urutan yang terjadi:**
1. Pull image di server01 Cikeas
2. Save image ke `tar.gz` di server01
3. SCP tar.gz ke server02–14 Cikeas (dari laptop, 2 server sekaligus)
4. SCP tar.gz ke bali01–19 (server01 yang push, 3 server sekaligus)
5. `docker load` di Cikeas (dari laptop)
6. `docker load` di Bali (server01 yang SSH ke Bali)

---

### 2. Distribute ke Cikeas saja

Kalau Bali belum siap atau tidak perlu update sekarang.

```bash
# Hanya target Cikeas
ansible-playbook playbooks/docker_distribute.yml --limit cikeas_servers
```

Atau kalau mau jalankan hanya Phase 3a + 4a (skip pull & save karena tar.gz sudah ada):

```bash
# Phase 3a: SCP ke Cikeas
ansible-playbook playbooks/docker_distribute.yml \
  --tags phase3a

# Phase 4a: Docker load di Cikeas
ansible-playbook playbooks/docker_distribute.yml \
  --tags phase4a
```

---

### 3. Distribute ke Bali saja

Kalau Cikeas sudah update, tinggal push ke Bali. Pastikan tar.gz sudah ada di server01 (`/tmp/docker_images/`).

```bash
# Hanya target Bali (server01 yang kerja ke Bali)
ansible-playbook playbooks/docker_distribute.yml --limit bali_servers
```

> **Penting:** `--limit bali_servers` tetap butuh server01 sebagai delegate. Pastikan server01 Cikeas bisa diakses dari laptop.

Atau jalankan per phase:

```bash
# Phase 3b: SCP dari server01 ke semua Bali
ansible-playbook playbooks/docker_distribute.yml \
  --tags phase3b

# Phase 4b: Docker load di semua Bali (via server01)
ansible-playbook playbooks/docker_distribute.yml \
  --tags phase4b
```

---

### 4. Test koneksi semua server

Wajib dijalankan pertama kali, dan tiap ada perubahan server.

```bash
ansible-playbook playbooks/ping_all.yml
```

**Output yang diharapkan:**
```
✅ server01 (10.200.168.41) — CONNECTED
✅ server02 (10.200.168.42) — CONNECTED
...
✅ bali01 (10.18.200.201) — CONNECTED (via server01)
✅ bali02 (10.18.200.202) — CONNECTED (via server01)
...
```

Test koneksi per group saja:

```bash
# Cikeas saja
ansible cikeas_servers -m ping

# Bali saja (via server01, pakai shell bukan ping module)
ansible-playbook playbooks/ping_all.yml --tags ping_bali
```

---

### 5. Ganti image / versi baru

Edit variabel di `playbooks/docker_distribute.yml`. Semua phase pakai variabel yang sama:

```yaml
# Ubah di setiap play yang ada vars:
vars:
  docker_image: "registry.gitlab.com/nodefluxio/visionaire4:4.58.0"
  image_tar_filename: "visionaire4_4.58.0.tar.gz"
  image_save_dir: "/tmp/docker_images"
  image_dest_dir: "/data"
```

Setelah ubah, jalankan ulang dari awal:

```bash
ansible-playbook playbooks/docker_distribute.yml
```

> **Playbook idempoten** — kalau tar.gz sudah ada atau image sudah di-load, step tersebut akan di-skip otomatis.

---

### 6. Jalankan per phase (bertahap)

Berguna saat debug atau koneksi lambat.

```bash
# Phase 1 — Pull image di server01
ansible-playbook playbooks/docker_distribute.yml \
  --limit source_server \
  --start-at-task "Pull Docker image"

# Phase 2 — Save image ke tar.gz di server01
ansible-playbook playbooks/docker_distribute.yml \
  --limit source_server \
  --start-at-task "Buat direktori"

# Phase 3a — SCP ke Cikeas saja
ansible-playbook playbooks/docker_distribute.yml \
  --limit cikeas_servers \
  --start-at-task "PHASE 3a"

# Phase 3b — SCP ke Bali (server01 yang push)
ansible-playbook playbooks/docker_distribute.yml \
  --limit bali_servers \
  --start-at-task "PHASE 3b"

# Phase 4a — Load di Cikeas
ansible-playbook playbooks/docker_distribute.yml \
  --limit cikeas_servers \
  --start-at-task "PHASE 4a"

# Phase 4b — Load di Bali
ansible-playbook playbooks/docker_distribute.yml \
  --limit bali_servers \
  --start-at-task "PHASE 4b"
```

---

### 7. Cek disk space sebelum distribusi

Wajib dicek kalau image besar.

```bash
# Cek /tmp di server01 (tempat save tar.gz)
ansible source_server -m shell -a "df -h /tmp/docker_images 2>/dev/null || df -h /tmp"

# Cek /data di semua server Cikeas
ansible cikeas_servers -m shell -a "df -h /data 2>/dev/null || df -h /"

# Cek /data di semua server Bali (via server01)
ansible-playbook playbooks/ping_all.yml  # atau cek manual lewat server01
```

---

## 📦 Variabel

| Variabel | Contoh nilai | Keterangan |
|---|---|---|
| `docker_image` | `registry.gitlab.com/org/app:1.0.0` | Image yang di-pull & distribute |
| `image_tar_filename` | `app_1.0.0.tar.gz` | Nama file tar.gz |
| `image_save_dir` | `/tmp/docker_images` | Direktori temp di server01 |
| `image_dest_dir` | `/data` | Direktori tujuan di target server |
| `cleanup_tar` | `true` / `false` | Hapus tar.gz setelah load sukses |

---

## 🩺 Troubleshooting

| Error | Penyebab | Solusi |
|---|---|---|
| `sshpass required` (di laptop) | sshpass belum install | `sudo apt install -y sshpass` |
| `sshpass: not found` (di server01) | sshpass belum install di server01 | `sshpass -p '...' ssh bhayangkara@10.200.168.41 "sudo apt install -y sshpass"` |
| `permission denied` saat SCP ke Bali | server01 tidak bisa SSH ke Bali | Cek password di `bali_servers.yml`, cek dari server01 manual: `sshpass -p '...' ssh bhayangkara@10.18.200.201 echo ok` |
| `no space left` saat save | Disk `/tmp` server01 penuh | Bersihkan `/tmp` atau ganti `image_save_dir` ke partisi lain |
| `no space left` saat SCP | Disk `/data` target penuh | `df -h /data` di target server, hapus file lama |
| `docker load` gagal | File tar.gz corrupt | Hapus tar.gz di target, jalankan ulang dari Phase 3 |
| `permission denied` docker | User bukan grup docker | `sudo usermod -aG docker bhayangkara` di server target |
| Bali `unreachable` | server01 tidak bisa SSH ke Bali | Test manual: `sshpass -p 'Bug4Root' ssh bhayangkara@10.18.200.201 echo ok` dari server01 |
| `Connection reset by 10.200.168.41` | fail2ban server01 block IP | Tunggu ~10 menit, atau whitelist IP di server01 |

---

## 🧠 Cara Kerja Detail

### Kenapa Bali pakai `delegate_to`?

Laptop tidak bisa SSH ke server Bali sama sekali (tidak ada VPN/routing langsung). Solusinya:

- Semua task untuk Bali di-**delegate ke server01** Cikeas
- Server01 yang eksekusi `sshpass scp` dan `sshpass ssh` ke Bali
- Laptop hanya orchestrate: kirim perintah ke server01, server01 yang kerja

```
TANPA delegate_to (❌ tidak bisa):
  Laptop ──SSH──→ bali01   ← blocked, tidak ada routing

DENGAN delegate_to (✅ bisa):
  Laptop ──SSH──→ server01 ──SSH──→ bali01
  (Laptop minta server01 untuk push ke bali01)
```

### Idempoten

Playbook aman dijalankan berulang. Setiap step cek dulu:
- `tar.gz` sudah ada di target? → skip SCP
- Image sudah di-load? → skip docker load
- Direktori sudah ada? → skip mkdir

### Serial SCP

- Cikeas: SCP berjalan 2 server sekaligus (`serial: 2`)
- Bali: server01 push ke 3 server sekaligus (`serial: 3`)

Ini agar server01 tidak kewalahan melayani terlalu banyak koneksi simultan.

---

## 📝 Catatan Operasional

- **Jangan jalankan banyak instance playbook bersamaan** — bisa flood server01 dan trigger fail2ban
- **Tar.gz tidak dihapus secara default** (`cleanup_tar: false`) — berguna jika perlu load ulang
- **Set `cleanup_tar: true`** di playbook jika disk terbatas dan image sudah confirmed loaded
- Server01 punya **dual role**: source server (pull/save) + jumphost (push ke Bali)