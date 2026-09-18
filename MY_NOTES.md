# 📘 Carnet de Bord Pédagogique — Projet Inception (42)

> _Ce document est un aide-mémoire personnel pour comprendre en profondeur l'architecture, le rôle de chaque composant et préparer les soutenances de peer-evaluation._

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

| Notion                                        | Où ça vit ?                | Ce que c'est                                                                                                     |
| :-------------------------------------------- | :------------------------- | :--------------------------------------------------------------------------------------------------------------- |
| **1. Le Dossier source** (`requirements/...`) | Sur le disque dur (Git)    | La **recette de cuisine** (`Dockerfile`, configs, scripts).                                                      |
| **2. L'Image Docker**                         | Dans le cache local Docker | Le **paquet compilé prêt à l'emploi** (généré par `docker compose build`).                                       |
| **3. Le Conteneur Docker**                    | En mémoire RAM             | Le **processus vivant qui tourne** (créé par `docker compose up`, celui qui apparaît quand on tape `docker ps`). |

---

### ⏱️ Que se passe-t-il EXACTEMENT lors de `docker compose up` ?

Voici la chronologie précise, milliseconde par milliseconde, quand vous tapez `make` ou `docker compose up` :

```
1. VERIFICATION & CREATION DES RESSOURCES EXTERNES :
   - Docker crée le réseau virtuel privé "inception-network" (bridge).
   - Docker branche les 2 volumes persistants sur l'hôte (/home/bpasquer/data/...).
   - Docker charge les fichiers de mots de passe (secrets) depuis ../secrets/.

2. CREATION DES 3 CONTENEURS EN RAM (Processus isolés) :
   - Conteneur "mariadb"
   - Conteneur "wordpress"
   - Conteneur "nginx" (qui lie le port 443 de votre machine au conteneur)

3. INJECTION DES SECRETS & VOLUMES DANS CHAQUE CONTENEUR :
   - Dans MariaDB : /var/lib/mysql est branché sur le volume + /run/secrets/ est injecté.
   - Dans WordPress : /var/www/html est branché sur le volume + /run/secrets/ est injecté.
   - Dans NGINX : /var/www/html est branché en lecture seule (:ro).

4. EXECUTION DES ENTRYPOINTS (Les scripts se lancent en parallèle) :
   - [MariaDB - init_db.sh] :
     -> Lit /run/secrets/db_password et db_root_password.
     -> Initialise les tables système (mariadb-install-db) si vierge.
     -> Crée la base WordPress et l'utilisateur 'wpuser'@'%' avec --bootstrap.
     -> Fait "exec mariadbd" : MariaDB devient le PID 1 et écoute sur le port 3306.

   - [WordPress - wp_init.sh] :
     -> Fait une boucle "until mariadb-admin ping" pour attendre que MariaDB soit réveillé.
     -> Dès que MariaDB répond : télécharge WordPress, génère wp-config.php.
     -> Installe WordPress avec l'admin (chief_bpasquer) et le 2ème user (student).
     -> Fait "exec php-fpm8.2 -F" : PHP-FPM devient le PID 1 et écoute sur le port 9000.

   - [NGINX - nginx_start.sh] :
     -> Vérifie si le certificat SSL existe (sinon le génère avec OpenSSL).
     -> Fait "exec nginx -g 'daemon off;'" : NGINX devient le PID 1 et écoute sur le port 443.

5. INFRASTRUCTURE PRETE ET EN ATTENTE (24h/24) :
   - Les 3 PID 1 tournent en RAM. Dès qu'un client arrive sur https://bpasquer.42.fr, NGINX répond !
```

---

## 🔒 3. Sécurité & Bonnes Pratiques Web : Les Réponses Clés

### A. Si j'éteins mon ordinateur, le site est-il coupé ?

- **Sur votre machine de test** : Oui, car c'est votre propre ordinateur qui joue le rôle de serveur. Si vous l'éteignez ou faites `docker compose down`, les conteneurs en RAM s'arrêtent.
- **En Production réelle** : On installe ce projet sur un serveur dédié (VPS dans un datacenter comme AWS, OVH ou Hetzner) qui reste alimenté et connecté à Internet 24h/24, 7j/7.

### B. Est-ce que mes mots de passe peuvent fuiter sur GitHub ?

