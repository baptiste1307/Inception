NAME			= inception
COMPOSE_FILE	= srcs/docker-compose.yml
COMPOSE			= docker compose -f $(COMPOSE_FILE)

# Chemins des données persistantes sur l'hôte Linux 42
DATA_DIR		= /home/bpasquer/data
WP_DATA			= $(DATA_DIR)/wordpress
DB_DATA			= $(DATA_DIR)/mariadb

# Couleurs pour l'affichage
GREEN			= \033[0;32m
YELLOW			= \033[0;33m
RED				= \033[0;31m
ORANGE			= \033[38;5;208m
RESET			= \033[0m

# ==============================================================================
# REGLES PRINCIPALES
# ==============================================================================

all: build up
	@echo "$(GREEN)[SUCCESS] Infrastructure Inception démarrée avec succès !$(RESET)"
	@echo "$(ORANGE)[INFO] Accédez au site sur : https://bpasquer.42.fr$(RESET)"

init:
	@echo "$(YELLOW)[INFO] Création des répertoires de données persistantes sur l'hôte...$(RESET)"
	@mkdir -p $(WP_DATA) $(DB_DATA) 2>/dev/null || true

build: init
	@echo "$(YELLOW)[INFO] Construction des images Docker (Debian Bookworm)...$(RESET)"
	@$(COMPOSE) build

build-no-cache: init
	@echo "$(YELLOW)[INFO] Construction des images Docker SANS CACHE...$(RESET)"
	@$(COMPOSE) build --no-cache

up: init
	@echo "$(YELLOW)[INFO] Lancement des conteneurs en arrière-plan...$(RESET)"
	@$(COMPOSE) up -d

down:
	@echo "$(YELLOW)[INFO] Arrêt des conteneurs...$(RESET)"
	@$(COMPOSE) down

stop:
	@echo "$(YELLOW)[INFO] Mise en pause des conteneurs...$(RESET)"
	@$(COMPOSE) stop

start:
	@echo "$(YELLOW)[INFO] Redémarrage des conteneurs existants...$(RESET)"
	@$(COMPOSE) start

status:
	@echo "$(ORANGE)=== ÉTAT DES CONTENEURS ===$(RESET)"
	@$(COMPOSE) ps
	@echo "\n$(ORANGE)=== VOLUMES DOCKER ===$(RESET)"
	@docker volume ls | grep -E "NAME|wp_data|db_data" || true
	@echo "\n$(ORANGE)=== RESEAUX DOCKER ===$(RESET)"
	@docker network ls | grep -E "NAME|inception" || true

logs:
	@$(COMPOSE) logs -f

# ==============================================================================
# REGLES DE NETTOYAGE
# ==============================================================================

clean: down
	@echo "$(YELLOW)[INFO] Suppression des conteneurs et des images...$(RESET)"
	@$(COMPOSE) down --rmi all --remove-orphans || true

fclean:
	@echo "$(RED)[WARNING] Nettoyage complet (conteneurs, images, volumes, réseaux)...$(RESET)"
	@$(COMPOSE) down -v --rmi all --remove-orphans 2>/dev/null || true
	@docker system prune -af --volumes 2>/dev/null || true
	@echo "$(RED)[WARNING] Suppression des dossiers de données $(DATA_DIR)...$(RESET)"
	@if [ -d "$(DATA_DIR)" ]; then \
		docker run --rm -v $(DATA_DIR):/mnt debian:bookworm rm -rf /mnt/wordpress /mnt/mariadb 2>/dev/null || true; \
		rm -rf $(DATA_DIR) 2>/dev/null || true; \
	fi
	@echo "$(GREEN)[SUCCESS] Environnement totalement réinitialisé.$(RESET)"

re: fclean all

.PHONY: all init build build-no-cache up down stop start status logs clean fclean re
