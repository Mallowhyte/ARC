# ARC Troubleshooting Guide
## Common Issues and Solutions

**Version:** 1.0.0  
**Last Updated:** November 2024

---

## 📋 Table of Contents
1. [Backend Issues](#backend-issues)
2. [Frontend Issues](#frontend-issues)
3. [Database Issues](#database-issues)
4. [Network Issues](#network-issues)
5. [OCR Issues](#ocr-issues)
6. [Authentication Issues](#authentication-issues)
7. [Performance Issues](#performance-issues)

---

## 🐍 Backend Issues

### Issue 1: Tesseract Not Found

**Error:**
```
⚠ WARNING: Tesseract OCR not found!
Error: tesseract is not installed or it's not in your PATH
```

**Cause:** Tesseract OCR is not installed or path is incorrect.

**Solutions:**

**Option A: Install Tesseract**
1. Download: https://digi.bib.uni-mannheim.de/tesseract/tesseract-ocr-w64-setup-5.3.3.20231005.exe
2. Run installer
3. Note installation path (default: `C:\Program Files\Tesseract-OCR`)
4. Restart backend

**Option B: Update Path in .env**
```env
TESSERACT_PATH=C:\Program Files\Tesseract-OCR\tesseract.exe
```

**Verify:**
```bash
# In new command prompt
tesseract --version

# Or test from backend
cd backend
python test_tesseract.py
```

---

### Issue 2: Module Not Found

**Error:**
```
ModuleNotFoundError: No module named 'xxx'
```

**Cause:** Python dependencies not installed or wrong virtual environment.

**Solutions:**

**Step 1: Verify Virtual Environment**
```bash
cd backend

# Check if (venv) appears in prompt
# If not, activate:
venv\Scripts\activate
```

**Step 2: Reinstall Dependencies**
```bash
pip install -r requirements.txt
```

**Step 3: Check Python Version**
```bash
python --version
# Should be 3.12 or higher
```

**Step 4: Nuclear Option (if still failing)**
```bash
# Delete venv
rmdir /s venv

# Recreate
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
```

---

### Issue 3: Backend Won't Start

**Error:**
```
Address already in use
```

**Cause:** Port 5000 is already in use by another process.

**Solutions:**

**Option A: Kill Process Using Port 5000**
```bash
# Find process using port 5000
netstat -ano | findstr :5000

# Kill process (replace PID with actual number)
taskkill /PID <PID> /F
```

**Option B: Use Different Port**

Edit `backend/.env`:
```env
PORT=5001
```

Update `lib/config/supabase_config.dart`:
```dart
static const String backendUrl = 'http://192.168.1.100:5001';
```

---

### Issue 4: Supabase Connection Failed

**Error:**
```
Error: Unable to connect to Supabase
```

**Cause:** Invalid Supabase credentials or network issue.

**Solutions:**

**Step 1: Verify Credentials**

Check `backend/.env`:
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-anon-key
```

**Step 2: Test Supabase Connection**
```python
from supabase import create_client
import os
from dotenv import load_dotenv

load_dotenv()

url = os.getenv('SUPABASE_URL')
key = os.getenv('SUPABASE_KEY')

try:
    client = create_client(url, key)
    print("✓ Supabase connection successful")
except Exception as e:
    print(f"✗ Connection failed: {e}")
```

**Step 3: Check Supabase Dashboard**
- Go to https://supabase.com
- Check if project is running
- Verify project URL matches

---

### Issue 5: File Upload to Storage Fails

**Error:**
```
❌ Error uploading file: Unauthorized
```

**Cause:** Storage bucket doesn't exist or RLS policies are blocking.

**Solutions:**

**Option A: Create Bucket Manually**
1. Go to Supabase → Storage
2. Create bucket named `documents`
3. Set to Private

**Option B: Update Storage Policies**
```sql
-- Allow authenticated users to upload
CREATE POLICY "Authenticated users can upload"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'documents');
```

**Option C: Temporarily Disable RLS (Testing Only)**
```sql
ALTER TABLE storage.objects DISABLE ROW LEVEL SECURITY;
```
⚠️ **Warning:** Re-enable for production!

---

### Issue 6: OCR Returns Empty Text

**Error:**
```
Could not extract sufficient text from document
```

**Cause:** Image quality is poor or OCR cannot read the text.

**Solutions:**

**Check 1: Image Quality**
- Ensure image is clear and not blurry
- Minimum resolution: 300 DPI recommended
- Text should be horizontal (not rotated)

**Check 2: Test with Sample Image**
```bash
cd backend
python test_tesseract.py
```

**Check 3: Adjust OCR Settings**

Edit `backend/ocr_engine.py`:
```python
# Try different PSM modes
text = pytesseract.image_to_string(
    pil_img,
    lang=self.ocr_language,
    config='--psm 3'  # Try values 3-13
)
```

PSM Modes:
- `3` - Fully automatic page segmentation (default)
- `6` - Uniform block of text
- `11` - Sparse text

---

## 📱 Frontend Issues

### Issue 1: Flutter Pub Get Fails

**Error:**
```
version solving failed
```

**Cause:** Dependency conflicts or corrupted cache.

**Solutions:**

**Step 1: Clean and Retry**
```bash
flutter clean
flutter pub get
```

**Step 2: Update Flutter**
```bash
flutter upgrade
flutter pub get
```

**Step 3: Check pubspec.yaml**
- Ensure proper indentation
- Verify version numbers
- Remove `pubspec.lock` and retry:
```bash
del pubspec.lock
flutter pub get
```

---

### Issue 2: Supabase Initialization Failed

**Error:**
```
Supabase.initialize() must be called before accessing instance
```

**Cause:** Supabase not initialized in main.dart.

**Solution:**

Check `lib/main.dart`:
```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );
  
  runApp(const MyApp());
}
```

---

### Issue 3: setState Called After Dispose

**Error:**
```
setState() called after dispose()
```

**Cause:** Async operation completes after widget is removed.

**Solution:**

Add mounted check before setState:
```dart
Future<void> someAsyncFunction() async {
  // ... async work ...
  
  if (!mounted) return;  // Check if widget is still mounted
  setState(() {
    // Update state
  });
}
```

---

### Issue 4: Image Picker Not Working

**Error:**
```
PlatformException: photo_access_denied
```

**Cause:** Missing permissions.

**Solutions:**

**Android:**

Edit `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

**iOS:**

Edit `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to capture documents</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need photo library access to select documents</string>
```

---

## 🗄️ Database Issues

### Issue 1: Column Does Not Exist

**Error:**
```
column "filename" does not exist
```

**Cause:** Database schema doesn't match backend expectations.

**Solution:**

Run migration in Supabase SQL Editor:
```sql
-- Rename columns
ALTER TABLE documents RENAME COLUMN file_name TO filename;
ALTER TABLE documents RENAME COLUMN file_path TO storage_url;

-- Or add missing columns
ALTER TABLE documents ADD COLUMN IF NOT EXISTS filename VARCHAR(255);
ALTER TABLE documents ADD COLUMN IF NOT EXISTS storage_url TEXT;
ALTER TABLE documents ADD COLUMN IF NOT EXISTS confidence NUMERIC(5,2);
```

---

### Issue 2: RLS Policy Blocks Insert

**Error:**
```
new row violates row-level security policy
```

**Cause:** Row-Level Security policies are blocking the operation.

**Solutions:**

**Step 1: Check User ID Matches**
- Ensure `user_id` in insert matches authenticated user

**Step 2: Review RLS Policies**
```sql
-- Check existing policies
SELECT * FROM pg_policies WHERE tablename = 'documents';
```

**Step 3: Fix Policy**
```sql
-- Drop and recreate
DROP POLICY IF EXISTS "Users can insert own documents" ON documents;

CREATE POLICY "Users can insert own documents" ON documents
FOR INSERT WITH CHECK (auth.uid()::text = user_id);
```

**Step 4: Temporary Disable (Testing Only)**
```sql
ALTER TABLE documents DISABLE ROW LEVEL SECURITY;
```
⚠️ **Warning:** Re-enable for production!

---

### Issue 3: Cannot Connect to Database

**Error:**
```
connection refused / timeout
```

**Cause:** Database is paused or network issue.

**Solutions:**

**Step 1: Check Supabase Dashboard**
- Go to https://supabase.com
- Check if project is active (not paused)
- Free tier projects pause after inactivity

**Step 2: Restart Project**
- Click "Restore" if paused
- Wait 2-3 minutes for project to start

**Step 3: Verify Connection String**
- Check `SUPABASE_URL` in `.env`
- Should be: `https://xxx.supabase.co`

---

## 🌐 Network Issues

### Issue 1: Connection Refused from Phone

**Error:**
```
SocketException: Connection refused
```

**Cause:** Phone cannot reach backend server.

**Solutions:**

**Step 1: Verify Backend is Running**
```bash
curl http://localhost:5000/health
# Should return JSON response
```

**Step 2: Get Computer's IP Address**
```bash
ipconfig
# Look for IPv4 Address (e.g., 192.168.1.100)
```

**Step 3: Update Flutter Config**

Edit `lib/config/supabase_config.dart`:
```dart
static const String backendUrl = 'http://192.168.1.100:5000';
```

**Step 4: Check Windows Firewall**

**Option A: Allow Python Through Firewall**
1. Windows Security → Firewall & network protection
2. Allow an app through firewall
3. Find Python → Check Private and Public
4. Click OK

**Option B: Create Inbound Rule**
1. Windows Firewall → Advanced settings
2. Inbound Rules → New Rule
3. Port → TCP → Specific local ports: 5000
4. Allow the connection
5. Apply to all profiles

**Step 5: Test from Phone Browser**
```
http://192.168.1.100:5000/health
```
Should return JSON immediately.

**Step 6: Verify Same Network**
- Phone and PC must be on same WiFi network
- Corporate/school networks may block device-to-device communication

---

### Issue 2: Upload Timeout

**Error:**
```
Upload timed out after 60 seconds
```

**Cause:** Processing taking too long or network is slow.

**Solutions:**

**Step 1: Check Backend Logs**
- See where it's stuck (OCR, classification, upload)

**Step 2: Test with Smaller File**
- Try uploading a small image (< 1MB)

**Step 3: Increase Timeout**

Edit `lib/services/api_service.dart`:
```dart
var streamedResponse = await request.send().timeout(
  const Duration(seconds: 120), // Increase from 60
  onTimeout: () {
    throw Exception('Upload timed out.');
  },
);
```

**Step 4: Optimize OCR Processing**
- Reduce image size before upload
- Use compressed formats (JPEG instead of PNG)

---

### Issue 3: CORS Error (Web Only)

**Error:**
```
Access to XMLHttpRequest blocked by CORS policy
```

**Cause:** CORS not configured properly for web.

**Solution:**

Edit `backend/app.py`:
```python
from flask_cors import CORS

app = Flask(__name__)
CORS(app, resources={
    r"/api/*": {
        "origins": ["http://localhost:*", "http://127.0.0.1:*"],
        "methods": ["GET", "POST", "PUT", "DELETE"],
        "allow_headers": ["Content-Type"]
    }
})
```

---

## 🔍 OCR Issues

### Issue 1: Poor Text Extraction Accuracy

**Problem:** OCR extracts incorrect text.

**Solutions:**

**Improve Image Quality:**
- Increase resolution (minimum 300 DPI)
- Ensure good lighting
- Avoid shadows and glare
- Keep text horizontal

**Adjust Preprocessing:**

Edit `backend/ocr_engine.py`:
```python
def preprocess_image(self, image_path):
    img = cv2.imread(image_path)
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    
    # Try different thresholding methods
    # Option 1: Otsu's method (current)
    _, thresh = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    
    # Option 2: Adaptive threshold
    # thresh = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
    #                                cv2.THRESH_BINARY, 11, 2)
    
    # Option 3: Simple threshold
    # _, thresh = cv2.threshold(gray, 127, 255, cv2.THRESH_BINARY)
    
    return thresh
```

**Try Different PSM Mode:**
```python
text = pytesseract.image_to_string(
    pil_img,
    lang=self.ocr_language,
    config='--psm 6'  # Try different values 3-13
)
```

---

### Issue 2: Non-English Characters Not Recognized

**Problem:** OCR doesn't recognize other languages.

**Solutions:**

**Step 1: Install Language Data**
Download language files from: https://github.com/tesseract-ocr/tessdata

Copy to: `C:\Program Files\Tesseract-OCR\tessdata\`

**Step 2: Update Configuration**

Edit `backend/.env`:
```env
OCR_LANGUAGE=eng+fil  # English + Filipino
# Or
OCR_LANGUAGE=eng+spa  # English + Spanish
```

**Step 3: Restart Backend**

---

## 🔐 Authentication Issues

### Issue 1: Email Verification Not Working

**Problem:** OTP code not received.

**Solutions:**

**Check Spam Folder:**
- Verification emails may be in spam

**Check Supabase Email Settings:**
1. Go to Supabase → Authentication → Email Templates
2. Verify "Confirm signup" template exists
3. Check email rate limits

**Resend Code:**
- Click "Resend Code" in app
- Wait 60 seconds between resends

**Use Magic Link (Alternative):**
```dart
await _supabase.auth.signInWithOtp(email: email);
```

---

### Issue 2: Login Fails After Signup

**Problem:** Cannot login immediately after signup.

**Cause:** Email not verified.

**Solution:**

**Option A: Verify Email**
- Check email for verification code
- Enter code in app

**Option B: Disable Email Verification (Testing Only)**

Supabase Dashboard:
1. Go to Authentication → Settings
2. Disable "Enable email confirmations"

⚠️ **Warning:** Enable for production!

---

## ⚡ Performance Issues

### Issue 1: Slow Upload/Classification

**Problem:** Processing takes too long.

**Causes & Solutions:**

**Large File Size:**
- Compress images before upload
- Resize to reasonable dimensions (max 2000x2000 px)

**Complex PDF:**
- Multi-page PDFs take longer
- Consider processing page-by-page

**Slow Network:**
- Check internet speed
- Try smaller files first

**Backend Processing:**
- Check backend terminal for bottleneck
- OCR typically takes 3-10 seconds per page

---

### Issue 2: App Freezes During Upload

**Problem:** UI becomes unresponsive.

**Cause:** Upload blocking main thread.

**Solution:**

Ensure async/await is used properly:
```dart
Future<void> _uploadFile() async {
  setState(() => _isLoading = true);
  
  try {
    await _apiService.classifyDocument(file, userId);
    if (!mounted) return;
    setState(() => _isLoading = false);
  } catch (e) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _error = e.toString();
    });
  }
}
```

---

## 🔧 Debug Mode

### Enable Verbose Logging

**Backend:**

Edit `backend/app.py`:
```python
import logging
logging.basicConfig(level=logging.DEBUG)
```

**Flutter:**

Add print statements:
```dart
print('📤 Uploading file: ${file.path}');
print('👤 User ID: $userId');
```

**Supabase:**

Enable debug mode:
```dart
await Supabase.initialize(
  url: SupabaseConfig.supabaseUrl,
  anonKey: SupabaseConfig.supabaseAnonKey,
  debug: true,  // Enable debug logs
);
```

---

## 📞 Still Having Issues?

### Diagnostic Checklist

- [ ] Backend running? Check terminal
- [ ] Tesseract installed? Run `tesseract --version`
- [ ] Database tables created? Check Supabase
- [ ] Storage bucket exists? Check Supabase Storage
- [ ] Correct IP address? Run `ipconfig`
- [ ] Firewall disabled/configured? Check Windows Security
- [ ] Same network? Phone and PC on same WiFi
- [ ] Environment variables set? Check `.env` and `supabase_config.dart`

### Collect Debug Information

When reporting issues, provide:

1. **Error message** (exact text)
2. **Backend terminal output** (full logs)
3. **Flutter console output**
4. **Steps to reproduce**
5. **Environment:**
   - OS version
   - Python version
   - Flutter version
   - Tesseract version

---

## 📚 Related Documentation

- [SETUP_GUIDE.md](SETUP_GUIDE.md) - Initial setup
- [API_DOCUMENTATION.md](API_DOCUMENTATION.md) - API reference
- [SYSTEM_OVERVIEW.md](SYSTEM_OVERVIEW.md) - Architecture
