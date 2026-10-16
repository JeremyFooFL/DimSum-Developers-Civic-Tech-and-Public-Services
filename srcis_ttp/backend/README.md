# Backend (YOLO Train Detector)

## Setup

```powershell
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
```

## Run

```powershell
python train_detector.py
```

Press `q` to quit and `r` to reset counters.

## Run YOLO With API (Recommended for Flutter Test View)

```powershell
python train_detector.py --api
```

This runs the YOLO detector and exposes API endpoints on port 5000.

## Capacity API (POC for Flutter Test View)

Run this in a second terminal:

```powershell
python capacity_api.py
```

Use this only if you want counter simulation without opening YOLO webcam detection.

Available endpoints:

- `GET /health`
- `GET /capacity`
- `POST /event/enter`
- `POST /event/exit`
- `POST /reset`

POC rule implemented by API:

- Start at `0%`
- Enter event increments by `1%`
- Exit event decrements by `1%`
- Capacity is clamped between `0%` and `100%`
