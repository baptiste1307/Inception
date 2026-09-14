# 1. IMAGE DE BASE (REGLE DU SUJET 42)
# Debian Bullseye (l'avant-dernière version stable, interdiction du tag ":latest")
FROM debian:bullseye

# 2. INSTALLATION DE NGINX ET OPENSSL
# - nginx : Le serveur web et reverse proxy
# - openssl : L'outil pour générer nos clés de chiffrement et certificats SSL
# - bash : L'interpréteur de commandes
# - rm -rf /var/lib/apt/lists/* : Nettoyage du cache APT pour alléger l'image
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    nginx \
    openssl \
    bash && \
    rm -rf /var/lib/apt/lists/*

# 3. CREATION DES DOSSIERS SYSTEME ET PERMISSIONS
RUN mkdir -p /var/www/html /etc/nginx/ssl /var/run/nginx && \
    chown -R www-data:www-data /var/www/html

# 4. INJECTION DE NOTRE CONFIGURATION NGINX
# On remplace la configuration par défaut de Debian par notre propre fichier
COPY conf/nginx.conf /etc/nginx/conf.d/default.conf

# 5. INJECTION DU SCRIPT DE DEMARRAGE
COPY tools/nginx_start.sh /usr/local/bin/nginx_start.sh
RUN chmod +x /usr/local/bin/nginx_start.sh

# 6. PORT RESEAU SECURISE (HTTPS)
# Seul le port 443 est exposé au monde extérieur
EXPOSE 443

# 7. LANCEMENT VIA L'ENTRYPOINT (PID 1)
# Exécute notre script qui génère le certificat SSL si besoin et lance NGINX au 1er plan
ENTRYPOINT ["/usr/local/bin/nginx_start.sh"]
