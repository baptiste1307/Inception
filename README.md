<h1 align="center">Inception</h1>

<p align="center">
  <strong>System administration and web infrastructure deployment with Docker & Docker Compose from scratch.</strong><br>
  <em>Created as part of the 42 curriculum by bpasquer.</em>
</p>

<p align="center">
  <a href="#overview">Overview</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#key-objectives--architectural-constraints">Objectives</a> •
  <a href="#instructions">Instructions</a> •
  <a href="#available-makefile-commands">Commands</a> •
  <a href="#architectural-comparisons">Comparisons</a> •
  <a href="#license">License</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Docker-24.0%2B-2496ED?style=flat-square&logo=docker&logoColor=white" alt="Docker" />
  <img src="https://img.shields.io/badge/Docker%20Compose-v2-2496ED?style=flat-square&logo=docker&logoColor=white" alt="Docker Compose" />
  <img src="https://img.shields.io/badge/Debian-12%20Bookworm-A81D33?style=flat-square&logo=debian&logoColor=white" alt="Debian 12" />
  <img src="https://img.shields.io/badge/NGINX-TLSv1.2%20%2F%201.3-009639?style=flat-square&logo=nginx&logoColor=white" alt="NGINX" />
  <img src="https://img.shields.io/badge/WordPress-PHP--FPM-21759B?style=flat-square&logo=wordpress&logoColor=white" alt="WordPress" />
  <img src="https://img.shields.io/badge/MariaDB-10.11-003545?style=flat-square&logo=mariadb&logoColor=white" alt="MariaDB" />
  <img src="https://img.shields.io/badge/License-MIT-black?style=flat-square" alt="License" />
</p>

---

## Overview

**Inception** is a system administration project from the 42 Common Core. Its main goal is to build a complete, resilient, and secure web infrastructure using **Docker** and **Docker Compose**, without using any pre-built images from DockerHub.

The infrastructure deploys a dynamic **WordPress** website powered by a **MariaDB** database and exposed exclusively through an **NGINX** web server over HTTPS (port 443 with TLSv1.2 / TLSv1.3). Each service runs in its own dedicated container built from scratch using Debian Bookworm (Debian 12).

### Architecture

```
[ Web Browser / Client ]
           │
           │ HTTPS (Port 443 - TLSv1.2/1.3)
           ▼
  ┌─────────────────┐
  │  NGINX Service  │ (Entrypoint / SSL Termination)
  └────────┬────────┘
           │
           │ FastCGI (Port 9000 - Internal Docker Network)
           ▼
 ┌───────────────────┐
 │ WordPress+PHP-FPM │ (Application Layer)
 └─────────┬─────────┘
           │
           │ MySQL Protocol (Port 3306 - Internal Docker Network)
           ▼
  ┌─────────────────┐
  │ MariaDB Service │ (Database Storage)
  └─────────────────┘
```

---

## Key Objectives & Architectural Constraints

- **Zero Pre-built Application Images**: Every service container (NGINX, WordPress, MariaDB) is built from scratch via custom Dockerfiles based on Debian Bookworm (Debian 12).
- **Strict HTTPS Termination**: Only port `443` is exposed to the outside world, enforced with TLSv1.2 and TLSv1.3 protocols.
- **Service Isolation & Security**: Containers communicate over a dedicated internal Docker bridge network; the MariaDB port (`3306`) and FastCGI port (`9000`) are not published to the host.
- **Volume Persistence**: WordPress website files and MariaDB databases are bound to host persistent volumes (`/home/bpasquer/data/wordpress` and `/home/bpasquer/data/mariadb`).
- **Clean Process Lifecycle**: Services run in the foreground as PID 1 or via dedicated daemons without infinite loops (`tail -f`) or hacky keepalive scripts.
- **Service Auto-restart**: Containers feature automatic restart policies (`restart: on-failure`) ensuring high availability.

---

## Instructions

### Prerequisites

- Operating System: **Linux (Debian/Ubuntu)** or a dedicated Virtual Machine.
- Tools: `docker`, `docker-compose-plugin` (or `docker-compose`), `make`.
- Add local domain resolution in `/etc/hosts` (re-apply if reset on 42 school login):
  ```bash
  echo "127.0.0.1 bpasquer.42.fr" >> /etc/hosts
  # Or with sudo if restricted:
  echo "127.0.0.1 bpasquer.42.fr" | sudo tee -a /etc/hosts
  ```

### Quick Start

1. **Clone the repository**:
   ```bash
   git clone <repository_url> inception && cd inception
   ```
