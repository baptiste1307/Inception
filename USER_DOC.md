# 📖 User Documentation — Inception Stack

This guide explains how an administrator or end-user can operate, access, and monitor the Inception web services.

---

## 1. Services Provided by the Stack

| Service             | Technology              | Role                                                       | Access / Port                    |
| :------------------ | :---------------------- | :--------------------------------------------------------- | :------------------------------- |
| **Reverse Proxy**   | **NGINX**               | Encrypts traffic via HTTPS (TLSv1.2/1.3), routes requests. | `https://login.42.fr` (Port 443) |
| **Web Application** | **WordPress + PHP-FPM** | CMS engine executing application logic and dynamic pages.  | Internal FastCGI (Port 9000)     |
| **Database**        | **MariaDB**             | Stores website content, articles, users, and settings.     | Internal MySQL (Port 3306)       |

---

## 2. Starting and Stopping the Project

All operational commands are run from the root of the repository via `make`:

- **Start the stack**:

  ```bash
  make
  ```

  _(Builds the images if necessary, creates storage directories, and starts the services in the background)._

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

### Local Domain Configuration

Ensure your system resolves `login.42.fr` locally by adding it to `/etc/hosts`:

```bash
echo "127.0.0.1 login.42.fr" >> /etc/hosts
```

> ⚠️ **Troubleshooting — Site Inaccessible / DNS Error (`ERR_NAME_NOT_RESOLVED`)**:
>
> - On **42 School workstations**, `/etc/hosts` on the physical host machine is **automatically reset on every logout or system reboot**. If the website cannot be reached, simply re-add the entry on the host machine (`echo "127.0.0.1 login.42.fr" >> /etc/hosts`).
> - When running inside a **headless VirtualBox VM (CLI only)**:
>   - **X11 Forwarding**: Connect via `ssh -X -p 2323 login@127.0.0.1` (note: you can replace `@127.0.0.1` with `@localhost`) and launch `firefox-esr &` inside the VM to open a graphical browser on the host display pointing to `https://login.42.fr`.
>   - **Terminal browser**: Install and use `lynx https://login.42.fr` or test with `curl -kI https://login.42.fr`.
>   - **Host Port Forwarding**: Forward host port `8443` to guest port `443` in VirtualBox NAT settings and browse on the host via `https://login.42.fr:8443`.

### URLs

- **Public Website**: [https://login.42.fr](https://login.42.fr) _(or `https://login.42.fr:8443` when port-forwarded)_
  _(Accept the self-signed SSL certificate warning in your browser)._
- **WordPress Admin Dashboard**: [https://login.42.fr/wp-login.php](https://login.42.fr/wp-login.php)

---

## 4. Locating and Managing Credentials

### 4.1 Locating Credentials

For security reasons, credentials and sensitive data are strictly excluded from the Git repository. They are stored locally across two locations:

- **Usernames & Non-sensitive settings**: defined in `srcs/.env`.
- **Confidential Passwords**: stored in files under the `secrets/` directory.

| Service / Role              | Username Location             | Password Location                               |
| :-------------------------- | :---------------------------- | :---------------------------------------------- |
| **WordPress Administrator** | `srcs/.env` (`WP_ADMIN_USER`) | `secrets/credentials.txt` (`WP_ADMIN_PASSWORD`) |
| **WordPress Author User**   | `srcs/.env` (`WP_USER`)       | `secrets/credentials.txt` (`WP_USER_PASSWORD`)  |
| **Database Root**           | `root` (default)              | `secrets/db_root_password.txt`                  |
| **Database Regular User**   | `srcs/.env` (`MYSQL_USER`)    | `secrets/db_password.txt`                       |

### 4.2 Managing and Initializing Credentials

To configure or update your secret files safely without exposing credentials:

1. **Initialize Secret Files**:
   Create the `secrets/` directory and files with strict access permissions:

   ```bash
   # Create directory and secret files
   mkdir -p secrets
   touch secrets/db_root_password.txt
   touch secrets/db_password.txt
   touch secrets/credentials.txt

   # Restrict permissions (read/write for current user only)
   chmod 600 secrets/*
   ```

2. **Add Your Confidential Passwords**:
   Edit each file with a text editor (e.g. `nano` or VS Code) to add your chosen passwords:
   - `secrets/db_root_password.txt`: Enter your MariaDB root password.
   - `secrets/db_password.txt`: Enter your regular database user password.
   - `secrets/credentials.txt`: Add the WordPress passwords formatted as:
     ```env
     WP_ADMIN_PASSWORD=<your_wp_admin_password>
     WP_USER_PASSWORD=<your_wp_user_password>
     ```

3. **Updating Existing WordPress Passwords**:
   - **Via the Web Interface**: Log into the WordPress dashboard at `https://<DOMAIN_NAME>/wp-admin`, navigate to **Users ➔ Profile**, and update your password under the **Account Management** section.
   - **Via Secret Files**: Update the values in `secrets/credentials.txt` before starting the containers.

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
  _(Press `Ctrl+C` to exit log viewing)._
