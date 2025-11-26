# API Endpoints Documentation

## Base URL
```
http://localhost:5000
```

For production, replace with your deployed backend URL.

---

## Endpoints

### 1. Health Check

**GET** `/health`

Check if the API server is running.

**Response:**
```json
{
    "status": "healthy",
    "service": "ARC Backend API",
    "version": "1.0.0"
}
```

**Status Codes:**
- `200` - Server is healthy

---

### 2. Classify Document

**POST** `/api/classify`

Upload and classify a document.

**Request:**
- Content-Type: `multipart/form-data`
- Body:
  - `file` (required): Document file (PDF, PNG, JPG, etc.)
  - `user_id` (optional): User identifier (defaults to 'anonymous')

**Example (curl):**
```bash
curl -X POST http://localhost:5000/api/classify \
  -F "file=@exam_form.pdf" \
  -F "user_id=user123"
```

**Example (Flutter/Dart):**
```dart
var request = http.MultipartRequest(
  'POST',
  Uri.parse('http://localhost:5000/api/classify'),
);
request.files.add(await http.MultipartFile.fromPath('file', filePath));
request.fields['user_id'] = userId;

var response = await request.send();
```

**Success Response (200):**
```json
{
    "success": true,
    "document_id": "550e8400-e29b-41d4-a716-446655440000",
    "document_type": "Exam Form",
    "confidence": 0.92,
    "keywords": ["examination", "form", "student", "semester", "course"],
    "storage_url": "https://supabase.co/storage/...",
    "message": "Document classified as Exam Form"
}
```

**Error Response (400):**
```json
{
    "error": "No file provided"
}
```

**Error Response (500):**
```json
{
    "error": "Internal server error",
    "details": "Error message details"
}
```

**Status Codes:**
- `200` - Success
- `400` - Bad request (no file, invalid file type)
- `500` - Server error

---

### 3. Get User Documents

**GET** `/api/documents?user_id={user_id}`

Retrieve all documents for a specific user.

**Query Parameters:**
- `user_id` (required): User identifier

**Example:**
```bash
curl http://localhost:5000/api/documents?user_id=user123
```

**Success Response (200):**
```json
{
    "success": true,
    "count": 5,
    "documents": [
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "user_id": "user123",
            "filename": "exam_form.pdf",
            "document_type": "Exam Form",
            "confidence": 0.92,
            "storage_url": "https://supabase.co/storage/...",
            "status": "classified",
            "created_at": "2025-01-15T14:30:00Z"
        },
        // ... more documents
    ]
}
```

**Error Response (500):**
```json
{
    "error": "Failed to retrieve documents",
    "details": "Error message"
}
```

**Status Codes:**
- `200` - Success
- `500` - Server error

---

### 4. Get Document by ID

**GET** `/api/documents/{document_id}`

Retrieve a specific document by its ID.

**Path Parameters:**
- `document_id` (required): Document UUID

**Example:**
```bash
curl http://localhost:5000/api/documents/550e8400-e29b-41d4-a716-446655440000
```

**Success Response (200):**
```json
{
    "success": true,
    "document": {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "user_id": "user123",
        "filename": "exam_form.pdf",
        "document_type": "Exam Form",
        "confidence": 0.92,
        "extracted_text": "Examination Form for Final Semester...",
        "storage_url": "https://supabase.co/storage/...",
        "status": "classified",
        "created_at": "2025-01-15T14:30:00Z",
        "updated_at": "2025-01-15T14:30:00Z"
    }
}
```

**Error Response (404):**
```json
{
    "error": "Document not found"
}
```

**Status Codes:**
- `200` - Success
- `404` - Document not found
- `500` - Server error

---

### 5. Get Statistics

**GET** `/api/stats?user_id={user_id}`

Get classification statistics for all documents or a specific user.

**Query Parameters:**
- `user_id` (optional): User identifier (if omitted, returns stats for all users)

**Example:**
```bash
curl http://localhost:5000/api/stats?user_id=user123
```

**Success Response (200):**
```json
{
    "success": true,
    "statistics": {
        "total_documents": 25,
        "by_category": {
            "Exam Form": 8,
            "Receipt": 6,
            "Clearance": 5,
            "Grade Sheet": 4,
            "Other": 2
        },
        "average_confidence": 0.87
    }
}
```

**Error Response (500):**
```json
{
    "error": "Failed to retrieve statistics",
    "details": "Error message"
}
```

**Status Codes:**
- `200` - Success
- `500` - Server error

---

## Document Categories

The API classifies documents into the following categories:

1. `Exam Form`
2. `Acknowledgement Form`
3. `Clearance`
4. `Receipt`
5. `Grade Sheet`
6. `Enrollment Form`
7. `ID Application`
8. `Certificate Request`
9. `Leave Form`
10. `Other`

---

## Error Handling

All endpoints follow a consistent error response format:

```json
{
    "error": "Error description",
    "details": "Detailed error message (optional)"
}
```

Common HTTP status codes:
- `200` - Success
- `400` - Bad Request (invalid input)
- `404` - Not Found (resource doesn't exist)
- `500` - Internal Server Error

---

## Rate Limiting

Currently no rate limiting is implemented. For production:
- Recommended: 100 requests per minute per user
- File upload: 10 requests per minute per user

---

## Authentication

Current implementation uses simple `user_id` field for identification.

**For production, implement:**
- JWT token-based authentication
- Supabase Auth integration
- API key authentication

Example with JWT:
```bash
curl -X POST http://localhost:5000/api/classify \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -F "file=@document.pdf"
```

---

## CORS Configuration

The API currently allows all origins (for development).

**For production:**
- Restrict to specific domains
- Configure in `app.py`:

```python
CORS(app, origins=['https://yourdomain.com'])
```

---

## File Upload Constraints

- **Maximum file size:** 16 MB
- **Allowed formats:** PDF, PNG, JPG, JPEG, TIFF, BMP
- **Timeout:** 60 seconds for processing

---

## Response Times

Typical response times:
- Health check: < 10ms
- Document classification: 2-5 seconds (depends on file size and OCR)
- Get documents: < 100ms
- Statistics: < 200ms

---

## Testing Endpoints

### Using cURL

```bash
# Health check
curl http://localhost:5000/health

# Classify document
curl -X POST http://localhost:5000/api/classify \
  -F "file=@test_document.pdf" \
  -F "user_id=test_user"

# Get documents
curl "http://localhost:5000/api/documents?user_id=test_user"

# Get statistics
curl "http://localhost:5000/api/stats?user_id=test_user"
```

### Using Postman

1. Import the collection from `/docs/postman_collection.json`
2. Set environment variables:
   - `base_url`: `http://localhost:5000`
   - `user_id`: Your test user ID
3. Run the collection

---

## WebSocket Support (Future Enhancement)

For real-time updates during document processing:

**Planned endpoint:** `ws://localhost:5000/ws/classify`

```javascript
const ws = new WebSocket('ws://localhost:5000/ws/classify');

ws.onmessage = (event) => {
    const data = JSON.parse(event.data);
    console.log('Progress:', data.progress);
};
```

---

## Changelog

### Version 1.0.0 (January 2025)
- Initial API release
- Basic document classification
- CRUD operations for documents
- Statistics endpoint
