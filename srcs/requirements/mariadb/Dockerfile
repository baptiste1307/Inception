# 1- avant dernière version stable de Debian
FROM debian:bullseye

# 2- installation des paquets
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    mariadb-server \
    mariadb-client \
    bash && \
    rm -rf /var/lib/apt/lists/*

# 3- préparation des dossiers système
RUN mkdir -p /run/mysqld /var/lib/mysql && \
    chown -R mysql:mysql /run/mysqld /var/lib/mysql


# 4- injection de mon fichier de config pour remplacer la config d'origine  
# --> permet à mariaDB d'écouter les requetes partout et pas juste sur 127.0.0.1
COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf

# 5- injection de mon script d'init. --> script qui gère le premier démarrage
# (je lui donne les droits d'exec)
COPY tools/init_db.sh /usr/local/bin/init_db.sh
RUN chmod +x /usr/local/bin/init_db.sh

# 6- j'expose le port 3306. 
# En gros, ce conteneur à vocation à écouter le port MySQL 3306
EXPOSE 3306

# 7- J'indique la commande à éxécuter au démarrage du conteneur
ENTRYPOINT ["/usr/local/bin/init_db.sh"]