- **Non, grâce à `.gitignore`** : Tout dossier ou fichier mentionné dans `.gitignore` (comme `secrets/` et `srcs/.env`) est ignoré par Git.
- Quand vous faites `git push`, ces fichiers ne quittent jamais votre disque dur physique. Sur le dépôt GitHub public, personne ne peut les voir.

### C. Avec l'inspecteur du navigateur (F12), peut-on voir mes mots de passe ou mes fichiers secrets ?

- **JAMAIS** : Il faut distinguer :
  1. **Le Côté Client (Front-end / Navigateur)** : L'inspecteur F12 ne voit que ce que NGINX a renvoyé (du simple HTML, CSS et JavaScript public).
  2. **Le Côté Serveur (Back-end / Conteneurs)** : Le code PHP, la base MariaDB et les fichiers dans `/run/secrets/` ne sont jamais envoyés au navigateur. Ils restent hermétiquement isolés sur le serveur.

---

## 💼 4. Pourquoi les Entreprises utilisent Docker vs Supabase / Cloud Géré

| Critère                           | Supabase (Cloud Géré / BaaS)                                     | Docker (Self-Hosted / Entreprise)                                                       |
| :-------------------------------- | :--------------------------------------------------------------- | :-------------------------------------------------------------------------------------- |
| **Vendor Lock-in (Dépendance)**   | Risque de dépendance si les tarifs ou règles changent.           | **Indépendance totale** : déplaçable sur n'importe quel hébergeur en 5 minutes.         |
| **Diversité des technologies**    | Limité à PostgreSQL et fonctions JavaScript/Edge.                | **N'importe quel programme** (IA en Python, C++, Rust, streaming vidéo Netflix, Kafka). |
| **Lois & Confidentialité (RGPD)** | Données stockées chez un tiers américain.                        | **Hébergement 100% privé** obligatoire pour banques, hôpitaux et gouvernements.         |
| **Coût à grande échelle**         | Très rentable au début, mais cher à des millions d'utilisateurs. | **Ultra économique à très grand volume** sur serveurs dédiés.                           |

### 🔄 Est-ce facile de passer de Supabase à Docker plus tard ?

**OUI, très facile !**
Supabase est basé sur **PostgreSQL standard** et est lui-même open-source. À tout moment :

1. Vous pouvez faire un export complet de votre base de données Supabase avec la commande standard `pg_dump`.
2. Vous pouvez réimporter ce fichier dans votre propre conteneur Docker PostgreSQL sur votre propre serveur.
3. Vous pouvez même faire tourner la suite Supabase complète directement dans vos propres conteneurs Docker (_Supabase Self-Hosted_) !

### 🤖 Peut-on implémenter un Agent IA avec Supabase ?

**OUI, et c'est même l'un des meilleurs outils pour cela !**

- **Extension `pgvector` intégrée** : Supabase supporte nativement le stockage et la recherche de vecteurs (embeddings), indispensable pour la mémoire des agents IA et le RAG (_Retrieval-Augmented Generation_).
- **Edge Functions** : Vous pouvez appeler des modèles de langage (LLM comme OpenAI GPT-4, Google Gemini ou Claude) directement depuis des fonctions Supabase pour exécuter la logique de votre agent IA sans avoir à gérer de serveurs complexes.

---

## 🛡️ 5. Réseau & NGINX (La Porte d'Entrée Sécurisée)

### A. HTTP (Port 80) vs HTTPS (Port 443)

- **Port 80 (HTTP en clair)** : Les données (mots de passe, cookies) circulent non chiffrées sur le réseau. N'importe qui sur le même Wi-Fi peut les intercepter (attaque _Man-in-the-Middle_).
- **Port 443 (HTTPS chiffré)** : Les données sont chiffrées par un tunnel cryptographique SSL/TLS. Les intercepteurs ne voient que du bruit illisible.

### B. Protocoles TLSv1.2 et TLSv1.3

- **TLS (Transport Layer Security)** : C'est le protocole mathématique moderne qui remplace l'ancien nom **SSL**.
- **Pourquoi TLS 1.2 / 1.3 uniquement ?** : Les anciennes versions (SSLv2, SSLv3, TLS 1.0, TLS 1.1) contiennent des failles de sécurité cryptographiques prouvées (_POODLE_, _BEAST_, _CRIME_). Elles sont interdites par le sujet 42.

