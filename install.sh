#!/data/data/com.termux/files/usr/bin/bash

# CNCjs + CLI Camera Streamer for Shapeoko 5 Pro
echo "--- Initializing CNCjs Termux Suite ---"

# 1. Install Dependencies (Termux:API app must be installed from F-Droid)
# Using -o Dpkg::Options::="--force-confnew" to prevent interactive prompts
pkg update -y -o Dpkg::Options::="--force-confnew" && pkg upgrade -y -o Dpkg::Options::="--force-confnew"
pkg install nodejs-lts python termux-api coreutils build-essential python-pip libopencv-headless -y

# 2. Install CNCjs and Python MJPEG Library
echo "Installing CNCjs and Camera components..."
npm install -g cncjs --unsafe-perm
pip install mjpeg-streamer opencv-python-headless

# 3. Create the persistent camera daemon script
cat >~/stream_camera.py <<'EOF'
import cv2
from mjpeg_streamer import MjpegServer, Stream

# Initialize camera (Try index 0 first, then 1 if black screen)
try:
    cap = cv2.VideoCapture(0)
except:
    cap = cv2.VideoCapture(1)

# Create MJPEG Stream
stream = Stream("cnc_cam", size=(640, 480), quality=50, fps=20)

# Configure and Start Server on Port 8080
server = MjpegServer("0.0.0.0", 8080)
server.add_stream(stream)
server.start()

print("MJPEG Streamer started on port 8080")
EOF

# 4. Auto-Configure CNCjs (.cncrc) to show the widget
# Fetches local IP to bake into the CNCjs UI configuration
IP_ADDR=$(ip addr show wlan0 | grep "inet\s" | awk '{print $2}' | sed 's/\/.*$//')
cat >~/.cncrc <<EOF
{
  "allowRemoteAccess": true,
  "controller": "Grbl",
  "webcam": {
    "url": "http://${IP_ADDR}:8080/cnc_cam"
  }
}
EOF

# 5. Create and update the start-cnc command
cat >"$PREFIX/bin/start-cnc" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
# Keep Android awake
termux-wake-lock
echo "Launching Wireless CNC Controller..."
python ~/stream_camera.py &
cncjs --port 8000
EOF

chmod +x "$PREFIX/bin/start-cnc"

echo "--- SETUP COMPLETE ---"
echo "1. Connect Shapeoko 5 Pro via OTG Adapter."
echo "2. Run 'start-cnc' in Termux."
echo "3. Access UI at http://$IP_ADDR:8000"
