#!/bin/bash

# Kuppanna Start Script
# Starts the Node.js backend and the ngrok tunnel in the background.

echo "=========================================="
echo "   Starting DirectDispatch Services       "
echo "=========================================="

# 1. Clean up existing processes if they are running
echo "🧹 Cleaning up existing Node.js or ngrok processes..."
pkill -f "node src/server.js" 2>/dev/null
pkill -f "ngrok http" 2>/dev/null
sleep 1

# 2. Start Node.js Backend
echo "🚀 Starting Node.js backend server on port 3000..."
cd "$(dirname "$0")/backend"
nohup node src/server.js > /tmp/kuppanna-backend.log 2>&1 &
BACKEND_PID=$!
echo "   Backend running (PID: $BACKEND_PID, logs at /tmp/kuppanna-backend.log)"

# 3. Start ngrok Tunnel
echo "📡 Starting ngrok tunnel (swoop-subsiding-treading.ngrok-free.dev)..."
nohup /opt/homebrew/bin/ngrok http --url=swoop-subsiding-treading.ngrok-free.dev 3000 > /tmp/kuppanna-ngrok.log 2>&1 &
NGROK_PID=$!
echo "   ngrok tunnel running (PID: $NGROK_PID, logs at /tmp/kuppanna-ngrok.log)"

# 4. Verify Health
sleep 3
echo "=========================================="
echo "🔍 Verifying Server Health..."
curl -s http://localhost:3000/health | grep -q "ok"
if [ $? -eq 0 ]; then
  echo "✅ Server is HEALTHY and running!"
  echo "📲 You can now run the app on your phone."
else
  echo "❌ Error starting server. Check logs at /tmp/kuppanna-backend.log"
fi
echo "=========================================="
