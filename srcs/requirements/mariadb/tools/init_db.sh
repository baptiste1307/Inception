#!/bin/bash

# si une commande rate, code d'erreur != 0 puis stop 
set -e

# 1 : ALLER CHERCHER LES MOTS DE PASSE SECRETS
# Docker a posé nos mots de passe secrets dans des fichiers texte dans /run/secrets/.
# On ouvre ces fichiers pour lire ce qu'il y a dedans et le mettre dans des variables.

if [ -f "/run/secrets/db_password" ]; then
    # On lit le mot de passe de l'utilisateur WordPress
    DB_PASSWORD=$(cat /run/secrets/db_password)
fi

if [ -f "/run/secrets/db_root_password" ]; then
    # On lit le mot de passe du root de la base de données
    DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
fi

# Si un des mots de passe ou un nom manque --> erreur et stop
if [ -z "$MYSQL_DATABASE" ] || [ -z "$MYSQL_USER" ] || [ -z "$DB_PASSWORD" ] || [ -z "$DB_ROOT_PASSWORD" ]; then
    echo "[ERREUR] Il manque des informations ou des mots de passe pour MariaDB !"
    exit 1
fi

# 2 : préparer le dossier systeme pour noter les secrets
# Au tout premier démarrage, le dossier /var/lib/mysql est vide.
# Si ce dossier système n'existe pas encore, on demande à MariaDB de le préparer.

if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "[INFO] Premier allumage : installation des fichiers système de MariaDB..."
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql > /dev/null
fi

# 3 : CREER LA BASE DE DONNEES ET LES UTILISATEURS
# On vérifie si la base WordPress existe déjà.
# Si le dossier /var/lib/mysql/NOM_DE_LA_BASE n'existe pas, c'est que c'est la toute
# première fois qu'on allume la machine. Donc on doit créer la base et donner les clés.
# Si elle existe déjà (par exemple si on a redémarré le conteneur hier), ON NE TOUCHE A RIEN !

if [ ! -d "/var/lib/mysql/$MYSQL_DATABASE" ]; then
    echo "[INFO] Création de la base de données '$MYSQL_DATABASE' et des utilisateurs..."

    # "mariadbd --bootstrap" permet d'exécuter des ordres SQL en silence,
    # directement sur les fichiers, sans ouvrir le réseau.
    mariadbd --user=mysql --bootstrap << SQL_EOF
-- 1. On recharge les tables de droits pour être sûr de partir sur du propre
FLUSH PRIVILEGES;

-- 2. On donne un mot de passe solide au compte "root"
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';

-- 3. On crée la base de données pour WordPress si elle n'existe pas
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;

-- 4. On crée le compte pour WordPress.
-- '%' = cet utilisateur a le droit
-- de se connecter depuis une AUTRE machine (le conteneur WordPress).
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';

-- 5. On donne TOUS les droits à cet utilisateur UNIQUEMENT sur la base WordPress
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';

-- 6. On valide et on enregistre tous ces changements
FLUSH PRIVILEGES;
SQL_EOF

    echo "[INFO] Base de données prête et sécurisée !"
fi

# ETAPE 4 : ALLUMER LE SERVEUR POUR DE VRAI (LE PID 1)
# "exec" remplace notre script bash par le vrai programme "mariadbd".
# Du coup, MariaDB devient le PID 1 (comme ça si ca plante ou erreur, le conteneur s'arrete),
# écoute les demandes sur le port 3306,
# et affiche tout ce qui se passe sur l'écran (--console).

echo "[INFO] Lancement de MariaDB en avant-plan..."
exec mariadbd --user=mysql --console