2. **Setup environment & secrets** (if not already present locally):
   ```bash
   cp srcs/.env.example srcs/.env
   # Ensure secrets/ folder contains db_password.txt, db_root_password.txt, credentials.txt
   # (See TEST_GUIDE_42.md or USER_DOC.md for CLI vs VS Code graphical setup)
   ```
3. **Build and launch the stack**:
   ```bash
   make
   ```
4. **Access the application**:
   - Website: `https://bpasquer.42.fr`
   - Admin Dashboard: `https://bpasquer.42.fr/wp-login.php`

### Available Makefile Commands

| Command               | Action                                                                                       |
| :-------------------- | :------------------------------------------------------------------------------------------- |
| `make` / `make all`   | Creates host data directories, builds images, and starts all containers in detached mode.    |
| `make build`          | Builds or rebuilds all Docker images.                                                        |
| `make build-no-cache` | Builds or rebuilds all Docker images without cache.                                          |
| `make up`             | Starts the containers without rebuilding.                                                    |
| `make down`           | Stops and removes active containers and networks.                                            |
| `make status`         | Displays the status of containers, volumes, and networks.                                    |
| `make logs`           | Follows real-time logs from all services.                                                    |
| `make clean`          | Stops containers and removes built Docker images.                                            |
| `make fclean`         | Complete teardown: removes containers, images, networks, volumes, and host data directories. |
| `make re`             | Re-executes `fclean` followed by `all`.                                                      |

---

## Architectural Comparisons

### 1. Virtual Machines vs Docker Containers

- **Virtual Machines (VMs)**: Virtualize hardware through a hypervisor. Each VM runs a full guest operating system (kernel, drivers, binaries). This introduces significant CPU and memory overhead and slow boot times.
- **Docker Containers**: Share the host Linux kernel and isolate applications using kernel features (`namespaces` for process/network isolation and `cgroups` for resource limits). Containers are lightweight, start in milliseconds, and consume minimal RAM.

### 2. Secrets vs Environment Variables

- **Environment Variables (`.env`)**: Useful for non-sensitive configuration parameters (domain names, database names, usernames). However, they are visible to any process running inside the container via `env` or `docker inspect`.
- **Docker Secrets**: Specifically designed for sensitive data (passwords, private keys, API tokens). Secrets are mounted securely into the container as files in in-memory temporary storage (`/run/secrets/`), preventing leakage through inspect commands or container logs.

### 3. Docker Network vs Host Network

- **Host Network (`network_mode: host`)**: Removes network isolation between the container and the host. The container shares the host's network stack directly, which creates security risks and port conflicts.
- **Custom Bridge Network (`inception-network`)**: Creates an isolated private virtual network. Containers communicate securely using DNS service discovery (e.g., `fastcgi_pass wordpress:9000`), and only explicitly published ports (port 443 for NGINX) are reachable from outside.

### 4. Docker Volumes vs Bind Mounts

- **Bind Mounts**: Directly mount an arbitrary file or directory from the host filesystem into a container. They depend heavily on the host directory structure and file permissions.
- **Docker Named Volumes**: Managed directly by the Docker daemon. In this project, we utilize named volumes (`wp_data` and `db_data`) with bind driver options to guarantee reliable data persistence inside `/home/bpasquer/data/` while keeping management integrated within Docker Compose lifecycle.

---

## Resources & AI Usage

### Documentation & References

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Specification](https://docs.docker.com/compose/)
- [NGINX Documentation & SSL Configuration](https://nginx.org/en/docs/)
- [PHP-FPM Configuration](https://www.php.net/manual/en/install.fpm.configuration.php)
- [MariaDB Server Administration](https://mariadb.com/kb/en/documentation/)
- [WP-CLI Official Handbook](https://make.wordpress.org/cli/handbook/)

### AI Usage Declaration

AI assistance was utilized as an interactive tutor and pair-programming partner during this project:

- **Pedagogical explanations**: Clarifying Linux process management (PID 1), daemon foreground execution (`daemon off;`, `php-fpm -F`), and FastCGI communication between NGINX and PHP-FPM.
- **Architecture design**: Validating idempotence strategies for database initialization (`mariadbd --bootstrap`) and automated WordPress deployment via WP-CLI.
- **Documentation structuring**: Formulating architectural comparisons and user/developer guides according to the 42 Inception evaluation standard.

---

## License

This project is licensed under the [MIT License](LICENSE). Educational project created as part of the 42 curriculum.
