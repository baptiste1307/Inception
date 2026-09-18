# 🛠️ Developer Documentation — Inception Stack

This document describes the technical implementation, development workflow, and maintenance guidelines for developers working on the Inception infrastructure.

---

## 1. Environment Setup from Scratch

### System Requirements

- Host OS: **Linux (42 VM, Debian) / Ubuntu 22.04+** — any distribution able to run Docker Engine.
- Docker Engine version 20.10+ & Docker Compose v2+.
- Sudo/root access to create `/home/bpasquer/data/` directories and edit `/etc/hosts`.

### Initial Setup Steps

1. **Clone the repository**:
   ```bash
   git clone <repo-url> inception
   cd inception
   ```
2. **Configure Environment File**:
   Copy the template environment file:
   ```bash
   cp srcs/.env.example srcs/.env
   ```
3. **Configure Secret Files**:
   Create the `secrets/` directory, initialize the secret files with strict permissions, and add your confidential credentials:

   ```bash
   # Create directory and secret files
   mkdir -p secrets
   touch secrets/db_root_password.txt
   touch secrets/db_password.txt
   touch secrets/credentials.txt

   # Restrict permissions (read/write for current user only)
   chmod 600 secrets/*
   ```

   Populate each file with your secrets:
   - `secrets/db_root_password.txt`: Root password for MariaDB.
   - `secrets/db_password.txt`: Password for the regular database user (`MYSQL_USER`).
   - `secrets/credentials.txt`: Administrator and standard WordPress user passwords formatted as:
     ```env
     WP_ADMIN_PASSWORD=<your_wp_admin_password>
     WP_USER_PASSWORD=<your_wp_user_password>
     ```

---

## 2. Directory Architecture & Roles

```text
inception/
├── Makefile                          # Top-level orchestration rules
├── README.md                         # Project presentation & comparisons
├── USER_DOC.md                       # User operations manual
├── DEV_DOC.md                        # Developer architecture manual
├── MY_NOTES.md                       # Pedagogical revision notebook
├── secrets/                          # Local secrets (gitignored)
└── srcs/
    ├── .env                          # Non-sensitive variables (domain, user names)
    ├── docker-compose.yml            # Services, networks, volumes & secrets
    └── requirements/
        ├── mariadb/
        │   ├── conf/50-server.cnf    # MariaDB networking & buffer config
        │   ├── tools/init_db.sh      # Database bootstrap & PID 1 launcher
        │   ├── Dockerfile            # Debian Bookworm + MariaDB 10.11 Server
        │   └── .dockerignore
        ├── wordpress/
        │   ├── conf/www.conf         # PHP-FPM FastCGI pool (port 9000)
        │   ├── tools/wp_init.sh      # WP-CLI download, auto-install & PID 1
        │   ├── Dockerfile            # Debian Bookworm + PHP8.2-FPM + WP-CLI
        │   └── .dockerignore
        └── nginx/
            ├── conf/nginx.conf       # TLSv1.2/1.3, FastCGI reverse proxy config
            ├── tools/nginx_start.sh  # OpenSSL certificate setup & PID 1
            ├── Dockerfile            # Debian Bookworm + NGINX + OpenSSL
            └── .dockerignore
```

---

## 3. Container Management Commands

| Action                        | Command                                                                                            |
| :---------------------------- | :------------------------------------------------------------------------------------------------- |
| **Build all from scratch**    | `docker compose -f srcs/docker-compose.yml build --no-cache` (ou `make build-no-cache`)            |
| **Rebuild single service**    | `docker compose -f srcs/docker-compose.yml build --no-cache <service>` (ex: `wordpress`)           |
| **Start with live logs**      | `docker compose -f srcs/docker-compose.yml up`                                                     |
| **Start detached**            | `docker compose -f srcs/docker-compose.yml up -d`                                                  |
| **Open container shell**      | `docker exec -it mariadb bash`<br>`docker exec -it wordpress bash`<br>`docker exec -it nginx bash` |
| **Inspect database directly** | `docker exec -it mariadb mariadb -u wpuser -p wordpress`                                           |
| **Test FastCGI routing**      | `docker exec -it nginx curl -k https://localhost`                                                  |

---

## 4. Data Persistence & Storage Architecture

Data persistence is decoupled from container lifecycle using named volumes with host bind points:

- **WordPress Files**:
  - Container path: `/var/www/html`
  - Host path: `/home/bpasquer/data/wordpress`
  - Lifecycle: Maintained across container rebuilds. Contains WordPress core, themes, plugins, and media uploads.
- **MariaDB Tables**:
  - Container path: `/var/lib/mysql`
  - Host path: `/home/bpasquer/data/mariadb`
  - Lifecycle: Preserves database schema, user accounts, posts, and metadata even after `make clean` or `docker compose down`.
- **Complete Reset**:
  - Executing `make fclean` safely removes container states, networks, cached images, and deletes host directories in `/home/bpasquer/data/`.
