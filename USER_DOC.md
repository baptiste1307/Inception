# 📖 User Documentation — Inception Stack

This guide explains how an administrator or end-user can operate, access, and monitor the Inception web services.

---

## 1. Services Provided by the Stack

| Service | Technology | Role | Access / Port |
| :--- | :--- | :--- | :--- |
| **Reverse Proxy** | **NGINX** | Encrypts traffic via HTTPS (TLSv1.2/1.3), routes requests. | `https://bpasquer.42.fr` (Port 443) |
| **Web Application** | **WordPress + PHP-FPM** | CMS engine executing application logic and dynamic pages. | Internal FastCGI (Port 9000) |
| **Database** | **MariaDB** | Stores website content, articles, users, and settings. | Internal MySQL (Port 3306) |

---

## 2. Starting and Stopping the Project

All operational commands are run from the root of the repository via `make`:

- **Start the stack**:
  ```bash
  make
  ```
  *(Builds the images if necessary, creates storage directories, and starts the services in the background).*

- **Stop the stack**:
  ```bash
  make down
  ```

- **Pause / Resume without destroying containers**:
  ```bash
  make stop   # Pause containers
  make start  # Resume containers
  ```

---

## 3. Accessing the Website & Administration Panel

### Local Domain Configuration (First Time Only)
Ensure your system resolves `bpasquer.42.fr` locally by checking `/etc/hosts`:
```bash
127.0.0.1 bpasquer.42.fr
```

### URLs
- **Public Website**: [https://bpasquer.42.fr](https://bpasquer.42.fr)
  *(Accept the self-signed SSL certificate warning in your browser).*
- **WordPress Admin Dashboard**: [https://bpasquer.42.fr/wp-login.php](https://bpasquer.42.fr/wp-login.php)

---

## 4. Locating and Managing Credentials

Credentials are stored securely in local files inside the `secrets/` directory (ignored by Git for security):

- **WordPress Administrator**:
  - **Username**: defined in `srcs/.env` (`WP_ADMIN_USER=chief_bpasquer`)
  - **Password**: stored in `secrets/credentials.txt` (`WP_ADMIN_PASSWORD`)
- **WordPress Standard User**:
  - **Username**: defined in `srcs/.env` (`WP_USER=student`)
  - **Password**: stored in `secrets/credentials.txt` (`WP_USER_PASSWORD`)
- **Database Credentials**:
  - **Root password**: stored in `secrets/db_root_password.txt`
  - **Database user password**: stored in `secrets/db_password.txt`

### Creating / Initializing Secrets

Two equivalent methods can be used to set up the credentials on a new clone:

#### Method A: Command-Line Interface (Terminal)
```bash
cp srcs/.env.example srcs/.env
mkdir -p secrets
echo "super_root_pass_42" > secrets/db_root_password.txt
echo "super_user_pass_42" > secrets/db_password.txt
cat << 'EOF' > secrets/credentials.txt
WP_ADMIN_PASSWORD=super_wp_admin_pass_42
WP_USER_PASSWORD=super_wp_user_pass_42
EOF
chmod 600 secrets/*
```

#### Method B: Visual Interface (VS Code / Remote - SSH)
1. In the file explorer, duplicate `srcs/.env.example` into `srcs/.env`.
2. Create a new folder named `secrets/` at the repository root.
3. Inside `secrets/`, create:
   - `db_root_password.txt` containing the root password.
   - `db_password.txt` containing the database user password.
   - `credentials.txt` containing `WP_ADMIN_PASSWORD=...` and `WP_USER_PASSWORD=...`.
4. Open the integrated terminal (`Ctrl + ~`) and restrict permissions: `chmod 600 secrets/*`.

*(Note: The `secrets/` folder appears dimmed in VS Code because it is safely excluded by `.gitignore`).*

---

## 5. Checking Service Health

- **View active container status**:
  ```bash
  make status
  ```
  Expected output: All 3 containers (`nginx`, `wordpress`, `mariadb`) should have the status `Up`.

- **Inspect real-time service logs**:
  ```bash
  make logs
  ```
  *(Press `Ctrl+C` to exit log viewing).*
