# On utilise l'avant-dernière version stable de Debian (Bullseye).
FROM debian:bullseye

# 2. INSTALLATION DES PAQUETS SYSTEME ET PHP
# - php7.4-fpm : Le gestionnaire de processus FastCGI qui exécute le code PHP
# - php7.4-mysql : L'extension PHP pour communiquer avec MariaDB
# - mariadb-client : Permet de tester la connexion à la base de données avant d'installer
# - curl & ca-certificates : Pour télécharger WP-CLI de manière sécurisée en HTTPS
# - bash : Le shell standard
# - rm -rf /var/lib/apt/lists/* : Supprime le cache APT pour garder l'image légère
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    php7.4-fpm \
    php7.4-mysql \
    mariadb-client \
    curl \
    ca-certificates \
    bash && \
    rm -rf /var/lib/apt/lists/*

# 3. INSTALLATION DE WP-CLI (WordPress Command Line Interface)
# Cet outil officiel permet d'installer et configurer WordPress en ligne de commande
# sans avoir besoin d'ouvrir un navigateur web et de cliquer partout.
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

# 4. CREATION DES DOSSIERS OBLIGATOIRES
# - /run/php : Dossier nécessaire à PHP-FPM pour stocker son fichier PID
# - /var/www/html : Le dossier où vivra le site WordPress (monté sur le volume persistant)
# On donne la propriété à www-data (l'utilisateur web standard).
RUN mkdir -p /run/php /var/www/html && \
    chown -R www-data:www-data /var/www/html

# 5. INJECTION DE NOTRE CONFIGURATION RESEAU
# Remplace la configuration par défaut pour écouter sur le port TCP 9000 (0.0.0.0:9000)
COPY conf/www.conf /etc/php/7.4/fpm/pool.d/www.conf

# 6. INJECTION ET PERMISSION DU SCRIPT D'INITIALISATION
COPY tools/wp_init.sh /usr/local/bin/wp_init.sh
RUN chmod +x /usr/local/bin/wp_init.sh

# 7. DOSSIER DE TRAVAIL PAR DEFAUT
# Toutes les commandes futures s'exécuteront directement dans le dossier du site
WORKDIR /var/www/html

# 8. PORT FASTCGI EXPOSE
# Le port 9000 est le port standard de PHP-FPM pour recevoir les requêtes de NGINX
EXPOSE 9000

# 9. COMMANDE DE DEMARRAGE DU CONTENEUR (RUN-TIME)
# Lance le script qui télécharge WordPress, configure les users, et lance PHP-FPM en PID 1
ENTRYPOINT ["/usr/local/bin/wp_init.sh"]
