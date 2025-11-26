"""
ARC Backend API - Flask Application
Main entry point for the AI-based Record Classifier backend
"""

import os
from datetime import datetime
from flask import Flask, request, jsonify
from flask_cors import CORS
from dotenv import load_dotenv
from werkzeug.utils import secure_filename
import traceback

from ocr_engine import OCREngine
from ml_classifier import DocumentClassifier
from field_extractor import FieldExtractor
from supabase_client import SupabaseClient

# Load environment variables
load_dotenv()

# Initialize Flask app
app = Flask(__name__)
CORS(app)

# Configuration
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'dev-secret-key')
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max file size
app.config['UPLOAD_FOLDER'] = 'temp_uploads'

# Allowed file extensions
ALLOWED_EXTENSIONS = {'pdf', 'png', 'jpg', 'jpeg', 'tiff', 'bmp'}

# Initialize services
print("Initializing services...")
ocr_engine = OCREngine()
classifier = DocumentClassifier()
supabase_client = SupabaseClient()

# Create temp upload folder if it doesn't exist
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

# Verify Tesseract is available
try:
    import pytesseract
    version = pytesseract.get_tesseract_version()
    print(f"✓ Tesseract OCR {version} detected")
except Exception as e:
    print("⚠ WARNING: Tesseract OCR not found!")
    print(f"  Error: {str(e)}")
    print("  Please install Tesseract: https://github.com/UB-Mannheim/tesseract/wiki")
    print("  And set TESSERACT_PATH in .env file")


def allowed_file(filename):
    """Check if file extension is allowed"""
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS


@app.route('/', methods=['GET'])
def index():
    """Root endpoint - API information"""
    return jsonify({
        'service': 'ARC Backend API',
        'description': 'AI-based Record Classifier - Document classification and OCR service',
        'version': '1.0.0',
        'status': 'running',
        'endpoints': {
            'health': '/health',
            'classify': '/api/classify (POST)',
            'statistics': '/api/stats',
            'user_documents': '/api/documents/{user_id}'
        },
        'documentation': {
            'classify': 'Upload file for OCR and classification',
            'stats': 'Get classification statistics',
            'documents': 'Retrieve user documents'
        }
    }), 200


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'ARC Backend API',
        'version': '1.0.0'
    }), 200


@app.route('/api/classify', methods=['POST'])
def classify_document():
    """
    Main endpoint for document classification
    Accepts file upload, performs OCR, classifies, and stores in Supabase
    """
    try:
        # Check if file is present in request
        if 'file' not in request.files:
            return jsonify({'error': 'No file provided'}), 400
        
        file = request.files['file']
        
        if file.filename == '':
            return jsonify({'error': 'No file selected'}), 400
        
        if not allowed_file(file.filename):
            return jsonify({'error': 'File type not allowed'}), 400
        
        # Get user_id from request (optional)
        user_id = request.form.get('user_id', 'anonymous')
        
        # Save file temporarily
        filename = secure_filename(file.filename)
        temp_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        file.save(temp_path)
        
        # Step 1: Perform OCR
        print(f"Processing file: {filename}")
        try:
            extracted_text = ocr_engine.extract_text(temp_path)
            length = len(extracted_text) if extracted_text is not None else 0
            print(f"OCR completed. Extracted {length} characters")
        except Exception as ocr_error:
            print(f"OCR Error: {str(ocr_error)}")
            # Clean up temp file
            if os.path.exists(temp_path):
                os.remove(temp_path)
            return jsonify({
                'error': 'OCR processing failed',
                'details': str(ocr_error)
            }), 500

        # Even if the text is very short or noisy, proceed to classification.
        # The classifier already handles "insufficient_text" cases and will
        # return a low-confidence "Other" result when appropriate.
        if not extracted_text or len(extracted_text.strip()) < 10:
            print("Warning: OCR extracted very little text; proceeding with classification using insufficient_text handling.")

        # Step 2: Classify document
        print(f"Classifying document...")
        classification_result = classifier.classify(extracted_text)
        print(f"Classification: {classification_result['document_type']} (confidence: {classification_result['confidence']})")
        
        # Step 2.1: Extract structured fields (no DB schema change; return in response)
        extracted_fields = {}
        try:
            if classification_result.get('document_type') == 'Syllabus Review Form':
                extracted_fields = FieldExtractor.extract_syllabus_review(extracted_text)
        except Exception as fe_err:
            print(f"Field extraction error: {str(fe_err)}")
        
        # Step 3: Upload file to Supabase Storage
        print(f"Uploading to Supabase storage...")
        storage_url = supabase_client.upload_file(temp_path, filename)
        print(f"File uploaded successfully")
        
        # Step 4: Save metadata to Supabase database
        record = {
            'user_id': user_id,
            'filename': filename,
            'document_type': classification_result['document_type'],
            'confidence': classification_result['confidence'],
            'extracted_text': extracted_text[:500],  # Store first 500 chars
            'storage_url': storage_url,
            'status': 'classified'
        }
        
        db_result = supabase_client.save_document_record(record)
        
        # Clean up temp file
        os.remove(temp_path)
        
        # Return result
        return jsonify({
            'success': True,
            'document_id': db_result['id'],
            'document_type': classification_result['document_type'],
            'confidence': classification_result['confidence'],
            'keywords': classification_result.get('keywords', []),
            'storage_url': storage_url,
            'fields': extracted_fields,
            'message': f'Document classified as {classification_result["document_type"]}'
        }), 200
        
    except Exception as e:
        print(f"Error processing document: {str(e)}")
        traceback.print_exc()
        
        # Clean up temp file if exists
        if 'temp_path' in locals() and os.path.exists(temp_path):
            os.remove(temp_path)
        
        return jsonify({
            'error': 'Internal server error',
            'details': str(e)
        }), 500


