# Wine Quality Prediction API (FastAPI)

## Endpoints

- `GET /health` → `{ "status": "ok" }`
- `POST /predict` with JSON `{ "alcohol": <float> }` → `{ "wine_quality": <alcohol * 1.5 rounded to 2 decimals> }`

## Run locally

```powershell
python -m pip install -r requirements.txt
python -m uvicorn app:app --reload
```

Open:
- http://127.0.0.1:8000/health
- http://127.0.0.1:8000/docs

## Example request

```powershell
curl -X POST "http://127.0.0.1:8000/predict" -H "Content-Type: application/json" -d '{"alcohol": 10.0}'
```

## No Jenkins? Run the pipeline locally

This repo includes a PowerShell script that performs the same steps as the Jenkins pipeline: pull (optional), run container, wait for `/health`, test `/predict` (valid + invalid), then cleanup.

```powershell
# If you already built the local image:
docker build -t wine-quality-api:local .

.
\smoke_test.ps1 -ImageName "wine-quality-api:local" -Port 8001 -StudentName "rushikesh" -RollNumber "2022bcs0151"

# Or if you pushed an image to Docker Hub:
.\smoke_test.ps1 -Pull -ImageName "YOUR_DOCKERHUB_USERNAME/wine-quality-api:latest" -Port 8001 -StudentName "rushikesh" -RollNumber "2022bcs0151"
```

## GitHub Actions CI

If you want CI on GitHub, the workflow in `.github/workflows/ci.yml` will:

1) `docker pull` the Docker Hub image
2) run the container
3) wait for `/health`
4) test `/predict` with valid + invalid inputs
5) cleanup the container

Update `IMAGE_NAME`, `STUDENT_NAME`, and `ROLL_NUMBER` in the workflow before running it.
