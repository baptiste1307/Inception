# 🧪 Guide de Test & Checklist d'Évaluation (Poste Linux 42)

> _Ce fichier récapitule toutes les étapes et commandes pratiques pour tester le projet Inception de A à Z sur une machine Linux de 42 ou dans une VM._

---

## ⚡ 0. Rappel : Préparation des fichiers locaux (si clone vierge)

Pour faire tourner le projet sur un clone vierge, deux méthodes sont possibles pour initialiser l'environnement et les secrets :

### Méthode 1 : En ligne de commande (Terminal)

```bash
# 1. Copier les variables d'environnement
cp srcs/.env.example srcs/.env

# 2. Créer le dossier secrets et les 3 fichiers de mots de passe
mkdir -p secrets
echo "super_root_pass_42" > secrets/db_root_password.txt
echo "super_user_pass_42" > secrets/db_password.txt

cat << 'SECRET_EOF' > secrets/credentials.txt
WP_ADMIN_PASSWORD=super_wp_admin_pass_42
WP_USER_PASSWORD=super_wp_user_pass_42
SECRET_EOF

# 3. Restreindre les permissions (lecture/écriture pour l'utilisateur uniquement)
chmod 600 secrets/*
```

---

### Méthode 2 : Via une interface visuelle (VS Code / Remote - SSH)

Si vous êtes connecté à votre VM via l'extension **Remote - SSH** (connect to host) de VS Code (ou avec VS Code directement dans la VM) :

1. **Variables d'environnement :**
   - Dans l'explorateur de fichiers à gauche, faites un clic droit sur `srcs/.env.example` ➔ **Copier**, puis collez-le dans le même dossier et renommez-le en `.env`.

2. **Dossier de secrets :**
   - Cliquez sur l'icône **Nouveau dossier** (📁+) à la racine du projet et nommez-le `secrets`.

3. **Création des fichiers de mots de passe :**
   - Clic droit sur le dossier `secrets` ➔ **Nouveau fichier** (📄+) :
     - `db_root_password.txt` : écrivez `super_root_pass_42` _(enregistrez avec `Cmd+S` ou `Ctrl+S`)_.
     - `db_password.txt` : écrivez `super_user_pass_42`.
     - `credentials.txt` : collez les deux lignes :
       `env
    WP_ADMIN_PASSWORD=super_wp_admin_pass_42
    WP_USER_PASSWORD=super_wp_user_pass_42
    `
       > 💡 _Note : Le dossier `secrets/` apparaîtra grisé dans l'explorateur VS Code. C'est normal : cela indique qu'il est correctement ignoré par `.gitignore` pour des raisons de sécurité._

4. **Permissions de sécurité :**
   - Ouvrez le terminal intégré de VS Code (`Ctrl + ~`) et appliquez les permissions strictes :
     ```bash
     chmod 600 secrets/*
     ```

---

## 🌐 Étape 3 : Configurer le DNS local (`/etc/hosts`)

Sur la machine Linux hôte (ou la VM), associez votre nom de domaine 42 à l'adresse IP locale (`127.0.0.1`) :

```bash
# Avec les droits root :
echo "127.0.0.1 bpasquer.42.fr" | sudo tee -a /etc/hosts

# Sur les postes Linux de 42 (où /etc/hosts est accessible en écriture libre sans sudo) :
echo "127.0.0.1 bpasquer.42.fr" >> /etc/hosts
```

> ⚠️ **DÉPANNAGE — Si le site est inaccessible (`ERR_NAME_NOT_RESOLVED`) :**
>
> - **Sur les postes 42** : Le fichier `/etc/hosts` de la machine physique hôte est **automatiquement réinitialisé à chaque fermeture de session ou redémarrage** ! Si le site devient inaccessible, il faut impérativement réajouter cette ligne dans `/etc/hosts` de la machine hôte (`echo "127.0.0.1 bpasquer.42.fr" >> /etc/hosts`).
> - **Si vos conteneurs tournent dans une VM (VirtualBox)** et que vous naviguez depuis la machine hôte :
>   - Vérifiez que la redirection NAT VirtualBox est configurée (par ex. port hôte `8443` -> port invité `443`), puis accédez via `https://bpasquer.42.fr:8443`.
>   - Ou ouvrez le navigateur directement à l'intérieur de la VM avec `https://bpasquer.42.fr`.

