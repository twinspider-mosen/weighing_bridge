import argparse
import json
import re
import sys
import time
from pathlib import Path
from datetime import datetime

import requests
from requests.auth import HTTPDigestAuth

# ============================================================
# CAMERA CONFIGURATION (DEFAULTS)
# ============================================================

CAMERA_IP = "192.168.0.101"
USERNAME = "admin"
PASSWORD = "admin@12345"

WAIT_SECONDS = 120
OUTPUT_DIR = Path("vehicle_capture")



def parse_metadata(data):
    """Extract Dahua key=value fields from a multipart part."""
    text = data.decode("latin-1", errors="ignore")
    fields = {}

    for line in text.splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            fields[key.strip()] = value.strip().strip('"')

    return fields



def read_parts(response):
    """Read multipart parts using their declared content lengths."""
    content_type = response.headers.get("Content-Type", "")
    match = re.search(r'boundary="?([^";]+)"?', content_type)

    if not match:
        raise RuntimeError(
            f"Unexpected stream Content-Type: {content_type}"
        )

    boundary = b"--" + match.group(1).encode("latin-1")

    while True:
        line = response.raw.readline()

        if not line:
            return

        if line.strip() != boundary:
            if line.strip() == boundary + b"--":
                return
            continue

        headers = {}

        while True:
            line = response.raw.readline()
            if not line or line in (b"\r\n", b"\n"):
                break

            if b":" in line:
                key, value = line.decode(
                    "latin-1"
                ).split(":", 1)
                headers[key.strip().lower()] = value.strip()

        length = headers.get("content-length")
        if length is None:
            print("Skipping multipart part without Content-Length")
            continue

        body = response.raw.read(int(length))
        if len(body) != int(length):
            return

        yield headers, body



def jpeg_from(data):
    """Return a complete JPEG if one exists in the given bytes."""
    start = data.find(b"\xff\xd8")
    if start < 0:
        return None

    end = data.find(b"\xff\xd9", start + 2)
    if end < 0:
        return None

    return data[start:end + 2]



def field(fields, suffix):
    """Find a field by its ending name, regardless of event index."""
    for key, value in fields.items():
        if key.endswith(suffix) and value:
            return value
    return ""



def save_one(fields, payload, output_dir=OUTPUT_DIR):
    plate = (
        field(fields, "TrafficCar.PlateNumber")
        or field(fields, "Object.Text")
    ).strip()

    if not plate or plate.lower() in {
        "unknown", "none", "null", "no", "0"
    }:
        return False

    try:
        scene_offset = int(field(fields, "SceneImage.Offset"))
        scene_length = int(field(fields, "SceneImage.Length"))
        plate_offset = int(field(fields, "Object.Image.Offset"))
        plate_length = int(field(fields, "Object.Image.Length"))
    except (TypeError, ValueError):
        return False

    # These offsets refer to the camera's image data buffer.
    scene_data = payload[
        scene_offset:scene_offset + scene_length
    ]
    plate_data = payload[
        plate_offset:plate_offset + plate_length
    ]

    scene_jpeg = jpeg_from(scene_data)
    plate_jpeg = jpeg_from(plate_data)

    if not scene_jpeg or not plate_jpeg:
        return False

    output_dir.mkdir(parents=True, exist_ok=True)

    safe_plate = re.sub(r"[^A-Za-z0-9_-]", "_", plate)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    prefix = f"{timestamp}_{safe_plate}"

    scene_file = f"{prefix}_scene.jpg"
    plate_file = f"{prefix}_plate.jpg"
    json_file = f"{prefix}.json"

    scene_path = output_dir / scene_file
    plate_path = output_dir / plate_file
    json_path = output_dir / json_file

    scene_path.write_bytes(scene_jpeg)
    plate_path.write_bytes(plate_jpeg)

    result = {
        "plate_number": plate,
        "vehicle_image": scene_file,
        "plate_image": plate_file,
        "captured_at": datetime.now().isoformat(timespec="seconds"),
    }

    json_path.write_text(
        json.dumps(result, indent=2),
        encoding="utf-8",
    )

    print("\nCapture saved:")
    print(f"Plate number: {plate}")
    print(f"Vehicle image: {scene_path}")
    print(f"Plate crop:    {plate_path}")
    print(f"JSON result:   {json_path}")

    # Structured JSON output for client applications (e.g. Flutter service)
    payload_dict = {
        "success": True,
        "plate_number": plate,
        "vehicle_image": str(scene_path.resolve()),
        "plate_image": str(plate_path.resolve()),
        "json_file": str(json_path.resolve()),
        "anpr_response": result,
    }
    print(f"__ANPR_JSON_START__{json.dumps(payload_dict)}__ANPR_JSON_END__")
    sys.stdout.flush()
    return True



