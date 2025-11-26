# ARC - AI-based Record Classifier
## System Overview & Architecture

**Version:** 1.0.0  
**Last Updated:** November 2024  
**Status:** Production Ready ✅

---

## 📋 Table of Contents
1. [Project Overview](#project-overview)
2. [System Architecture](#system-architecture)
3. [Technology Stack](#technology-stack)
4. [Key Features](#key-features)
5. [System Components](#system-components)
6. [Data Flow](#data-flow)
7. [Security](#security)

---

## 📖 Project Overview

### Purpose
ARC (AI-based Record Classifier) is an intelligent document management system designed to automatically classify and organize various types of academic and administrative documents using OCR (Optical Character Recognition) and machine learning techniques.

### Target Users
- **Registrar Staff** - Process student records and academic documents
- **Faculty Members** - Manage grade sheets and academic forms
- **Administrative Staff** - Handle receipts, clearances, and various forms
- **IT Administrators** - System configuration and maintenance

### Problem Statement
Manual document classification is time-consuming, error-prone, and inefficient. ARC automates this process by:
- Extracting text from documents using OCR
- Classifying documents into predefined categories
- Storing documents securely in cloud storage
- Providing easy search and retrieval capabilities

---

## 🏗️ System Architecture

### High-Level Architecture

```
┌─────────────────┐
│  Flutter App    │ ◄─── User Interface (Mobile/Web)
│  (Frontend)     │
└────────┬────────┘
         │ HTTP/REST API
         │
┌────────▼────────┐
│  Flask Backend  │ ◄─── Business Logic & Processing
│  (Python)       │
└────┬───────┬────┘
     │       │
     │       └──────────┐
     │                  │
┌────▼────────┐  ┌──────▼──────┐
│  Tesseract  │  │  Supabase   │
│  OCR Engine │  │  (Database  │
└─────────────┘  │  & Storage) │
                 └─────────────┘
```

### Component Interaction Flow

1. **User uploads document** via Flutter app
2. **Flutter sends file** to Flask backend via REST API
3. **Backend processes file:**
   - Saves temporarily to local storage
   - Extracts text using Tesseract OCR
   - Classifies document using ML classifier
   - Uploads file to Supabase Storage
   - Saves metadata to Supabase Database
4. **Backend returns result** to Flutter app
5. **Flutter displays** classification result to user

---

## 🛠️ Technology Stack

### Frontend (Flutter)
- **Framework:** Flutter 3.5+
- **Language:** Dart
- **State Management:** setState (StatefulWidgets)
- **HTTP Client:** http package
- **Authentication:** Supabase Auth
- **Image Picker:** image_picker package
- **File Picker:** file_picker package

**Key Dependencies:**
```yaml
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.0.0
  http: ^1.1.0
  image_picker: ^1.0.4
  file_picker: ^6.0.0
```

### Backend (Python Flask)
- **Framework:** Flask 3.0.0
- **Language:** Python 3.14
- **OCR Engine:** Tesseract 5.3.3
- **ML Library:** scikit-learn
- **Database Client:** supabase-py
- **Image Processing:** OpenCV, Pillow
- **PDF Processing:** pdf2image, PyPDF2

**Key Dependencies:**
```txt
Flask==3.0.0
Flask-CORS==4.0.0
python-dotenv==1.0.0
supabase==2.0.0
pytesseract>=0.3.10
Pillow>=10.0.0
opencv-python==4.8.1.78
scikit-learn==1.3.2
pandas==2.1.3
```

### Database & Storage
- **Database:** Supabase (PostgreSQL)
- **Storage:** Supabase Storage
- **Authentication:** Supabase Auth

### External Services
- **Tesseract OCR:** Text extraction from images and PDFs
- **Supabase:** Backend-as-a-Service (BaaS)

---

## ✨ Key Features

### 1. Document Upload & Processing
- ✅ Support multiple file formats (PDF, PNG, JPG, JPEG, TIFF, BMP)
- ✅ File size limit: 16MB
- ✅ Multiple upload sources (Camera, Gallery, File System)
- ✅ Real-time upload progress
- ✅ Error handling and validation

### 2. OCR Text Extraction
- ✅ High-accuracy text extraction using Tesseract 5.3.3
- ✅ Image preprocessing for better OCR results
- ✅ Multi-page PDF support
- ✅ Automatic language detection (default: English)

### 3. Automatic Document Classification
- ✅ 10 document categories:
  - Exam Form
  - Acknowledgement Form
  - Clearance
  - Receipt
  - Grade Sheet
  - Enrollment Form
  - ID Application
  - Certificate Request
  - Leave Form
  - Other
- ✅ Confidence score for each classification
- ✅ Keyword-based classification algorithm
- ✅ Extensible ML model support

### 4. Cloud Storage
- ✅ Secure file storage in Supabase Storage
- ✅ Automatic file naming with timestamps
- ✅ MIME type detection
- ✅ Public URL generation
- ✅ File deduplication

### 5. User Authentication
- ✅ Email/password authentication
- ✅ Email verification with OTP
- ✅ Password reset functionality
- ✅ User profile management
- ✅ Session management

### 6. Document Management
- ✅ View all uploaded documents
- ✅ Filter by document type
- ✅ Search documents
- ✅ View document details
- ✅ Access stored files

### 7. Analytics & Statistics
- ✅ Total documents uploaded
- ✅ Classification breakdown by type
- ✅ Average confidence scores
- ✅ Upload trends

---

## 🔧 System Components

### Frontend Components

#### 1. Authentication Module
**Files:**
- `lib/screens/auth/login_screen.dart`
- `lib/screens/auth/signup_screen.dart`
- `lib/screens/auth/forgot_password_screen.dart`
- `lib/screens/auth/email_verification_screen.dart`
- `lib/screens/auth/auth_gate.dart`
- `lib/services/auth_service.dart`

**Features:**
- User registration with email verification
- Login with email/password
- Password reset
- OTP-based email verification
- Auto-logout on token expiry

#### 2. Upload Module
**Files:**
- `lib/screens/upload_screen.dart`
- `lib/services/api_service.dart`

**Features:**
- File selection (Camera/Gallery/Files)
- File validation
- Upload progress tracking
- Real-time classification results
- Error handling

#### 3. Documents Module
**Files:**
- `lib/screens/documents_screen.dart`
- `lib/models/document_model.dart`

**Features:**
- Document listing
- Category filtering
- Document details view
- Pull-to-refresh

#### 4. Statistics Module
**Files:**
- `lib/screens/statistics_screen.dart`

**Features:**
- Upload statistics
- Category breakdown
- Visual charts (future enhancement)

### Backend Components

#### 1. API Server
**File:** `backend/app.py`

**Endpoints:**
- `GET /` - API information
- `GET /health` - Health check
- `POST /api/classify` - Upload and classify document
- `GET /api/documents` - Get user documents
- `GET /api/documents/<id>` - Get specific document
- `GET /api/stats` - Get statistics

#### 2. OCR Engine
**File:** `backend/ocr_engine.py`

**Features:**
- Image preprocessing (grayscale, thresholding, denoising)
- Text extraction from images
- PDF text extraction
- Multi-page document support

#### 3. ML Classifier
**File:** `backend/ml_classifier.py`

**Features:**
- Keyword-based classification
- Confidence score calculation
- Category mapping
- Extensible for custom ML models

#### 4. Supabase Client
**File:** `backend/supabase_client.py`

**Features:**
- File upload to storage
- Database operations (CRUD)
- Document record management
- Statistics queries

---

## 🔄 Data Flow

### Upload Flow

```
1. User selects file
   ↓
2. Flutter validates file (size, type)
   ↓
3. Flutter sends POST to /api/classify
   ↓
4. Backend receives file
   ↓
5. Backend saves file temporarily
   ↓
6. OCR extracts text
   ↓
7. Classifier determines document type
   ↓
8. File uploaded to Supabase Storage
   ↓
9. Metadata saved to database
   ↓
10. Backend returns result
   ↓
11. Flutter displays result to user
```

### Authentication Flow

```
1. User enters credentials
   ↓
2. Flutter sends to Supabase Auth
   ↓
3. Supabase validates credentials
   ↓
4. Supabase returns JWT token
   ↓
5. Flutter stores token
   ↓
6. Token used for subsequent API calls
```

---

## 🔒 Security

### Authentication & Authorization
- ✅ JWT-based authentication
- ✅ Supabase Auth for user management
- ✅ Row-Level Security (RLS) policies
- ✅ Secure password hashing (handled by Supabase)

### Data Protection
- ✅ HTTPS for all API communications
- ✅ Environment variables for sensitive data
- ✅ Private storage buckets
- ✅ User-specific data isolation via RLS

### Input Validation
- ✅ File type validation
- ✅ File size limits
- ✅ SQL injection prevention (ORM)
- ✅ XSS prevention

### Backend Security
- ✅ CORS configuration
- ✅ Rate limiting (recommended for production)
- ✅ Input sanitization
- ✅ Error message sanitization

---

## 📊 Performance Considerations

### Optimization Techniques
1. **Database Indexing** - Indexes on user_id, document_type, created_at
2. **Image Preprocessing** - Optimized for OCR accuracy and speed
3. **Async Operations** - Non-blocking file uploads
4. **Caching** - Future: Redis for frequently accessed data
5. **Lazy Loading** - Documents loaded on-demand

### Scalability
- Horizontal scaling via multiple Flask instances
- Database connection pooling
- Cloud storage (unlimited scalability)
- Microservices-ready architecture

---

## 🎯 Future Enhancements

### Planned Features
- [ ] Custom ML model training interface
- [ ] Batch document upload
- [ ] Document editing and annotation
- [ ] Advanced search (full-text search)
- [ ] Export reports (PDF, Excel)
- [ ] Real-time collaboration
- [ ] Mobile push notifications
- [ ] Document versioning
- [ ] Audit logs
- [ ] Advanced analytics dashboard

### Infrastructure Improvements
- [ ] Docker containerization
- [ ] CI/CD pipeline
- [ ] Automated testing suite
- [ ] Monitoring and alerting
- [ ] Load balancing
- [ ] CDN for static assets

---

## 📞 Support & Maintenance

### System Requirements
- **Backend:** Python 3.12+, Tesseract OCR 5.3+
- **Frontend:** Flutter 3.5+, Dart 3.0+
- **Database:** PostgreSQL 14+ (via Supabase)

### Monitoring Points
- API response times
- OCR processing times
- Storage usage
- Database query performance
- Error rates

### Backup Strategy
- Daily automated backups via Supabase
- 30-day retention period
- Test restore procedures monthly

---

## 📝 Version History

### v1.0.0 (November 2024)
- ✅ Initial release
- ✅ Core upload and classification functionality
- ✅ User authentication
- ✅ Document management
- ✅ Basic statistics

---

**For detailed setup instructions, see [SETUP_GUIDE.md](SETUP_GUIDE.md)**  
**For API documentation, see [API_DOCUMENTATION.md](API_DOCUMENTATION.md)**  
**For troubleshooting, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md)**
