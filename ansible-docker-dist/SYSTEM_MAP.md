# SYSTEM_MAP.md

## Deskripsi Umum
Repository ini berisi playbook Ansible untuk mendistribusikan Docker image ke dua lokasi berbeda:
- **Server Cikeas (14 server)** — diakses langsung dari laptop via SSH
- **Server Bali/Polda Bali (19 server)** — laptop tidak bisa akses langsung, semua operasi Bali di-delegate ke server01 Cikeas sebagai perantara

## Arsitektur Koneksi
```
Laptop ──SSH──▶ Server Cikeas (14 server, 10.200.168.x)
Laptop ──SSH──▶ server01 ──SSH──▶ Server Bali (19 server, 10.18.200.x)
               (delegate_to)
```

## Struktur Direktori & Komponen Utama

- [ansible.cfg](file:///home/rosemary/ansible-docker-dist/ansible.cfg)
  - Konfigurasi global: inventory path, remote_user, transfer_method=scp

- [inventory/](file:///home/rosemary/ansible-docker-dist/inventory/)
  - [hosts.ini](file:///home/rosemary/ansible-docker-dist/inventory/hosts.ini): Daftar semua server
    - `[source_server]`: server01 (pull & save image)
    - `[cikeas_servers]`: server01–14 (direct SSH dari laptop)
    - `[bali_servers]`: bali01–19 (via server01 sebagai perantara)
    - `[target_servers:children]`: parent group = cikeas + bali
  - [group_vars/cikeas_servers.yml](file:///home/rosemary/ansible-docker-dist/inventory/group_vars/cikeas_servers.yml): Credential Cikeas
  - [group_vars/bali_servers.yml](file:///home/rosemary/ansible-docker-dist/inventory/group_vars/bali_servers.yml): Credential Bali (dipakai server01 via sshpass)
  - [hosts.ini.example](file:///home/rosemary/ansible-docker-dist/inventory/hosts.ini.example): Template tanpa credential asli

- [playbooks/](file:///home/rosemary/ansible-docker-dist/playbooks/)
  - [docker_distribute.yml](file:///home/rosemary/ansible-docker-dist/playbooks/docker_distribute.yml): Playbook utama
    - Phase 1: Pull image di server01
    - Phase 2: Save image ke tar.gz di server01
    - Phase 3a: SCP tar.gz → Cikeas (dari laptop, serial 2)
    - Phase 3b: SCP tar.gz → Bali (server01 push via delegate_to, serial 3)
    - Phase 4a: docker load di Cikeas (dari laptop, serial 2)
    - Phase 4b: docker load di Bali (server01 SSH ke Bali via delegate_to, serial 3)
  - [ping_all.yml](file:///home/rosemary/ansible-docker-dist/playbooks/ping_all.yml): Test koneksi semua server
    - Cikeas: ansible ping module langsung
    - Bali: sshpass ssh via delegate_to server01

- [roles/](file:///home/rosemary/ansible-docker-dist/roles/)
  - `01_pull_image`: docker pull di source server
  - `02_save_image`: docker save | gzip → tar.gz di source server
  - `03_distribute_image`: SCP tar.gz dari server01 ke target (Cikeas saja, role ini tidak dipakai untuk Bali)
  - `04_load_image`: docker load di target server (Cikeas saja)

## Flow Utama
```
docker pull [image] di server01
  → docker save → tar.gz di /tmp/docker_images/
  → [Cikeas] SCP tar.gz langsung dari laptop
  → [Cikeas] docker load
  → [Bali]   server01 SCP tar.gz ke bali01-19
  → [Bali]   server01 SSH ke bali01-19, docker load
```

## Perubahan Signifikan Terakhir (2026-07-02)
- Tambah 19 server Bali ke inventory (group `bali_servers`)
- Arsitektur Bali: semua operasi via `delegate_to: server01` (tidak perlu ProxyJump dari laptop)
- Phase 3 & 4 dipecah: 3a/4a = Cikeas, 3b/4b = Bali
- group_vars per-site untuk credential yang berbeda
