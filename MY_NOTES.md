# 📘 Carnet de Bord Pédagogique — Projet Inception (42)

> *Ce document est un aide-mémoire personnel pour comprendre en profondeur l'architecture, le rôle de chaque composant et préparer les soutenances de peer-evaluation.*

---

## 🏛️ 1. L'Architecture Globale (L'Analogie du Restaurant)

Dans Inception, notre machine virtuelle Linux joue le rôle de **Serveur Web**. Le visiteur (le client) n'a rien à installer chez lui : il ouvre juste son navigateur et tape `https://bpasquer.42.fr`.

```
[ Visiteur / Client sur son navigateur ]
                  │
                  │ HTTPS (Port 443 uniquement - TLSv1.2/TLSv1.3)
                  ▼
         ┌──────────────────┐
         │  Conteneur NGINX │ (Le Serveur de salle)
         └────────┬─────────┘
                  │
                  │ FastCGI (Port TCP 9000)
                  ▼
      ┌───────────────────────┐
      │  Conteneur WordPress  │ (Le Cuisinier en cuisine : PHP-FPM)
      └──────────┬────────────┘
                 │
                 │ MySQL / SQL (Port TCP 3306)
                 ▼
         ┌──────────────────┐
         │ Conteneur MariaDB│ (Le Magasinier dans la chambre froide)
         └──────────────────┘
```

### Qui fait quoi ?
- **NGINX (Le Serveur de salle)** : Seul conteneur exposé sur Internet (port 443). Il accueille le visiteur avec un certificat de sécurité SSL/TLS, distribue les fichiers statiques (images, css) et transmet les requêtes PHP à WordPress.
- **WordPress + PHP-FPM (Le Cuisinier)** : Exécute le code source PHP. Il assemble dynamiquement les données pour fabriquer une page HTML propre prête à être affichée.
- **MariaDB (La Réserve / Chambre froide)** : Stocke les données brutes (comptes, mots de passe hachés, articles). Il est invisible depuis l'extérieur et ne répond qu'aux demandes de WordPress sur le port 3306.

---

## 🔄 2. Les 3 Concepts Fondamentaux de Docker & Cycle de Vie

| Notion | Où ça vit ? | Ce que c'est |
| :--- | :--- | :--- |
| **1. Le Dossier source** (`requirements/...`) | Sur le disque dur (Git) | La **recette de cuisine** (`Dockerfile`, configs, scripts). |
| **2. L'Image Docker** | Dans le cache local Docker | Le **paquet compilé prêt à l'emploi** (généré par `docker compose build`). |
| **3. Le Conteneur Docker** | En mémoire RAM | Le **processus vivant qui tourne** (créé par `docker compose up`, celui qui apparaît quand on tape `docker ps`). |

### 🛠️ Build Time vs Run Time (Le fonctionnement étape par étape)

#### 1. Le Build (`docker compose build`) — Étape de fabrication de l'image
- **Exécution une seule fois des étapes du Dockerfile (`FROM`, `RUN`, `COPY`)** :
- Tout est **figé dans l'image**. Le logiciel (ex: MariaDB ou PHP) est donc déjà installé et prêt sur le disque dur virtuel de l'image.
- **Les secrets (mots de passe) ne sont pas encore connus à cette étape.**

#### 2. Le Run (`docker compose up`) — Démarrage du conteneur
- L'image est **démarrée en mémoire vive (RAM)**.
- Docker monte les volumes et injecte les fichiers secrets dans `/run/secrets/`.
- Docker lance la commande de l'**`ENTRYPOINT`** (notre script `init_db.sh` ou `wp_init.sh`).
- **En gros :** l'`ENTRYPOINT` configure les **données dynamiques** (mots de passe, utilisateurs, base SQL) et lance le service au démarrage du conteneur.

### 💾 Volatilité vs Volumes Persistants
- Par défaut, un conteneur est **éphémère** : si on le supprime (`docker compose down`), tout ce qui a été écrit dedans disparaît.
- Pour ne jamais perdre les données (base de données et fichiers du site), on branche des **Volumes Docker** pointant vers `/home/bpasquer/data/` sur le disque dur réel de la machine hôte.

---

## 🗄️ 3. Conteneur 1 : MariaDB

Quand on build le dossier `mariadb/` (stocké sur disque dur), ça crée l'image MariaDB dans le cache local Docker (un paquet prêt à l'emploi).  
Puis lors du `docker compose up`, le conteneur est créé en RAM et le script configure les secrets et lance le serveur.

