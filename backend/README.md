# ARC Backend

Flask-based backend API for the ARC (AI-based Record Classifier) system.

## Features

- Document upload and processing
- OCR text extraction using Tesseract
- ML-based document classification
- Integration with Supabase for storage and database
- RESTful API endpoints

## Quick Start

### 1. Install Dependencies

```bash
pip install -r requirements.txt
```

### 2. Configure Environment

Copy `.env.example` to `.env` and fill in your credentials:

```bash
cp .env.example .env
```

### 3. Run the Server

```bash
python app.py
```

Server will start on `http://localhost:5000`

## API Endpoints

- `GET /health` - Health check
- `POST /api/classify` - Upload and classify document
- `GET /api/documents` - Get user documents
- `GET /api/documents/{id}` - Get specific document
- `GET /api/stats` - Get classification statistics

See [API Documentation](../docs/api_endpoints.md) for details.

## Components

- **app.py** - Main Flask application
- **ocr_engine.py** - OCR text extraction
- **ml_classifier.py** - Document classification
- **supabase_client.py** - Database and storage operations

## Testing

```bash
# Test health endpoint
curl http://localhost:5000/health

# Test classification
curl -X POST http://localhost:5000/api/classify \
  -F "file=@sample.pdf" \
  -F "user_id=test_user"
```

## Deployment

See [Setup Guide](../docs/setup_guide.md) for deployment instructions.
