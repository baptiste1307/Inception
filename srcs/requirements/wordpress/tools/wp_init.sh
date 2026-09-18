#!/bin/bash

# "set -e" : si une commande rate, arrête tout immédiatement !
# "set -e" : si une commande rate, arrete tout immediatement !
set -e

# ==============================================================================
# ETAPE 1 : RECUPERER LES MOTS DE PASSE SECRETS
# ETAPE 1 : RECUPERER ET VALIDER LES MOTS DE PASSE SECRETS
# ==============================================================================
# 1. Mot de passe de la base de données (pour que WordPress puisse se connecter à MariaDB)
# 1. Mot de passe de la base de donnees (pour que WordPress puisse se connecter a MariaDB)
if [ -f "/run/secrets/db_password" ]; then
    DB_PASSWORD=$(cat /run/secrets/db_password)
fi

# 2. Mots de passe des utilisateurs WordPress (déposés dans le fichier secret credentials)
# 2. Mots de passe des utilisateurs WordPress (deposes dans le fichier secret credentials)
if [ -f "/run/secrets/credentials" ]; then
    WP_ADMIN_PASSWORD=$(grep '^WP_ADMIN_PASSWORD=' /run/secrets/credentials | cut -d '=' -f2-)
    WP_USER_PASSWORD=$(grep '^WP_USER_PASSWORD=' /run/secrets/credentials | cut -d '=' -f2-)
fi

# 3. Verification de la presence de toutes les variables necessaires
if [ -z "${DB_PASSWORD}" ] || [ -z "${WP_ADMIN_PASSWORD}" ] || [ -z "${WP_USER_PASSWORD}" ]; then
    echo "[ERREUR] Des secrets obligatoires sont manquants dans /run/secrets/ !"
    exit 1
fi

if [ -z "${MYSQL_DATABASE}" ] || [ -z "${MYSQL_USER}" ] || [ -z "${DOMAIN_NAME}" ]; then
    echo "[ERREUR] Des variables d'environnement obligatoires (.env) sont manquantes !"
    exit 1
fi

# ==============================================================================
# ETAPE 2 : ATTENDRE QUE MARIADB SOIT REVEILLE
# ==============================================================================
# Au démarrage, WordPress et MariaDB s'allument en même temps.
# MariaDB met quelques secondes à s'initialiser. On envoie un "ping" toutes les 2 secondes
# jusqu'à ce que MariaDB réponde : "C'est bon, je suis prêt !".
# Au demarrage, WordPress et MariaDB s'allument en meme temps.
# MariaDB met quelques secondes a s'initialiser. On envoie un "ping" toutes les 2 secondes
# jusqu'a ce que MariaDB responde : "C'est bon, je suis pret !".

echo "[INFO] Vérification de la connexion à MariaDB..."
echo "[INFO] Verification de la connexion a MariaDB..."
until mariadb-admin --host=mariadb --user="${MYSQL_USER}" --password="${DB_PASSWORD}" ping --silent; do
    echo "[INFO] MariaDB n'est pas encore prêt... On attend 2 secondes..."
    echo "[INFO] MariaDB n'est pas encore pret... On attend 2 secondes..."
    sleep 2
done
echo "[INFO] MariaDB est prêt et joignable !"
echo "[INFO] MariaDB est pret et joignable !"

# ==============================================================================
# ETAPE 3 : INSTALLER WORDPRESS (SEULEMENT AU TOUT PREMIER DEMARRAGE)
# ETAPE 3 : INSTALLER WORDPRESS DE FAÇON IDEMPOTENTE
# ==============================================================================
# Si le fichier "wp-config.php" existe déjà, c'est que le site a déjà été installé.
# On ne touche à rien pour préserver les articles et réglages existants !

# 1. Telecharger les fichiers sources officiels de WordPress (si absent)
if [ ! -f "/var/www/html/wp-settings.php" ]; then
    echo "[INFO] Telechargement des fichiers sources de WordPress..."
    wp core download --allow-root --force
fi

# 2. Creer le fichier wp-config.php (si absent)
if [ ! -f "/var/www/html/wp-config.php" ]; then
    echo "[INFO] Premier démarrage : Installation de WordPress en cours..."

    # 1. Télécharger les fichiers sources officiels de WordPress
    wp core download --allow-root

    # 2. Créer le fichier wp-config.php (qui contient l'adresse et le mot de passe de MariaDB)
    # Note : "--dbhost=mariadb:3306" utilise le nom du conteneur MariaDB sur le réseau Docker !
    echo "[INFO] Creation du fichier wp-config.php..."
    wp config create \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${DB_PASSWORD}" \
        --dbhost="mariadb:3306" \
        --allow-root
fi

    # 3. Lancer l'installation du site avec le premier utilisateur (ADMINISTRATEUR)
    # ATTENTION REGLE 42 : le nom de l'admin ne doit PAS contenir "admin" ou "Admin"
# 3. Lancer l'installation du site avec le premier utilisateur (ADMINISTRATEUR) si non installe
if ! wp core is-installed --allow-root > /dev/null 2>&1; then
    echo "[INFO] Installation de WordPress avec l'administrateur..."
    wp core install \
        --url="https://${DOMAIN_NAME}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email \
        --allow-root
else
    echo "[INFO] WordPress est deja installe en base de donnees."
fi

    # 4. Créer le SECOND utilisateur obligatoire selon le sujet 42
# 4. Creer le SECOND utilisateur obligatoire selon le sujet 42 (si absent)
if ! wp user get "${WP_USER}" --allow-root > /dev/null 2>&1; then
    echo "[INFO] Creation du second utilisateur standard (${WP_USER})..."
    wp user create \
        "${WP_USER}" \
        "${WP_USER_EMAIL}" \
        --role=author \
        --user_pass="${WP_USER_PASSWORD}" \
        --allow-root

    echo "[INFO] WordPress installé avec succès avec 2 utilisateurs !"
else
    echo "[INFO] WordPress est déjà installé, pas besoin de réinstaller."
    echo "[INFO] Le second utilisateur (${WP_USER}) existe deja."
fi

echo "[INFO] Configuration de WordPress terminee avec succes !"

# ==============================================================================
# ETAPE 4 : DONNER LES BONS DROITS A L'UTILISATEUR WEB
# ==============================================================================
# On s'assure que www-data peut lire et écrire dans le dossier pour uploader des images
# On s'assure que www-data peut lire et ecrire dans le dossier pour uploader des images
chown -R www-data:www-data /var/www/html

# ==============================================================================
# ETAPE 5 : LANCER PHP-FPM EN PID 1 (PREMIER PLAN)
# ==============================================================================
# L'option "-F" (Foreground) est capitale : elle empêche PHP-FPM de passer en arrière-plan.
# On s'assure que le dossier /run/php existe pour le fichier PID
mkdir -p /run/php

# L'option "-F" (Foreground) est capitale : elle empeche PHP-FPM de passer en arriere-plan.
# "exec" remplace notre script bash par PHP-FPM pour qu'il devienne le PID 1 propre.
# NOTE : bookworm (Debian 12) fournit PHP 8.2 ; le binaire s'appelle donc php-fpm8.2
# et se trouve dans /usr/sbin (déjà présent dans le PATH de l'image).
echo "[INFO] Démarrage de PHP-FPM au premier plan (PID 1)..."
echo "[INFO] Demarrage de PHP-FPM au premier plan (PID 1)..."
exec php-fpm8.2 -F
