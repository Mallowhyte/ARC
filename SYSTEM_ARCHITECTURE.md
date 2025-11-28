# ARC - Automated Record & Document Classifier
## Complete System Architecture

**Version:** 2.0.0  
**Last Updated:** November 2025  
**Status:** Production Ready ✅

---

## Table of Contents

1. [High-Level Architecture Diagram](#1-high-level-architecture-diagram)
2. [Frontend Components (Flutter)](#2-frontend-components-flutter)
3. [Backend Services (Flask)](#3-backend-services-flask)
4. [OCR + ML Pipeline](#4-ocr--ml-pipeline)
5. [Database Schema](#5-database-schema)
6. [API Endpoints](#6-api-endpoints)
7. [Authentication & Authorization](#7-authentication--authorization)
8. [Tech Stack](#8-recommended-tech-stack)
9. [Data Flow](#9-data-flow-upload--ocr--classification--storage--statistics)
10. [Production Deployment](#10-deployment-architecture-production)

---

## 1. High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                      USERS                                              │
│                         (Instructors, Admins via Mobile/Web)                            │
└─────────────────────────────────────────┬───────────────────────────────────────────────┘
                                          │ HTTPS
                                          ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              FLUTTER FRONTEND (Mobile/Web)                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌───────────┐  │
│  │ Auth Screens │  │Upload Screen │  │Documents List│  │  Statistics  │  │  Profile  │  │
│  │ Login/Signup │  │ File Picker  │  │ Search/Filter│  │   Charts     │  │  Settings │  │
│  │ Email Verify │  │ Camera/Gallery│ │ Detail View  │  │  Dashboard   │  │           │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘  └───────────┘  │
│                                          │                                              │
│  ┌────────────────────────────────────────────────────────────────────────────────────┐ │
│  │                              SERVICE LAYER                                         │ │
│  │   ApiService  │  AuthService  │  SupabaseService  │  StateManagement (Provider)    │ │
│  └────────────────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────┬───────────────────────────────────────────────┘
                                          │ REST API (JSON)
                                          ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              FLASK BACKEND API                                          │
│  ┌──────────────────────────────────────────────────────────────────────────────────┐   │
│  │                              API ENDPOINTS                                       │   │
│  │  POST /api/classify  │  GET /api/documents  │  GET /api/stats  │  GET /health    │   │
│  └──────────────────────────────────────────────────────────────────────────────────┘   │
│                                          │                                              │
│  ┌──────────────────────────────────────────────────────────────────────────────────┐   │
│  │                         PROCESSING PIPELINE                                      │   │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐        │   │
│  │  │ File Upload │───▶│  OCR Engine │───▶│ ML Classifier│───▶│Field Extract│      │   │
│  │  │  Validation │    │  (Tesseract)│    │ (TF-IDF+NB) │    │  (Regex)    │        │   │
│  │  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘        │   │
│  └──────────────────────────────────────────────────────────────────────────────────┘   │
│                                          │                                              │
│  ┌──────────────────────────────────────────────────────────────────────────────────┐   │
│  │                         SUPABASE CLIENT                                          │   │
│  │            Storage Upload  │  Database Insert  │  Statistics Query               │   │
│  └──────────────────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────┬───────────────────────────────────────────────┘
                                          │
                    ┌─────────────────────┴─────────────────────┐
                    ▼                                           ▼
┌───────────────────────────────────────┐       ┌───────────────────────────────────────────┐
│        SUPABASE STORAGE               │       │           SUPABASE DATABASE               │
│  ┌─────────────────────────────────┐  │       │  ┌─────────────────────────────────────┐  │
│  │    documents/ bucket            │  │       │  │  users         │  documents         │  │
│  │  • PDFs                         │  │       │  │  • id          │  • id              │  │
│  │  • Images (JPG/PNG)             │  │       │  │  • email       │  • user_id         │  │
│  │  • Scanned forms                │  │       │  │  • role        │  • filename        │  │
│  └─────────────────────────────────┘  │       │  │  • created_at  │  • document_type   │  │
└───────────────────────────────────────┘       │  │                │  • confidence      │  │
                                                │  │                │  • extracted_text  │  │
┌───────────────────────────────────────┐       │  │                │  • storage_url     │  │
│        SUPABASE AUTH                  │       │  │                │  • status          │  │
│  • Email/Password                     │       │  │                │  • created_at      │  │
│  • Email verification                 │       │  └─────────────────────────────────────┘  │
│  • Password reset                     │       │                                           │
│  • JWT tokens                         │       │  Row Level Security (RLS) Policies        │
└───────────────────────────────────────┘       └───────────────────────────────────────────┘
```

---

## 2. Frontend Components (Flutter)

### Screen Components

| Component | File | Purpose |
|-----------|------|---------|
| **Auth Screens** | `lib/screens/auth/` | Login, Signup, Email Verification, Password Reset |
| **Home Screen** | `lib/screens/home_screen.dart` | Dashboard with quick actions, recent docs, stats summary |
| **Upload Screen** | `lib/screens/upload_screen.dart` | File picker, camera, gallery; upload + classify flow |
| **Documents Screen** | `lib/screens/documents_screen.dart` | List view with search, filter by type, detail bottom sheet |
| **Statistics Screen** | `lib/screens/statistics_screen.dart` | Charts (fl_chart), category breakdown, confidence metrics |
| **Profile Screen** | `lib/screens/profile_screen.dart` | User info, settings, logout |

### Service Layer

| Service | File | Responsibility |
|---------|------|----------------|
| `ApiService` | `lib/services/api_service.dart` | HTTP calls to Flask backend (classify, documents, stats) |
| `AuthService` | `lib/services/auth_service.dart` | Supabase Auth wrapper (login, signup, verify, reset) |
| `SupabaseService` | `lib/services/supabase_service.dart` | Supabase client singleton |

### Models

| Model | File | Fields |
|-------|------|--------|
| `DocumentModel` | `lib/models/document_model.dart` | id, userId, filename, documentType, confidence, extractedText, storageUrl, keywords, createdAt |
| `UserModel` | `lib/models/user_model.dart` | id, email, displayName, role, emailVerified |

### Configuration

| File | Purpose |
|------|---------|
| `lib/config/supabase_config.dart` | Supabase URL, anon key, backend URL, API endpoints |
| `lib/theme/app_theme.dart` | Light/dark theme definitions, colors, typography |

---

## 3. Backend Services (Flask)

### Directory Structure

```
backend/
├── app.py                 # Flask app, routes, CORS, error handling
├── ocr_engine.py          # Tesseract OCR with multipass preprocessing
├── ml_classifier.py       # TF-IDF + Naive Bayes + rule-based fallback
├── field_extractor.py     # Regex-based structured field extraction
├── supabase_client.py     # Supabase SDK wrapper (storage + DB)
├── requirements.txt       # Python dependencies
├── .env                   # Environment variables (SUPABASE_URL, SUPABASE_KEY)
└── uploads/               # Temporary file storage during processing
```

### Core Modules

| Module | Class/Functions | Description |
|--------|-----------------|-------------|
| `ocr_engine.py` | `OCREngine` | Multipass OCR with image preprocessing |
| `ml_classifier.py` | `DocumentClassifier` | Hybrid ML + rule-based classification |
| `field_extractor.py` | `FieldExtractor` | Document-specific field extraction |
| `supabase_client.py` | `SupabaseClient` | Storage upload, DB CRUD, statistics |

### OCR Engine Features

- **Preprocessing Pipeline:**
  - Grayscale conversion
  - CLAHE (Contrast Limited Adaptive Histogram Equalization)
  - Otsu thresholding
  - Adaptive thresholding
  - Denoising (fastNlMeansDenoising)
  - Deskewing
  - Line removal for table forms

- **Multipass OCR:**
  - Multiple preprocessing candidates (raw, CLAHE, dilated, blackhat, inverted)
  - Multiple Tesseract PSM modes (3, 4, 6, 11)
  - Multiple OEM modes (3, 1)
  - Orientation detection via `image_to_osd`
  - Header region OCR (top 20%) with character whitelist
  - Best result selection by median word confidence

### ML Classifier Features

- **Document Categories:**
  - Syllabus Review Form
  - Grade Sheet
  - Enrollment Form
  - Clearance Form
  - Exam Permit
  - Official Receipt
  - Certificate
  - Memorandum
  - Letter
  - ID Document
  - Other

- **Classification Methods:**
  - ML Model: TF-IDF Vectorizer + Multinomial Naive Bayes
  - Rule-based fallback: Keyword scoring + fuzzy matching
  - Confidence threshold: 0.3 (fallback if below)

### Field Extractor Features

- **Syllabus Review Form Fields:**
  - `document_code` (e.g., FM-USTP-ACAD-12)
  - `course_code` (e.g., IT121)
  - `semester` (e.g., 2nd Semester)
  - `academic_year` (e.g., 2024-2025)
  - `descriptive_title`
  - `faculty` (list of names)
  - `reviewed_by`
  - `review_date`
  - `indicators_table` (boolean)
  - `yes_count`, `no_count`

---

## 4. OCR + ML Pipeline

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              OCR + CLASSIFICATION PIPELINE                          │
└─────────────────────────────────────────────────────────────────────────────────────┘

     ┌──────────┐
     │  INPUT   │  PDF / JPG / PNG / TIFF / BMP
     └────┬─────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│  STEP 1: FILE VALIDATION                                                            │
│  • Check file extension (allowed: pdf, png, jpg, jpeg, tiff, bmp)                   │
│  • Check file size (max 16MB)                                                       │
│  • Secure filename                                                                  │
└─────────────────────────────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│  STEP 2: IMAGE PREPROCESSING (OpenCV)                                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                 │
│  │  Grayscale  │─▶│    CLAHE    │─▶│ Otsu Thresh │─▶│  Denoise    │                 │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘                 │
│                                                                                     │
│  MULTIPASS CANDIDATES:                                                              │
│  • Raw grayscale          • Otsu + denoise        • Adaptive threshold              │
│  • CLAHE enhanced         • Dilated               • Morphology cleaned              │
│  • Blackhat transform     • Inverted              • Bilateral filtered              │
└─────────────────────────────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│  STEP 3: TESSERACT OCR                                                              │
│  • Multiple PSM modes: 3 (auto), 6 (block), 11 (sparse), 4 (column)                 │
│  • OEM modes: 3 (default), 1 (LSTM only)                                            │
│  • Orientation detection via image_to_osd                                           │
│  • Header region OCR (top 20%) with PSM 7 + whitelist                               │
│  • Select best result by median word confidence                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│  STEP 4: TEXT CLASSIFICATION                                                        │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │  ML MODEL (if trained)                                                      │    │
│  │  • TF-IDF Vectorizer (1-2 grams, max 5000 features)                         │    │
│  │  • Multinomial Naive Bayes                                                  │    │
│  │  • Confidence threshold: 0.3                                                │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
│                              │                                                      │
│                              ▼ (if confidence < threshold or no model)              │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │  RULE-BASED FALLBACK                                                        │    │
│  │  • Keyword scoring per category                                             │    │
│  │  • Fuzzy matching (difflib)                                                 │    │
│  │  • Regex patterns (document codes, dates)                                   │    │
│  │  • Special signals (e.g., "SYLLABUS REVIEW FORM", "FM-USTP-ACAD-12")        │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│  STEP 5: FIELD EXTRACTION (Document-Specific)                                       │
│  • Syllabus Review Form:                                                            │
│    - document_code, course_code, semester, academic_year                            │
│    - faculty (list), reviewed_by, review_date                                       │
│    - indicators_table (bool), yes_count, no_count                                   │
│  • (Extensible to other document types)                                             │
└─────────────────────────────────────────────────────────────────────────────────────┘
          │
          ▼
     ┌──────────┐
     │  OUTPUT  │  { document_type, confidence, keywords, fields }
     └──────────┘
```

---

## 5. Database Schema

### Table: `profiles` (User Profiles)

```sql
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    display_name TEXT,
    role TEXT DEFAULT 'instructor' CHECK (role IN ('instructor', 'admin')),
    department TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS Policies
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile"
    ON public.profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id);
```

### Table: `documents`

```sql
CREATE TABLE public.documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    filename TEXT NOT NULL,
    document_type TEXT NOT NULL,
    confidence REAL NOT NULL DEFAULT 0.0,
    extracted_text TEXT,                    -- First 500 chars for search
    storage_url TEXT NOT NULL,
    status TEXT DEFAULT 'classified' CHECK (status IN ('pending', 'processing', 'classified', 'failed')),
    keywords TEXT[],                        -- Array of extracted keywords
    extracted_fields JSONB,                 -- Structured fields (optional)
    file_size_bytes INTEGER,
    mime_type TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_documents_user_id ON public.documents(user_id);
CREATE INDEX idx_documents_document_type ON public.documents(document_type);
CREATE INDEX idx_documents_created_at ON public.documents(created_at DESC);
CREATE INDEX idx_documents_extracted_text_gin ON public.documents 
    USING gin(to_tsvector('english', extracted_text));

-- RLS Policies
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own documents"
    ON public.documents FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own documents"
    ON public.documents FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own documents"
    ON public.documents FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own documents"
    ON public.documents FOR DELETE
    USING (auth.uid() = user_id);
```

### Table: `document_types` (Reference)

```sql
CREATE TABLE public.document_types (
    id SERIAL PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    description TEXT,
    keywords TEXT[],
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed data
INSERT INTO public.document_types (name, description) VALUES
    ('Syllabus Review Form', 'Academic syllabus review and approval form'),
    ('Grade Sheet', 'Student grade records and transcripts'),
    ('Enrollment Form', 'Student enrollment and registration forms'),
    ('Clearance Form', 'Academic or administrative clearance'),
    ('Exam Permit', 'Examination permits and authorizations'),
    ('Official Receipt', 'Payment receipts and financial documents'),
    ('Certificate', 'Academic certificates and awards'),
    ('Memorandum', 'Official memos and communications'),
    ('Letter', 'Formal letters and correspondence'),
    ('ID Document', 'Identification documents'),
    ('Other', 'Uncategorized documents');
```

### Table: `classification_logs` (Audit Trail)

```sql
CREATE TABLE public.classification_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID REFERENCES public.documents(id) ON DELETE SET NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    original_type TEXT,
    corrected_type TEXT,                    -- For user corrections / active learning
    confidence REAL,
    method TEXT,                            -- 'ml_model', 'rule_based', 'manual'
    processing_time_ms INTEGER,
    ocr_confidence REAL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Entity Relationship Diagram

```
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│   auth.users    │       │    profiles     │       │   documents     │
├─────────────────┤       ├─────────────────┤       ├─────────────────┤
│ id (PK)         │◄──────│ id (PK, FK)     │       │ id (PK)         │
│ email           │       │ email           │       │ user_id (FK)────┼──┐
│ encrypted_pass  │       │ display_name    │       │ filename        │  │
│ created_at      │       │ role            │       │ document_type   │  │
└─────────────────┘       │ department      │       │ confidence      │  │
        │                 │ created_at      │       │ extracted_text  │  │
        │                 └─────────────────┘       │ storage_url     │  │
        │                                           │ status          │  │
        │                                           │ keywords[]      │  │
        │                                           │ extracted_fields│  │
        │                                           │ created_at      │  │
        │                                           └─────────────────┘  │
        │                                                    │           │
        └────────────────────────────────────────────────────┼───────────┘
                                                             │
                                                             ▼
                                           ┌─────────────────────────────┐
                                           │   classification_logs       │
                                           ├─────────────────────────────┤
                                           │ id (PK)                     │
                                           │ document_id (FK)            │
                                           │ user_id (FK)                │
                                           │ original_type               │
                                           │ corrected_type              │
                                           │ confidence                  │
                                           │ method                      │
                                           │ processing_time_ms          │
                                           │ created_at                  │
                                           └─────────────────────────────┘
```

---

## 6. API Endpoints

### Endpoint Summary

| Method | Endpoint | Description | Auth | Request | Response |
|--------|----------|-------------|------|---------|----------|
| `GET` | `/health` | Health check | No | — | `{ status, version }` |
| `POST` | `/api/classify` | Upload + OCR + Classify | Yes | `multipart/form-data` | `{ success, document_id, document_type, confidence, keywords, fields, storage_url }` |
| `GET` | `/api/documents` | List user documents | Yes | `?user_id=<uuid>&limit=50` | `[ { id, filename, document_type, ... } ]` |
| `GET` | `/api/documents/<id>` | Get single document | Yes | — | `{ id, filename, document_type, extracted_text, ... }` |
| `DELETE` | `/api/documents/<id>` | Delete document | Yes | — | `{ success: true }` |
| `GET` | `/api/stats` | User statistics | Yes | `?user_id=<uuid>` | `{ total_documents, by_category, average_confidence }` |

### Request/Response Examples

#### POST /api/classify

**Request:**
```bash
curl -X POST http://localhost:5000/api/classify \
  -F "file=@syllabus_review.pdf" \
  -F "user_id=abc123-uuid"
```

**Response (200 OK):**
```json
{
  "success": true,
  "document_id": "d1e2f3a4-5678-90ab-cdef-1234567890ab",
  "document_type": "Syllabus Review Form",
  "confidence": 0.95,
  "keywords": ["syllabus", "review", "course", "faculty"],
  "fields": {
    "document_code": "FM-USTP-ACAD-12",
    "course_code": "IT121",
    "semester": "2nd Semester",
    "academic_year": "2024-2025",
    "faculty": ["Kilven Mark P. Badiang", "Jo Roxan Borata"],
    "indicators_table": true,
    "yes_count": 8,
    "no_count": 2
  },
  "storage_url": "https://xyz.supabase.co/storage/v1/object/public/documents/...",
  "message": "Document classified as Syllabus Review Form"
}
```

#### GET /api/stats

**Request:**
```bash
curl http://localhost:5000/api/stats?user_id=abc123-uuid
```

**Response (200 OK):**
```json
{
  "total_documents": 42,
  "by_category": {
    "Syllabus Review Form": 15,
    "Grade Sheet": 10,
    "Enrollment Form": 8,
    "Other": 9
  },
  "average_confidence": 0.87
}
```

---

## 7. Authentication & Authorization

### Authentication Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Flutter   │────▶│  Supabase   │────▶│  PostgreSQL │
│   Client    │◀────│    Auth     │◀────│   (users)   │
└─────────────┘     └─────────────┘     └─────────────┘
       │
       │ JWT Token (in header)
       ▼
┌─────────────┐
│   Flask     │  Validates user_id from request
│   Backend   │  (trusts Supabase for auth)
└─────────────┘
```

### Auth Features

| Feature | Implementation |
|---------|----------------|
| **Sign Up** | Email + password via Supabase Auth |
| **Email Verification** | Required before document upload |
| **Sign In** | Email + password, returns JWT |
| **Password Reset** | Email-based reset link |
| **Session Management** | Supabase handles JWT refresh |
| **Role-Based Access** | `profiles.role` column (instructor/admin) |

### Authorization Matrix

| Action | Instructor | Admin |
|--------|------------|-------|
| Upload documents | ✅ Own only | ✅ Any |
| View documents | ✅ Own only | ✅ Any |
| Delete documents | ✅ Own only | ✅ Any |
| View statistics | ✅ Own only | ✅ Global |
| Retrain model | ❌ | ✅ |
| Manage users | ❌ | ✅ |

### Security Measures

- **JWT-based authentication** via Supabase Auth
- **Row-Level Security (RLS)** policies on all tables
- **HTTPS** for all API communications
- **Environment variables** for sensitive credentials
- **CORS** configuration on Flask backend
- **Input validation** (file type, size, sanitization)
- **SQL injection prevention** via ORM/parameterized queries

---

## 8. Recommended Tech Stack

| Layer | Technology | Rationale |
|-------|------------|-----------|
| **Frontend** | Flutter 3.x | Cross-platform (Android, iOS, Web), single codebase |
| **State Management** | Provider / Riverpod | Simple, scalable state management |
| **UI Components** | Material 3, fl_chart | Modern UI, built-in charts |
| **Backend** | Flask (Python 3.10+) | Lightweight, easy integration with ML/OCR libs |
| **OCR** | Tesseract 5.x + pytesseract | Open-source, accurate, multi-language support |
| **Image Processing** | OpenCV (cv2) | Preprocessing for better OCR accuracy |
| **ML Classification** | scikit-learn (TF-IDF + Naive Bayes) | Fast training, good for text classification |
| **Database** | Supabase (PostgreSQL) | Managed, real-time, built-in auth, RLS |
| **File Storage** | Supabase Storage | Integrated with DB, signed URLs |
| **Authentication** | Supabase Auth | Email/password, JWT, email verification |
| **Hosting (Backend)** | Railway / Render / Fly.io | Easy Python deployment, free tiers |
| **Hosting (Frontend)** | Firebase Hosting / Vercel | Flutter web deployment |

### Dependencies

**Flutter (pubspec.yaml):**
```yaml
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.0.0
  http: ^1.1.0
  image_picker: ^1.0.4
  file_picker: ^6.0.0
  fl_chart: ^0.65.0
  provider: ^6.0.0
```

**Python (requirements.txt):**
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
pdf2image>=1.16.0
```

---

## 9. Data Flow: Upload → OCR → Classification → Storage → Statistics

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                    DATA FLOW                                            │
└─────────────────────────────────────────────────────────────────────────────────────────┘

STEP 1: USER UPLOADS DOCUMENT
─────────────────────────────
  User (Flutter App)
       │
       │ [1] Select file (PDF/Image)
       │ [2] Tap "Upload & Classify"
       ▼
  ApiService.classifyDocument()
       │
       │ [3] POST /api/classify
       │     - multipart/form-data
       │     - file + user_id
       ▼

STEP 2: BACKEND RECEIVES FILE
─────────────────────────────
  Flask Backend (app.py)
       │
       │ [4] Validate file type & size
       │ [5] Save to temp folder
       ▼

STEP 3: OCR EXTRACTION
──────────────────────
  OCREngine.extract_text()
       │
       │ [6] Detect file type (PDF vs Image)
       │ [7] If PDF: Convert pages to images (pdf2image)
       │ [8] Preprocess image (grayscale, threshold, denoise)
       │ [9] Run Tesseract OCR (multipass, multiple configs)
       │ [10] Select best result by confidence
       │ [11] Extract header region separately
       ▼
  extracted_text: str (raw OCR output)

STEP 4: CLASSIFICATION
──────────────────────
  DocumentClassifier.classify()
       │
       │ [12] Check text length (min 10 chars)
       │ [13] Try ML model (TF-IDF + Naive Bayes)
       │ [14] If confidence < 0.3: fallback to rule-based
       │ [15] Rule-based: keyword scoring + fuzzy match
       │ [16] Extract keywords (TF-IDF top terms)
       ▼
  classification_result: { document_type, confidence, keywords, method }

STEP 5: FIELD EXTRACTION
────────────────────────
  FieldExtractor.extract_*()
       │
       │ [17] If document_type == "Syllabus Review Form":
       │       - Extract course_code, semester, faculty, etc.
       │ [18] Return structured fields dict
       ▼
  extracted_fields: { course_code, semester, faculty, ... }

STEP 6: STORAGE UPLOAD
──────────────────────
  SupabaseClient.upload_file()
       │
       │ [19] Generate unique filename (timestamp + original)
       │ [20] Upload to Supabase Storage bucket "documents"
       │ [21] Get public URL
       ▼
  storage_url: str

STEP 7: DATABASE INSERT
───────────────────────
  SupabaseClient.save_document_record()
       │
       │ [22] Insert into documents table:
       │       - user_id, filename, document_type
       │       - confidence, extracted_text (500 chars)
       │       - storage_url, status, keywords
       │ [23] Return inserted record with ID
       ▼
  db_result: { id, ... }

STEP 8: RESPONSE TO CLIENT
──────────────────────────
  Flask returns JSON
       │
       │ [24] { success, document_id, document_type,
       │        confidence, keywords, fields, storage_url }
       ▼
  Flutter receives response
       │
       │ [25] Parse into DocumentModel
       │ [26] Update UI (show classification result)
       │ [27] Navigate to Documents list (optional)
       ▼

STEP 9: STATISTICS UPDATE
─────────────────────────
  (Automatic via database)
       │
       │ [28] Statistics Screen queries:
       │       SELECT document_type, COUNT(*), AVG(confidence)
       │       FROM documents WHERE user_id = ?
       │       GROUP BY document_type
       │
       │ [29] Display charts (fl_chart):
       │       - Pie chart: documents by category
       │       - Bar chart: uploads over time
       │       - Metric cards: total, avg confidence
       ▼
  Statistics Dashboard updated
```

---

## 10. Deployment Architecture (Production)

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              PRODUCTION DEPLOYMENT                                      │
└─────────────────────────────────────────────────────────────────────────────────────────┘

                    ┌─────────────────────────────────────┐
                    │         CDN / Edge Network          │
                    │      (Cloudflare / Firebase CDN)    │
                    └─────────────────┬───────────────────┘
                                      │
        ┌─────────────────────────────┼─────────────────────────────┐
        │                             │                             │
        ▼                             ▼                             ▼
┌───────────────────┐     ┌───────────────────┐     ┌───────────────────┐
│   Flutter Web     │     │   Android APK     │     │    iOS App        │
│ (Firebase Hosting)│     │  (Play Store)     │     │  (App Store)      │
└───────────────────┘     └───────────────────┘     └───────────────────┘
        │                             │                             │
        └─────────────────────────────┼─────────────────────────────┘
                                      │ HTTPS
                                      ▼
                    ┌─────────────────────────────────────┐
                    │      Load Balancer / API Gateway    │
                    │         (Railway / Render)          │
                    └─────────────────┬───────────────────┘
                                      │
                    ┌─────────────────┴───────────────────┐
                    │                                     │
                    ▼                                     ▼
        ┌───────────────────┐             ┌───────────────────┐
        │  Flask Instance 1 │             │  Flask Instance 2 │
        │  (Worker/Gunicorn)│             │  (Worker/Gunicorn)│
        └─────────┬─────────┘             └─────────┬─────────┘
                  │                                 │
                  └─────────────┬───────────────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        │                       │                       │
        ▼                       ▼                       ▼
┌───────────────┐     ┌───────────────────┐     ┌───────────────┐
│   Supabase    │     │  Supabase Storage │     │  Supabase DB  │
│     Auth      │     │   (S3-compatible) │     │  (PostgreSQL) │
└───────────────┘     └───────────────────┘     └───────────────┘
```

### Deployment Checklist

- [ ] Set environment variables on hosting platform
- [ ] Configure CORS for production domain
- [ ] Enable HTTPS/SSL certificates
- [ ] Set up database connection pooling
- [ ] Configure Gunicorn workers (2-4 per CPU)
- [ ] Set up monitoring (Sentry, Datadog)
- [ ] Configure automated backups
- [ ] Set up CI/CD pipeline
- [ ] Load testing before launch

---

## Summary

| Aspect | Current Implementation |
|--------|------------------------|
| **Frontend** | Flutter (mobile-first, web-ready) |
| **Backend** | Flask + Tesseract + scikit-learn |
| **Database** | Supabase PostgreSQL with RLS |
| **Storage** | Supabase Storage (documents bucket) |
| **Auth** | Supabase Auth (email/password + verification) |
| **OCR** | Tesseract 5 with multipass preprocessing |
| **Classification** | Hybrid ML (TF-IDF+NB) + rule-based fallback |
| **Field Extraction** | Regex-based, document-type-specific |

---

## Related Documentation

- [SYSTEM_OVERVIEW.md](SYSTEM_OVERVIEW.md) - High-level project overview
- [API_DOCUMENTATION.md](API_DOCUMENTATION.md) - Detailed API reference
- [SETUP_GUIDE.md](SETUP_GUIDE.md) - Installation instructions
- [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - Production deployment
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues and fixes
- [docs/database_schema.md](docs/database_schema.md) - Database details
- [docs/ml_model_training.md](docs/ml_model_training.md) - ML training guide

---

**Document Version:** 2.0.0  
**Last Updated:** November 2025  
**Maintainer:** ARC Development Team
