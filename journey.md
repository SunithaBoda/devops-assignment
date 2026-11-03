# Journey

I started by running the app as it was given. FastAPI in `backend/main.py`, a Celery worker in `backend/worker.py`, Redis in the middle, and a single HTML page that already knew how to call `POST /notify/` and poll `GET /task_status/{task_id}`. It worked on a laptop if Redis was on localhost. That was also the problem.

The assignment was not to rebuild the product. It was to containerize it, take the hardcoded bits out, and deploy it with code.

## What was hardcoded

Two values actually break as soon as you leave the laptop:

- Redis in `worker.py` was `redis://localhost:6379/0`. Inside Docker or ECS that hostname is wrong. I made it `REDIS_URL`.
- The frontend called `http://localhost:8000`. That is fine if you open the HTML file directly, and useless behind nginx or an ALB. I switched it to a relative URL, and only fall back to localhost when the page is opened as `file://`.

I also added `GET /health` next to the original `POST /health/`. Docker and the load balancer probe with GET. I did not want to invent a new API, just make the existing health check usable.

One more small fix in the status endpoint: `ready()` is true for both success and failure, so a failed task could have been returned as completed. I check failure first. I also pass `app=celery` into `AsyncResult`, because without that the worker and the API do not always share the same Redis result backend once they are in separate containers.

## How I packaged it

Backend and worker are the same Python code, so they share one image. Compose (and later ECS) just changes the command: `uvicorn` vs `celery worker`.

The frontend is nginx. Locally it also proxies `/notify/`, `/task_status/`, and `/health` to the API, so you only open http://localhost:8080. In AWS I did not want nginx talking across tasks, so `nginx.cloud.conf` is static files only. The ALB routes those API paths to FastAPI.

While bringing Compose up I hit two dependency issues that were not obvious from the original `requirements.txt`. Newer kombu wanted `packaging`, then it wanted redis-py 6, which Celery 5.4 refuses. I pinned kombu to 5.3.7 so Celery and redis-py 5.2 stay compatible. After that the worker stayed up, and a notify-and-poll round trip completed in about ten seconds.

## Cloud

I looked at EKS and skipped it. Three processes do not need a Kubernetes control plane. Running Compose on EC2 would work, but then I am patching machines, which is the opposite of “prefer managed services”. App Runner is awkward for a Celery worker that should not be public.

So: ECS Fargate for the three services, ElastiCache for Redis, ECR for images, CloudWatch for logs, ALB in front.

I put the tasks in public subnets with public IPs so they can pull from ECR without a NAT gateway. NAT is the expensive part of a tiny VPC. Redis is still private. ElastiCache has no public endpoint, and the security group only allows 6379 from the backend and worker. The ALB is the only thing open to the internet, on port 80. I left TLS off because it needs a hostname and an ACM certificate. Easy to add later, noisy for this assignment.

## Deploy order

Terraform cannot start ECS on an image that is not in ECR yet. The GitHub Actions workflow therefore creates the ECR repos first, builds and pushes the git SHA, then applies the rest. `ci.yml` never talks to AWS. It just validates Terraform and starts Compose far enough to hit `/health`. `deploy.yml` is the only job with AWS keys, and it does not cancel in-progress runs, so two pushes cannot stomp on each other mid-apply.

If someone runs `terraform apply` by hand before pushing images, the services sit in PENDING. That is expected. Follow the pipeline order.

## What I would do next

HTTPS on the ALB, GitHub OIDC instead of long-lived access keys, a Redis AUTH token in Secrets Manager, and private subnets if this ever left demo-land.
