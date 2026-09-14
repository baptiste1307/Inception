#!/bin/bash

# "set -e" : arrêt immédiat du script en cas d'erreur
set -e

# ==============================================================================
# ETAPE 1 : GENERER LE CERTIFICAT SSL/TLS S'IL N'EXISTE PAS ENCORE
# ==============================================================================
# Un certificat SSL permet au navigateur d'établir une connexion chiffrée en HTTPS (Port 443).
# On vérifie si la clé privée et le certificat existent déjà dans /etc/nginx/ssl/.
# Si non, on les fabrique avec l'outil officiel OpenSSL.

if [ ! -f "/etc/nginx/ssl/inception.crt" ]; then
    echo "[INFO] Génération du certificat SSL auto-signé pour bpasquer.42.fr..."
    mkdir -p /etc/nginx/ssl

    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/inception.key \
        -out /etc/nginx/ssl/inception.crt \
        -subj "/C=FR/ST=IDF/L=Paris/O=42/OU=42/CN=bpasquer.42.fr/UID=bpasquer"

    echo "[INFO] Certificat SSL généré avec succès !"
fi

# ==============================================================================
# ETAPE 2 : LANCER NGINX EN PID 1 (PREMIER PLAN)
# ==============================================================================
# "daemon off;" empêche NGINX de se détacher en tâche de fond.
# "exec" remplace notre script bash par NGINX pour qu'il devienne le vrai PID 1 du conteneur.
# Pas de triche de type "tail -f" !
echo "[INFO] Démarrage de NGINX en avant-plan (PID 1)..."
exec nginx -g "daemon off;"
