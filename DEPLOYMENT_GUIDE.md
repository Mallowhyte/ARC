# ARC Deployment Guide
## Production Deployment Instructions

**Version:** 1.0.0  
**Last Updated:** November 2024

---

## 📋 Table of Contents
1. [Pre-Deployment Checklist](#pre-deployment-checklist)
2. [Backend Deployment](#backend-deployment)
3. [Frontend Deployment](#frontend-deployment)
4. [Database Configuration](#database-configuration)
5. [Security Hardening](#security-hardening)
6. [Monitoring & Maintenance](#monitoring--maintenance)
7. [Backup Strategy](#backup-strategy)

---

## ✅ Pre-Deployment Checklist

### Code Review
- [ ] All features tested and working
- [ ] No console.log or debug statements in production code
- [ ] Error handling implemented
- [ ] Input validation in place
- [ ] Security vulnerabilities addressed

### Environment
- [ ] Production environment variables configured
- [ ] Secrets not committed to repository
- [ ] API keys rotated from development
- [ ] Database backup created

### Performance
- [ ] Load testing completed
- [ ] Database indexes optimized
- [ ] Large files handling tested
- [ ] Concurrent user testing done

### Documentation
- [ ] API documentation complete
- [ ] Setup guide reviewed
- [ ] Troubleshooting guide updated
- [ ] User manual prepared

---

## 🐍 Backend Deployment

### Option 1: Traditional Server (VPS)

#### Prerequisites
- Ubuntu 20.04+ or similar Linux server
- Domain name configured
- SSL certificate (Let's Encrypt)

#### Step 1: Server Setup

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Python 3.12
sudo apt install python3.12 python3.12-venv python3-pip -y

# Install Tesseract OCR
sudo apt install tesseract-ocr -y
sudo apt install libtesseract-dev -y

# Install system dependencies
sudo apt install libpq-dev python3-dev build-essential -y

# Install Nginx
sudo apt install nginx -y

# Install Supervisor (for process management)
sudo apt install supervisor -y
```

#### Step 2: Deploy Application

```bash
# Create application directory
sudo mkdir -p /var/www/arc-backend
cd /var/www/arc-backend

# Clone repository
git clone <your-repo-url> .

# Create virtual environment
python3.12 -m venv venv
source venv/bin/activate

# Install dependencies
pip install --upgrade pip
pip install -r requirements.txt
pip install gunicorn  # Production WSGI server
```

#### Step 3: Configure Environment

```bash
# Create production .env
sudo nano /var/www/arc-backend/.env
```

```env
# Production Environment Variables
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-production-anon-key

SECRET_KEY=your-very-long-random-secret-key-change-this
HOST=0.0.0.0
PORT=8000

TESSERACT_PATH=/usr/bin/tesseract
OCR_LANGUAGE=eng

FLASK_ENV=production
FLASK_DEBUG=False

STORAGE_BUCKET=documents
MAX_FILE_SIZE=16777216
```

#### Step 4: Configure Gunicorn

```bash
# Create Gunicorn config
sudo nano /var/www/arc-backend/gunicorn_config.py
```

```python
import multiprocessing

# Server socket
bind = "127.0.0.1:8000"
backlog = 2048

# Worker processes
workers = multiprocessing.cpu_count() * 2 + 1
worker_class = "sync"
worker_connections = 1000
timeout = 120
keepalive = 2

# Logging
accesslog = "/var/log/arc/access.log"
errorlog = "/var/log/arc/error.log"
loglevel = "info"

# Process naming
proc_name = "arc-backend"

# Server mechanics
daemon = False
pidfile = "/var/run/arc-backend.pid"
umask = 0
user = None
group = None
tmp_upload_dir = None
```

#### Step 5: Configure Supervisor

```bash
# Create supervisor config
sudo nano /etc/supervisor/conf.d/arc-backend.conf
```

```ini
[program:arc-backend]
command=/var/www/arc-backend/venv/bin/gunicorn -c gunicorn_config.py app:app
directory=/var/www/arc-backend
user=www-data
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
stderr_logfile=/var/log/arc/error.log
stdout_logfile=/var/log/arc/access.log
```

```bash
# Create log directory
sudo mkdir -p /var/log/arc
sudo chown www-data:www-data /var/log/arc

# Reload supervisor
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start arc-backend

# Check status
sudo supervisorctl status arc-backend
```

#### Step 6: Configure Nginx

```bash
# Create Nginx config
sudo nano /etc/nginx/sites-available/arc-backend
```

```nginx
server {
    listen 80;
    server_name api.yourdomain.com;

    # Redirect HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.yourdomain.com;

    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/api.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.yourdomain.com/privkey.pem;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Upload size limit
    client_max_body_size 16M;

    # Proxy settings
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 120s;
    }

    # Health check endpoint
    location /health {
        proxy_pass http://127.0.0.1:8000/health;
        access_log off;
    }
}
```

```bash
# Enable site
sudo ln -s /etc/nginx/sites-available/arc-backend /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```

#### Step 7: SSL Certificate (Let's Encrypt)

```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx -y

# Obtain certificate
sudo certbot --nginx -d api.yourdomain.com

# Auto-renewal is configured automatically
# Test renewal
sudo certbot renew --dry-run
```

---

### Option 2: Docker Deployment

#### Dockerfile

Create `Dockerfile` in backend directory:

```dockerfile
FROM python:3.12-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    tesseract-ocr \
    libtesseract-dev \
    libpq-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install gunicorn

# Copy application
COPY . .

# Create directories
RUN mkdir -p temp_uploads models logs

# Expose port
EXPOSE 8000

# Run with Gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "4", "--timeout", "120", "app:app"]
```

#### docker-compose.yml

```yaml
version: '3.8'

services:
  backend:
    build: ./backend
    ports:
      - "8000:8000"
    environment:
      - SUPABASE_URL=${SUPABASE_URL}
      - SUPABASE_KEY=${SUPABASE_KEY}
      - SECRET_KEY=${SECRET_KEY}
      - FLASK_ENV=production
      - TESSERACT_PATH=/usr/bin/tesseract
    volumes:
      - ./backend/temp_uploads:/app/temp_uploads
      - ./backend/models:/app/models
      - ./backend/logs:/app/logs
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

#### Deploy with Docker

```bash
# Build image
docker-compose build

# Start container
docker-compose up -d

# Check logs
docker-compose logs -f backend

# Check status
docker-compose ps
```

---

### Option 3: Cloud Platform (Heroku)

#### Procfile

Create `Procfile` in backend directory:

```
web: gunicorn --bind 0.0.0.0:$PORT --timeout 120 app:app
```

#### runtime.txt

```
python-3.12.0
```

#### Deploy to Heroku

```bash
# Login to Heroku
heroku login

# Create app
heroku create arc-backend

# Set environment variables
heroku config:set SUPABASE_URL=your-url
heroku config:set SUPABASE_KEY=your-key
heroku config:set SECRET_KEY=your-secret
heroku config:set FLASK_ENV=production

# Add Tesseract buildpack
heroku buildpacks:add --index 1 https://github.com/pathwaycom/heroku-buildpack-tesseract

# Deploy
git push heroku main

# Check logs
heroku logs --tail
```

---

## 📱 Frontend Deployment

### Option 1: Web Deployment (Flutter Web)

#### Build for Production

```bash
# Clean build
flutter clean

# Build web version
flutter build web --release --web-renderer canvaskit

# Output: build/web/
```

#### Deploy to Netlify

```bash
# Install Netlify CLI
npm install -g netlify-cli

# Deploy
cd build/web
netlify deploy --prod
```

**Or via Netlify Dashboard:**
1. Go to https://app.netlify.com
2. Drag and drop `build/web` folder
3. Configure custom domain

#### Deploy to Firebase Hosting

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login
firebase login

# Initialize
firebase init hosting

# Deploy
firebase deploy --only hosting
```

---

### Option 2: Mobile App Deployment

#### Android (Google Play Store)

**Step 1: Prepare Release Build**

```bash
# Generate signing key
keytool -genkey -v -keystore ~/arc-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias arc
```

**Step 2: Configure Signing**

Create `android/key.properties`:

```properties
storePassword=your-store-password
keyPassword=your-key-password
keyAlias=arc
storeFile=../arc-release-key.jks
```

Edit `android/app/build.gradle`:

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    ...
    
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

**Step 3: Build APK/AAB**

```bash
# Build APK
flutter build apk --release

# Build App Bundle (for Play Store)
flutter build appbundle --release
```

**Step 4: Upload to Play Store**
1. Create Google Play Developer account
2. Create new application
3. Upload AAB file
4. Fill in store listing
5. Submit for review

---

#### iOS (App Store)

**Prerequisites:**
- Apple Developer Account ($99/year)
- Mac with Xcode

**Step 1: Open in Xcode**

```bash
open ios/Runner.xcworkspace
```

**Step 2: Configure Signing**
- Select Runner target
- Signing & Capabilities tab
- Select your team
- Xcode handles provisioning

**Step 3: Build for Release**

```bash
flutter build ios --release
```

**Step 4: Archive and Upload**
- Product → Archive in Xcode
- Distribute App
- App Store Connect
- Upload

---

## 🗄️ Database Configuration

### Production Settings

#### Enable Connection Pooling

```python
# backend/supabase_client.py
from supabase import create_client, Client

class SupabaseClient:
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            url = os.getenv('SUPABASE_URL')
            key = os.getenv('SUPABASE_KEY')
            cls._instance.client = create_client(url, key)
        return cls._instance
```

#### Database Backups

**Automated Backups:**
- Supabase provides automatic daily backups
- Retention: 7 days (Free), 30 days (Pro)

**Manual Backup:**

```bash
# Using pg_dump
pg_dump -h db.your-project.supabase.co -U postgres -d postgres > backup.sql
```

**Schedule Backups:**

```bash
# Cron job (daily at 2 AM)
0 2 * * * /path/to/backup-script.sh
```

---

## 🔒 Security Hardening

### Backend Security

#### 1. Environment Variables

```env
# Use strong secrets
SECRET_KEY=$(openssl rand -hex 32)

# Use service role key sparingly
SUPABASE_SERVICE_KEY=only-for-admin-operations
```

#### 2. Rate Limiting

```python
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

limiter = Limiter(
    app,
    key_func=get_remote_address,
    default_limits=["200 per day", "50 per hour"]
)

@app.route('/api/classify', methods=['POST'])
@limiter.limit("10 per minute")
def classify_document():
    # ... existing code
```

#### 3. CORS Configuration

```python
from flask_cors import CORS

CORS(app, resources={
    r"/api/*": {
        "origins": ["https://yourdomain.com"],
        "methods": ["GET", "POST"],
        "allow_headers": ["Content-Type", "Authorization"]
    }
})
```

#### 4. Input Validation

```python
from werkzeug.utils import secure_filename

def allowed_file(filename):
    ALLOWED_EXTENSIONS = {'pdf', 'png', 'jpg', 'jpeg', 'tiff', 'bmp'}
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS
```

### Database Security

#### 1. Enable RLS

```sql
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
```

#### 2. Restrict Service Role Usage

- Use anon key for client-side operations
- Use service role key only for admin/backend operations
- Never expose service role key in frontend

#### 3. Audit Logging

```sql
-- Create audit log table
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id TEXT,
    action VARCHAR(50),
    table_name VARCHAR(50),
    record_id UUID,
    changes JSONB,
    ip_address INET,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 📊 Monitoring & Maintenance

### Application Monitoring

#### 1. Health Check Endpoint

```python
@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        'status': 'healthy',
        'service': 'ARC Backend API',
        'version': '1.0.0',
        'timestamp': datetime.now().isoformat()
    }), 200
```

#### 2. Logging

```python
import logging
from logging.handlers import RotatingFileHandler

# Configure logging
handler = RotatingFileHandler('logs/app.log', maxBytes=10000000, backupCount=5)
handler.setLevel(logging.INFO)
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
handler.setFormatter(formatter)
app.logger.addHandler(handler)
```

#### 3. Error Tracking

**Sentry Integration:**

```bash
pip install sentry-sdk[flask]
```

```python
import sentry_sdk
from sentry_sdk.integrations.flask import FlaskIntegration

sentry_sdk.init(
    dsn="your-sentry-dsn",
    integrations=[FlaskIntegration()],
    traces_sample_rate=1.0
)
```

### Database Monitoring

#### Supabase Dashboard
- Monitor query performance
- Check storage usage
- Review API usage

#### Query Optimization

```sql
-- Analyze slow queries
SELECT * FROM pg_stat_statements 
ORDER BY total_exec_time DESC 
LIMIT 10;

-- Add indexes for frequently queried columns
CREATE INDEX IF NOT EXISTS idx_documents_user_type 
ON documents(user_id, document_type);
```

---

## 💾 Backup Strategy

### Automated Backups

#### Database Backups

**Script:** `scripts/backup-database.sh`

```bash
#!/bin/bash

# Configuration
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups/database"
DB_NAME="arc_production"

# Create backup
pg_dump -h $DB_HOST -U $DB_USER -d $DB_NAME > "$BACKUP_DIR/backup_$DATE.sql"

# Compress backup
gzip "$BACKUP_DIR/backup_$DATE.sql"

# Delete backups older than 30 days
find $BACKUP_DIR -name "*.sql.gz" -mtime +30 -delete

# Upload to cloud storage (optional)
aws s3 cp "$BACKUP_DIR/backup_$DATE.sql.gz" s3://your-bucket/backups/
```

#### Storage Backups

Supabase Storage handles backups automatically, but you can also:

```python
# Backup script to download all files
from supabase import create_client

client = create_client(url, key)
files = client.storage.from_('documents').list()

for file in files:
    # Download and save locally
    data = client.storage.from_('documents').download(file['name'])
    with open(f"backup/{file['name']}", 'wb') as f:
        f.write(data)
```

### Disaster Recovery

#### Recovery Steps

1. **Database Recovery:**
```bash
# Restore from backup
psql -h $DB_HOST -U $DB_USER -d $DB_NAME < backup_20241113.sql
```

2. **Application Recovery:**
```bash
# Redeploy from repository
git pull origin main
sudo supervisorctl restart arc-backend
```

3. **Verify:**
```bash
curl https://api.yourdomain.com/health
```

---

## 📝 Post-Deployment Checklist

- [ ] All services running
- [ ] SSL certificate valid
- [ ] Health check responds
- [ ] Test document upload
- [ ] Monitor error logs
- [ ] Backup system verified
- [ ] Monitoring dashboards configured
- [ ] Team notified of deployment

---

## 📚 Related Documentation

- [SETUP_GUIDE.md](SETUP_GUIDE.md) - Development setup
- [API_DOCUMENTATION.md](API_DOCUMENTATION.md) - API reference
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues
- [SYSTEM_OVERVIEW.md](SYSTEM_OVERVIEW.md) - Architecture overview
