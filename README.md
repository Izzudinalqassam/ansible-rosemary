# 🛠️ Ansible Rosemary

Kumpulan Ansible playbook untuk **otomasi server VisionAIre** — dari setup awal, distribusi Docker image, update compose, sampai manajemen swap memory.

> Semua playbook dibuat **idempotent** (aman dijalankan berkali-kali) dan mendukung **selective targeting** per server.

---

## 📦 Daftar Playbook

| Folder | Fungsi | Kapan Dipakai |
|---|---|---|
| [`visionaire-deps-ansible/`](./visionaire-deps-ansible/) | Install semua dependency VisionAIre (NVIDIA Driver, Docker, nvidia-docker2, docker-compose) | **Server baru** — setup awal sebelum deploy |
| [`ansible-docker-dist/`](./ansible-docker-dist/) | Pull Docker image sekali, distribute ke semua server (Cikeas + Bali) via SCP | **Sebelum update** — pastikan image sudah tersedia di semua server |
| [`ansible-compose-update/`](./ansible-compose-update/) | Cek image saat ini, update versi image di docker-compose.yaml, restart container | **Saat update** — ganti versi image dan restart node |
| [`ansible-swap-increase/`](./ansible-swap-increase/) | Cek dan upgrade swap memory (threshold 8 GB → target 64 GB) | **Maintenance** — server yang swap-nya kurang |

---

## 🔄 Urutan Operasional (Workflow)

Untuk **deploy atau update VisionAIre** di server, ikuti urutan ini:

```
1. visionaire-deps-ansible     ← Setup awal (sekali saja per server baru)
   Install NVIDIA Driver, Docker, nvidia-docker2, docker-compose

2. ansible-docker-dist         ← Distribute image ke semua server
   Pull image → Save tar.gz → SCP ke semua server → Docker load

3. ansible-compose-update      ← Update versi di compose & restart
   Cek image → Update docker-compose.yaml → Restart container

4. ansible-swap-increase       ← Opsional, jika swap kurang
   Cek swap → Upgrade ke 64 GB jika ≤ 8 GB
```

---

## 🛠 Prasyarat

| Kebutuhan | Di mana | Keterangan |
|---|---|---|
| Ansible ≥ 2.12 | Laptop / WSL | Control node |
| `sshpass` | Laptop + server01 | Untuk auth SSH via password |
| Python 3 | Semua server | Dibutuhkan Ansible |

```bash
# Install di laptop (sekali saja)
sudo apt update && sudo apt install -y ansible sshpass
```

---

## 🚀 Quick Start

### 1. Clone repo

```bash
git clone https://github.com/Izzudinalqassam/ansible-rosemary.git
cd ansible-rosemary
```

### 2. Setup inventory

Setiap folder punya file `*.example` di inventory. Salin dan isi dengan data asli:

```bash
# Contoh untuk ansible-compose-update
cp ansible-compose-update/inventory/hosts.ini.example \
   ansible-compose-update/inventory/hosts.ini
# Edit hosts.ini → isi IP server dan credential
```

> ⚠️ **File `hosts.ini` dan `group_vars/*.yml` TIDAK di-commit ke Git** karena berisi credential. Hanya file `.example` yang ada di repo.

### 3. Jalankan playbook

```bash
# Masuk ke folder yang dibutuhkan
cd ansible-compose-update

# Cek koneksi dulu
ansible all -m ping

# Jalankan playbook
ansible-playbook playbooks/check_images.yml
```

---

## 📁 Struktur Repository

```
ansible-rosemary/
│
├── README.md                          ← Dokumen ini
├── .gitignore                         ← Mengabaikan file sensitif
│
├── visionaire-deps-ansible/           ← [1] Install dependency server baru
│   ├── README.md
│   ├── ansible.cfg
│   ├── site.yml                       ← Playbook utama
│   ├── inventory/
│   │   ├── hosts.ini.example
│   │   └── hosts.ini                  ← (gitignored, isi manual)
│   ├── group_vars/
│   │   ├── all.yml.example
│   │   └── all.yml                    ← (gitignored, isi manual)
│   └── roles/
│       ├── nvidia_driver/             ← Install NVIDIA driver + reboot
│       ├── docker/                    ← Install Docker CE + atur data-root
│       ├── nvidia_docker/             ← Install nvidia-docker2
│       └── docker_compose/            ← Install docker-compose v1.29.2
│
├── ansible-docker-dist/               ← [2] Distribute Docker image
│   ├── readme.md
│   ├── ansible.cfg
│   ├── inventory/
│   │   ├── hosts.ini.example
│   │   └── group_vars/
│   │       ├── cikeas_servers.yml.example
│   │       └── bali_servers.yml.example
│   ├── playbooks/
│   │   ├── docker_distribute.yml      ← Playbook utama distribusi
│   │   └── ping_all.yml              ← Test koneksi semua server
│   └── roles/
│       ├── 01_pull_image/             ← Docker pull di server01
│       ├── 02_save_image/             ← Docker save → tar.gz
│       ├── 03_distribute_image/       ← SCP tar.gz ke semua server
│       └── 04_load_image/             ← Docker load di target
│
├── ansible-compose-update/            ← [3] Update image & restart compose
│   ├── readme.md
│   ├── ansible.cfg
│   ├── inventory/
│   │   └── hosts.ini.example
│   ├── playbooks/
│   │   ├── check_images.yml              ← Cek image (read-only, aman)
│   │   ├── check_scheduled_restart.yml   ← Cek status --scheduled-restart (read-only)
│   │   ├── compose_update.yml            ← Update + restart (smart skip)
│   │   ├── restart_nodes.yml             ← Rolling restart 1 server/waktu
│   │   └── scheduled_restart.yml         ← Toggle --scheduled-restart
│   └── roles/
│       ├── 00_check_image/            ← Cek image saat ini
│       ├── 01_update_image/           ← Replace image (skip jika sama)
│       ├── 02_restart_compose/        ← Restart (hanya node berubah)
│       ├── 03_restart_node/           ← Restart semua node per server
│       └── 04_scheduled_restart/      ← Toggle --scheduled-restart
│
└── ansible-swap-increase/             ← [4] Upgrade swap memory
    ├── readme.md
    ├── ansible.cfg
    ├── inventory/
    │   └── hosts.ini.example
    ├── playbooks/
    │   └── manage_swap.yml            ← Playbook utama
    └── roles/
        └── swap_manager/              ← Cek & upgrade swap
```