@app.route('/api/documents', methods=['GET'])
def get_documents():
    """Get all documents for a user"""
    try:
        user_id = request.args.get('user_id', 'anonymous')
        documents = supabase_client.get_user_documents(user_id)
        
        return jsonify({
            'success': True,
            'count': len(documents),
            'documents': documents
        }), 200
        
    except Exception as e:
        return jsonify({
            'error': 'Failed to retrieve documents',
            'details': str(e)
        }), 500


@app.route('/api/documents/<document_id>', methods=['GET'])
def get_document_by_id(document_id):
    """Get a specific document by ID"""
    try:
        document = supabase_client.get_document_by_id(document_id)
        
        if not document:
            return jsonify({'error': 'Document not found'}), 404
        
        return jsonify({
            'success': True,
            'document': document
        }), 200
        
    except Exception as e:
        return jsonify({
            'error': 'Failed to retrieve document',
            'details': str(e)
        }), 500


@app.route('/api/next-document-number', methods=['GET'])
def next_document_number():
    """Return the next ISO document number.

    Query params:
        prefix: e.g., PROC, FORM
        department: department code e.g., BSIT
        year: optional, defaults to current year
    """
    prefix = request.args.get('prefix')
    department = request.args.get('department')
    year_param = request.args.get('year')

    if not prefix or not department:
        return jsonify({'error': 'prefix and department are required'}), 400

    try:
        year = int(year_param) if year_param else datetime.now().year
    except ValueError:
        return jsonify({'error': 'year must be an integer'}), 400

    try:
        doc_number = supabase_client.get_next_document_number(prefix.upper(), department.upper(), year)
        return jsonify({'success': True, 'document_number': doc_number}), 200
    except Exception as e:
        return jsonify({'error': 'Failed to generate document number', 'details': str(e)}), 500


@app.route('/api/stats', methods=['GET'])
def get_statistics():
    """Get classification statistics"""
    try:
        user_id = request.args.get('user_id')
        stats = supabase_client.get_statistics(user_id)
        
        return jsonify({
            'success': True,
            'statistics': stats
        }), 200
        
    except Exception as e:
        return jsonify({
            'error': 'Failed to retrieve statistics',
            'details': str(e)
        }), 500


if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    host = os.getenv('HOST', '0.0.0.0')
    debug = os.getenv('FLASK_DEBUG', 'True') == 'True'
    
    print("\n" + "="*60)
    print("🎓 ARC Backend API - AI-based Record Classifier")
    print("="*60)
    print(f"✓ Server starting on {host}:{port}")
    print(f"✓ Debug mode: {'ON' if debug else 'OFF'}")
    print(f"✓ Health check: http://localhost:{port}/health")
    print(f"✓ Classify endpoint: http://localhost:{port}/api/classify")
    print("="*60 + "\n")
    
    app.run(host=host, port=port, debug=debug)
