from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import evaluation, model_versions, retraining, runs
from app.core.config import get_settings

settings = get_settings()

app = FastAPI(
    title="PROVA Backend",
    description="Preprocessing, OCR (TrOCR), Classification (BERT), and "
    "Evaluation services for the PROVA cognitive error classification pipeline.",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_allow_origins,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(runs.router)
app.include_router(evaluation.router)
app.include_router(model_versions.router)
app.include_router(retraining.router)


@app.get("/health")
def health():
    return {"status": "ok"}