_Vérification :_

```bash
ping -c 2 bpasquer.42.fr
# Doit répondre depuis 127.0.0.1
```

---

## 🚀 Étape 4 : Lancer le projet avec le Makefile

Lancez la compilation et le démarrage en une seule commande à la racine du projet :

```bash
make
```

_Pour suivre les logs en direct et vérifier que tout s'initialise bien :_

```bash
make logs
```

_(Appuyez sur `Ctrl + C` pour quitter les logs sans éteindre les conteneurs)._

---

## 🔍 Étape 5 : La Checklist Complète des Tests (Grille 42)

### Test 1 : Vérifier l'état des conteneurs

```bash
make status
# ou
docker ps
```

✅ **Validation** : Les 3 conteneurs (`nginx`, `wordpress`, `mariadb`) doivent afficher le statut `Up`. Aucun ne doit être `Restarting` ou `Exited`.

---

### Test 2 : Vérifier les processus maîtres (Règle du PID 1)

Pour prouver au correcteur qu'il n'y a aucun hack du genre `tail -f` :

```bash
# 1. Dans MariaDB (doit afficher 'mariadbd' en PID 1) :
docker top mariadb

# 2. Dans WordPress (doit afficher 'php-fpm' en PID 1) :
docker top wordpress

# 3. Dans NGINX (doit afficher 'nginx' en PID 1) :
docker top nginx
```

✅ **Validation** : Le PID 1 est bien le binaire officiel de chaque service.

---

### Test 3 : Tester l'accès Web et le certificat SSL (HTTPS 443)

Deux approches possibles selon la manière dont vous évaluez le projet :

#### Méthode A : Directement DANS la VM (Idéal pour la soutenance officielle 42)

Dans la VM, NGINX écoute directement sur le port 443 standard :

##### 👉 Si votre VM est en ligne de commande pure (sans bureau graphique / Headless) :

