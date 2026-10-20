# Backend (YOLO Train Detector)

## Quick Start (Recommended)

From the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File run_demo.ps1
```

This sets up the backend on first run, starts it in its own window, and opens the web app.
In the app, go to the Capacity Test View and switch on **Sync with YOLO backend**:
that loads the model and opens the webcam. Switching it off (or leaving the page)
stops detection and releases the camera. Close the backend window to shut it down.

## Setup

```powershell
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
```

## Run YOLO With API (For the Flutter Test View)

```powershell
python train_detector.py --api
```

This exposes the API on port 5000 and waits. Detection starts when the app calls
`POST /detector/start` (the sync toggle) and stops on `POST /detector/stop`.

In the detector window, press `q` to stop detection and `r` to reset counters.

## Run YOLO Standalone

```powershell
python train_detector.py
```

Starts detection immediately, without the API. Press `q` to quit and `r` to reset counters.

## Capacity API (Simulation, No Webcam)

```powershell
python capacity_api.py
```

Use this only if you want counter simulation without YOLO webcam detection.
Don't run it at the same time as `train_detector.py --api`; both use port 5000.

## Endpoints

- `GET /health`
- `GET /capacity`
- `POST /detector/start` (YOLO backend only)
- `POST /detector/stop` (YOLO backend only)
- `POST /event/enter`
- `POST /event/exit`
- `POST /reset`

POC rule implemented by API:

- Start at `0%`
- Enter event increments by `25%`
- Exit event decrements by `25%`
- Capacity never drops below `0%`
