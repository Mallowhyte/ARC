# ARC Setup Guide

Complete guide for setting up the ARC - AI-based Record Classifier system.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Backend Setup](#backend-setup)
3. [Supabase Setup](#supabase-setup)
4. [Flutter App Setup](#flutter-app-setup)
5. [Testing](#testing)
6. [Deployment](#deployment)

---

## Prerequisites

### Software Requirements

- **Python 3.8+**
- **Flutter SDK 3.9.2+**
- **Node.js 16+** (for Supabase CLI)
- **Tesseract OCR**
- **Git**

### Install Tesseract OCR

**Windows:**
```bash
# Download and install from:
https://github.com/UB-Mannheim/tesseract/wiki

# Add to PATH:
C:\Program Files\Tesseract-OCR
```

**macOS:**
```bash
brew install tesseract
```

**Linux:**
```bash
sudo apt-get install tesseract-ocr
```

---

## Backend Setup

### 1. Navigate to Backend Directory

```bash
cd backend
```

### 2. Create Virtual Environment

```bash
# Windows
python -m venv venv
venv\Scripts\activate

# macOS/Linux
python3 -m venv venv
source venv/bin/activate
```

### 3. Install Dependencies

```bash
pip install -r requirements.txt
```

### 4. Configure Environment Variables

Copy the example environment file:

```bash
cp .env.example .env
```

Edit `.env` with your credentials:

```env
# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-anon-key
SUPABASE_SERVICE_KEY=your-service-role-key

# Flask Configuration
FLASK_ENV=development
FLASK_DEBUG=True
SECRET_KEY=your-secret-key-here

# Server Configuration
PORT=5000
HOST=0.0.0.0

# ML Model Configuration
MODEL_PATH=models/classifier_model.pkl
CONFIDENCE_THRESHOLD=0.7

# OCR Configuration
TESSERACT_PATH=/usr/bin/tesseract  # Adjust for your system
OCR_LANGUAGE=eng
```

### 5. Create Models Directory

```bash
mkdir models
```

### 6. Test Backend

```bash
python app.py
```

You should see:
```
Starting ARC Backend API on 0.0.0.0:5000
```

Test the health endpoint:
```bash
curl http://localhost:5000/health
```

---

## Supabase Setup

### 1. Create Supabase Project

1. Go to [supabase.com](https://supabase.com)
2. Click "New Project"
3. Fill in project details:
   - Name: `arc-classifier`
   - Database Password: (save this!)
   - Region: Choose closest to you

### 2. Get API Credentials

1. Go to Project Settings → API
2. Copy:
   - Project URL
   - `anon` `public` key
   - `service_role` `secret` key

### 3. Create Database Tables

In Supabase SQL Editor, run:

```sql
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create documents table
CREATE TABLE documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id VARCHAR(255) NOT NULL,
    filename VARCHAR(500) NOT NULL,
    document_type VARCHAR(100) NOT NULL,
    confidence DECIMAL(3,2) NOT NULL,
    extracted_text TEXT,
    storage_url TEXT NOT NULL,
    status VARCHAR(50) DEFAULT 'classified',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX idx_documents_user_id ON documents(user_id);
CREATE INDEX idx_documents_document_type ON documents(document_type);
CREATE INDEX idx_documents_created_at ON documents(created_at DESC);

-- Enable RLS
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Enable read access for all users" ON documents
    FOR SELECT USING (true);

CREATE POLICY "Enable insert for all users" ON documents
    FOR INSERT WITH CHECK (true);
```

### 4. Create Storage Bucket

1. Go to Storage in Supabase Dashboard
2. Click "New Bucket"
3. Name: `documents`
4. Make it **Private**
5. Click "Create Bucket"

### 5. Configure Storage Policies

In the Storage Policies section:

```sql
-- Allow all authenticated users to upload
CREATE POLICY "Allow uploads" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'documents');

-- Allow all users to read
CREATE POLICY "Allow reads" ON storage.objects
    FOR SELECT USING (bucket_id = 'documents');
```

---

## Flutter App Setup

### 1. Install Flutter Dependencies

```bash
flutter pub get
```

### 2. Configure Supabase Credentials

Edit `lib/config/supabase_config.dart`:

```dart
class SupabaseConfig {
  static const String supabaseUrl = 'https://your-project.supabase.co';
  static const String supabaseAnonKey = 'your-anon-key-here';
  
  static const String backendUrl = 'http://localhost:5000';
  // For Android Emulator, use: 'http://10.0.2.2:5000'
  // For iOS Simulator, use: 'http://localhost:5000'
  // For physical device, use your computer's IP: 'http://192.168.x.x:5000'
}
```

### 3. Platform-Specific Setup

#### Android

Add permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
```

#### iOS

Add to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>We need access to camera to scan documents</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to photo library to select documents</string>
```

### 4. Run the App

```bash
# Check connected devices
flutter devices

# Run on specific device
flutter run -d <device-id>

# Or just run
flutter run
```

---

## Testing

### Backend Tests

```bash
cd backend

# Test health endpoint
curl http://localhost:5000/health

# Test classification (with a sample PDF)
curl -X POST http://localhost:5000/api/classify \
  -F "file=@sample_document.pdf" \
  -F "user_id=test_user"

# Get documents
curl "http://localhost:5000/api/documents?user_id=test_user"

# Get statistics
curl "http://localhost:5000/api/stats?user_id=test_user"
```

### Flutter Tests

```bash
# Run unit tests
flutter test

# Run integration tests
flutter drive --target=test_driver/app.dart
```

---

## Deployment

### Backend Deployment

#### Option 1: Heroku

```bash
# Install Heroku CLI
# https://devcenter.heroku.com/articles/heroku-cli

# Login
heroku login

# Create app
heroku create arc-backend

# Add buildpack
heroku buildpacks:add --index 1 https://github.com/heroku/heroku-buildpack-apt
heroku buildpacks:add --index 2 heroku/python

# Create Aptfile for Tesseract
echo "tesseract-ocr" > Aptfile
echo "tesseract-ocr-eng" >> Aptfile

# Set environment variables
heroku config:set SUPABASE_URL=your_url
heroku config:set SUPABASE_KEY=your_key
# ... other env vars

# Deploy
git push heroku main

# Check logs
heroku logs --tail
```

#### Option 2: Railway

1. Go to [railway.app](https://railway.app)
2. Create new project
3. Deploy from GitHub
4. Add environment variables
5. Deploy!

### Flutter App Deployment

#### Android

```bash
# Build APK
flutter build apk --release

# Build App Bundle
flutter build appbundle --release

# APK location:
# build/app/outputs/flutter-apk/app-release.apk
```

#### iOS

```bash
# Build IPA
flutter build ios --release

# Open in Xcode for signing and upload
open ios/Runner.xcworkspace
```

---

## Troubleshooting

### Backend Issues

**Issue: Tesseract not found**
```
Solution: Install Tesseract and set TESSERACT_PATH in .env
```

**Issue: Supabase connection failed**
```
Solution: Check SUPABASE_URL and SUPABASE_KEY in .env
```

**Issue: Import errors**
```
Solution: Activate virtual environment and reinstall dependencies
pip install -r requirements.txt
```

### Flutter Issues

**Issue: Supabase connection timeout**
```
Solution: Check network connectivity and Supabase credentials
```

**Issue: Backend connection refused**
```
Solution: 
- Ensure backend is running
- Check backend URL in supabase_config.dart
- For Android emulator, use http://10.0.2.2:5000
```

**Issue: File picker not working**
```
Solution: Add permissions to AndroidManifest.xml and Info.plist
```

---

## Next Steps

1. ✅ Test the complete workflow
2. ✅ Upload sample documents
3. ✅ Review classification results
4. ✅ Train custom ML model (optional)
5. ✅ Configure user authentication
6. ✅ Deploy to production

---

## Support

For issues and questions:
- Check [API Documentation](api_endpoints.md)
- Review [Database Schema](database_schema.md)
- See [ML Training Guide](ml_model_training.md)

---

## Security Checklist

Before deploying to production:

- [ ] Change all default secrets and keys
- [ ] Enable Supabase RLS policies
- [ ] Use environment variables for sensitive data
- [ ] Enable HTTPS for backend
- [ ] Implement user authentication
- [ ] Set up rate limiting
- [ ] Configure CORS properly
- [ ] Regular security updates
- [ ] Backup database regularly
- [ ] Monitor error logs
