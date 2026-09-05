.PHONY: dev test lint build up down migrate deploy

# --- Local dev ---
dev:
	cd backend && python3 -m venv .venv && . .venv/bin/activate && pip install -r requirements-dev.txt

test:
	cd backend && . .venv/bin/activate && pytest tests/ -v --cov=app

lint:
	cd backend && . .venv/bin/activate && ruff check app && black --check app

# --- Docker Compose stack ---
up:
	cd infra && docker compose up --build

down:
	cd infra && docker compose down -v

migrate:
	cd backend && . .venv/bin/activate && python -m alembic upgrade head

migration:
	cd backend && . .venv/bin/activate && python -m alembic revision --autogenerate -m "$(msg)"

# --- Kubernetes ---
deploy:
	kubectl apply -f infra/k8s/00-namespace.yaml
	kubectl apply -f infra/k8s/01-configmap.yaml
	kubectl apply -f infra/k8s/03-postgres.yaml
	kubectl apply -f infra/k8s/04-redis.yaml
	kubectl apply -f infra/k8s/05-backend-deployment.yaml
	kubectl apply -f infra/k8s/06-hpa.yaml
	kubectl apply -f infra/k8s/07-ingress.yaml
	kubectl apply -f infra/k8s/08-pdb.yaml

rollback:
	kubectl rollout undo deployment/dreamcast-backend -n dreamcast

# --- Mobile ---
mobile-run:
	cd mobile && flutter pub get && flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1

mobile-release:
	cd mobile && flutter build appbundle --release --dart-define=API_BASE_URL=https://api.dreamcast.app/api/v1
