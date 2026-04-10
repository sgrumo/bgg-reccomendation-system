.PHONY: up down dev-api dev-recommender test

up:
	docker compose up -d

down:
	docker compose down

env-import:
	export $$(grep -v '^#' .env | xargs) 

dev-api: up
	export $$(grep -v '^#' .env | xargs) && mix setup && mix phx.server

dev-recommender: up
	cd recommender && uvicorn api:app --host 0.0.0.0 --port 8000 --reload

test: up
	mix test

checklist:
	mix format --check-formatted
	mix credo --strict
	mix compile --warning-as-errors
	mix test