### C. Le DNS Interne de Docker (Service Discovery)

- Dans `conf/nginx.conf`, la ligne `fastcgi_pass wordpress:9000;` fonctionne sans avoir besoin d'écrire une adresse IP.
- Docker intègre un **serveur DNS interne** (`127.0.0.11`) qui traduit automatiquement le nom du conteneur `wordpress` en son IP virtuelle sur le réseau `inception-network`.

---

## 🗄️ 6. Conteneur 1 : MariaDB

### A. Les 3 fichiers clés :

1. **`conf/50-server.cnf`** :
   - Change `bind-address = 127.0.0.1` (écoute interne seulement) en `bind-address = 0.0.0.0` pour que MariaDB écoute sur le port 3306 et accepte les connexions venant du conteneur WordPress.
2. **`Dockerfile`** :
   - Base `debian:bookworm` (Debian 12 = l'avant-dernière version stable, car Debian 13 "Trixie" est la stable actuelle depuis août 2025 ; pas de `:latest`).
   - Installe `mariadb-server` et copie les fichiers de config et d'init.
3. **`tools/init_db.sh`** :
   - Récupère les mots de passe secrets dans `/run/secrets/`.
   - Utilise `mariadbd --bootstrap` au 1er allumage pour créer la base et les utilisateurs sans ouvrir de port réseau.
   - Crée l'utilisateur avec `'wpuser'@'%'` (`%` = autorise la connexion depuis n'importe quelle adresse IP du réseau Docker).
   - Termine par `exec mariadbd --user=mysql --console` (**PID 1** au premier plan, pas de `tail -f`).

### B. La notion d'Idempotence

- **Définition** : Un script est **idempotent** si l'exécuter 1 fois ou 100 fois produit le même résultat sans provoquer d'erreur.
- **Analogie** : Le bouton du 3ème étage dans un ascenseur.
- **Application** : Le test `if [ ! -d "/var/lib/mysql/$MYSQL_DATABASE" ]` évite de tenter de recréer la base de données si le conteneur redémarre.

---

## 📝 7. Conteneur 2 : WordPress + PHP-FPM

### Pourquoi PHP-FPM ?

- Un navigateur ne comprend que le HTML/CSS/JS.
- NGINX ne sait pas exécuter le PHP : s'il le renvoyait brut, le visiteur verrait le code source du site.
- PHP-FPM est le moteur qui prend le code PHP, va chercher les infos dans MariaDB, et génère le HTML final.

### Les 3 fichiers clés :

1. **`conf/www.conf`** :
   - Remplace la socket locale Unix par `listen = 0.0.0.0:9000` (port FastCGI standard pour que NGINX puisse lui parler).
   - Définit `clear_env = no` pour que PHP ait accès aux variables d'environnement.