---

## 🔐 Keamanan

File-file berikut **TIDAK di-commit** ke Git (di-gitignore):

| Pattern | Alasan |
|---|---|
| `**/inventory/hosts.ini` | Berisi IP server asli |
| `**/inventory/group_vars/*.yml` | Berisi password SSH/sudo |
| `**/group_vars/all.yml` | Berisi credential |

Gunakan file `.example` sebagai template, salin dan isi secara lokal.

> 💡 **Tips:** Untuk keamanan lebih baik, pertimbangkan menggunakan [Ansible Vault](https://docs.ansible.com/ansible/latest/vault_guide/index.html) untuk mengenkripsi credential.

---

## 📝 Detail Setiap Playbook

### 1. `visionaire-deps-ansible` — Install Dependencies

Otomatis install semua dependency VisionAIre sesuai dokumen `Dependencies_Installation.pdf`:
- **NVIDIA Driver** — auto-detect versi recommended, reboot otomatis jika perlu
- **Docker CE** — data disimpan di `/data/docker` (atau `/root/docker` jika `/data` tidak ada)
- **nvidia-docker2** — agar container bisa akses GPU
- **docker-compose v1.29.2**

Server tanpa GPU NVIDIA? Step driver & nvidia-docker2 otomatis di-skip.

```bash
cd visionaire-deps-ansible
ansible-playbook site.yml
```

---

### 2. `ansible-docker-dist` — Distribute Docker Image

Pull image sekali di server01, simpan sebagai tar.gz, lalu distribute ke semua server:
- **Cikeas (14 server)** — langsung dari laptop via Ansible
- **Bali / Polda Bali (19 server)** — server01 sebagai perantara (laptop tidak bisa SSH ke Bali)

```bash
cd ansible-docker-dist
ansible-playbook playbooks/docker_distribute.yml
```

---

### 3. `ansible-compose-update` — Update Image & Restart

Cek image yang sedang dipakai, update versi image di `docker-compose.yaml`, dan restart container. Node yang sudah pakai image terbaru **otomatis di-skip**.

```bash
cd ansible-compose-update

# Cek image saja (read-only, aman)
ansible-playbook playbooks/check_images.yml

# Update & restart
ansible-playbook playbooks/compose_update.yml \
  -e "new_image=registry.gitlab.com/nodefluxio/visionaire4:4.58.0"

# Rolling restart tanpa update image (1 server, jeda 2 menit)
ansible-playbook playbooks/restart_nodes.yml
ansible-playbook playbooks/restart_nodes.yml --limit server01,server05
```

#### ⏰ Toggle `--scheduled-restart`

Tambah/hapus flag `--scheduled-restart` di command docker-compose. Waktu otomatis staggered per node (selang 5 menit berdasarkan nomor node: node-1 = 02:00, node-2 = 02:05, dst). Setelah edit, rolling restart 1 server per waktu dengan jeda 2 menit per node.

```bash
# Enable (tambah/uncomment) di semua server
ansible-playbook playbooks/scheduled_restart.yml

# Disable (comment out) di semua server
ansible-playbook playbooks/scheduled_restart.yml -e "scheduled_restart_action=disable"

# Target server tertentu
ansible-playbook playbooks/scheduled_restart.yml --limit server01,server05

# Hanya edit tanpa down & up
ansible-playbook playbooks/scheduled_restart.yml --tags phase1

# Validasi: cek status --scheduled-restart di semua node (read-only)
ansible-playbook playbooks/check_scheduled_restart.yml
ansible-playbook playbooks/check_scheduled_restart.yml --limit server01,server05
```

---

### 4. `ansible-swap-increase` — Upgrade Swap Memory

Cek swap di semua server, upgrade ke 64 GB jika swap saat ini ≤ 8 GB.

```bash
cd ansible-swap-increase
ansible-playbook playbooks/manage_swap.yml
```

---

## 👤 Author

**Izzudin Al Qassam** — DevOps / Infrastructure
