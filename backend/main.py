from celery.result import AsyncResult
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from worker import celery, write_log_celery

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.post("/notify/")
async def notify_user(email: str):
    """Endpoint that triggers the background task in Celery."""
    task = write_log_celery.delay(f"Notification sent to {email}")
    return {"message": f"Email will be sent to {email}", "task_id": task.id}


@app.get("/task_status/{task_id}")
async def get_task_status(task_id: str):
    """Endpoint to check the status of the task."""
    task_result = AsyncResult(task_id, app=celery)
    if task_result.failed():
        return {"task_id": task_id, "status": "failed"}
    if task_result.successful():
        return {"task_id": task_id, "status": "completed", "result": task_result.result}
    return {"task_id": task_id, "status": "in progress"}


@app.get("/health")
@app.post("/health/")
async def health():
    """Liveness check for Docker and the load balancer."""
    return {"message": "OK"}
