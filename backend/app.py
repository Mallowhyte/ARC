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
        # Fetch user's primary department for RBAC scoping
        dept = supabase_client.get_primary_department(user_id)
        dept_id = dept.get('id') if dept else None
        dept_code = dept.get('code') if dept else None
        # Role guard: only Admin or Faculty can upload
        roles = supabase_client.get_user_roles(user_id)
        role_names = [r.get('role') for r in roles]
        if 'admin' not in role_names and 'faculty' not in role_names:
            return jsonify({'error': 'Forbidden: your role cannot upload'}), 403
        
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
        
        # Step 3: Detect DPM and Upload file to Supabase Storage
        dpm = {}
        try:
            dpm = supabase_client.detect_dpm(extracted_text)
        except Exception as _:
            dpm = {}
        dpm_number = dpm.get('dpm_number') if isinstance(dpm, dict) else None
        dpm_item_id = dpm.get('dpm_item_id') if isinstance(dpm, dict) else None
        dpm_confidence = dpm.get('confidence') if isinstance(dpm, dict) else None
        dpm_folder = dpm.get('dpm_folder') if isinstance(dpm, dict) else None
        # Apply threshold: if low confidence or no match, route to uncategorized and do not set dpm fields
        # Use 0.2 to allow a single strong evidence to classify when the rule set is comprehensive
        if not dpm_item_id or not isinstance(dpm_confidence, (int, float)) or float(dpm_confidence) < 0.2:
            dpm_number = None
            dpm_item_id = None
            dpm_confidence = None
            dpm_folder = None

        print(f"Uploading to Supabase storage...")
        storage_url, storage_key = supabase_client.upload_file(
            temp_path,
            filename,
            user_id,
            dept_code,
            dpm_folder,
        )
        print(f"File uploaded successfully")
        
        # Step 4: Save metadata to Supabase database
        record = {
            'user_id': user_id,
            'owner_id': user_id,
            'department_id': dept_id,
            'filename': filename,
            'document_type': classification_result['document_type'],
            'confidence': classification_result['confidence'],
            'extracted_text': extracted_text[:500],  # Store first 500 chars
            'storage_url': storage_url,
            'status': 'classified',
            'storage_key': storage_key,
            'dpm_number': dpm_number,
            'dpm_item_id': dpm_item_id,
            'dpm_confidence': dpm_confidence,
        }
        
        db_result = supabase_client.save_document_record(record)
        # Audit: upload
        try:
            supabase_client.add_audit_log(
                actor_user_id=user_id,
                action='upload',
                resource_type='document',
                resource_id=db_result.get('id'),
                metadata={'filename': filename, 'document_type': classification_result.get('document_type')}
            )
        except Exception:
            pass
        
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


@app.route('/api/roles', methods=['GET'])
def get_roles():
    """Return roles for a user via service-role backend to avoid client RLS issues."""
    try:
      user_id = request.args.get('user_id')
      if not user_id:
          return jsonify({'error': 'user_id is required'}), 400
      roles = supabase_client.get_user_roles(user_id)
      return jsonify({'success': True, 'roles': roles}), 200
    except Exception as e:
      return jsonify({'error': 'Failed to get roles', 'details': str(e)}), 500

@app.route('/api/documents', methods=['GET'])
def get_documents():
    """Get all documents for a user"""
    try:
        user_id = request.args.get('user_id')
        if not user_id:
            return jsonify({'error': 'user_id is required'}), 400
        documents = supabase_client.get_documents_allowed(user_id)
        # Audit: list
        try:
            supabase_client.add_audit_log(
                actor_user_id=user_id,
                action='list',
                resource_type='document',
                resource_id=None,
                metadata={'count': len(documents)}
            )
        except Exception:
            pass
        
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
        caller_id = request.args.get('user_id')
        if not caller_id:
            return jsonify({'error': 'user_id is required'}), 400

        document = supabase_client.get_document_by_id(document_id)
        
        if not document:
            return jsonify({'error': 'Document not found'}), 404

        # RBAC check (Admin, Auditor, Faculty)
        roles = supabase_client.get_user_roles(caller_id)
        role_names = [r.get('role') for r in roles]
        allowed = False
        if 'admin' in role_names or 'auditor' in role_names:
            allowed = True
        else:
            # Faculty can access only their own documents
            allowed = document.get('owner_id') == caller_id

        if not allowed:
            return jsonify({'error': 'Forbidden'}), 403

        # Audit: view document
        try:
            supabase_client.add_audit_log(
                actor_user_id=caller_id,
                action='view',
                resource_type='document',
                resource_id=document_id,
                metadata={'owner_id': document.get('owner_id')}
            )
        except Exception:
            pass

        return jsonify({
            'success': True,
            'document': document
        }), 200
        
    except Exception as e:
        return jsonify({
            'error': 'Failed to retrieve document',
            'details': str(e)
        }), 500


