# DevOps Assessment Assignment

Containerized FastAPI + Celery + Redis notifier, with Terraform for AWS and a GitHub Actions pipeline that builds, pushes, and deploys the stack.

Behavior is unchanged: `POST /notify/` enqueues a Celery task, and `GET /task_status/{task_id}` returns live status and the result. The Redis URL is now `REDIS_URL` instead of a hardcoded localhost value.

## Quick start (local)

```bash
cp .env.example .env
docker compose up --build -d --wait
```

Open http://localhost:8080, submit an email, and watch the task move from **IN PROGRESS** to **COMPLETED**.

Full developer commands are in [instructions.md](instructions.md).

## Repository layout

```
backend/                 FastAPI app + Celery worker
frontend/                Single-page UI + nginx configs
infra/terraform/         AWS VPC, ECS Fargate, ALB, ElastiCache, ECR, CloudWatch
.github/workflows/       CI (compose + Terraform validate) and CD (ECR + Terraform)
docker-compose.yml       Local full stack
Dockerfile               Backend/worker image
architecture.md          Cloud and local diagrams
journey.md               Decisions and trade-offs
instructions.md          Local Docker runbook
```

## Architecture

```
Browser
  └─ ALB (or local nginx :8080)
       ├─ /                  frontend (nginx)
       ├─ /notify*           FastAPI
       ├─ /task_status*      FastAPI
       └─ /health            FastAPI
            FastAPI ── Redis (ElastiCache; locally a Redis container) ── Celery worker
```

See [architecture.md](architecture.md) for the diagrams.

## What was added

| Requirement | Implementation |
|-------------|----------------|
| Containerize backend and worker | One Python image; Compose/ECS override the command for the worker |
| Environment variables | `REDIS_URL` |
| Local dependencies as containers | Redis 7 in Compose |
| `docker-compose.yml` | frontend, backend, worker, Redis |
| IaC | Terraform on AWS |
| CI/CD | GitHub Actions: compose build, Terraform validate, build/push ECR, `terraform apply` |
| Managed cloud services | ECS Fargate, ElastiCache Redis, ECR, ALB, CloudWatch Logs |
| Frontend | Calls `POST /notify/`, polls `GET /task_status/{task_id}` |

## Cloud deploy (AWS)

Resources Terraform creates:

- VPC with two public subnets (no NAT gateway, to keep cost down)
- Application Load Balancer with path-based routing
- ECS Fargate services: frontend, backend, worker
- ElastiCache Redis 7 (`cache.t3.micro`)
- ECR repositories
- CloudWatch log groups

### GitHub Actions secrets

| Secret | Purpose |
|--------|---------|
| `AWS_ACCESS_KEY_ID` | Deploy user (needs VPC, ECS, ECR, ElastiCache, IAM, CloudWatch) |
| `AWS_SECRET_ACCESS_KEY` | Same |
| `AWS_REGION` (optional variable) | Defaults to `us-east-1` |

Push to `main` (or run **Deploy** via `workflow_dispatch`). The workflow:

1. Creates an S3 + DynamoDB Terraform backend if missing
2. Applies ECR first so images have a place to land
3. Builds and pushes backend/frontend images tagged with the git SHA
4. Applies the rest of the stack with `TF_VAR_image_tag=<sha>`
5. Waits until ECS services are stable and prints the ALB URL

### Manual Terraform

```bash
export AWS_REGION=us-east-1
chmod +x scripts/ensure-tf-backend.sh
./scripts/ensure-tf-backend.sh

cd infra/terraform
terraform init \
  -backend-config="bucket=<from script>" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=devops-assignment-tf-lock" \
  -backend-config="encrypt=true"

terraform apply -target=aws_ecr_repository.backend -target=aws_ecr_repository.frontend
# build and push images (see deploy.yml), then:
terraform apply -var="image_tag=<git-sha>"
```

Tear down when you are done (this stack is **not** free):

```bash
terraform destroy
```

Typical idle cost is a few dollars per day, driven by the ALB and ElastiCache node.

## CI

On every push and pull request, `.github/workflows/ci.yml`:

- `terraform fmt -check` and `terraform validate`
- `docker compose up --wait` and a health check

## Submission

1. Push this repository to **your** GitHub account (do not push to the assignment source repo).
2. Add GitHub Actions secrets if you want the AWS deploy to run.
3. Record a short video walkthrough of local Compose and the GitHub Actions deploy workflow.
4. Email **advaid@superclaims.ai** with subject `DevOps Assessment Assignment`, the repo URL, and the walkthrough video.
