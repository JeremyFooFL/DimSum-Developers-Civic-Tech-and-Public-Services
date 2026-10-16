from datetime import datetime
from threading import Lock

from flask import Flask, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

_lock = Lock()
_boarding_count = 0
_exiting_count = 0
_capacity_step = 25


def _current_capacity_percent() -> int:
    # POC rule: +25% for enter, -25% for exit, floored at 0.
    occupancy = _boarding_count - _exiting_count
    return max(0, occupancy * _capacity_step)


@app.get('/health')
def health():
    return jsonify({'status': 'ok'})


@app.get('/capacity')
def get_capacity():
    with _lock:
        capacity_percent = _current_capacity_percent()
        payload = {
            'capacityPercent': capacity_percent,
            'boarding': _boarding_count,
            'exiting': _exiting_count,
            'timestamp': datetime.now().isoformat(),
        }
    return jsonify(payload)


@app.post('/event/enter')
def event_enter():
    global _boarding_count

    with _lock:
        _boarding_count += 1
        payload = {'capacityPercent': _current_capacity_percent()}
    return jsonify(payload)


@app.post('/event/exit')
def event_exit():
    global _exiting_count

    with _lock:
        if _current_capacity_percent() > 0:
            _exiting_count += 1
        payload = {'capacityPercent': _current_capacity_percent()}
    return jsonify(payload)


@app.post('/reset')
def reset():
    global _boarding_count, _exiting_count

    with _lock:
        _boarding_count = 0
        _exiting_count = 0
    return jsonify({'capacityPercent': 0})


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
