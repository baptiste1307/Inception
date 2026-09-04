#!/bin/bash

# "set -e" : si une commande rate, arrête tout immédiatement !
set -e

# ==============================================================================
# ETAPE 1 : RECUPERER LES MOTS DE PASSE SECRETS
# ==============================================================================
# 1. Mot de passe de la base de données (pour que WordPress puisse se connecter à MariaDB)
if [ -f "/run/secrets/db_password" ]; then
    DB_PASSWORD=$(cat /run/secrets/db_password)
fi

# 2. Mots de passe des utilisateurs WordPress (déposés dans le fichier secret credentials)
if [ -f "/run/secrets/credentials" ]; then
    WP_ADMIN_PASSWORD=$(grep '^WP_ADMIN_PASSWORD=' /run/secrets/credentials | cut -d '=' -f2-)
    WP_USER_PASSWORD=$(grep '^WP_USER_PASSWORD=' /run/secrets/credentials | cut -d '=' -f2-)
fi

# ==============================================================================
# ETAPE 2 : ATTENDRE QUE MARIADB SOIT REVEILLE
# ==============================================================================
# Au démarrage, WordPress et MariaDB s'allument en même temps.
# MariaDB met quelques secondes à s'initialiser. On envoie un "ping" toutes les 2 secondes
# jusqu'à ce que MariaDB réponde : "C'est bon, je suis prêt !".

echo "[INFO] Vérification de la connexion à MariaDB..."
until mariadb-admin --host=mariadb --user="${MYSQL_USER}" --password="${DB_PASSWORD}" ping --silent; do
    echo "[INFO] MariaDB n'est pas encore prêt... On attend 2 secondes..."
    sleep 2
done
echo "[INFO] MariaDB est prêt et joignable !"

# ==============================================================================
# ETAPE 3 : INSTALLER WORDPRESS (SEULEMENT AU TOUT PREMIER DEMARRAGE)
# ==============================================================================
# Si le fichier "wp-config.php" existe déjà, c'est que le site a déjà été installé.
# On ne touche à rien pour préserver les articles et réglages existants !

if [ ! -f "/var/www/html/wp-config.php" ]; then
    echo "[INFO] Premier démarrage : Installation de WordPress en cours..."

    # 1. Télécharger les fichiers sources officiels de WordPress
    wp core download --allow-root

    # 2. Créer le fichier wp-config.php (qui contient l'adresse et le mot de passe de MariaDB)
    # Note : "--dbhost=mariadb:3306" utilise le nom du conteneur MariaDB sur le réseau Docker !
    wp config create \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${DB_PASSWORD}" \
        --dbhost="mariadb:3306" \
        --allow-root

    # 3. Lancer l'installation du site avec le premier utilisateur (ADMINISTRATEUR)
    # ATTENTION REGLE 42 : le nom de l'admin ne doit PAS contenir "admin" ou "Admin"
    wp core install \
        --url="https://${DOMAIN_NAME}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email \
        --allow-root

    # 4. Créer le SECOND utilisateur obligatoire selon le sujet 42
    wp user create \
        "${WP_USER}" \
        "${WP_USER_EMAIL}" \
        --role=author \
        --user_pass="${WP_USER_PASSWORD}" \
        --allow-root

    echo "[INFO] WordPress installé avec succès avec 2 utilisateurs !"
else
    echo "[INFO] WordPress est déjà installé, pas besoin de réinstaller."
fi

# ==============================================================================
# ETAPE 4 : DONNER LES BONS DROITS A L'UTILISATEUR WEB
# ==============================================================================
# On s'assure que www-data peut lire et écrire dans le dossier pour uploader des images
chown -R www-data:www-data /var/www/html

# ==============================================================================
# ETAPE 5 : LANCER PHP-FPM EN PID 1 (PREMIER PLAN)
# ==============================================================================
# L'option "-F" (Foreground) est capitale : elle empêche PHP-FPM de passer en arrière-plan.
# "exec" remplace notre script bash par PHP-FPM pour qu'il devienne le PID 1 propre.
echo "[INFO] Démarrage de PHP-FPM au premier plan (PID 1)..."
exec php-fpm7.4 -F
