# WorkAdventure Docker Hosting Guide (Local & Production VPS)

This guide walks you through self-hosting **WorkAdventure (v1.33.5+)** using Docker and Docker Compose. This setup uses official pre-built containers and supports:
- **Local Testing**: Runs on `http://localhost` in 60 seconds with no SSL hassle (browsers natively treat `localhost` as a Secure Context for camera and mic access).
- **Production VPS**: Runs on any Linux VPS (Hetzner, DigitalOcean, AWS, etc.) with automatic Let's Encrypt SSL/TLS certificates via Traefik.

---

## 1. Quick Start: Local Testing (`localhost`)

Run WorkAdventure on your local computer (Windows with Docker Desktop, macOS, or Linux):

### Option A: Using the Setup Script
- **Windows (PowerShell)**:
  ```powershell
  .\docker-setup.ps1 -Mode local
  docker compose -f docker-compose.standalone.yaml -f docker-compose.local.yaml up -d
  ```
- **Linux / macOS / WSL (Bash)**:
  ```bash
  bash docker-setup.sh local
  docker compose -f docker-compose.standalone.yaml -f docker-compose.local.yaml up -d
  ```

### Option B: Manual Setup
1. Copy the example environment file:
   ```bash
   cp .env.docker.example .env
   ```
2. Edit `.env` and set:
   ```env
   DOMAIN=localhost
   SECRET_KEY=my_local_secret_key_12345678901234567890
   ADMIN_API_TOKEN=my_admin_token_1234567890
   MAP_STORAGE_API_TOKEN=my_map_token_1234567890
   ```
3. Start the containers:
   ```bash
   docker compose -f docker-compose.standalone.yaml -f docker-compose.local.yaml up -d
   ```
4. Open your browser and navigate to:
   👉 **`http://localhost`**

> [!TIP]
> **Why `http://localhost` works for WebRTC**: Chrome, Edge, and Firefox treat `http://localhost` as a Secure Context (`window.isSecureContext === true`). Your camera, microphone, and proximity bubbles work locally without needing self-signed SSL certificates!

---

## 2. Quick Start: Production on a VPS

Deploy WorkAdventure to an Ubuntu or Debian cloud server (e.g. Hetzner, DigitalOcean Droplet, Linode, AWS EC2).

### Server Requirements
- **Hardware**: Minimum 2 vCPUs, 4 GB RAM (e.g., a $5–$7/month VPS).
- **OS**: Ubuntu 22.04 / 24.04 LTS or Debian 12.
- **Docker**: Docker Engine and Docker Compose v2 installed.
- **DNS**: A domain name (e.g. `office.yourcompany.com`) pointing to your server's public IPv4 address.

### Step 1: Configure DNS
In your domain registrar / DNS provider (Cloudflare, Namecheap, AWS Route53, etc.), create an **A Record**:
```
Type: A
Name: office (or @ for root domain)
Value: <YOUR_SERVER_PUBLIC_IP>
TTL: 300 (or Auto)
```
*(If using Cloudflare, turn proxy status to **DNS Only / Grey Cloud** during initial SSL issuance).*

### Step 2: Open Firewall Ports
On your server, ensure ports 80, 443, and 50051 are open:
```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 50051/tcp
sudo ufw allow 22/tcp
sudo ufw enable
```

### Step 3: Clone Repository & Generate Configuration
SSH into your server and run:
```bash
git clone https://github.com/Seifkassab20/workadventure.git
cd workadventure

# Run the interactive setup script
bash docker-setup.sh prod office.yourcompany.com admin@yourcompany.com
```

### Step 4: Start WorkAdventure
```bash
docker compose -f docker-compose.standalone.yaml up -d
```

### Step 5: Verify Deployment
1. Check container statuses:
   ```bash
   docker compose -f docker-compose.standalone.yaml ps
   ```
2. Check Traefik logs to watch Let's Encrypt acquire your SSL certificate:
   ```bash
   docker compose -f docker-compose.standalone.yaml logs -f reverse-proxy
   ```
3. Open **`https://office.yourcompany.com`** in your browser!

---

## 3. Architecture Overview

```
                                 +-------------------------------------------------------------+
                                 |                  DOCKER HOST (VPS or Local)                 |
                                 |                                                             |
   [ Browser / Client ]          |       +---------------------------------------------+       |
           |                     |       |                   Traefik                   |       |
   HTTP:80 / HTTPS:443           |       |  (Reverse Proxy + Let's Encrypt ACME)       |       |
           +---------------------------->|                                             |       |
                                 |       +-----+------+------+------+------+-----+-----+       |
                                 |             |      |      |      |      |     |             |
                                 |             |      |      |      |      |     +--------+    |
                                 |             |      |      |      |      |              |    |
                                 |             v      v      v      v      v              v    |
                                 |          +------+------+------+------+------+       +------+  |
                                 |          | play | back | map- |upload| icon |       |redis |  |
                                 |          |      |      |stor. |      |      |       |      |  |
                                 |          +------+------+------+------+------+       +------+  |
                                 |             |      |      |                         ^  ^  ^   |
                                 |             |      |      +-- [data/maps volume]    |  |  |   |
                                 |             |      +--------- (gRPC:50051 / 50053)--+  |  |   |
                                 |             +---------------- (gRPC:50051)-------------+  |   |
                                 |                                                            |  |   |
                                 |                   uploader --------------------------------+  |   |
                                 |                                                               |
   [ Automation Bots ]           |                                                               |
           |                     |                                                               |
   gRPC :50051 (Room API)        |                                                               |
           +------------------------------------> play:50051 (Host port 50051)                |
                                 +-------------------------------------------------------------+
```