2. **`Dockerfile`** :
   - Installe `php8.2-fpm`, `php8.2-mysql` (Debian 12 fournit PHP 8.2), `mariadb-client` et **WP-CLI** (l'outil en ligne de commande officiel de WordPress).
3. **`tools/wp_init.sh`** :
   - Attend que MariaDB soit réveillé via une boucle `until mariadb-admin ping`.
   - Utilise **WP-CLI** pour automatiser l'installation sans souris ni navigateur : `wp core download`, `wp config create`, `wp core install`.
   - **Règle 42 stricte** : Crée l'admin dont le pseudo **ne contient PAS** le mot "admin/Admin/administrator" (`chief_bpasquer`) + crée un 2ème utilisateur standard (`student`).
   - Lance PHP-FPM au premier plan via `exec php-fpm8.2 -F` (**PID 1**).

---

## 🎯 8. Questions Types en Soutenance 42

#### Q1 : Pourquoi as-tu créé un réseau Docker personnalisé ?

> _« Pour que mes conteneurs puissent communiquer entre eux par leur nom d'hôte (`mariadb`, `wordpress`) de manière totalement isolée et sécurisée, sans exposer les ports 3306 et 9000 sur Internet. Seul le port 443 de NGINX est exposé. »_

#### Q2 : C'est quoi le PID 1 et pourquoi `tail -f` est interdit ?

> _« Le PID 1 est le processus principal qui contrôle la vie du conteneur. Si on utilise `tail -f`, le conteneur reste allumé pour rien même si le service plante, et Docker ne peut pas lui envoyer proprement les signaux d'arrêt (`SIGTERM`). En utilisant `exec` ou `daemon off;`, notre service (MariaDB, PHP-FPM ou NGINX) devient lui-même le PID 1. »_

#### Q3 : Où sont stockés tes mots de passe ?

> _« Ils ne sont jamais écrits en dur dans le code ni sur Git. Ils sont gérés via les Docker Secrets, stockés localement dans `secrets/` (ignoré par Git) et montés de façon sécurisée dans `/run/secrets/` au démarrage du conteneur. »_

#### Q4 : Que se passe-t-il si je supprime tous les conteneurs avec `docker compose down` ?

> _« Les processus s'arrêtent et les conteneurs disparaissent, mais les données du site et de la base SQL sont préservées intactes car elles sont stockées sur les volumes persistants dans `/home/bpasquer/data/`. »_

#### Q5 : Pourquoi NGINX utilise TLSv1.2 et TLSv1.3 ?

> _« Parce que ce sont les protocoles de chiffrement modernes recommandés par les standards de sécurité actuels. Les versions antérieures (SSLv2, SSLv3, TLS 1.0, TLS 1.1) contiennent des failles de sécurité cryptographiques connues (comme POODLE ou BEAST) et sont interdites par le sujet. »_

#### Q6 : Qu'est-ce que le mode `--bootstrap` de MariaDB ?

> _« C'est une commande interne qui permet d'exécuter des requêtes SQL d'initialisation directement sur les fichiers de la base sans ouvrir de port réseau ni lancer de serveur en arrière-plan. C'est rapide, propre et sécurisé au premier démarrage. »_

---

## 📦 9. Docker Compose : Volumes Nommés & Réseau Bridge

### A. Named Volumes vs Bind Mounts

- **Bind Mount direct** : Lien direct entre un chemin de l'hôte et le conteneur. Non géré par le cycle de vie Docker.
- **Named Volume avec driver local (Exigé par 42)** : Déclaré dans la section `volumes:` avec un nom officiel (`wp_data`, `db_data`) et des options de driver (`type: none`, `o: bind`, `device: /home/bpasquer/data/...`). Il est visible dans `docker volume ls` et géré proprement par Docker Compose.

### B. Le Réseau Bridge (`driver: bridge`)

- C'est un **mini-routeur virtuel privé** créé par Docker.
- Il permet la communication interne sécurisée entre conteneurs (via leurs adresses IP privées 172.18.X.X et leurs noms d'hôtes).
- Il isole hermétiquement les services d'Internet : seuls les ports explicitement publiés avec `ports:` (port 443 de NGINX) sont accessibles de l'extérieur.

---

## 🎬 10. Pourquoi ce projet s'appelle "Inception" ?

Le nom est un clin d'œil direct au célèbre film **Inception** de Christopher Nolan (_« un rêve dans un rêve dans un rêve »_) :

```
[ Votre Ordinateur Physique (Mac / PC de 42) ]
              │
              ▼
    [ Machine Virtuelle (Linux Debian) ]  <-- Niveau 1 de virtualisation
              │
              ▼
        [ Moteur Docker Engine ]          <-- Niveau 2 d'isolation
              │
              ▼
      [ Conteneurs Virtuels ]             <-- Niveau 3 (NGINX, WordPress, MariaDB)
```

C'est de la **virtualisation imbriquée dans de la virtualisation** !

---

## 💡 11. Résumé Ultime sur `--bootstrap` (MariaDB)

- **Sans `--bootstrap` (la méthode galère)** :
  1. Le script devrait démarrer MariaDB en tâche de fond (`service mysql start`).
  2. Attendre 3-4 secondes avec un `sleep` que le port réseau s'ouvre.
  3. Se connecter avec un client pour exécuter les requêtes SQL de création d'utilisateurs.
  4. Éteindre le serveur en tâche de fond.
  5. Relancer MariaDB au premier plan en PID 1.
- **Avec `--bootstrap` (notre méthode propre)** :
  - MariaDB lit les requêtes SQL et les grave **directement dans les fichiers physiques du disque dur**, hors-ligne, sans allumer de réseau ni de serveur.
  - C'est instantané (0.5 seconde) et 100% sécurisé au premier démarrage !
