# Ansible — Provisioning Server VisionAIre

Playbook Ansible untuk **provisioning otomatis** server VisionAIre di Ubuntu 22.04+.
Mencakup instalasi dependencies, verifikasi, dan inisialisasi service — sampai siap
dijalankan dengan `docker-compose up`.

---

## Daftar Isi

- [Tentang Project](#tentang-project)
- [Prasyarat](#prasyarat)
- [Quick Start](#quick-start)
- [Konfigurasi](#konfigurasi)
  - [Inventory — Daftar Server](#inventory--daftar-server)
  - [Variables — Kredensial dan Konfigurasi](#variables--kredensial-dan-konfigurasi)
- [Struktur Direktori](#struktur-direktori)
- [Daftar Playbook](#daftar-playbook)
  - [install-dependencies.yml](#1-install-dependenciesyml)
  - [verify-dependencies.yml](#2-verify-dependenciesyml)
  - [init-folders.yml](#3-init-foldersyml)
  - [init-services.yml](#4-init-servicesyml)
  - [full-deploy.yml](#5-full-deployyml)
- [Service yang Tersedia](#service-yang-tersedia)
- [Lokasi Deployment di Server](#lokasi-deployment-di-server)
- [Contoh Workflow](#contoh-workflow)
- [Referensi Command](#referensi-command)
- [Urutan Start Container](#urutan-start-container)
- [FAQ dan Troubleshooting](#faq-dan-troubleshooting)

---

## Tentang Project

Project ini mengotomasi seluruh proses penyiapan server untuk menjalankan
VisionAIre. Terdiri dari **5 playbook** yang bisa dijalankan secara terpisah
maupun berurutan:

| Tahap | Playbook | Fungsi |
|-------|----------|--------|
| 1 | `install-dependencies.yml` | Install NVIDIA driver, Docker, docker-compose |
| 2 | `verify-dependencies.yml` | Verifikasi semua dependency terinstall |
| 3 | `init-folders.yml` | Buat folder deployment + docker network/volume |
| 4 | `init-services.yml` | Copy compose files + replace IP |
| 5 | `full-deploy.yml` | Jalankan tahap 1–4 secara berurutan |

Container **tidak di-start** oleh Ansible — user menjalankan `docker-compose up`
secara manual untuk mengurangi risiko kesalahan saat deployment.

---

## Prasyarat

### Di komputer kamu (control machine)

```bash
sudo apt update
sudo apt install -y ansible sshpass
```

> `sshpass` hanya dibutuhkan jika login ke server pakai password.
> Kalau pakai SSH key, tidak perlu install ini.

### Di server target

- Ubuntu 22.04 atau lebih baru
- Akses SSH dari control machine
- User dengan hak sudo

### Versi Ansible

Playbook ini membutuhkan **Ansible 2.11+** (untuk filter `split()`).
Cek versi:

```bash
ansible --version
```

---

## Quick Start

Untuk yang sudah familiar dengan Ansible, ini langkah minimalnya:

```bash
# 1. Clone / download project
cd visionaire-deps-ansible

# 2. Edit daftar server
nano inventory/hosts.ini

# 3. Edit kredensial
nano group_vars/all.yml

# 4. Jalankan full provisioning
ansible-playbook playbooks/full-deploy.yml
```

Untuk penjelasan lengkap setiap langkah, baca section di bawah.

---

## Konfigurasi

### Inventory — Daftar Server

File: `inventory/hosts.ini`

Isi dengan IP address server yang ingin di-provisioning:

```ini
[visionaire_servers]
192.168.100.1
192.168.100.2
192.168.100.3
```

**Format yang didukung:**

```ini
# Hanya IP
192.168.100.1

# IP + custom user
192.168.100.2 ansible_user=ubuntu

# Hostname + IP + user
node-01 ansible_host=192.168.100.1 ansible_user=ubuntu
```

Kalau semua server pakai user dan password yang sama, cukup atur sekali di
`group_vars/all.yml` — tidak perlu ditulis berulang di tiap baris.

### Variables — Kredensial dan Konfigurasi

File: `group_vars/all.yml`

| Variable | Keterangan | Contoh |
|----------|-----------|--------|
| `ansible_user` | User SSH ke server | `"ubuntu"` |
| `ansible_ssh_pass` | Password SSH (hapus jika pakai key) | `"password123"` |
| `ansible_become_pass` | Password sudo di server | `"password123"` |
| `docker_compose_version` | Versi docker-compose | `"1.29.2"` |
| `deploy_root_if_data_exists` | Path deployment jika `/data` ada | `"/data/deployments"` |
| `deploy_root_if_no_data` | Path deployment jika `/data` tidak ada | `"/deployments"` |
| `mandatory_services` | Service yang selalu di-deploy | `[database, dashboard]` |

**Kalau pakai SSH key** (bukan password):

```yaml
ansible_user: "ubuntu"
# ansible_ssh_pass: ...          ← hapus/comment baris ini
ansible_ssh_private_key_file: "~/.ssh/id_rsa"   # ← aktifkan baris ini
```

---

## Struktur Direktori

```
visionaire-deps-ansible/
├── ansible.cfg                    # Konfigurasi Ansible
├── site.yml                       # Wrapper (backward compatibility)
│
├── playbooks/                     # ← PLAYBOOK (jalankan dari sini)
│   ├── install-dependencies.yml   #   Install semua dependency
│   ├── verify-dependencies.yml    #   Verifikasi dependency
│   ├── init-folders.yml           #   Buat folder + docker prereqs
│   ├── init-services.yml          #   Copy compose + replace IP
│   └── full-deploy.yml            #   Jalankan semua tahap
│
├── inventory/
│   └── hosts.ini                  # ← EDIT: daftar IP server
│
├── group_vars/
│   └── all.yml                    # ← EDIT: kredensial & konfigurasi
│
├── roles/                         # Logic Ansible (tidak perlu diedit)
│   ├── nvidia_driver/             #   Install NVIDIA driver + reboot
│   ├── docker/                    #   Install Docker CE + atur data-root
│   │   └── templates/daemon.json.j2
│   ├── nvidia_docker/             #   Install nvidia-docker2
│   ├── docker_compose/            #   Install docker-compose
│   ├── verify_deps/               #   Verifikasi dependency
│   ├── init_folders/              #   Buat folder + docker network/volume
│   └── init_services/             #   Copy compose + replace IP
│       ├── defaults/main.yml
│       └── tasks/
│           ├── main.yml
│           ├── detect_paths.yml
│           ├── create_directories.yml
│           ├── docker_prerequisites.yml
│           ├── copy_services.yml
│           └── replace_ip.yml
│
└── compose-examples/              # Template docker-compose per service
    ├── database/
    ├── dashboard/
    ├── fremisn-cpu/
    ├── fremisn-gpu/
    ├── liodra/
    ├── qwertex/
    ├── v4/
    ├── v4-intel-nuc/
    └── v4-offline-analysis/
```

---

## Daftar Playbook

> **Penting:** Selalu jalankan command dari **root directory project**
> (`visionaire-deps-ansible/`), bukan dari dalam folder `playbooks/`.

### 1. `install-dependencies.yml`

**Tujuan:** Install seluruh dependency yang dibutuhkan VisionAIre.

**Kapan digunakan:**
- Server baru yang belum ada Docker/NVIDIA driver.
- Ingin memastikan semua dependency terpasang.

**Apa yang dilakukan:**
1. Bootstrap Python3 (untuk server fresh install)
2. Install NVIDIA Driver (versi recommended, auto-detect) + reboot otomatis
3. Install Docker CE, nvidia-docker2, docker-compose v1.29.2

**Prasyarat:**
- Server sudah bisa diakses via SSH
- `inventory/hosts.ini` dan `group_vars/all.yml` sudah dikonfigurasi

**Command:**

```bash
# Semua server
ansible-playbook playbooks/install-dependencies.yml

# Server tertentu saja
ansible-playbook playbooks/install-dependencies.yml --limit 192.168.100.1

# Beberapa server
ansible-playbook playbooks/install-dependencies.yml --limit "192.168.100.1,192.168.100.2"

# Dry run (tanpa eksekusi, lihat apa yang akan berubah)
ansible-playbook playbooks/install-dependencies.yml --check --diff
```

**Output yang diharapkan:**
- NVIDIA driver terinstall (atau di-skip jika tidak ada GPU)
- Docker CE aktif dan running
- nvidia-docker2 terinstall (atau di-skip jika tidak ada GPU)
- docker-compose terinstall di `/usr/local/bin/docker-compose`

---

### 2. `verify-dependencies.yml`

**Tujuan:** Verifikasi semua dependency sudah terinstall dengan benar.

**Kapan digunakan:**
- Setelah menjalankan `install-dependencies.yml`
- Ingin memastikan server siap sebelum deploy service
- Debugging jika service tidak mau jalan

**Apa yang dicek:**

| Komponen | Cara Cek | Gagal jika |
|----------|---------|------------|
| Python3 | `python3 --version` | Tidak ditemukan |
| Docker | `docker --version` | Tidak terinstall |
| Docker service | `systemctl is-active docker` | Tidak aktif |
| docker-compose | `docker-compose --version` | Tidak terinstall / versi salah |
| NVIDIA Driver | `nvidia-smi` | Error (hanya jika ada GPU) |
| NVIDIA Runtime | `docker info \| grep nvidia` | Tidak terdaftar (hanya jika ada GPU) |

**Prasyarat:**
- Sudah menjalankan `install-dependencies.yml` (atau install manual)

**Command:**

```bash
# Semua server
ansible-playbook playbooks/verify-dependencies.yml

# Server tertentu
ansible-playbook playbooks/verify-dependencies.yml --limit 192.168.100.1
```

**Output yang diharapkan:**

Jika semua OK:
```
HASIL VERIFIKASI DEPENDENCIES — 192.168.100.1
====================================================
Python3        : ✅ OK
Docker         : ✅ OK
Docker Service : ✅ aktif
docker-compose : ✅ OK
NVIDIA Driver  : ✅ OK
NVIDIA Runtime : ✅ OK
====================================================
```

Jika ada yang gagal — proses dihentikan dengan pesan error yang jelas.

---

### 3. `init-folders.yml`

**Tujuan:** Inisialisasi folder deployment dan docker prerequisites.

**Kapan digunakan:**
- Ingin menyiapkan struktur folder tanpa copy service
- Persiapan server sebelum deployment

**Apa yang dilakukan:**
1. Deteksi apakah `/data` ada di server
2. Buat folder deployment root (`/data/deployments` atau `/deployments`)
3. Buat docker network `nf-visionaire`
4. Buat docker volume `analytic-volume`

**Prasyarat:**
- Docker sudah terinstall dan aktif

**Command:**

```bash
# Semua server
ansible-playbook playbooks/init-folders.yml

# Server tertentu
ansible-playbook playbooks/init-folders.yml --limit 192.168.100.1

# Beberapa server sekaligus
ansible-playbook playbooks/init-folders.yml --limit "192.168.100.1,192.168.100.2"
```

**Output yang diharapkan:**
```
INISIALISASI FOLDER SELESAI
====================================================
Server     : 192.168.100.1
Deploy root: /data/deployments
Network    : nf-visionaire ✅
Volume     : analytic-volume ✅
====================================================
```

---

### 4. `init-services.yml`

**Tujuan:** Copy compose files dari `compose-examples/` dan replace placeholder IP.

**Kapan digunakan:**
- Setelah dependencies terinstall dan folder sudah siap
- Ingin menambah service baru ke server yang sudah ada

**Apa yang dilakukan:**
1. Deteksi lokasi deployment
2. Tanya IP address dan pilihan service (interaktif)
3. Validasi template compose tersedia
4. Buat subfolder per service
5. Buat docker network + volume (idempotent)
6. Copy compose files
7. Replace `{ip}` → IP address yang diinput

**Prasyarat:**
- Docker sudah terinstall dan aktif
- Tahu IP address server untuk deployment

**Command:**

```bash
# Interaktif (akan ditanya IP dan service)
ansible-playbook playbooks/init-services.yml

# Non-interaktif (langsung pass parameter)
ansible-playbook playbooks/init-services.yml \
  -e "target_ip=192.168.100.1" \
  -e "optional_services_input=v4,fremisn-cpu,liodra"

# Server tertentu + non-interaktif
ansible-playbook playbooks/init-services.yml \
  --limit 192.168.100.1 \
  -e "target_ip=192.168.100.1" \
  -e "optional_services_input=v4,liodra,qwertex"
```

**Prompt interaktif:**

```
====================================================
INISIALISASI SERVICE VISIONAIRE
====================================================

Masukkan IP address server untuk deployment: 192.168.100.1

Service WAJIB (otomatis): database, dashboard

Service TAMBAHAN yang tersedia:
  v4, v4-intel-nuc, v4-offline-analysis,
  fremisn-cpu, fremisn-gpu, liodra, qwertex

Pilih service tambahan (pisahkan koma, kosongkan jika tidak ada): v4,liodra
```

**Output yang diharapkan:**
```
INISIALISASI SERVICE SELESAI
====================================================
Server          : 192.168.100.1
Deploy root     : /data/deployments
Target IP       : 192.168.100.1
Service wajib   : database, dashboard
Service opsional: v4, liodra
====================================================
```

---

### 5. `full-deploy.yml`

**Tujuan:** Jalankan seluruh proses provisioning dari awal sampai akhir.

**Kapan digunakan:**
- Server baru yang belum ada apa-apa
- Ingin satu command untuk semua tahap

**Apa yang dilakukan:**
1. Install dependencies (`install-dependencies.yml`)
2. Verifikasi (`verify-dependencies.yml`) — gagal = stop
3. Init folders (`init-folders.yml`)
4. Init services (`init-services.yml`) — prompt IP + services

**Prasyarat:**
- Server Ubuntu 22.04+ dengan akses SSH
- `inventory/hosts.ini` dan `group_vars/all.yml` sudah dikonfigurasi

**Command:**

```bash
# Interaktif
ansible-playbook playbooks/full-deploy.yml

# Non-interaktif
ansible-playbook playbooks/full-deploy.yml \
  -e "target_ip=192.168.100.1" \
  -e "optional_services_input=v4,fremisn-cpu,liodra"

# Server tertentu
ansible-playbook playbooks/full-deploy.yml \
  --limit 192.168.100.1 \
  -e "target_ip=192.168.100.1" \
  -e "optional_services_input=v4"

# Backward compatible (via site.yml)
ansible-playbook site.yml
```

---

## Service yang Tersedia

### Service Wajib (otomatis di-deploy)

| Service | Image | Port | Keterangan |
|---------|-------|------|-----------|
| `database` | `timescale/timescaledb-ha:pg17` | 5432 | TimescaleDB (PostgreSQL) |
| `dashboard` | `registry.gitlab.com/nodefluxio/lenz:4.3.2` | 4003 | Lenz Dashboard |

### Service Opsional (dipilih saat init-services)

| Service | Image | Port | GPU |
|---------|-------|------|-----|
| `v4` | `nodefluxio/visionaire4:4.57.57` | 4044, 9090, 3000, 3030 | ✅ Device 0 |
| `v4-intel-nuc` | `nodefluxio/visionaire4:4.57.53-blackwell` | 4004 | Intel iGPU |
| `v4-offline-analysis` | `registry.gitlab.com/.../visionaire4:offline_analysis_schedulled` | 4004 | ✅ All GPUs |
| `fremisn-cpu` | `registry.gitlab.com/.../fremis-n:v3.2.4-cpu` | 4005, 4006 | ❌ |
| `fremisn-gpu` | `nodefluxio/fremis-n:v3.1.7-gpu` | 4005 | ✅ All GPUs |
| `liodra` | `registry.gitlab.com/.../liodra:3.7.1` | 9080, 8090 | ❌ |
| `qwertex` | `registry.gitlab.com/.../quertex/go:latest-...DeepSeek-R1...` | 4007 | ✅ Device 0 |

### ⚠️ Konflik Port

Service berikut **tidak bisa jalan bersamaan di 1 server** karena port yang sama:

| Konflik | Port | Pilih salah satu |
|---------|------|------------------|
| Face Recognition | 4005 | `fremisn-cpu` **atau** `fremisn-gpu` |
| VisionAIre Edge | 4004 | `v4-intel-nuc` **atau** `v4-offline-analysis` |

---

## Lokasi Deployment di Server

Ansible otomatis mendeteksi lokasi:

| Kondisi di server | Path deployment |
|-------------------|----------------|
| Ada folder `/data` | `/data/deployments/` |
| Tidak ada `/data` | `/deployments/` |

Contoh struktur yang dihasilkan:

```
/data/deployments/
├── database/
│   └── docker-compose.yaml     ← {ip} sudah diganti IP asli
├── dashboard/
│   └── docker-compose.yaml
├── v4/
│   └── docker-compose.yaml
└── liodra/
    └── docker-compose.yaml
```

---

## Contoh Workflow

### Workflow 1: Deploy Penuh (Server Baru)

```
ansible-playbook playbooks/full-deploy.yml
```

```
install-dependencies.yml
        ↓
verify-dependencies.yml → gagal? STOP ❌
        ↓
init-folders.yml
        ↓
init-services.yml (prompt IP + services)
        ↓
✅ Selesai — jalankan docker-compose up secara manual
```

### Workflow 2: Install Dependencies Saja

```bash
ansible-playbook playbooks/install-dependencies.yml
```

Berguna jika hanya ingin menyiapkan dependency tanpa deploy service.

### Workflow 3: Install + Verifikasi

```bash
ansible-playbook playbooks/install-dependencies.yml
ansible-playbook playbooks/verify-dependencies.yml
```

Berguna untuk memastikan instalasi berhasil sebelum lanjut ke tahap berikutnya.

### Workflow 4: Inisialisasi Folder Saja

```bash
ansible-playbook playbooks/init-folders.yml
```

Berguna jika dependency sudah terinstall dan hanya ingin menyiapkan struktur folder.

### Workflow 5: Tambah Service Baru ke Server yang Sudah Ada

```bash
ansible-playbook playbooks/init-services.yml \
  -e "target_ip=192.168.100.1" \
  -e "optional_services_input=qwertex"
```

Berguna jika server sudah berjalan dan ingin menambah service baru.

### Workflow 6: Non-Interaktif (CI/CD)

```bash
ansible-playbook playbooks/full-deploy.yml \
  -e "target_ip=192.168.100.1" \
  -e "optional_services_input=v4,fremisn-cpu,liodra,qwertex"
```

Semua parameter di-pass via `-e`, tidak ada prompt interaktif.

---

## Referensi Command

### Opsi Umum

| Opsi | Fungsi | Contoh |
|------|--------|--------|
| `--limit` | Jalankan hanya pada server tertentu | `--limit 192.168.100.1` |
| `--limit` | Beberapa server sekaligus | `--limit "192.168.100.1,192.168.100.2"` |
| `-e` | Pass variable tanpa prompt | `-e "target_ip=192.168.100.1"` |
| `--check` | Dry run (tidak eksekusi) | `--check --diff` |
| `-v` / `-vv` / `-vvv` | Verbose output (makin banyak `v` = makin detail) | `-vv` |

### Cheat Sheet

```bash
# === FULL DEPLOY ===
# Semua server (interaktif)
ansible-playbook playbooks/full-deploy.yml

# Semua server (non-interaktif)
ansible-playbook playbooks/full-deploy.yml \
  -e "target_ip=192.168.100.1" \
  -e "optional_services_input=v4,fremisn-cpu,liodra"

# 1 server saja
ansible-playbook playbooks/full-deploy.yml \
  --limit 192.168.100.1 \
  -e "target_ip=192.168.100.1" \
  -e "optional_services_input=v4"

# === PER TAHAP ===
# Install dependencies
ansible-playbook playbooks/install-dependencies.yml

# Verifikasi
ansible-playbook playbooks/verify-dependencies.yml

# Init folders
ansible-playbook playbooks/init-folders.yml

# Init services (interaktif)
ansible-playbook playbooks/init-services.yml

# Init services (non-interaktif)
ansible-playbook playbooks/init-services.yml \
  -e "target_ip=192.168.100.1" \
  -e "optional_services_input=v4,liodra"

# === UTILITAS ===
# Dry run (lihat apa yang akan berubah tanpa eksekusi)
ansible-playbook playbooks/install-dependencies.yml --check --diff

# Verbose (untuk debugging)
ansible-playbook playbooks/verify-dependencies.yml -vv

# Test koneksi SSH ke semua server
ansible visionaire_servers -m ping

# Backward compatible (via site.yml)
ansible-playbook site.yml
```

---

## Urutan Start Container

Setelah provisioning selesai, jalankan container **secara manual** dengan urutan berikut:

```bash
# Ganti /data/deployments dengan /deployments jika tidak ada /data

# 1. Database (paling awal, dependency utama)
cd /data/deployments/database && docker-compose up -d

# 2. Face Recognition (pilih salah satu: cpu ATAU gpu)
cd /data/deployments/fremisn-cpu && docker-compose up -d

# 3. Media Server & LLM (paralel OK, tidak saling bergantung)
cd /data/deployments/liodra && docker-compose up -d
cd /data/deployments/qwertex && docker-compose up -d

# 4. Analytics Engine (butuh database + fremisn sudah jalan)
cd /data/deployments/v4 && docker-compose up -d

# 5. Dashboard (paling akhir, butuh semua service di atas)
cd /data/deployments/dashboard && docker-compose up -d
```

**Kenapa urutannya penting?**
- `database` harus jalan duluan karena hampir semua service menyimpan data di sini
- `fremisn` harus jalan sebelum `v4` karena v4 butuh face recognition service
- `dashboard` paling akhir karena butuh koneksi ke database, v4, dan fremisn

---

## FAQ dan Troubleshooting

### Apakah aman dijalankan berkali-kali?

**Ya.** Semua playbook bersifat **idempotent** — setiap step dicek dulu sebelum
dieksekusi. Kalau dependency sudah terinstall atau folder sudah ada, task otomatis
di-skip (`changed=0`). Aman dijalankan ulang kapan saja.

### Error koneksi SSH pertama kali?

Server baru biasanya belum ada di `known_hosts`. Sudah diatasi dengan
`host_key_checking = False` di `ansible.cfg`, jadi tidak perlu `ssh` manual dulu.

### Server tidak punya GPU NVIDIA?

Tidak masalah. Step NVIDIA driver dan nvidia-docker2 otomatis di-skip jika tidak
terdeteksi GPU. Playbook yang sama bisa dipakai untuk server CPU-only.

### Bagaimana kalau hanya ingin deploy ke 1 server dari banyak server?

Gunakan `--limit`:

```bash
ansible-playbook playbooks/full-deploy.yml --limit 192.168.100.2
```

### Bagaimana cek status server setelah provisioning?

```bash
# Test koneksi
ansible visionaire_servers -m ping

# Cek docker
ansible visionaire_servers -m command -a "docker info | head -20"

# Cek docker-compose
ansible visionaire_servers -m command -a "docker-compose --version"

# Cek GPU (jika ada)
ansible visionaire_servers -m command -a "nvidia-smi"
```

### Verifikasi manual di server

```bash
ssh ubuntu@192.168.100.1

# Cek docker
docker info | grep "Docker Root Dir"

# Cek GPU via docker
docker run --rm --gpus all nvidia/cuda:11.6.2-base-ubuntu20.04 nvidia-smi

# Cek docker-compose
docker-compose --version

# Cek folder deployment
ls -la /data/deployments/

# Cek docker network
docker network ls | grep nf-visionaire

# Cek compose file (pastikan IP sudah diganti)
cat /data/deployments/dashboard/docker-compose.yaml
```