@app.route('/api/documents/<document_id>', methods=['DELETE'])
def delete_document(document_id):
    """Delete a specific document by ID with RBAC checks"""
    try:
        caller_id = request.args.get('user_id')
        if not caller_id:
            return jsonify({'error': 'user_id is required'}), 400

        # Fetch document
        document = supabase_client.get_document_by_id(document_id)
        if not document:
            return jsonify({'error': 'Document not found'}), 404

        # RBAC: Admin can delete any; Faculty can delete only their own; Auditor cannot delete
        roles = supabase_client.get_user_roles(caller_id)
        role_names = [r.get('role') for r in roles]
        is_admin = 'admin' in role_names
        is_auditor = 'auditor' in role_names
        is_owner = document.get('owner_id') == caller_id

        if is_auditor or (not is_admin and not is_owner):
            return jsonify({'error': 'Forbidden'}), 403

        ok = supabase_client.delete_document(document_id)
        if not ok:
            return jsonify({'error': 'Failed to delete document'}), 500

        # Audit: delete
        try:
            supabase_client.add_audit_log(
                actor_user_id=caller_id,
                action='delete',
                resource_type='document',
                resource_id=document_id,
                metadata={'owner_id': document.get('owner_id')}
            )
        except Exception:
            pass

        return jsonify({'success': True}), 200

    except Exception as e:
        return jsonify({'error': 'Failed to delete document', 'details': str(e)}), 500


@app.route('/api/documents/<document_id>/download', methods=['GET'])
def download_document(document_id):
    """Return a fresh signed download URL for a document with RBAC checks."""
    try:
        caller_id = request.args.get('user_id')
        if not caller_id:
            return jsonify({'error': 'user_id is required'}), 400

        # Fetch document
        document = supabase_client.get_document_by_id(document_id)
        if not document:
            return jsonify({'error': 'Document not found'}), 404

        # RBAC: Admin/Auditor can download any; Faculty can download only own
        roles = supabase_client.get_user_roles(caller_id)
        role_names = [r.get('role') for r in roles]
        is_admin = 'admin' in role_names
        is_auditor = 'auditor' in role_names
        is_owner = document.get('owner_id') == caller_id

        if not (is_admin or is_auditor or is_owner):
            return jsonify({'error': 'Forbidden'}), 403

        signed_url = supabase_client.get_signed_download_url(
            storage_key=document.get('storage_key'),
            storage_url=document.get('storage_url'),
            expires_seconds=60 * 10,
        )
        if not signed_url:
            return jsonify({'error': 'Failed to create download URL'}), 500

        # Audit: treat as view with sub_action=download
        try:
            supabase_client.add_audit_log(
                actor_user_id=caller_id,
                action='view',
                resource_type='document',
                resource_id=document_id,
                metadata={'sub_action': 'download'}
            )
        except Exception:
            pass

        return jsonify({'success': True, 'url': signed_url}), 200

    except Exception as e:
        return jsonify({'error': 'Failed to prepare download', 'details': str(e)}), 500

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
        # Audit: stats_view
        try:
            supabase_client.add_audit_log(
                actor_user_id=user_id,
                action='stats_view',
                resource_type='system',
                resource_id=None,
                metadata={'total_documents': stats.get('total_documents', 0)}
            )
        except Exception:
            pass
        
        return jsonify({
            'success': True,
            'statistics': stats
        }), 200
        
    except Exception as e:
        return jsonify({
            'error': 'Failed to retrieve statistics',
            'details': str(e)
        }), 500


@app.route('/api/dpm/reclassify', methods=['POST'])
def dpm_reclassify():
    try:
        limit_param = request.args.get('limit')
        try:
            limit = int(limit_param) if limit_param else 100
        except ValueError:
            return jsonify({'error': 'limit must be an integer'}), 400
        result = supabase_client.reclassify_dpm(limit=limit, threshold=0.2, only_missing=True)
        return jsonify({'success': True, 'result': result}), 200
    except Exception as e:
        return jsonify({'error': 'Failed to reclassify DPM', 'details': str(e)}), 500


@app.route('/api/users/display', methods=['GET'])
def users_display():
    """Return display info (full_name, email) for comma-separated ids query param.

    Example: /api/users/display?ids=<uuid1>,<uuid2>
    """
    try:
        ids_param = request.args.get('ids', '')
        ids = [s.strip() for s in ids_param.split(',') if s.strip()]
        if not ids:
            return jsonify({'error': 'ids is required'}), 400
        mapping = supabase_client.get_user_displays(ids)
        return jsonify({'success': True, 'users': mapping}), 200
    except Exception as e:
        return jsonify({'error': 'Failed to resolve user displays', 'details': str(e)}), 500


@app.route('/api/users/resolve', methods=['GET'])
def resolve_user_by_email():
    """Resolve a user by email to return their id, email, and full_name.

    Example: /api/users/resolve?email=user@example.com
    """
    try:
        email = request.args.get('email', '').strip()
        if not email:
            return jsonify({'error': 'email is required'}), 400
        user = supabase_client.find_user_by_email(email)
        if not user or not user.get('id'):
            return jsonify({'error': 'User not found'}), 404
        return jsonify({'success': True, 'user': user}), 200
    except Exception as e:
        return jsonify({'error': 'Failed to resolve user by email', 'details': str(e)}), 500


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
