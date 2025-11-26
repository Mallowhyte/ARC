# ARC API Documentation
## Backend REST API Reference

**Base URL:** `http://localhost:5000` (Development)  
**Version:** 1.0.0  
**Protocol:** HTTP/HTTPS  
**Format:** JSON

---

## 📋 Table of Contents
1. [Overview](#overview)
2. [Authentication](#authentication)
3. [Endpoints](#endpoints)
4. [Error Handling](#error-handling)
5. [Rate Limiting](#rate-limiting)
6. [Examples](#examples)

---

## 📖 Overview

### Base URLs

| Environment | URL |
|------------|-----|
| Development (Localhost) | `http://localhost:5000` |
| Development (Network) | `http://YOUR_IP:5000` |
| Production | `https://your-domain.com` |

### Content Types

**Request:**
- `application/json` - For JSON data
- `multipart/form-data` - For file uploads

**Response:**
- `application/json` - All responses are JSON

### HTTP Methods

| Method | Usage |
|--------|-------|
| GET | Retrieve data |
| POST | Create or process data |
| PUT | Update data (future) |
| DELETE | Delete data (future) |

---

## 🔐 Authentication

### Overview
The backend itself doesn't require authentication for document classification. However, user-specific operations (viewing documents, statistics) are filtered by `user_id`.

### User ID
Most endpoints require a `user_id` parameter to identify the user. This should be the Supabase Auth user ID.

```
user_id: string (UUID format)
Example: "abc-123-def-456-ghi"
```

### Future: JWT Authentication
Planned for production:
- All requests require `Authorization: Bearer <token>` header
- Tokens obtained from Supabase Auth
- Tokens expire after configurable time

---

## 📡 Endpoints

### 1. Root Endpoint

**Get API Information**

```http
GET /
```

**Description:** Returns basic API information and available endpoints.

**Parameters:** None

**Response:**

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
  },
  "documentation": {
    "classify": "Upload file for OCR and classification",
    "stats": "Get classification statistics",
    "documents": "Retrieve user documents"
  }
}
```

**Status Codes:**
- `200 OK` - Success

---

### 2. Health Check

**Check Backend Health**

```http
GET /health
```

**Description:** Simple health check to verify backend is running.

**Parameters:** None

**Response:**

```json
{
  "status": "healthy",
  "service": "ARC Backend API",
  "version": "1.0.0"
}
```

**Status Codes:**
- `200 OK` - Backend is healthy

**Example:**

```bash
curl http://localhost:5000/health
```

---

### 3. Classify Document

**Upload and Classify a Document**

```http
POST /api/classify
```

**Description:** Upload a document file, perform OCR, classify it, store in Supabase, and return results.

**Content-Type:** `multipart/form-data`

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `file` | File | Yes | Document file (PDF, PNG, JPG, etc.) |
| `user_id` | String | Yes | User identifier (Supabase Auth UID) |

**Accepted File Types:**
- `application/pdf` (.pdf)
- `image/png` (.png)
- `image/jpeg` (.jpg, .jpeg)
- `image/tiff` (.tiff)
- `image/bmp` (.bmp)

**Max File Size:** 16MB

**Request Example:**

```bash
curl -X POST http://localhost:5000/api/classify \
  -F "file=@/path/to/document.jpg" \
  -F "user_id=abc-123-def"
```

**Response (Success):**

```json
{
  "success": true,
  "message": "Document classified successfully",
  "data": {
    "document_id": "5e16f497-92f1-4e5d-895a-0c71ef5dceb8",
    "filename": "1763008438342.jpg",
    "document_type": "Grade Sheet",
    "confidence": 0.85,
    "extracted_text": "Sample extracted text from document...",
    "storage_url": "https://your-project.supabase.co/storage/v1/object/public/documents/20241113_123045_1763008438342.jpg",
    "status": "classified",
    "created_at": "2024-11-13T12:30:45.123Z"
  }
}
```

**Response (Error - No File):**

```json
{
  "error": "No file provided"
}
```
Status: `400 Bad Request`

**Response (Error - Invalid File Type):**

```json
{
  "error": "File type not allowed"
}
```
Status: `400 Bad Request`

**Response (Error - Insufficient Text):**

```json
{
  "error": "Could not extract sufficient text from document",
  "extracted_text": "abc"
}
```
Status: `400 Bad Request`

**Response (Error - OCR Failed):**

```json
{
  "error": "OCR processing failed",
  "details": "tesseract is not installed or it's not in your PATH"
}
```
Status: `500 Internal Server Error`

**Status Codes:**
- `200 OK` - Document classified successfully
- `400 Bad Request` - Invalid request (no file, wrong type, insufficient text)
- `500 Internal Server Error` - Processing error (OCR, storage, database)

**Processing Flow:**
1. Validate file presence and type
2. Save file temporarily
3. Extract text using Tesseract OCR
4. Classify document using ML classifier
5. Upload file to Supabase Storage
6. Save metadata to Supabase Database
7. Return classification result
8. Clean up temporary file

---

### 4. Get User Documents

**Retrieve Documents for a User**

```http
GET /api/documents?user_id={user_id}
```

**Description:** Get all documents uploaded by a specific user.

**Parameters:**

| Parameter | Type | Required | Location | Description |
|-----------|------|----------|----------|-------------|
| `user_id` | String | Yes | Query | User identifier |
| `limit` | Integer | No | Query | Max documents to return (default: 50) |

**Request Example:**

```bash
curl "http://localhost:5000/api/documents?user_id=abc-123-def"
```

**Response (Success):**

```json
{
  "success": true,
  "documents": [
    {
      "id": "5e16f497-92f1-4e5d-895a-0c71ef5dceb8",
      "user_id": "abc-123-def",
      "filename": "grade_sheet.jpg",
      "document_type": "Grade Sheet",
      "confidence": 0.85,
      "extracted_text": "Sample text...",
      "storage_url": "https://...",
      "status": "classified",
      "created_at": "2024-11-13T12:30:45.123Z",
      "updated_at": "2024-11-13T12:30:45.123Z"
    },
    {
      "id": "7f28a3b9-83c2-5f6e-9a1b-1d82fa4ecf9d",
      "user_id": "abc-123-def",
      "filename": "receipt.pdf",
      "document_type": "Receipt",
      "confidence": 0.92,
      "extracted_text": "Receipt text...",
      "storage_url": "https://...",
      "status": "classified",
      "created_at": "2024-11-12T08:15:30.456Z",
      "updated_at": "2024-11-12T08:15:30.456Z"
    }
  ],
  "count": 2
}
```

**Response (Error - No User ID):**

```json
{
  "error": "user_id is required"
}
```
Status: `400 Bad Request`

**Status Codes:**
- `200 OK` - Documents retrieved successfully
- `400 Bad Request` - Missing user_id
- `500 Internal Server Error` - Database error

---

### 5. Get Document by ID

**Retrieve a Specific Document**

```http
GET /api/documents/{document_id}
```

**Description:** Get details of a specific document by its ID.

**Parameters:**

| Parameter | Type | Required | Location | Description |
|-----------|------|----------|----------|-------------|
| `document_id` | String | Yes | Path | Document UUID |

**Request Example:**

```bash
curl "http://localhost:5000/api/documents/5e16f497-92f1-4e5d-895a-0c71ef5dceb8"
```

**Response (Success):**

```json
{
  "success": true,
  "document": {
    "id": "5e16f497-92f1-4e5d-895a-0c71ef5dceb8",
    "user_id": "abc-123-def",
    "filename": "grade_sheet.jpg",
    "document_type": "Grade Sheet",
    "confidence": 0.85,
    "extracted_text": "Full extracted text from document...",
    "storage_url": "https://your-project.supabase.co/storage/v1/object/public/documents/20241113_123045_grade_sheet.jpg",
    "status": "classified",
    "created_at": "2024-11-13T12:30:45.123Z",
    "updated_at": "2024-11-13T12:30:45.123Z"
  }
}
```

**Response (Error - Not Found):**

```json
{
  "error": "Document not found"
}
```
Status: `404 Not Found`

**Status Codes:**
- `200 OK` - Document found
- `404 Not Found` - Document doesn't exist
- `500 Internal Server Error` - Database error

---

### 6. Get Statistics

**Get Classification Statistics**

```http
GET /api/stats?user_id={user_id}
```

**Description:** Get statistics about document classifications for a user.

**Parameters:**

| Parameter | Type | Required | Location | Description |
|-----------|------|----------|----------|-------------|
| `user_id` | String | No | Query | User identifier (omit for all users) |

**Request Example:**

```bash
# User-specific stats
curl "http://localhost:5000/api/stats?user_id=abc-123-def"

# Global stats (all users)
curl "http://localhost:5000/api/stats"
```

**Response (Success):**

```json
{
  "success": true,
  "statistics": {
    "total_documents": 45,
    "by_type": {
      "Grade Sheet": 15,
      "Receipt": 12,
      "Exam Form": 8,
      "Clearance": 5,
      "Enrollment Form": 3,
      "Other": 2
    },
    "average_confidence": 0.82,
    "recent_uploads": [
      {
        "id": "5e16f497-92f1-4e5d-895a-0c71ef5dceb8",
        "filename": "grade_sheet.jpg",
        "document_type": "Grade Sheet",
        "created_at": "2024-11-13T12:30:45.123Z"
      }
    ]
  }
}
```

**Status Codes:**
- `200 OK` - Statistics retrieved successfully
- `500 Internal Server Error` - Database error

---

## ⚠️ Error Handling

### Error Response Format

All errors follow this format:

```json
{
  "error": "Error message describing what went wrong",
  "details": "Optional: Additional technical details"
}
```

### Common HTTP Status Codes

| Code | Meaning | Description |
|------|---------|-------------|
| `200` | OK | Request successful |
| `400` | Bad Request | Invalid request (missing parameters, wrong format) |
| `404` | Not Found | Resource not found |
| `413` | Payload Too Large | File size exceeds 16MB limit |
| `415` | Unsupported Media Type | Invalid file type |
| `500` | Internal Server Error | Server error (OCR, database, storage) |
| `503` | Service Unavailable | Backend not responding |

### Error Examples

**File Too Large:**
```json
{
  "error": "File size exceeds 16MB limit"
}
```

**Tesseract Not Found:**
```json
{
  "error": "OCR processing failed",
  "details": "tesseract is not installed or it's not in your PATH"
}
```

**Database Connection Failed:**
```json
{
  "error": "Error saving document record",
  "details": "Unable to connect to database"
}
```

---

## 🚦 Rate Limiting

### Current Implementation
**Status:** Not implemented (Development)

### Recommended for Production

| Endpoint | Limit | Window |
|----------|-------|--------|
| `/api/classify` | 10 requests | per minute |
| `/api/documents` | 60 requests | per minute |
| `/api/stats` | 30 requests | per minute |

**Implementation:**
- Use Flask-Limiter or similar
- Return `429 Too Many Requests` when exceeded
- Include `Retry-After` header

---

## 📚 Examples

### Example 1: Upload and Classify (Python)

```python
import requests

# Prepare file and data
url = "http://localhost:5000/api/classify"
files = {
    'file': open('document.jpg', 'rb')
}
data = {
    'user_id': 'abc-123-def'
}

# Make request
response = requests.post(url, files=files, data=data)

# Handle response
if response.status_code == 200:
    result = response.json()
    print(f"Document Type: {result['data']['document_type']}")
    print(f"Confidence: {result['data']['confidence']}")
else:
    print(f"Error: {response.json()['error']}")
```

### Example 2: Upload and Classify (JavaScript/Flutter)

```dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> uploadDocument(File file, String userId) async {
  var request = http.MultipartRequest(
    'POST',
    Uri.parse('http://localhost:5000/api/classify'),
  );

  // Add file
  request.files.add(
    await http.MultipartFile.fromPath('file', file.path),
  );

  // Add user_id
  request.fields['user_id'] = userId;

  // Send request
  var streamedResponse = await request.send();
  var response = await http.Response.fromStream(streamedResponse);

  if (response.statusCode == 200) {
    var result = json.decode(response.body);
    print('Document Type: ${result['data']['document_type']}');
    print('Confidence: ${result['data']['confidence']}');
  } else {
    var error = json.decode(response.body);
    print('Error: ${error['error']}');
  }
}
```

### Example 3: Get User Documents (cURL)

```bash
curl -X GET "http://localhost:5000/api/documents?user_id=abc-123-def" \
  -H "Content-Type: application/json"
```

### Example 4: Get Statistics (Python)

```python
import requests

url = "http://localhost:5000/api/stats"
params = {'user_id': 'abc-123-def'}

response = requests.get(url, params=params)

if response.status_code == 200:
    stats = response.json()['statistics']
    print(f"Total Documents: {stats['total_documents']}")
    print(f"Average Confidence: {stats['average_confidence']}")
    print("\nBy Type:")
    for doc_type, count in stats['by_type'].items():
        print(f"  {doc_type}: {count}")
```

---

## 🔄 Versioning

### Current Version: 1.0.0

### Future Versions
API versioning will be implemented via URL path:
- `/v1/api/classify`
- `/v2/api/classify`

This allows backward compatibility when breaking changes are introduced.

---

## 📝 Change Log

### v1.0.0 (November 2024)
- Initial API release
- Basic classification endpoint
- Document retrieval endpoints
- Statistics endpoint
- Health check endpoint

---

## 🔗 Related Documentation

- [SYSTEM_OVERVIEW.md](SYSTEM_OVERVIEW.md) - System architecture
- [SETUP_GUIDE.md](SETUP_GUIDE.md) - Installation instructions
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues and solutions
- [DATABASE_SCHEMA.md](docs/database_schema.md) - Database structure

---

## 📞 Support

For API-related issues:
1. Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
2. Review backend terminal logs
3. Test with cURL to isolate issues
4. Check Supabase dashboard for storage/database errors
