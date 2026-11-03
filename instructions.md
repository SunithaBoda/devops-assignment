# Local container instructions

These steps run the full stack on a developer laptop: FastAPI, Celery worker, Redis, and the nginx frontend.

## Prerequisites

- Docker Desktop (or Docker Engine 24+) with Compose v2

## 1. Clone and configure

```bash
git clone <your-fork-url>
cd devops-assignment
cp .env.example .env
```

`.env` is interpolated by Compose. The default already works for local Redis:

```
REDIS_URL=redis://redis:6379/0
```

## 2. Build all images

```bash
docker compose build
```

This builds:

- `devops-assignment-backend:local` from the root `Dockerfile` (used by **backend** and **worker**)
- `devops-assignment-frontend:local` from `frontend/Dockerfile` with `nginx.conf` (proxies API paths)

## 3. Start the full stack

```bash
docker compose up -d --wait
```

`--wait` blocks until health checks pass. Expected ports:

| Service  | URL                         |
|----------|-----------------------------|
| Frontend | http://localhost:8080       |
| Backend  | http://localhost:8000       |
| API docs | http://localhost:8000/docs  |
| Redis    | localhost:6379 (debug only) |

Open **http://localhost:8080**, enter an email, and click **Send notification**. The page calls `POST /notify/` then polls `GET /task_status/{task_id}` until the worker finishes (~10 seconds).

## 4. View logs and debug

```bash
# all services
docker compose logs -f

# one service
docker compose logs -f backend
docker compose logs -f worker
docker compose logs -f redis
docker compose logs -f frontend

# last 100 lines, then follow
docker compose logs -f --tail=100 worker
```

Useful checks when something fails:

```bash
# container status and health
docker compose ps

# API liveness
curl -i http://localhost:8000/health

# enqueue a task without the UI
curl -s -X POST "http://localhost:8000/notify/?email=dev@example.com"
# {"message":"Email will be sent to dev@example.com","task_id":"..."}

# poll that task
curl -s http://localhost:8000/task_status/<task_id>

# Redis connectivity from the backend container
docker compose exec backend python -c "import os,redis; r=redis.from_url(os.environ['REDIS_URL']); print(r.ping())"
```

### Common issues

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Frontend shows "Failed to trigger task" | Backend not healthy | `docker compose ps` and `docker compose logs backend` |
| Status stuck on **IN PROGRESS** | Worker not consuming | `docker compose logs worker`; confirm Redis health |
| `Connection refused` on 6379 inside app | `REDIS_URL` still points at localhost | Use `redis://redis:6379/0` in Compose |
| CORS error when opening `index.html` as a file | Browser is on `file://` | Use http://localhost:8080, or keep the `file://` fallback to port 8000 |
| Port 8080 / 8000 already in use | Local process bound | Stop the other process or change the left-hand ports in `docker-compose.yml` |

## 5. Stop and clean up

```bash
docker compose down        # keep the Redis volume
docker compose down -v     # also delete redis-data
```

## Running without Docker

If you still want the original venv workflow:

1. Start Redis (`redis-server` or `docker run -p 6379:6379 redis:7-alpine`).
2. `cd backend && python -m venv venv && source venv/bin/activate && pip install -r ../requirements.txt`
3. Terminal 1: `celery -A worker worker --loglevel=info`
4. Terminal 2: `uvicorn main:app --reload --port 8000`
5. Open `frontend/index.html` in a browser (`file://` talks to `http://localhost:8000`).
