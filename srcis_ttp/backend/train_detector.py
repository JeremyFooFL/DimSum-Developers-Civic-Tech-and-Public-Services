import argparse
import cv2
import numpy as np
from ultralytics import YOLO
from collections import defaultdict
from datetime import datetime
from threading import Lock, Thread

from flask import Flask, jsonify
from flask_cors import CORS


class TrainDetector:
    def __init__(self):
        print("Initializing Train Detector...")
        self.capacity_step = 25

        # Load YOLO model
        print("Loading YOLOv8...")
        self.model = YOLO("yolov8n.pt")

        # Initialize webcam
        self.cap = cv2.VideoCapture(0)
        if not self.cap.isOpened():
            raise RuntimeError("Could not open webcam")

        # Get camera properties
        self.width = int(self.cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        self.height = int(self.cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        print(f"Camera resolution: {self.width}x{self.height}")

        # Counting line (vertical line in center)
        self.counting_line_x = self.width // 2

        # Tracking variables
        self.person_tracks = defaultdict(list)
        self.counted_ids = set()
        self.boarding_count = 0
        self.exiting_count = 0
        self.direction_threshold = 30
        self.max_trail_length = 20
        self.counter_lock = Lock()

        # Running flag
        self.is_running = False

    def get_stats(self):
        """Return current statistics for API."""
        with self.counter_lock:
            occupancy = self.boarding_count - self.exiting_count
            return {
                "boarding": self.boarding_count,
                "exiting": self.exiting_count,
                "occupancy": occupancy,
                "capacityPercent": max(0, occupancy * self.capacity_step),
                "active_detections": len(self.person_tracks),
                "timestamp": datetime.now().isoformat(),
            }

    def record_boarding(self):
        with self.counter_lock:
            self.boarding_count += 1

    def record_exit(self):
        with self.counter_lock:
            if self.boarding_count - self.exiting_count > 0:
                self.exiting_count += 1

    def reset_counts(self):
        with self.counter_lock:
            self.boarding_count = 0
            self.exiting_count = 0
            self.counted_ids.clear()
            self.person_tracks.clear()

    def determine_direction(self, track_history):
        if len(track_history) < 5:
            return None
        recent = track_history[-5:]
        x_positions = [pos[0] for pos in recent]
        if x_positions[-1] - x_positions[0] > self.direction_threshold:
            return "boarding"
        if x_positions[0] - x_positions[-1] > self.direction_threshold:
            return "exiting"
        return None

    def check_crossing(self, person_id, current_pos, track_history):
        if person_id in self.counted_ids or len(track_history) < 3:
            return None

        prev_pos = track_history[-3]
        curr_x, _ = current_pos
        prev_x, _ = prev_pos

        crossed_from_left = prev_x < self.counting_line_x and curr_x >= self.counting_line_x
        crossed_from_right = prev_x > self.counting_line_x and curr_x <= self.counting_line_x

        if crossed_from_left:
            direction = self.determine_direction(track_history)
            if direction == "boarding":
                self.record_boarding()
                self.counted_ids.add(person_id)
                print(f"ENTERED (Total: {self.boarding_count})")
                return "boarding"
        elif crossed_from_right:
            direction = self.determine_direction(track_history)
            if direction == "exiting":
                self.record_exit()
                self.counted_ids.add(person_id)
                print(f"EXITED (Total: {self.exiting_count})")
                return "exiting"
        return None

    def process_frame(self, frame):
        """Process a single frame and return annotated frame."""
        # Mirror frame
        frame = cv2.flip(frame, 1)

        # Run YOLO tracking (class 0 = person)
        results = self.model.track(frame, persist=True, classes=[0], verbose=False)

        # Draw counting line
        cv2.line(frame, (self.counting_line_x, 0), (self.counting_line_x, self.height), (0, 255, 255), 3)
        cv2.putText(
            frame,
            "PLATFORM",
            (self.counting_line_x - 150, 50),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.8,
            (255, 255, 255),
            2,
        )
        cv2.putText(
            frame,
            "TRAIN",
            (self.counting_line_x + 20, 50),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.8,
            (255, 255, 255),
            2,
        )

        # Process detections
        for box in results[0].boxes:
            if int(box.cls[0]) != 0:
                continue

            x1, y1, x2, y2 = map(int, box.xyxy[0])
            track_id = int(box.id[0]) if box.id is not None else None

            if track_id is None:
                continue

            center_x = (x1 + x2) // 2
            center_y = (y1 + y2) // 2

            # Update track
            self.person_tracks[track_id].append((center_x, center_y))
            if len(self.person_tracks[track_id]) > self.max_trail_length:
                self.person_tracks[track_id].pop(0)

            # Check crossing
            crossing = self.check_crossing(track_id, (center_x, center_y), self.person_tracks[track_id])

            # Draw box
            color = (
                (0, 255, 0)
                if crossing == "boarding"
                else (0, 0, 255)
                if crossing == "exiting"
                else (255, 0, 0)
            )
            cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)
            cv2.putText(frame, f"ID:{track_id}", (x1, y1 - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.6, color, 2)

            # Draw trail
            track = self.person_tracks[track_id]
            for i in range(1, len(track)):
                cv2.line(frame, track[i - 1], track[i], (0, 255, 255), 2)

        # Draw dashboard
        self._draw_dashboard(frame)

        return frame

    def _draw_dashboard(self, frame):
        # Dashboard background
        cv2.rectangle(frame, (10, 10), (300, 150), (0, 0, 0), -1)
        cv2.rectangle(frame, (10, 10), (300, 150), (255, 255, 255), 2)

        cv2.putText(frame, "TRAIN COUNTER", (20, 40), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2)
        cv2.putText(frame, f"Entered: {self.boarding_count}", (20, 80), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
        cv2.putText(frame, f"Exited: {self.exiting_count}", (20, 110), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)

        current = self.boarding_count - self.exiting_count
        occ_color = (0, 255, 0) if current < 5 else (0, 165, 255) if current < 10 else (0, 0, 255)
        cv2.putText(frame, f"On Train: {current}", (20, 140), cv2.FONT_HERSHEY_SIMPLEX, 0.7, occ_color, 2)

    def run(self):
        """Main loop: call this to start detection."""
        self.is_running = True
        print("\nStarting detection...")
        print("Walk LEFT->RIGHT to ENTER | RIGHT->LEFT to EXIT")
        print("Press 'Q' to quit | 'R' to reset\n")

        while self.is_running:
            ret, frame = self.cap.read()
            if not ret:
                break

            processed = self.process_frame(frame)
            cv2.imshow("Train Detector", processed)

            key = cv2.waitKey(1) & 0xFF
            if key == ord("q"):
                self.is_running = False
            elif key == ord("r"):
                self.reset_counts()
                print("Reset")

        self.cleanup()

    def cleanup(self):
        self.cap.release()
        cv2.destroyAllWindows()
        print(f"\nFinal: {self.boarding_count} entered, {self.exiting_count} exited")


def create_api(detector: TrainDetector) -> Flask:
    app = Flask(__name__)
    CORS(app)

    @app.get('/health')
    def health():
        return jsonify({'status': 'ok'})

    @app.get('/capacity')
    def capacity():
        return jsonify(detector.get_stats())

    @app.post('/event/enter')
    def event_enter():
        detector.record_boarding()
        return jsonify({'capacityPercent': detector.get_stats()['capacityPercent']})

    @app.post('/event/exit')
    def event_exit():
        detector.record_exit()
        return jsonify({'capacityPercent': detector.get_stats()['capacityPercent']})

    @app.post('/reset')
    def reset():
        detector.reset_counts()
        return jsonify({'capacityPercent': 0})

    return app


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='YOLO train detector with optional API mode')
    parser.add_argument('--api', action='store_true', help='Expose detector counters via Flask API')
    parser.add_argument('--host', default='0.0.0.0', help='API host when --api is enabled')
    parser.add_argument('--port', type=int, default=5000, help='API port when --api is enabled')
    args = parser.parse_args()

    detector = TrainDetector()
    if args.api:
      api = create_api(detector)
      detector_thread = Thread(target=detector.run, daemon=True)
      detector_thread.start()
      api.run(host=args.host, port=args.port, debug=False)
    else:
      detector.run()
