#!/bin/bash
set -e

# ==============================================================================
# ETAPE 1 : RECUPERER ET VALIDER LES MOTS DE PASSE SECRETS
# ==============================================================================
# 1. Mot de passe de la base de donnees (pour MariaDB)
if [ -f "/run/secrets/db_password" ]; then
    DB_PASSWORD=$(cat /run/secrets/db_password | tr -d '\r')
fi

# 2. Mots de passe des utilisateurs WordPress
if [ -f "/run/secrets/credentials" ]; then
    WP_ADMIN_PASSWORD=$(grep '^WP_ADMIN_PASSWORD=' /run/secrets/credentials | cut -d '=' -f2- | tr -d '\r')
    WP_USER_PASSWORD=$(grep '^WP_USER_PASSWORD=' /run/secrets/credentials | cut -d '=' -f2- | tr -d '\r')
fi

# 3. Verification des secrets et variables obligatoires
if [ -z "${DB_PASSWORD}" ] || [ -z "${WP_ADMIN_PASSWORD}" ] || [ -z "${WP_USER_PASSWORD}" ]; then
    echo "[ERREUR] Des secrets obligatoires sont manquants dans /run/secrets/ !"
    exit 1
fi

if [ -z "${MYSQL_DATABASE}" ] || [ -z "${MYSQL_USER}" ] || [ -z "${DOMAIN_NAME}" ]; then
    echo "[ERREUR] Des variables d'environnement obligatoires (.env) sont manquantes !"
    exit 1
fi

# ==============================================================================
# ETAPE 2 : ATTENDRE QUE MARIADB SOIT OPERATIONNEL
# ==============================================================================
echo "[INFO] Verification de la connexion a MariaDB..."
until mariadb-admin --host=mariadb --user="${MYSQL_USER}" --password="${DB_PASSWORD}" ping --silent; do
    echo "[INFO] MariaDB n'est pas encore pret... On attend 2 secondes..."
    sleep 2
done
echo "[INFO] MariaDB est pret et joignable !"

# ==============================================================================
# ETAPE 3 : INSTALLER ET CONFIGURER WORDPRESS
# ==============================================================================
# 1. Telecharger les fichiers sources de WordPress (si absent)
if [ ! -f "/var/www/html/wp-settings.php" ]; then
    echo "[INFO] Telechargement des fichiers sources de WordPress..."
    wp core download --allow-root --force
fi

# 2. Creer le fichier wp-config.php (si absent)
if [ ! -f "/var/www/html/wp-config.php" ]; then
    echo "[INFO] Creation du fichier wp-config.php..."
    wp config create \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${DB_PASSWORD}" \
        --dbhost="mariadb:3306" \
        --allow-root
fi

# 3. Lancer l'installation du site avec le premier utilisateur (ADMINISTRATEUR) si non installe
# Regle 42 : le nom de l'admin ne doit PAS contenir "admin" ou "Admin"
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

# 4. Creer le second utilisateur standard obligatoire selon le sujet 42 (si absent)
if ! wp user get "${WP_USER}" --allow-root > /dev/null 2>&1; then
    echo "[INFO] Creation du second utilisateur standard (${WP_USER})..."
    wp user create \
        "${WP_USER}" \
        "${WP_USER_EMAIL}" \
        --role=author \
        --user_pass="${WP_USER_PASSWORD}" \
        --allow-root
    echo "[INFO] WordPress installe avec succes avec 2 utilisateurs !"
else
    echo "[INFO] Le second utilisateur (${WP_USER}) existe deja."
fi

echo "[INFO] Configuration de WordPress terminee avec succes !"

# ==============================================================================
# ETAPE 4 : ASSIGNER LES PERMISSIONS A WWW-DATA
# ==============================================================================
chown -R www-data:www-data /var/www/html

# ==============================================================================
# ETAPE 5 : LANCER PHP-FPM EN PID 1 (PREMIER PLAN)
# ==============================================================================
mkdir -p /run/php
echo "[INFO] Demarrage de PHP-FPM au premier plan (PID 1)..."
exec php-fpm8.2 -F
