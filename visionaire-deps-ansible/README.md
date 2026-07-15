# Ansible - Install Dependencies VisionAIre

Playbook ini otomatis install semua dependency yang dibutuhin VisionAIre di server
Ubuntu 22.04+ (sesuai dokumen `Depedencies_Installation.pdf`):

1. **NVIDIA Driver** — versi *recommended* (auto-detect pakai `ubuntu-drivers autoinstall`), lalu reboot otomatis kalau perlu.
2. **Docker CE** (`docker-ce`, `docker-ce-cli`, `containerd.io`) — data disimpan di `/data/docker` kalau folder `/data` ada, atau `/root/docker` kalau tidak ada. Dicek otomatis per server, tidak perlu diatur manual.
3. **nvidia-docker2** — biar container bisa akses GPU.
4. **docker-compose v1.29.2** — sama seperti versi di dokumen dependensi.

Kalau server ternyata tidak punya GPU NVIDIA, step driver & nvidia-docker2 otomatis
di-skip (tidak akan error), jadi playbook yang sama bisa dipakai juga untuk server
CPU-only.

---

## 1. Syarat di komputer kamu (control machine)

```bash
sudo apt update
sudo apt install -y ansible sshpass
```

`sshpass` cuma dibutuhin kalau login ke server pakai password. Kalau pakai SSH key,
tidak perlu install ini.

## 2. Cara pakai (server baru berapa pun, 1 atau 20)

### a. Isi daftar server di `inventory/hosts.ini`

```ini
[visionaire_servers]
192.168.100.1
192.168.100.2
192.168.100.3
```

Tinggal tambah baris IP baru kalau ada server baru lagi. Tidak ada batas jumlah.

### b. Isi kredensial di `group_vars/all.yml`

```yaml
ansible_user: "ubuntu"
ansible_ssh_pass: "password_ssh_kamu"
ansible_become_pass: "password_sudo_kamu"
```

Kalau semua server pakai user & password yang sama, cukup diisi sekali di sini —
tidak perlu diulang-ulang per server. Kalau pakai SSH key, hapus baris
`ansible_ssh_pass` dan aktifkan baris `ansible_ssh_private_key_file`.

### c. Jalankan playbook

```bash
cd visionaire-deps-ansible
ansible-playbook site.yml
```

Selesai. Ansible akan otomatis:
- cek koneksi & python di tiap server,
- install driver NVIDIA (kalau ada GPU) lalu reboot server itu sendiri,
- lanjut install docker, nvidia-docker2, docker-compose,
- kasih ringkasan status di akhir untuk tiap server.

### d. Test dulu tanpa eksekusi apa-apa (opsional tapi disarankan)

```bash
ansible-playbook site.yml --check --diff
```

### e. Kalau cuma mau jalan ke 1 server tertentu saja

```bash
ansible-playbook site.yml --limit 192.168.100.2
```

---

## 3. Kenapa aman dijalankan berkali-kali (idempotent)

Semua step sudah dibuat "cek dulu sebelum install" — kalau driver/docker/compose
sudah terpasang dengan versi yang benar, task-nya otomatis di-skip
(`changed=0`), jadi playbook yang sama bisa dijalankan ulang kapan saja tanpa
takut error atau install dobel.

## 4. Kalau ada error koneksi SSH pertama kali

Server baru biasanya belum ada di `known_hosts`. Sudah diatasi dengan
`host_key_checking = False` di `ansible.cfg`, jadi tidak perlu `ssh` manual dulu
ke tiap server sebelum jalanin ansible.

## 5. Struktur project

```
visionaire-deps-ansible/
├── ansible.cfg              # konfigurasi ansible
├── site.yml                 # playbook utama (jalankan file ini)
├── inventory/hosts.ini      # daftar IP server -> EDIT DI SINI kalau ada server baru
├── group_vars/all.yml       # user/password/versi -> EDIT DI SINI
└── roles/
    ├── nvidia_driver/       # step 1: install driver + reboot
    ├── docker/               # step 2: install docker-ce + atur data-root
    ├── nvidia_docker/        # step 3: install nvidia-docker2
    └── docker_compose/       # step 4: install docker-compose
```

## 6. Verifikasi manual setelah selesai (opsional)

```bash
ssh user@192.168.100.1
docker info | grep "Docker Root Dir"     # cek lokasi data docker
docker run --rm --gpus all nvidia/cuda:11.6.2-base-ubuntu20.04 nvidia-smi
docker-compose --version
```
