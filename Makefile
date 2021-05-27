# This Makefile is designed to be included by another Makefile located in your project directory.
# ==> https://github.com/EmakinaFR/docker-magento2/wiki/Makefile

SHELL := /bin/bash
PHP_SERVICE := docker-compose exec -u www-data:www-data php sh -c

# Define a dynamic project name that will be prepended to each service name
export COMPOSE_PROJECT_NAME := magento2_$(shell echo $${PWD\#\#*/} | tr '[:upper:]' '[:lower:]')

# Extract environment variables needed by the environment
export PROJECT_LOCATION := $(shell echo ${MAKEFILE_DIRECTORY})
export DOCKER_PHP_IMAGE := $(shell grep DOCKER_PHP_IMAGE ${MAKEFILE_DIRECTORY}docker/local/.env | awk -F '=' '{print $$NF}')
export DOCKER_MYSQL_IMAGE := $(shell grep DOCKER_MYSQL_IMAGE ${MAKEFILE_DIRECTORY}docker/local/.env | awk -F '=' '{print $$NF}')

##
## ----------------------------------------------------------------------------
##   Environment
## ----------------------------------------------------------------------------
##

backup: ## Backup the "mysql" volume
	docker run --rm \
		--volumes-from $$(docker-compose ps -q mysql) \
		--volume $$(pwd):/backup \
		busybox sh -c "tar cvf /backup/backup.tar /var/lib/mysql"

build: ## Build the environment
	docker-compose build --pull

cache: ## Flush cache stored in Redis
	docker-compose exec redis sh -c "redis-cli -n 1 FLUSHDB"
	docker-compose exec redis sh -c "redis-cli -n 2 FLUSHDB"

composer: ## Install Composer dependencies from the "php" container
	$(PHP_SERVICE) "composer install --optimize-autoloader --prefer-dist --working-dir=/var/www/html"

logs: ## Follow logs generated by all containers
	docker-compose logs -f --tail=0

logs-full: ## Follow logs generated by all containers from the containers creation
	docker-compose logs -f

mysql: ## Open a terminal in the "mysql" container
	docker-compose exec mysql sh

nginx: ## Open a terminal in the "nginx" container
	docker-compose exec -u nginx:nginx nginx sh -l

php: ## Open a terminal in the "php" container
	docker-compose exec -u www-data:www-data php sh -l

ps: ## List all containers managed by the environment
	docker-compose ps

purge: ## Purge all services, associated volumes and the Mutagen session
	docker-compose down --volumes
	mutagen sync terminate --label-selector='name==${COMPOSE_PROJECT_NAME}'

restart: stop start ## Restart the environment

restore: ## Restore the "mysql" volume
	docker run --rm \
		--volumes-from $$(docker-compose ps -q mysql) \
		--volume $$(pwd):/backup \
		busybox sh -c "tar xvf /backup/backup.tar var/lib/mysql/"
	docker-compose restart mysql

root: ## Display the commands to set up the environment for an advanced usage
	@echo "export COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME}"
	@echo "export COMPOSE_FILE=${COMPOSE_FILE}"
	@echo "export PROJECT_LOCATION=${PROJECT_LOCATION}"
	@echo "export DOCKER_PHP_IMAGE=${DOCKER_PHP_IMAGE}"
	@echo "export DOCKER_MYSQL_IMAGE=${DOCKER_MYSQL_IMAGE}"
	@echo ""
	@echo "# Run this command to configure your shell:"
	@echo "# eval \$$(make root)"

start: ## Start the environment
	@docker-compose up --detach --remove-orphans

	@if [[ ! "$$(mutagen sync list --label-selector='name==${COMPOSE_PROJECT_NAME}')" =~ "${COMPOSE_PROJECT_NAME}" ]]; then \
		mutagen sync create \
			--label=name="${COMPOSE_PROJECT_NAME}" \
			--default-owner-beta="id:1000" \
			--default-group-beta="id:1000" \
			--sync-mode="two-way-resolved" \
			--ignore-vcs --ignore=".idea" --ignore="pub/static" \
			--symlink-mode="posix-raw" \
		"${PROJECT_LOCATION}" "docker://${COMPOSE_PROJECT_NAME}_synchro/var/www/html/"; \
	else \
		mutagen sync resume --label-selector='name==${COMPOSE_PROJECT_NAME}'; \
	fi

	@while [[ ! "$$(mutagen sync list --label-selector='name==${COMPOSE_PROJECT_NAME}')" =~ "Status: Watching for changes" ]]; do \
		echo "Waiting for synchronization to complete..."; \
		sleep 10; \
	done

stats: ## Print real-time statistics about containers ressources usage
	docker stats $(docker ps --format={{.Names}})

stop: ## Stop the environment
	@docker-compose stop
	@mutagen sync pause --label-selector='name==${COMPOSE_PROJECT_NAME}'

yarn: ## Install Composer dependencies from the "php" container
	$(PHP_SERVICE) "yarn install --cwd=/var/www/html"

.PHONY: backup build cache composer logs logs-full mysql nginx php ps purge restart restore root start stats stop yarn

.DEFAULT_GOAL := help
help:
	@grep -E '(^[a-zA-Z_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) \
		| sed -e 's/^.*Makefile://g' \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' \
		| sed -e 's/\[32m##/[33m/'
.PHONY: help
