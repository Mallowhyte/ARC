# ARC Setup Guide
## Complete Installation & Configuration Instructions

**Version:** 1.0.0  
**Last Updated:** November 2024

---

## 📋 Table of Contents
1. [Prerequisites](#prerequisites)
2. [Backend Setup](#backend-setup)
3. [Frontend Setup](#frontend-setup)
4. [Database Setup](#database-setup)
5. [Environment Configuration](#environment-configuration)
6. [Running the System](#running-the-system)
7. [Verification](#verification)

---

## 📦 Prerequisites

### Required Software

#### 1. Python 3.12 or Higher
**Download:** https://www.python.org/downloads/

**Verify installation:**
```bash
python --version
# Should show: Python 3.12.x or higher
```

#### 2. Tesseract OCR 5.3+
**Windows Download:** https://digi.bib.uni-mannheim.de/tesseract/tesseract-ocr-w64-setup-5.3.3.20231005.exe

**Installation:**
- Run the installer
- **Important:** Note the installation path (default: `C:\Program Files\Tesseract-OCR`)
- Check "Add to PATH" if available

**Verify installation:**
```bash
tesseract --version
# Should show: tesseract 5.3.3
```

#### 3. Flutter SDK 3.5+
**Download:** https://docs.flutter.dev/get-started/install

**Verify installation:**
```bash
flutter --version
# Should show: Flutter 3.5.x or higher

flutter doctor
# Check for any issues
```

#### 4. Git
**Download:** https://git-scm.com/downloads

**Verify installation:**
```bash
git --version
```

### Required Accounts

#### Supabase Account
**Sign up:** https://supabase.com

**You'll need:**
- Project URL
- Anon Key
- Service Role Key (optional, for advanced features)

---

## 🐍 Backend Setup

### Step 1: Clone Repository
```bash
cd C:\Users\Admin
git clone <repository-url> auto_file_classifier
cd auto_file_classifier\backend
```

### Step 2: Create Virtual Environment
```bash
# Create virtual environment
python -m venv venv

# Activate virtual environment
# Windows:
venv\Scripts\activate

# You should see (venv) in your terminal prompt
```

### Step 3: Install Dependencies
```bash
# Upgrade pip
python -m pip install --upgrade pip

# Install all requirements
pip install -r requirements.txt
```

**If you encounter errors:**

**Pillow build error:**
```bash
pip install --only-binary :all: Pillow
```

**pytesseract Python 3.14 compatibility:**
Already handled in `ocr_engine.py` with compatibility patch.

### Step 4: Configure Environment Variables

Create `.env` file in `backend/` directory:

```bash
# Copy template
copy .env.example .env

# Or create new file
```

**Edit `.env` with your values:**

```env
# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-supabase-anon-key

# Flask Configuration
SECRET_KEY=your-secret-key-here-change-in-production
HOST=0.0.0.0
PORT=5000

# Tesseract OCR Configuration
TESSERACT_PATH=C:\Program Files\Tesseract-OCR\tesseract.exe
OCR_LANGUAGE=eng

# ML Model Configuration (optional)
MODEL_PATH=models/classifier_model.pkl
CONFIDENCE_THRESHOLD=0.7

# Storage Configuration
STORAGE_BUCKET=documents
MAX_FILE_SIZE=16777216
```

**Important Notes:**
- Replace `SUPABASE_URL` and `SUPABASE_KEY` with your actual Supabase credentials
- Update `TESSERACT_PATH` if you installed Tesseract in a different location
- `HOST=0.0.0.0` is required for network access (physical device testing)
- `SECRET_KEY` should be changed for production

### Step 5: Verify Backend Setup

```bash
# Test Tesseract
python test_tesseract.py

# Expected output:
# ✓ Tesseract version: 5.3.3.20231005
# ✓ Path: C:\Program Files\Tesseract-OCR\tesseract.exe
# ✓ OCR extracted: 'Hello World! Test 123'
# ✓ OCR is working correctly!
```

### Step 6: Create Required Directories

```bash
# These are created automatically, but you can verify:
mkdir temp_uploads
mkdir models
```

---

## 📱 Frontend Setup

### Step 1: Navigate to Project Root

```bash
cd C:\Users\Admin\auto_file_classifier
```

### Step 2: Install Flutter Dependencies

```bash
flutter pub get
```

### Step 3: Configure Supabase

Edit `lib/config/supabase_config.dart`:

```dart
class SupabaseConfig {
  // Replace with your Supabase credentials
  static const String supabaseUrl = 'https://your-project.supabase.co';
  static const String supabaseAnonKey = 'your-supabase-anon-key';

  // Backend API Configuration
  // IMPORTANT: Replace with your computer's IP address
  // Run 'ipconfig' in CMD to find your IPv4 Address
  static const String backendUrl = 'http://192.168.1.100:5000'; // Your IP here!

  // API Endpoints
  static const String classifyEndpoint = '/api/classify';
  static const String documentsEndpoint = '/api/documents';
  static const String statsEndpoint = '/api/stats';
}
```

**Finding Your IP Address:**

**Windows:**
```bash
ipconfig
# Look for "IPv4 Address" under your active network adapter
# Example: 192.168.1.100
```

**Important Backend URL Configuration:**

| Environment | Backend URL |
|------------|-------------|
| **Web/Desktop** | `http://localhost:5000` |
| **Android Emulator** | `http://10.0.2.2:5000` |
| **Physical Device** | `http://YOUR_IP:5000` (e.g., `http://192.168.1.100:5000`) |

### Step 4: Verify Flutter Setup

```bash
flutter doctor

# Check for issues
# Install any missing dependencies
```

---

## 🗄️ Database Setup

### Step 1: Create Supabase Project

1. Go to https://supabase.com
2. Click "New Project"
3. Fill in project details
4. Wait for project to be created (2-3 minutes)

### Step 2: Get Supabase Credentials

1. Go to **Project Settings** → **API**
2. Copy **Project URL**
3. Copy **anon/public key**
4. Save these for configuration

### Step 3: Create Database Tables

1. Go to **SQL Editor** in Supabase dashboard
2. Click **New Query**
3. Copy and paste the following SQL:

```sql
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create documents table
CREATE TABLE IF NOT EXISTS documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id TEXT NOT NULL,
    filename VARCHAR(255) NOT NULL,
    storage_url TEXT NOT NULL,
    file_size INTEGER,
    file_type VARCHAR(50),
    document_type VARCHAR(100) NOT NULL,
    confidence NUMERIC(5,2) DEFAULT 0.00,
    extracted_text TEXT,
    keywords TEXT[],
    status VARCHAR(50) DEFAULT 'classified',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_documents_user_id ON documents(user_id);
CREATE INDEX IF NOT EXISTS idx_documents_type ON documents(document_type);
CREATE INDEX IF NOT EXISTS idx_documents_created_at ON documents(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_documents_status ON documents(status);

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email VARCHAR(255) UNIQUE NOT NULL,
    full_name VARCHAR(255),
    role VARCHAR(50) DEFAULT 'user',
    department VARCHAR(100),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for documents
CREATE POLICY "Users can view own documents" ON documents
    FOR SELECT USING (auth.uid()::text = user_id);

CREATE POLICY "Users can insert own documents" ON documents
    FOR INSERT WITH CHECK (auth.uid()::text = user_id);

CREATE POLICY "Users can update own documents" ON documents
    FOR UPDATE USING (auth.uid()::text = user_id);

CREATE POLICY "Users can delete own documents" ON documents
    FOR DELETE USING (auth.uid()::text = user_id);

-- Create RLS policies for users
CREATE POLICY "Users can view own data" ON users
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own data" ON users
    FOR UPDATE USING (auth.uid() = id);
```

4. Click **Run** to execute

### Step 4: Create Storage Bucket

**Option A: Using Supabase Dashboard**
1. Go to **Storage** in Supabase dashboard
2. Click **New bucket**
3. Name: `documents`
4. Set to **Private** (not public)
5. Click **Create bucket**

**Option B: Backend Will Create Automatically**
- The backend creates the bucket on first run if it doesn't exist
- This requires `service_role` key (optional)

### Step 5: Configure Storage Policies (Optional)

If using service role key or want custom policies:

1. Go to **Storage** → **Policies**
2. Create policies for the `documents` bucket:

```sql
-- Allow authenticated users to upload
CREATE POLICY "Authenticated users can upload"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'documents');

-- Allow users to read their own files
CREATE POLICY "Users can read own files"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'documents');
```

---

## ⚙️ Environment Configuration

### Backend Environment Variables

**File:** `backend/.env`

```env
# Supabase (REQUIRED)
SUPABASE_URL=https://yfosfxhwxikgqpjdtvlo.supabase.co
SUPABASE_KEY=your-anon-key-here

# Flask (REQUIRED)
SECRET_KEY=change-this-to-random-string-in-production
HOST=0.0.0.0
PORT=5000

# Tesseract (REQUIRED)
TESSERACT_PATH=C:\Program Files\Tesseract-OCR\tesseract.exe
OCR_LANGUAGE=eng

# Optional Settings
MODEL_PATH=models/classifier_model.pkl
CONFIDENCE_THRESHOLD=0.7
STORAGE_BUCKET=documents
MAX_FILE_SIZE=16777216
```

### Frontend Configuration

**File:** `lib/config/supabase_config.dart`

```dart
static const String supabaseUrl = 'https://yfosfxhwxikgqpjdtvlo.supabase.co';
static const String supabaseAnonKey = 'your-anon-key-here';
static const String backendUrl = 'http://192.168.1.100:5000';
```

---

## 🚀 Running the System

### Step 1: Start Backend Server

```bash
# Navigate to backend directory
cd C:\Users\Admin\auto_file_classifier\backend

# Activate virtual environment
venv\Scripts\activate

# Start Flask server
python app.py
```

**Expected output:**
```
Initializing services...
✓ Tesseract OCR 5.3.3.20231005 detected
ℹ Using keyword-based classification
ℹ Storage bucket 'documents' exists
============================================================
🎓 ARC Backend API - AI-based Record Classifier
============================================================
Version: 1.0.0
Environment: Development
Debug Mode: ON
Host: 0.0.0.0
Port: 5000
============================================================
Available Endpoints:
  → GET  /           (API Info)
  → GET  /health     (Health Check)
  → POST /api/classify
  → GET  /api/documents
  → GET  /api/stats
============================================================
✓ Server is running!
   Access at: http://localhost:5000
   Network:    http://192.168.1.100:5000
============================================================
 * Running on all addresses (0.0.0.0)
 * Running on http://127.0.0.1:5000
 * Running on http://192.168.1.100:5000
```

### Step 2: Start Flutter App

**Terminal 2 (keep backend running):**

```bash
# Navigate to project root
cd C:\Users\Admin\auto_file_classifier

# Run on connected device or emulator
flutter run

# Or specify device:
flutter run -d chrome     # For web
flutter run -d windows    # For Windows desktop
flutter run -d <device-id> # For specific device
```

**List available devices:**
```bash
flutter devices
```

---

## ✅ Verification

### Backend Health Check

**Test 1: Root Endpoint**
```bash
curl http://localhost:5000/
```

**Expected response:**
```json
{
  "service": "ARC Backend API",
  "version": "1.0.0",
  "status": "running",
  "endpoints": {
    "health": "/health",
    "classify": "/api/classify (POST)",
    "statistics": "/api/stats",
    "user_documents": "/api/documents/{user_id}"
  }
}
```

**Test 2: Health Check**
```bash
curl http://localhost:5000/health
```

**Expected response:**
```json
{
  "status": "healthy",
  "service": "ARC Backend API",
  "version": "1.0.0"
}
```

**Test 3: Tesseract OCR**
```bash
python test_tesseract.py
```

### Frontend Verification

1. **Launch App** - App should open without errors
2. **Sign Up** - Create a test account
3. **Verify Email** - Check email for OTP code
4. **Login** - Login with created account
5. **Upload Test** - Try uploading a document
6. **View Documents** - Check if document appears in list
7. **Statistics** - Verify statistics show uploaded document

### Network Connectivity Test (Physical Device)

**From your phone browser:**
```
http://YOUR_IP:5000/health
```

Should return JSON response immediately. If timeout:
- Check Windows Firewall
- Verify IP address is correct
- Ensure backend is running
- Check phone and PC are on same network

---

## 🔥 Common Setup Issues

### Issue 1: Tesseract Not Found

**Error:** `tesseract is not installed or it's not in your PATH`

**Solution:**
1. Install Tesseract: https://digi.bib.uni-mannheim.de/tesseract/tesseract-ocr-w64-setup-5.3.3.20231005.exe
2. Update `.env` with correct path:
   ```env
   TESSERACT_PATH=C:\Program Files\Tesseract-OCR\tesseract.exe
   ```
3. Restart backend

### Issue 2: Python Module Not Found

**Error:** `ModuleNotFoundError: No module named 'xxx'`

**Solution:**
```bash
# Ensure virtual environment is activated
venv\Scripts\activate

# Reinstall requirements
pip install -r requirements.txt
```

### Issue 3: Flutter Pub Get Fails

**Error:** Package resolution errors

**Solution:**
```bash
flutter clean
flutter pub get
```

### Issue 4: Backend Connection Timeout

**Error:** `Connection refused` or timeout

**Solution:**
- Backend URL must match your environment
- Physical device: Use computer's IP
- Android emulator: Use `10.0.2.2`
- Web/desktop: Use `localhost`
- Check Windows Firewall

### Issue 5: Database Column Not Found

**Error:** `column 'filename' does not exist`

**Solution:**
Run the migration SQL in Supabase SQL Editor:
```sql
ALTER TABLE documents RENAME COLUMN file_name TO filename;
ALTER TABLE documents RENAME COLUMN file_path TO storage_url;
```

---

## 📞 Next Steps

- ✅ **Test Upload Flow** - Upload various document types
- ✅ **Review Logs** - Check backend terminal for errors
- ✅ **Configure Production** - Update environment variables for production
- ✅ **Setup Monitoring** - Configure error tracking
- ✅ **Review Security** - Check RLS policies and CORS settings

**For troubleshooting, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md)**  
**For API details, see [API_DOCUMENTATION.md](API_DOCUMENTATION.md)**
