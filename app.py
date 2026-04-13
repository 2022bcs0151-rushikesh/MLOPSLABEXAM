from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(title="Wine Quality Predictor")


class PredictRequest(BaseModel):
    alcohol: float


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.post("/predict")
def predict(payload: PredictRequest) -> dict:
    wine_quality = round(payload.alcohol * 1.5, 2)
    return {"wine_quality": wine_quality}
