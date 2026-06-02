# Kuppanna — Uber Direct Delivery Integration (MVP)

A zero-cost local MVP integrating a restaurant delivery app with the **Uber Direct Sandbox API**. 

The architecture consists of:
1. **Node.js (Express) Backend**: Manages OAuth2 token handshakes, SQLite persistence, and handles incoming webhooks.
2. **Flutter Mobile Application**: A premium client interface supporting checkout and real-time delivery status tracking.

---

## 📁 Repository Structure
```
Kuppanna/
├── README.md               # Setup and testing instructions (this file)
├── .gitignore              # Configured to ignore secrets and local SQLite databases
├── backend/                # Express server + SQLite database logic
└── kuppanna_app/           # Flutter cross-platform mobile client application
```

---

## 🛠️ Step 1: Backend Setup (Node.js)

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Create a `.env` file in the `backend/` folder (it is ignored by Git) and populate it with your Uber Developer Sandbox credentials:
   ```env
   # Uber Direct Sandbox Credentials
   UBER_CLIENT_ID=YOUR_CLIENT_ID
   UBER_CLIENT_SECRET=YOUR_CLIENT_SECRET
   UBER_CUSTOMER_ID=YOUR_CUSTOMER_ID
   UBER_TOKEN_URL=https://auth.uber.com/oauth/v2/token
   UBER_API_BASE=https://api.uber.com/v1

   # Server Configuration
   PORT=3000
   ```
4. Start the Express server:
   ```bash
   npm start
   ```
   *The server will start on `http://localhost:3000` and automatically initialize a local SQLite database (`kuppanna.sqlite`) to store OAuth tokens and order logs.*

---

## 📡 Step 2: Public Tunneling (ngrok)

To receive live webhook callbacks from Uber's Sandbox servers on your local machine, configure an `ngrok` tunnel:

1. Install ngrok:
   ```bash
   brew install ngrok
   ```
2. Configure your auth token (from your ngrok dashboard):
   ```bash
   ngrok config add-authtoken YOUR_AUTHTOKEN
   ```
3. Start the tunnel to port `3000`:
   ```bash
   ngrok http --url=YOUR_STATIC_OR_DYNAMIC_DOMAIN.ngrok-free.dev 3000
   ```
4. Configure your Webhook URL in the **Uber Direct Developer Dashboard** (`direct.uber.com` under **Developer > Webhooks**):
   * **Webhook URL**: `https://YOUR_SUBDOMAIN.ngrok-free.dev/api/uber-webhook`
   * **Authentication Type**: `Basic HMAC`
   * **Signing Key**: `AnySecretStringYouWant`
   * **Events**: Subscribed to `event.delivery_status`

---

## 📱 Step 3: Flutter Client Setup

1. Open [`kuppanna_app/lib/config/app_config.dart`](file:///Users/siddy/Desktop/Kuppanna/kuppanna_app/lib/config/app_config.dart) and configure your ngrok tunnel URL:
   ```dart
   static const String ngrokBaseUrl = 'https://YOUR_SUBDOMAIN.ngrok-free.dev';
   ```
2. Open your project in Xcode (or connect an Android device with USB Debugging enabled):
   * For iOS: `open ios/Runner.xcworkspace` (select your Apple Developer account Team in the **Signing & Capabilities** tab).
3. Start the application:
   ```bash
   cd kuppanna_app
   flutter run --dart-define=USE_NGROK=true
   ```

---

## 🧪 Step 4: Testing Delivery Lifecycles

### 🤖 1. Automated Simulation (Robo Courier)
When you place a new order on the mobile app, the backend automatically flags it with the **Robo Courier** specification:
```json
"test_specifications": {
  "robo_courier_specification": { "mode": "auto" }
}
```
Uber's actual Sandbox servers will simulate a courier. The order will automatically progress on a **30-second schedule**:
* **0s**: Assigned (`pickup`)
* **30s**: Courier is en route
* **60s**: Arrived at pickup
* **90s**: Courier picked up *(iPhone screen moves to "Food Picked Up")*
* **120s**: Dropoff is imminent
* **150s**: Delivered! *(iPhone screen moves to "Delivered")*

### 💻 2. Manual Webhook Simulation (Via Terminal)
If you want to trigger status changes instantly without waiting for the sandbox timer, send a mock webhook directly to your ngrok URL:

*   **Assign Driver:**
    ```bash
    curl -s -X POST https://YOUR_SUBDOMAIN.ngrok-free.dev/api/uber-webhook \
      -H "Content-Type: application/json" \
      -d '{"kind": "eats.delivery.status.changed", "data": {"id": "YOUR_DELIVERY_ID", "status": "pickup"}}'
    ```
*   **Pick Up Food:**
    ```bash
    curl -s -X POST https://YOUR_SUBDOMAIN.ngrok-free.dev/api/uber-webhook \
      -H "Content-Type: application/json" \
      -d '{"kind": "eats.delivery.status.changed", "data": {"id": "YOUR_DELIVERY_ID", "status": "pickup_complete"}}'
    ```
*   **Delivered:**
    ```bash
    curl -s -X POST https://YOUR_SUBDOMAIN.ngrok-free.dev/api/uber-webhook \
      -H "Content-Type: application/json" \
      -d '{"kind": "eats.delivery.status.changed", "data": {"id": "YOUR_DELIVERY_ID", "status": "delivered"}}'
    ```

---

## 🚀 Step 5: Cloud Deployment (Render.com)

To keep your backend running 24/7 without needing your Mac turned on or `ngrok` running, you can deploy the Express server to a cloud provider like **Render** (free tier available):

### 1. Push Code to GitHub
Ensure your code is pushed to your GitHub repository (excluding `.env` and `kuppanna.sqlite` as defined in `.gitignore`).

### 2. Create a Web Service on Render
1. Log in to [Render](https://render.com).
2. Click **New +** and select **Web Service**.
3. Link your GitHub repository.
4. Configure the service settings:
   * **Runtime**: `Node`
   * **Build Command**: `npm install` (navigate to directory or set root directory as `backend/`)
   * **Start Command**: `node src/server.js`

### 3. Add Environment Variables
Under the **Environment** tab in Render, add your secret keys:
* `UBER_CLIENT_ID`
* `UBER_CLIENT_SECRET`
* `UBER_CUSTOMER_ID`
* `UBER_TOKEN_URL` = `https://auth.uber.com/oauth/v2/token`
* `UBER_API_BASE` = `https://api.uber.com/v1`

### 4. Configure Persistent Disk (Required for SQLite)
Since SQLite is a file-based database, cloud servers will delete your data every time they reboot or deploy new code. To prevent this:
1. In your Render service, go to **Disk** settings.
2. Click **Add Disk**:
   * **Name**: `kuppanna-db`
   * **Mount Path**: `/var/data`
   * **Size**: `1 GB` (free tier)
3. Update your `.env` setting or code database path to point to `/var/data/kuppanna.sqlite` to ensure your order history and OAuth tokens are persisted forever!

