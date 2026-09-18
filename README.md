_This project has been created as part of the 42 curriculum by bpasquer._

# Inception — System Administration & Containerization

## Description

**Inception** is a system administration project from the 42 Common Core. Its main goal is to build a complete, resilient, and secure web infrastructure using **Docker** and **Docker Compose**, without using any pre-built images from DockerHub.

The infrastructure deploys a dynamic **WordPress** website powered by a **MariaDB** database and exposed exclusively through an **NGINX** web server over HTTPS (port 443 with TLSv1.2 / TLSv1.3). Each service runs in its own dedicated container built from scratch using Debian Bookworm (Debian 12).

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

## Instructions

### Prerequisites

- Operating System: **Linux (Debian/Ubuntu)** or a dedicated Virtual Machine.
- Tools: `docker`, `docker-compose-plugin` (or `docker-compose`), `make`.
- Add local domain resolution in `/etc/hosts`:
  ```bash
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

| Command             | Action                                                                                       |
| :------------------ | :------------------------------------------------------------------------------------------- |
| `make` / `make all` | Creates host data directories, builds images, and starts all containers in detached mode.    |
| `make build`        | Builds or rebuilds all Docker images.                                                        |
| `make up`           | Starts the containers without rebuilding.                                                    |
| `make down`         | Stops and removes active containers and networks.                                            |
| `make status`       | Displays the status of containers, volumes, and networks.                                    |
| `make logs`         | Follows real-time logs from all services.                                                    |
| `make clean`        | Stops containers and removes built Docker images.                                            |
| `make fclean`       | Complete teardown: removes containers, images, networks, volumes, and host data directories. |
| `make re`           | Re-executes `fclean` followed by `all`.                                                      |

---

## Project Description & Architectural Comparisons

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
