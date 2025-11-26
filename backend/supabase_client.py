"""
Supabase Client Module
Handles database operations and file storage with Supabase
"""

import os
import mimetypes
from datetime import datetime
from supabase import create_client, Client
from typing import Dict, List, Optional


class SupabaseClient:
    """Client for interacting with Supabase database and storage"""
    
    def __init__(self):
        """Initialize Supabase client"""
        self.supabase_url = os.getenv('SUPABASE_URL')
        self.supabase_key = os.getenv('SUPABASE_KEY')
        
        if not self.supabase_url or not self.supabase_key:
            raise ValueError("SUPABASE_URL and SUPABASE_KEY must be set in environment variables")
        
        self.client: Client = create_client(self.supabase_url, self.supabase_key)
        self.bucket_name = 'documents'
        
        # Ensure storage bucket exists
        self._ensure_bucket_exists()
    
    def _ensure_bucket_exists(self):
        """Ensure the storage bucket exists"""
        try:
            # Try to get bucket info
            bucket = self.client.storage.get_bucket(self.bucket_name)
            print(f"✓ Storage bucket '{self.bucket_name}' is ready")
        except Exception as get_error:
            # Bucket doesn't exist, try to create it
            try:
                self.client.storage.create_bucket(
                    self.bucket_name,
                    options={'public': False}
                )
                print(f"✓ Created storage bucket: {self.bucket_name}")
            except Exception as create_error:
                # If bucket already exists or we can't create it, try to use it anyway
                # This error often occurs when using anon key instead of service_role key
                error_msg = str(create_error)
                if 'already exists' in error_msg.lower():
                    print(f"✓ Storage bucket '{self.bucket_name}' already exists")
                elif 'row-level security' in error_msg.lower() or 'unauthorized' in error_msg.lower():
                    print(f"ℹ Storage bucket '{self.bucket_name}' exists (create permission not needed)")
                else:
                    print(f"⚠ Warning: Could not verify bucket: {error_msg}")
                    print(f"  Continuing anyway - bucket may already exist")
    
    def upload_file(self, file_path: str, filename: str) -> str:
        """
        Upload file to Supabase storage
        
        Args:
            file_path: Local path to file
            filename: Name to save file as
            
        Returns:
            Public URL of uploaded file
        """
        try:
            # Detect MIME type automatically
            mime_type, _ = mimetypes.guess_type(file_path)
            if mime_type is None:
                mime_type = 'application/octet-stream'  # fallback if unknown

            # Read file
            with open(file_path, 'rb') as f:
                file_data = f.read()
            
            # Generate unique filename with timestamp
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            unique_filename = f"{timestamp}_{filename}"
            
            # Upload to Supabase storage with correct content-type
            result = self.client.storage.from_(self.bucket_name).upload(
                unique_filename,
                file_data,
                {"content-type": mime_type}
            )
            
            # Get public URL
            file_url = self.client.storage.from_(self.bucket_name).get_public_url(unique_filename)
            
            print(f"✅ File uploaded successfully: {unique_filename} (MIME: {mime_type})")
            return file_url
            
        except Exception as e:
            print(f"❌ Error uploading file: {str(e)}")
            raise
    
    def save_document_record(self, record: Dict) -> Dict:
        """
        Save document metadata to database
        
        Args:
            record: Dictionary containing document metadata
            
        Returns:
            Inserted record with ID
        """
        try:
            # Add timestamp
            record['created_at'] = datetime.now().isoformat()
            
            # Insert into documents table
            result = self.client.table('documents').insert(record).execute()
            
            if result.data:
                print(f"Document record saved with ID: {result.data[0]['id']}")
                return result.data[0]
            else:
                raise Exception("Failed to save document record")
                
        except Exception as e:
            print(f"Error saving document record: {str(e)}")
            raise
    
    def get_user_documents(self, user_id: str, limit: int = 50) -> List[Dict]:
        """
        Get all documents for a specific user
        
        Args:
            user_id: User identifier
            limit: Maximum number of documents to return
            
        Returns:
            List of document records
        """
        try:
            result = self.client.table('documents')\
                .select('*')\
                .eq('user_id', user_id)\
                .order('created_at', desc=True)\
                .limit(limit)\
                .execute()
            
            return result.data if result.data else []
            
        except Exception as e:
            print(f"Error retrieving documents: {str(e)}")
            return []
    
    def get_document_by_id(self, document_id: str) -> Optional[Dict]:
        """
        Get a specific document by ID
        
        Args:
            document_id: Document ID
            
        Returns:
            Document record or None
        """
        try:
            result = self.client.table('documents')\
                .select('*')\
                .eq('id', document_id)\
                .single()\
                .execute()
            
            return result.data if result.data else None
            
        except Exception as e:
            print(f"Error retrieving document: {str(e)}")
            return None
    
    def update_document(self, document_id: str, updates: Dict) -> Dict:
        """
        Update document record
        
        Args:
            document_id: Document ID
            updates: Dictionary of fields to update
            
        Returns:
            Updated document record
        """
        try:
            updates['updated_at'] = datetime.now().isoformat()
            
            result = self.client.table('documents')\
                .update(updates)\
                .eq('id', document_id)\
                .execute()
            
            if result.data:
                return result.data[0]
            else:
                raise Exception("Failed to update document")
                
        except Exception as e:
            print(f"Error updating document: {str(e)}")
            raise
    
    def delete_document(self, document_id: str) -> bool:
        """
        Delete document record and file
        
        Args:
            document_id: Document ID
            
        Returns:
            True if successful
        """
        try:
            # Get document info first
            document = self.get_document_by_id(document_id)
            if not document:
                return False
            
            # Delete from storage if URL exists
            if document.get('storage_url'):
                # Extract filename from URL
                filename = document['storage_url'].split('/')[-1]
                try:
                    self.client.storage.from_(self.bucket_name).remove([filename])
                except Exception as e:
                    print(f"Error deleting file from storage: {str(e)}")
            
            # Delete database record
            self.client.table('documents').delete().eq('id', document_id).execute()
            
            return True
            
        except Exception as e:
            print(f"Error deleting document: {str(e)}")
            return False
    
    def get_statistics(self, user_id: Optional[str] = None) -> Dict:
        """
        Get classification statistics
        
        Args:
            user_id: Optional user filter
            
        Returns:
            Statistics dictionary
        """
        try:
            query = self.client.table('documents').select('document_type, confidence')
            
            if user_id:
                query = query.eq('user_id', user_id)
            
            result = query.execute()
            documents = result.data if result.data else []
            
            # Calculate statistics
            total = len(documents)
            
            if total == 0:
                return {
                    'total_documents': 0,
                    'by_category': {},
                    'average_confidence': 0
                }
            
            # Count by category
            category_counts = {}
            total_confidence = 0
            
            for doc in documents:
                doc_type = doc.get('document_type', 'Unknown')
                category_counts[doc_type] = category_counts.get(doc_type, 0) + 1
                total_confidence += doc.get('confidence', 0)
            
            avg_confidence = total_confidence / total if total > 0 else 0
            
            return {
                'total_documents': total,
                'by_category': category_counts,
                'average_confidence': round(avg_confidence, 2)
            }
            
        except Exception as e:
            print(f"Error getting statistics: {str(e)}")
            return {
                'total_documents': 0,
                'by_category': {},
                'average_confidence': 0
            }
    
    def get_next_document_number(self, prefix: str, department_code: str, year: int) -> str:
        """Generate the next ISO document number via Postgres function get_next_document_number.

        Args:
            prefix: Document prefix e.g., 'PROC', 'FORM'
            department_code: Department code e.g., 'BSIT'
            year: Four-digit year (e.g., 2025)

        Returns:
            The generated document number string.
        """
        try:
            result = self.client.rpc(
                'get_next_document_number',
                {
                    'p_prefix': prefix,
                    'p_department_code': department_code,
                    'p_year': year,
                },
            ).execute()
            # Supabase RPC returns scalar result in result.data; ensure it's present
            if isinstance(result.data, list) and result.data:
                # For supabase-py <2.0 result.data may be list of dicts with key 'get_next_document_number'
                value = list(result.data[0].values())[0]
                return value
            elif isinstance(result.data, str):
                return result.data
            else:
                raise ValueError('Unexpected RPC response format')
        except Exception as e:
            print(f"Error generating document number: {str(e)}")
            raise

    def search_documents(self, query: str, user_id: Optional[str] = None) -> List[Dict]:
        """
        Search documents by text content
        
        Args:
            query: Search query
            user_id: Optional user filter
            
        Returns:
            List of matching documents
        """
        try:
            db_query = self.client.table('documents')\
                .select('*')\
                .ilike('extracted_text', f'%{query}%')
            
            if user_id:
                db_query = db_query.eq('user_id', user_id)
            
            result = db_query.execute()
            return result.data if result.data else []
            
        except Exception as e:
            print(f"Error searching documents: {str(e)}")
            return []


if __name__ == "__main__":
    # Test Supabase client
    from dotenv import load_dotenv
    load_dotenv()
    
    try:
        client = SupabaseClient()
        print("Supabase client initialized successfully")
        
        # Test statistics
        stats = client.get_statistics()
        print(f"Statistics: {stats}")
        
    except Exception as e:
        print(f"Error: {str(e)}")
