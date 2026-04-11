.PHONY: up down dev-api dev-recommender test prod-up prod-down prod-logs

up:
	docker compose -f infra/local/docker-compose.yml up -d

down:
	docker compose -f infra/local/docker-compose.yml down

prod-up:
	docker compose -f infra/prod/docker-compose.yml --env-file infra/prod/.env up -d --build

prod-down:
	docker compose -f infra/prod/docker-compose.yml --env-file infra/prod/.env down

prod-logs:
	docker compose -f infra/prod/docker-compose.yml --env-file infra/prod/.env logs -f

env-import:
	export $$(grep -v '^#' .env | xargs) 

dev-api: up
	export $$(grep -v '^#' .env | xargs) && mix setup && mix phx.server
	cd recommender && uvicorn api:app --host 0.0.0.0 --port 8000 --reload

dev-recommender: 
	cd recommender && uvicorn api:app --host 0.0.0.0 --port 8000 --reload

test: up
	mix test

checklist:
	mix format --check-formatted
	mix credo --strict
	mix compile --warning-as-errors
	mix test
