# 🧪 Guide de Test & Checklist d'Évaluation (Poste Linux 42)

> *Ce fichier récapitule toutes les étapes et commandes pratiques pour tester le projet Inception de A à Z sur une machine Linux de 42 ou dans une VM.*

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

Si vous êtes connecté à votre VM via l'extension **Remote - SSH** de VS Code (ou avec VS Code directement dans la VM) :

1. **Variables d'environnement :**
   - Dans l'explorateur de fichiers à gauche, faites un clic droit sur `srcs/.env.example` ➔ **Copier**, puis collez-le dans le même dossier et renommez-le en `.env`.

2. **Dossier de secrets :**
   - Cliquez sur l'icône **Nouveau dossier** (📁+) à la racine du projet et nommez-le `secrets`.

3. **Création des fichiers de mots de passe :**
   - Clic droit sur le dossier `secrets` ➔ **Nouveau fichier** (📄+) :
     - `db_root_password.txt` : écrivez `super_root_pass_42` *(enregistrez avec `Cmd+S` ou `Ctrl+S`)*.
     - `db_password.txt` : écrivez `super_user_pass_42`.
     - `credentials.txt` : collez les deux lignes :
       ```env
       WP_ADMIN_PASSWORD=super_wp_admin_pass_42
       WP_USER_PASSWORD=super_wp_user_pass_42
       ```
   > 💡 *Note : Le dossier `secrets/` apparaîtra grisé dans l'explorateur VS Code. C'est normal : cela indique qu'il est correctement ignoré par `.gitignore` pour des raisons de sécurité.*

4. **Permissions de sécurité :**
   - Ouvrez le terminal intégré de VS Code (`Ctrl + ~`) et appliquez les permissions strictes :
     ```bash
     chmod 600 secrets/*
     ```

---

## 🌐 Étape 3 : Configurer le DNS local (`/etc/hosts`)

Sur la machine Linux, associez votre nom de domaine 42 à l'adresse IP locale (`127.0.0.1`) :

```bash
echo "127.0.0.1 bpasquer.42.fr" | sudo tee -a /etc/hosts
```

*Vérification :*
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

*Pour suivre les logs en direct et vérifier que tout s'initialise bien :*
```bash
make logs
```
*(Appuyez sur `Ctrl + C` pour quitter les logs sans éteindre les conteneurs).*

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
1. Ouvrez Firefox ou Chrome sur la machine Linux.
2. Allez sur : **`https://bpasquer.42.fr`**
3. Acceptez le certificat auto-signé (*« Avancé » ➔ « Accepter le risque »*).
4. Cliquez sur le cadenas à côté de l'URL pour inspecter le certificat SSL :
   - Vérifiez qu'il est émis pour `bpasquer.42.fr`.
   - Vérifiez que le protocole utilisé est bien `TLSv1.2` ou `TLSv1.3`.

*Test en ligne de commande pour le correcteur :*
```bash
# Vérifier que le port 443 répond en TLSv1.2 / TLSv1.3
curl -kI https://bpasquer.42.fr
```

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
1. Dans le panel WordPress, créez un nouvel article (titre : *"Article Test 42"*, contenu : *"Les données persistent !"*), puis cliquez sur **Publier**.
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