### Les 3 fichiers clés :
1. **`conf/50-server.cnf`** :
   - Change `bind-address = 127.0.0.1` en `bind-address = 0.0.0.0` pour que MariaDB écoute sur le port 3306 et accepte les requêtes venant du conteneur WordPress.
2. **`Dockerfile`** :
   - Base `debian:bullseye` (avant-dernière version stable, pas de `:latest`).
   - Installe `mariadb-server` et copie les fichiers de config et d'init.
3. **`tools/init_db.sh`** :
   - Récupère les mots de passe secrets dans `/run/secrets/`.
   - Utilise `mariadbd --bootstrap` au 1er allumage pour créer la base et les utilisateurs sans ouvrir de port réseau.
   - Crée l'utilisateur avec `'wpuser'@'%'` (`%` = autorise la connexion depuis le conteneur WordPress).
   - Termine par `exec mariadbd --user=mysql --console` (**PID 1** au premier plan, pas de `tail -f`).

---

## 📝 4. Conteneur 2 : WordPress + PHP-FPM

### Pourquoi PHP-FPM ?
- Un navigateur ne comprend que le HTML/CSS/JS.
- NGINX ne sait pas lire le PHP : si NGINX envoyait un fichier `.php` brut, le client verrait le code source du site (faille de sécurité majeure).
- PHP-FPM est le moteur qui prend le code PHP, va chercher les infos dans MariaDB, et génère le HTML final.

### Les 3 fichiers clés :
1. **`conf/www.conf`** :
   - Remplace la socket locale Unix par `listen = 0.0.0.0:9000` (port FastCGI standard pour que NGINX puisse lui parler).
   - Définit `clear_env = no` pour que PHP ait accès aux variables d'environnement.
2. **`Dockerfile`** :
   - Installe `php7.4-fpm`, `php7.4-mysql`, `mariadb-client` et **WP-CLI** (l'outil en ligne de commande officiel de WordPress).
3. **`tools/wp_init.sh`** :
   - Attend que MariaDB soit réveillé via une boucle `until mariadb-admin ping`.
   - Utilise `wp core download`, `wp config create`, `wp core install` pour installer le site.
   - **Règle 42 stricte** : Crée l'admin dont le pseudo **ne contient PAS** "admin/Admin" (`chief_bpasquer`) + crée un 2ème utilisateur standard (`student`).
   - Lance PHP-FPM au premier plan via `exec php-fpm7.4 -F` (**PID 1**).

---

## 🛡️ 5. Conteneur 3 : NGINX (À venir)

- **Port 443 (HTTPS) uniquement**.
- Utilise un certificat SSL auto-signé avec les protocoles sécurisés `TLSv1.2` ou `TLSv1.3`.
- Redirige toutes les requêtes de fichiers `.php` vers `wordpress:9000` via FastCGI.

---

## 🎯 6. Questions Types en Soutenance 42

#### Q1 : Pourquoi as-tu créé un réseau Docker personnalisé ?
> *« Pour que mes conteneurs puissent communiquer entre eux par leur nom d'hôte (`mariadb`, `wordpress`) de manière totalement isolée et sécurisée, sans exposer les ports 3306 et 9000 sur Internet. Seul le port 443 de NGINX est exposé. »*

#### Q2 : C'est quoi le PID 1 et pourquoi `tail -f` est interdit ?
> *« Le PID 1 est le processus principal qui contrôle la vie du conteneur. Si on utilise `tail -f`, le conteneur reste allumé pour rien même si le service plante, et Docker ne peut pas lui envoyer proprement les signaux d'arrêt (`SIGTERM`). En utilisant `exec`, notre service (MariaDB ou PHP-FPM) devient lui-même le PID 1. »*

#### Q3 : Où sont stockés tes mots de passe ?
> *« Ils ne sont jamais écrits en dur dans le code ni sur Git. Ils sont gérés via les Docker Secrets, stockés localement dans `secrets/` (ignoré par Git) et montés de façon sécurisée dans `/run/secrets/` au démarrage du conteneur. »*

#### Q4 : Que se passe-t-il si je supprime tous les conteneurs avec `docker compose down` ?
> *« Les processus s'arrêtent et les conteneurs disparaissent, mais les données du site et de la base SQL sont préservées intactes car elles sont stockées sur les volumes persistants dans `/home/bpasquer/data/`. »*
