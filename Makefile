# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Makefile                                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: bpasquer <bpasquer@student.42.fr>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2026/09/02 15:30:00 by bpasquer          #+#    #+#              #
#    Updated: 2026/09/04 14:00:00 by bpasquer         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

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
BLUE			= \033[0;34m
RESET			= \033[0m

# ==============================================================================
# REGLES PRINCIPALES
# ==============================================================================

all: build up
	@echo "$(GREEN)[SUCCESS] Infrastructure Inception démarrée avec succès !$(RESET)"
	@echo "$(BLUE)[INFO] Accédez au site sur : https://bpasquer.42.fr$(RESET)"

init:
	@echo "$(YELLOW)[INFO] Création des répertoires de données persistantes sur l'hôte...$(RESET)"
	@mkdir -p $(WP_DATA) $(DB_DATA) 2>/dev/null || true

build: init
	@echo "$(YELLOW)[INFO] Construction des images Docker (Debian Bullseye)...$(RESET)"
	@$(COMPOSE) build

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
	@echo "$(BLUE)=== ÉTAT DES CONTENEURS ===$(RESET)"
	@$(COMPOSE) ps
	@echo "\n$(BLUE)=== VOLUMES DOCKER ===$(RESET)"
	@docker volume ls | grep -E "NAME|wp_data|db_data" || true
	@echo "\n$(BLUE)=== RESEAUX DOCKER ===$(RESET)"
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
	@echo "$(RED)[WARNING] Suppression des dossiers de données /home/bpasquer/data...$(RESET)"
	@rm -rf $(WP_DATA) $(DB_DATA) 2>/dev/null || true
	@echo "$(GREEN)[SUCCESS] Environnement totalement réinitialisé.$(RESET)"

re: fclean all

.PHONY: all init build up down stop start status logs clean fclean re