### Services Breakdown

| Service | Container Image | Internal Port | Description |
| :--- | :--- | :--- | :--- |
| `reverse-proxy` | `traefik:v3.6.1` | `:80`, `:443`, `:50051` | Routes traffic, handles HTTPS termination & automatic Let's Encrypt certificates. |
| `play` | `thecodingmachine/workadventure-play:v1.33.5` | `:3000`, `:3001`, `:50051` | Serves web client HTML/JS, handles Pusher WebSockets (`/ws/`), and Room API gRPC. |
| `back` | `thecodingmachine/workadventure-back:v1.33.5` | `:8080`, `:50051` | Coordinates player coordinates, movement, proximity bubbles, and game state. |
| `map-storage` | `thecodingmachine/workadventure-map-storage:v1.33.5` | `:3000`, `:50053` | Hosts maps, serves map editor web UI, and provides HTTP upload endpoints. |
| `uploader` | `thecodingmachine/workadventure-uploader:v1.33.5` | `:8080` | Handles in-game chat image and file attachment uploads. |
| `icon` | `matthiasluedtke/iconserver:v3.21.0` | `:8080` | Generates favicons and letter-based avatar fallback icons. |
| `redis` | `redis:7-alpine` | `:6379` | Fast in-memory state store with disk append-only persistence. |

---

## 4. Managing Persistent Maps

All map data is stored in the Docker volume `map-storage-data` (mounted at `/maps` inside the container).

### Uploading Maps via Web UI
1. Navigate to: `https://<YOUR_DOMAIN>/map-storage/ui/` (or `http://localhost/map-storage/ui/` locally).
2. Authenticate using the token value from `MAP_STORAGE_API_TOKEN` in your `.env`.
3. Upload your map ZIP bundle or directory exported from [Tiled Map Editor](https://www.mapeditor.org/).

### Uploading Maps via curl
```bash
curl -X POST "https://<YOUR_DOMAIN>/map-storage/upload-directory" \
  -H "Authorization: Bearer <MAP_STORAGE_API_TOKEN>" \
  -F "file=@my-office-map.zip"
```

### Changing Default Start Room
In `.env`, edit `START_ROOM_URL`:
```env
# To use your uploaded map:
START_ROOM_URL=/_/global/<YOUR_DOMAIN>/map-storage/my-office/map.json

# Or to use the official starter kit:
START_ROOM_URL=/_/global/maps.workadventu.re/starter/map.json
```
Then run `docker compose -f docker-compose.standalone.yaml up -d play`.

---

## 5. Video & Audio Options

### Default: Jitsi + WebRTC P2P
- **Meeting Rooms**: By default, stepping into a meeting area opens Jitsi Meet via `meet.jit.si`.
- **Proximity Bubbles**: Proximity conversation uses direct browser-to-browser WebRTC via Google STUN (`stun:stun.l.google.com:19302`). Supports up to 4 users per bubble with zero setup.

### Upgrading to LiveKit
For conferences or virtual offices with larger group sizes (5+ users per bubble):
1. Get a LiveKit instance (e.g. from [LiveKit Cloud](https://livekit.io) or self-hosted).
2. In `.env`, uncomment and set:
   ```env
   LIVEKIT_HOST=wss://your-livekit-instance.livekit.cloud
   LIVEKIT_API_KEY=your_api_key
   LIVEKIT_API_SECRET=your_api_secret
   ```
3. Restart containers:
   ```bash
   docker compose -f docker-compose.standalone.yaml up -d
   ```

---

## 6. Maintenance & Useful Commands

### Viewing Logs
```bash
# View all logs
docker compose -f docker-compose.standalone.yaml logs -f

# View specific service logs (e.g. play or traefik)
docker compose -f docker-compose.standalone.yaml logs -f play
docker compose -f docker-compose.standalone.yaml logs -f reverse-proxy
```

### Stopping and Starting
```bash
# Stop all services
docker compose -f docker-compose.standalone.yaml down

# Start all services in background
docker compose -f docker-compose.standalone.yaml up -d
```

### Backing Up Persistent Data
All maps, Redis records, and SSL certificates reside in Docker named volumes:
```bash
# Create a backup archive of maps and redis volumes
docker run --rm -v workadventure_map-storage-data:/maps -v $(pwd):/backup alpine tar czf /backup/maps-backup-$(date +%F).tar.gz -C /maps .
docker run --rm -v workadventure_redis-data:/data -v $(pwd):/backup alpine tar czf /backup/redis-backup-$(date +%F).tar.gz -C /data .
```

### Upgrading to a New WorkAdventure Version
1. Edit `VERSION` in `.env` (e.g. `VERSION=v1.34.0`).
2. Pull new images and restart:
   ```bash
   docker compose -f docker-compose.standalone.yaml pull
   docker compose -f docker-compose.standalone.yaml up -d
   ```