- **Option 1 — X11 Forwarding avec SSH (Ouvre Firefox avec affichage déporté sur l'hôte) :**
  1. Depuis le terminal de votre machine physique hôte, connectez-vous avec l'option `-X` :
     ```bash
     ssh -X -p 2323 bpasquer@127.0.0.1
     ```
  2. Dans la VM, installez Firefox s'il n'est pas déjà présent :
     ```bash
     sudo apt update && sudo apt install -y firefox-esr
     ```
  3. Lancez Firefox :
     ```bash
     firefox-esr &
     ```
     _(La fenêtre Firefox s'ouvrira visuellement sur votre écran physique hôte, mais le trafic réseau tourne 100% à l'intérieur de la VM)_.
  4. Tapez simplement dans ce Firefox : **`https://bpasquer.42.fr`** _(aucun port requis !)_.

- **Option 2 — Navigateur Web en mode texte dans le terminal (Lynx) :**

  ```bash
  sudo apt update && sudo apt install -y lynx
  lynx https://bpasquer.42.fr
  ```

  _(Appuyez sur `q` pour quitter Lynx)_.

- **Option 3 — Preuve irréfutable en ligne de commande pour le correcteur :**
  ```bash
  # Vérifie que le port 443 standard répond en 200 OK en TLSv1.2 / TLSv1.3
  curl -kI https://bpasquer.42.fr
  ```

##### 👉 Si votre VM a une interface graphique (Bureau XFCE / GNOME) :

Ouvrez le menu des applications ➔ **Internet** ➔ **Navigateur Web Firefox**, ou tapez `firefox-esr &` dans un terminal de la VM, et allez sur `https://bpasquer.42.fr`.

---

#### Méthode B : Depuis le navigateur de la machine hôte physique (Postes 42 / Cluster)

Sur les PC physiques de 42, les étudiants ne sont pas `root` et ne peuvent pas ouvrir le port 443 sur l'hôte physique.

- La règle NAT VirtualBox redirige donc le port hôte **`8443`** vers le port **`443`** de la VM.
- Accédez à : **`https://bpasquer.42.fr:8443`**
- Acceptez le certificat auto-signé (_« Avancé » ➔ « Accepter le risque »_).
- Inspectez le certificat SSL : émis pour `bpasquer.42.fr`, protocoles `TLSv1.2` ou `TLSv1.3`.
  > 💡 _Note pour l'évaluation : L'infrastructure Docker respecte 100% la consigne « port 443 only » (vérifiable dans `docker-compose.yml` avec `ports: - "443:443"`). Le port 8443 n'est qu'un contournement réseau de l'hôte physique lié aux restrictions de droits des clusters 42._

---

### Test 4 : Connexion au Panel WordPress & Vérification des 2 Utilisateurs

1. Rendez-vous sur : **`https://bpasquer.42.fr/wp-login.php`**
2. Connectez-vous avec :
   - **Identifiant** : `chief_bpasquer`
   - **Mot de passe** : `super_wp_admin_pass_42`
3. Rendez-vous dans le menu **« Utilisateurs »** à gauche.
   ✅ **Validation** :
   - Vous devez voir **2 utilisateurs** : `chief_bpasquer` (Administrateur) et `student` (Auteur).
   - Le pseudo de l'administrateur **ne contient PAS** le mot "admin" ou "administrator".

---

### Test 5 : Vérification des Volumes sur l'hôte physique

Le sujet impose que les volumes soient stockés dans `/home/bpasquer/data/` sur l'hôte :

```bash
# Fichiers WordPress
ls -la /home/bpasquer/data/wordpress

# Fichiers de la base MariaDB
ls -la /home/bpasquer/data/mariadb
```

✅ **Validation** : Les fichiers du site WordPress et les tables de base de données existent physiquement sur votre disque dur.

---

### Test 6 : Le Crash Test de Persistance des données (LE test éliminatoire)

1. Dans le panel WordPress, créez un nouvel article (titre : _"Article Test 42"_, contenu : _"Les données persistent !"_), puis cliquez sur **Publier**.
2. Éteignez tous les conteneurs :
   ```bash
   make down
   ```
3. Vérifiez qu'aucun conteneur ne tourne :
   ```bash
   docker ps
   ```
4. Rallumez tout :
   ```bash
   make up
   ```
5. Rechargez la page `https://bpasquer.42.fr` sur votre navigateur :
   ✅ **Validation** : Votre article est toujours là ! Rien n'a été perdu.

---

### Test 7 : Isolation Réseau (Sécurité)

Vérifiez que seuls NGINX et le port 443 sont ouverts sur la machine hôte :

```bash
# Vérifier les ports ouverts sur la machine hôte
docker ps --format "table {{.Names}}\t{{.Ports}}"
```

✅ **Validation** :

- `nginx` : `0.0.0.0:443->443/tcp`
- `wordpress` : `9000/tcp` (aucun port d'écoute ouvert sur 0.0.0.0 de l'hôte)
- `mariadb` : `3306/tcp` (aucun port d'écoute ouvert sur 0.0.0.0 de l'hôte)

---

### Test 8 : Le Nettoyage Complet (`fclean` et `re`)

```bash
# Nettoyage total (conteneurs, images, volumes, réseaux, données locales)
make fclean

# Relance complète de zéro
make re
```

✅ **Validation** : Le projet repart proprement d'une feuille blanche sans erreur.