def main():
    parser = argparse.ArgumentParser(description="Dahua ANPR Capture")
    parser.add_argument("--ip", default=CAMERA_IP, help="Camera IP address")
    parser.add_argument("--user", default=USERNAME, help="Camera username")
    parser.add_argument("--password", default=PASSWORD, help="Camera password")
    parser.add_argument("--timeout", type=int, default=WAIT_SECONDS, help="Timeout in seconds")
    parser.add_argument("--output", default=str(OUTPUT_DIR), help="Output directory")
    args, _ = parser.parse_known_args()

    camera_ip = args.ip
    username = args.user
    password = args.password
    wait_seconds = args.timeout
    output_dir = Path(args.output)

    stream_url = (
        f"http://{camera_ip}/cgi-bin/"
        "snapManager.cgi?action=attachFileProc"
        "&Flags[0]=Event&Events=[TrafficJunction]&heartbeat=5"
    )

    info_url = (
        f"http://{camera_ip}/cgi-bin/"
        "magicBox.cgi?action=getSystemInfo"
    )

    session = requests.Session()
    session.auth = HTTPDigestAuth(username, password)

    print(f"Checking camera authentication for {camera_ip}...")

    with session.get(info_url, timeout=10) as response:
        response.raise_for_status()

    print(f"Authenticated. Waiting up to {wait_seconds}s for one recognized vehicle...")

    deadline = time.monotonic() + wait_seconds
    metadata = {}
    recent_payloads = []

    with session.get(
        stream_url,
        stream=True,
        timeout=(10, wait_seconds + 15),
    ) as response:
        response.raise_for_status()
        response.raw.decode_content = False

        for headers, body in read_parts(response):
            if time.monotonic() > deadline:
                break

            content_type = headers.get("content-type", "").lower()
            parsed = parse_metadata(body)

            if parsed:
                metadata.update(parsed)

            looks_binary = (
                "image" in content_type
                or b"\xff\xd8" in body
            )

            if looks_binary:
                recent_payloads.append(body)
                recent_payloads = recent_payloads[-3:]

            if not (
                field(metadata, "TrafficCar.PlateNumber")
                or field(metadata, "Object.Text")
            ):
                continue

            candidates = list(reversed(recent_payloads))

            if recent_payloads:
                candidates.append(b"".join(recent_payloads))

            for payload in candidates:
                if save_one(metadata, payload, output_dir=output_dir):
                    return

    print(
        "\nNo complete recognized-vehicle capture was saved. "
        "The camera may not have recognized a plate, or its "
        "image payload format may need adjustment."
    )
    fail_dict = {
        "success": False,
        "error": "No recognized vehicle detected within timeout window.",
    }
    print(f"__ANPR_JSON_START__{json.dumps(fail_dict)}__ANPR_JSON_END__")
    sys.stdout.flush()



if __name__ == "__main__":
    try:
        main()
    except requests.RequestException as exc:
        print(f"Camera connection/authentication error: {exc}")
        err_dict = {
            "success": False,
            "error": f"Camera connection/authentication error: {exc}",
        }
        print(f"__ANPR_JSON_START__{json.dumps(err_dict)}__ANPR_JSON_END__")
        sys.stdout.flush()
    except KeyboardInterrupt:
        print("\nCapture cancelled.")