# Database Schema Documentation

## Supabase PostgreSQL Database

### Tables

#### 1. `documents` Table

Primary table for storing document metadata and classification results.

```sql
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

-- Indexes for performance
CREATE INDEX idx_documents_user_id ON documents(user_id);
CREATE INDEX idx_documents_document_type ON documents(document_type);
CREATE INDEX idx_documents_created_at ON documents(created_at DESC);
```

**Columns:**
- `id`: Unique identifier (UUID)
- `user_id`: User who uploaded the document
- `filename`: Original filename
- `document_type`: Classified category (Exam Form, Receipt, etc.)
- `confidence`: Classification confidence score (0.00 - 1.00)
- `extracted_text`: OCR extracted text (first 500 characters)
- `storage_url`: URL to stored file in Supabase Storage
- `status`: Processing status (uploaded, processing, classified, error)
- `created_at`: Timestamp of creation
- `updated_at`: Timestamp of last update

---

#### 2. `users` Table (Optional - for future user management)

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'staff',
    department VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_login TIMESTAMP WITH TIME ZONE
);

-- Index
CREATE INDEX idx_users_email ON users(email);
```

**Columns:**
- `id`: Unique identifier
- `email`: User email address
- `name`: Full name
- `role`: User role (admin, staff, faculty, registrar)
- `department`: Department or office
- `created_at`: Account creation timestamp
- `last_login`: Last login timestamp

---

#### 3. `classification_history` Table (Optional - for tracking changes)

```sql
CREATE TABLE classification_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id UUID REFERENCES documents(id) ON DELETE CASCADE,
    old_type VARCHAR(100),
    new_type VARCHAR(100),
    changed_by VARCHAR(255),
    reason TEXT,
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index
CREATE INDEX idx_history_document_id ON classification_history(document_id);
```

**Columns:**
- `id`: Unique identifier
- `document_id`: Reference to document
- `old_type`: Previous classification
- `new_type`: Updated classification
- `changed_by`: User who made the change
- `reason`: Reason for reclassification
- `changed_at`: Timestamp of change

---

## Supabase Storage Buckets

### `documents` Bucket

Stores uploaded document files (PDF, images).

**Configuration:**
- Public: No (private access only)
- File size limit: 16MB
- Allowed file types: PDF, PNG, JPG, JPEG, TIFF, BMP

**File naming convention:**
```
{timestamp}_{original_filename}
Example: 20250115_143020_exam_form.pdf
```

---

## Row Level Security (RLS) Policies

### Documents Table Policies

```sql
-- Enable RLS
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own documents
CREATE POLICY "Users can view own documents"
ON documents FOR SELECT
USING (auth.uid()::text = user_id);

-- Policy: Users can insert their own documents
CREATE POLICY "Users can insert own documents"
ON documents FOR INSERT
WITH CHECK (auth.uid()::text = user_id);

-- Policy: Users can update their own documents
CREATE POLICY "Users can update own documents"
ON documents FOR UPDATE
USING (auth.uid()::text = user_id);

-- Policy: Admins can view all documents
CREATE POLICY "Admins can view all documents"
ON documents FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM users
        WHERE id = auth.uid()
        AND role = 'admin'
    )
);
```

---

## Document Categories

The system classifies documents into the following categories:

1. **Exam Form** - Examination application forms
2. **Acknowledgement Form** - Receipt acknowledgements
3. **Clearance** - Clearance certificates
4. **Receipt** - Payment receipts
5. **Grade Sheet** - Grade reports and transcripts
6. **Enrollment Form** - Student enrollment forms
7. **ID Application** - Student ID applications
8. **Certificate Request** - Certificate request forms
9. **Leave Form** - Leave application forms
10. **Other** - Unclassified or unknown documents

---

## Sample Queries

### Get all documents for a user
```sql
SELECT * FROM documents
WHERE user_id = 'user123'
ORDER BY created_at DESC;
```

### Get documents by category
```sql
SELECT * FROM documents
WHERE document_type = 'Receipt'
AND user_id = 'user123'
ORDER BY created_at DESC;
```

### Get classification statistics
```sql
SELECT 
    document_type,
    COUNT(*) as count,
    AVG(confidence) as avg_confidence
FROM documents
WHERE user_id = 'user123'
GROUP BY document_type
ORDER BY count DESC;
```

### Search documents by content
```sql
SELECT * FROM documents
WHERE extracted_text ILIKE '%keyword%'
AND user_id = 'user123';
```

---

## Migration Scripts

### Initial Setup
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
```

---

## Backup and Maintenance

### Backup Strategy
- Daily automated backups via Supabase
- Keep backups for 30 days
- Test restore procedures monthly

### Maintenance Tasks
- Monitor storage usage
- Archive old documents (>1 year)
- Update confidence scores based on user feedback
- Retrain ML model quarterly
