"""
Supabase Client Module
Handles database operations and file storage with Supabase
"""

import os
import mimetypes
from datetime import datetime
from supabase import create_client, Client
from typing import Dict, List, Optional, Tuple
import requests
import urllib.parse


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
    
    def upload_file(self, file_path: str, filename: str, user_id: str, department_code: Optional[str] = None) -> Tuple[str, str]:
        try:
            mime_type, _ = mimetypes.guess_type(file_path)
            if mime_type is None:
                mime_type = 'application/octet-stream'

            with open(file_path, 'rb') as f:
                file_data = f.read()

            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            unique_filename = f"{timestamp}_{filename}"
            folder_prefix = (department_code or 'misc').strip()
            storage_key = f"{folder_prefix}/{user_id}/{unique_filename}"

            self.client.storage.from_(self.bucket_name).upload(
                storage_key,
                file_data,
                {"content-type": mime_type}
            )

            file_url = None
            try:
                # 7 days
                signed = self.client.storage.from_(self.bucket_name).create_signed_url(storage_key, 60 * 60 * 24 * 7)
                if isinstance(signed, dict) and ('signedURL' in signed or 'signed_url' in signed):
                    file_url = signed.get('signedURL') or signed.get('signed_url')
                elif isinstance(signed, str):
                    file_url = signed
            except Exception:
                file_url = self.client.storage.from_(self.bucket_name).get_public_url(storage_key)

            print(f"✅ File uploaded successfully: {storage_key} (MIME: {mime_type})")
            return (file_url or self.client.storage.from_(self.bucket_name).get_public_url(storage_key), storage_key)

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

    def get_user_roles(self, user_id: str) -> List[Dict]:
        try:
            result = self.client.table('user_roles').select('role, department_id').eq('user_id', user_id).execute()
            roles = result.data if result.data else []
            # Fallback via RPC if RLS blocks or no rows visible
            if not roles:
                try:
                    rpc = self.client.rpc('get_user_roles_for', {'p_user_id': user_id}).execute()
                    if rpc.data:
                        roles = rpc.data
                except Exception:
                    pass
            for r in roles:
                dep_id = r.get('department_id')
                if dep_id:
                    try:
                        dep = self.client.table('departments').select('id, code').eq('id', dep_id).single().execute()
                        if dep.data:
                            r['department_code'] = dep.data.get('code')
                    except Exception:
                        pass
            return roles
        except Exception as e:
            # Try RPC fallback if direct select failed
            try:
                rpc = self.client.rpc('get_user_roles_for', {'p_user_id': user_id}).execute()
                return rpc.data if rpc.data else []
            except Exception:
                print(f"Error retrieving user roles: {str(e)}")
                return []

    def get_primary_department(self, user_id: str) -> Optional[Dict]:
        roles = self.get_user_roles(user_id)
        for r in roles:
            if r.get('department_id'):
                return {'id': r.get('department_id'), 'code': r.get('department_code')}
        return None

    def get_documents_allowed(self, user_id: str, limit: int = 50) -> List[Dict]:
        try:
            roles = self.get_user_roles(user_id)
            role_names = [r.get('role') for r in roles]
            if 'admin' in role_names or 'auditor' in role_names:
                res = self.client.table('documents').select('*').order('created_at', desc=True).limit(limit).execute()
                return res.data if res.data else []
            res = self.client.table('documents').select('*').eq('owner_id', user_id).order('created_at', desc=True).limit(limit).execute()
            return res.data if res.data else []
        except Exception as e:
            print(f"Error retrieving allowed documents: {str(e)}")
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
            
            # Delete from storage if key or URL exists
            storage_key = document.get('storage_key')
            if not storage_key and document.get('storage_url'):
                url = document['storage_url']
                try:
                    # signed URL example: .../object/sign/documents/<key>?token=...
                    # public URL example: .../object/public/documents/<key>
                    parts = url.split('/object/')
                    if len(parts) > 1:
                        tail = parts[1]
                        # remove 'sign/' or 'public/' prefix
                        if tail.startswith('sign/'):
                            tail = tail[len('sign/'):]
                        if tail.startswith('public/'):
                            tail = tail[len('public/'):]
                        # remove bucket prefix
                        if tail.startswith(f"{self.bucket_name}/"):
                            storage_key = tail[len(f"{self.bucket_name}/"):]
                        else:
                            storage_key = tail
                        # strip query
                        storage_key = storage_key.split('?')[0]
                except Exception:
                    storage_key = None
            if storage_key:
                try:
                    self.client.storage.from_(self.bucket_name).remove([storage_key])
                except Exception as e:
                    print(f"Error deleting file from storage: {str(e)}")
            
            # Delete database record
            self.client.table('documents').delete().eq('id', document_id).execute()
            
            return True
            
        except Exception as e:
            print(f"Error deleting document: {str(e)}")
            return False

    def _extract_storage_key(self, storage_url: Optional[str]) -> Optional[str]:
        """Extract storage key from a public or signed storage URL."""
        if not storage_url:
            return None
        try:
            parts = storage_url.split('/object/')
            if len(parts) <= 1:
                return None
            tail = parts[1]
            if tail.startswith('sign/'):
                tail = tail[len('sign/'):]
            if tail.startswith('public/'):
                tail = tail[len('public/'):]
            if tail.startswith(f"{self.bucket_name}/"):
                tail = tail[len(f"{self.bucket_name}/"):]
            tail = tail.split('?')[0]
            return tail
        except Exception:
            return None

    def get_signed_download_url(self, storage_key: Optional[str] = None, storage_url: Optional[str] = None, expires_seconds: int = 60 * 5) -> Optional[str]:
        """Return a fresh signed URL for a storage object, falling back to public URL."""
        try:
            key = storage_key or self._extract_storage_key(storage_url)
            if not key:
                return storage_url
            try:
                signed = self.client.storage.from_(self.bucket_name).create_signed_url(key, expires_seconds)
                if isinstance(signed, dict):
                    return signed.get('signedURL') or signed.get('signed_url')
                if isinstance(signed, str):
                    return signed
            except Exception:
                pass
            return self.client.storage.from_(self.bucket_name).get_public_url(key)
        except Exception as e:
            print(f"Error creating signed download URL: {str(e)}")
            return storage_url
    
    def get_statistics(self, user_id: Optional[str] = None) -> Dict:
        """
        Get classification statistics
        
        Args:
            user_id: Optional user filter
            
        Returns:
            Statistics dictionary
        """
        try:
            documents: List[Dict] = []
            if user_id:
                documents = self.get_documents_allowed(user_id, limit=1000)
            else:
                res = self.client.table('documents').select('document_type, confidence').execute()
                documents = res.data if res.data else []
            
            # Calculate statistics
            total = len(documents)
            
            if total == 0:
                return {
                    'total_documents': 0,
                    'by_category': {},
                    'average_confidence': 0
                }
            
            # Group by category
            by_category: Dict[str, int] = {}
            total_confidence = 0.0
            for doc in documents:
                doc_type = doc.get('document_type', 'Unknown')
                by_category[doc_type] = by_category.get(doc_type, 0) + 1
                conf = doc.get('confidence') or 0
                try:
                    total_confidence += float(conf)
                except Exception:
                    pass
            
            avg_conf = (total_confidence / total) if total > 0 else 0
            
            return {
                'total_documents': total,
                'by_category': by_category,
                'average_confidence': avg_conf
            }
        
        except Exception as e:
            print(f"Error calculating statistics: {str(e)}")
            return {
                'total_documents': 0,
                'by_category': {},
                'average_confidence': 0
            }

    def add_audit_log(self,
                      actor_user_id: Optional[str],
                      action: str,
                      resource_type: str,
                      resource_id: Optional[str] = None,
                      metadata: Optional[Dict] = None) -> None:
        """Insert an audit log row. Best-effort; errors are swallowed."""
        try:
            payload = {
                'actor_user_id': actor_user_id,
                'action': action,
                'resource_type': resource_type,
                'resource_id': resource_id,
                'metadata': metadata or {},
            }
            self.client.table('audit_logs').insert(payload).execute()
        except Exception as e:
            print(f"Audit log insert failed: {e}")
    
    def _auth_admin_get_user(self, user_id: str) -> Optional[Dict]:
        """Fetch a user from Supabase Auth Admin REST API using the service key."""
        try:
            url = f"{self.supabase_url}/auth/v1/admin/users/{user_id}"
            headers = {
                'apiKey': self.supabase_key,
                'Authorization': f"Bearer {self.supabase_key}",
            }
            resp = requests.get(url, headers=headers, timeout=10)
            if resp.status_code != 200:
                return None
            data = resp.json()
            return data
        except Exception as e:
            print(f"Auth admin get user failed: {e}")
            return None

    def _auth_admin_find_user_by_email(self, email: str) -> Optional[Dict]:
        """Find a user by exact email using the Auth Admin REST API.

        Some Supabase deployments ignore the email filter and return a page of users.
        To be safe, we filter for an exact, case-insensitive email match and, if not
        found, we paginate through a few pages.
        """
        try:
            base_url = f"{self.supabase_url}/auth/v1/admin/users"
            headers = {
                'apiKey': self.supabase_key,
                'Authorization': f"Bearer {self.supabase_key}",
            }

            def pick_match(payload) -> Optional[Dict]:
                target = (email or '').strip().lower()
                if not target:
                    return None
                if isinstance(payload, list):
                    for u in payload:
                        if isinstance(u, dict) and (u.get('email') or '').strip().lower() == target:
                            return u
                    return None
                if isinstance(payload, dict):
                    if 'users' in payload and isinstance(payload.get('users'), list):
                        return pick_match(payload.get('users'))
                    if (payload.get('email') or '').strip().lower() == target:
                        return payload
                return None

            # Attempt direct query by email param
            try:
                resp = requests.get(base_url, headers=headers, params={'email': email}, timeout=10)
                if resp.status_code == 200:
                    match = pick_match(resp.json())
                    if match:
                        return match
            except Exception:
                pass

            # Fallback: paginate and search
            for page in range(1, 6):  # scan up to ~1000 users at 200/page
                try:
                    resp2 = requests.get(base_url, headers=headers, params={'per_page': 200, 'page': page}, timeout=10)
                    if resp2.status_code != 200:
                        break
                    data2 = resp2.json()
                    match = pick_match(data2)
                    if match:
                        return match
                    # Stop if fewer than a page returned (end of list)
                    if isinstance(data2, list) and len(data2) < 200:
                        break
                    if isinstance(data2, dict) and isinstance(data2.get('users'), list) and len(data2.get('users')) < 200:
                        break
                except Exception:
                    break
            return None
        except Exception as e:
            print(f"Auth admin find user by email failed: {e}")
            return None

    def find_user_by_email(self, email: str) -> Optional[Dict]:
        try:
            try:
                res = self.client.table('users').select('id, full_name, email').eq('email', email).maybe_single().execute()
                if isinstance(res.data, dict) and res.data.get('id'):
                    return {'id': res.data.get('id'), 'email': res.data.get('email'), 'full_name': res.data.get('full_name')}
            except Exception:
                pass
            data = self._auth_admin_find_user_by_email(email)
            if not data:
                return None
            meta = data.get('user_metadata') or data.get('raw_user_meta_data') or {}
            full_name = None
            if isinstance(meta, dict):
                full_name = meta.get('full_name') or meta.get('name')
            return {'id': data.get('id'), 'email': data.get('email'), 'full_name': full_name}
        except Exception as e:
            print(f"find_user_by_email failed: {e}")
            return None

    def get_user_displays(self, ids: List[str]) -> Dict[str, Dict[str, Optional[str]]]:
        """Return mapping of user_id -> {full_name, email}.

        Tries public.users first, then falls back to Auth Admin API for missing IDs.
        """
        result: Dict[str, Dict[str, Optional[str]]] = {}
        if not ids:
            return result
        try:
            # Prefer view over auth.users to avoid Admin API
            try:
                res_v = self.client.table('auth_users_view').select('id, full_name, email').in_('id', ids).execute()
                rows_v = res_v.data or []
                for row in rows_v:
                    uid = row.get('id')
                    if uid:
                        result[uid] = {
                            'full_name': row.get('full_name'),
                            'email': row.get('email'),
                        }
            except Exception:
                pass

            # Fallback to project table 'users' if present
            try:
                missing_pre = [i for i in ids if i not in result]
                if missing_pre:
                    res = self.client.table('users').select('id, full_name, email').in_('id', missing_pre).execute()
                    rows = res.data or []
                    for row in rows:
                        uid = row.get('id')
                        if uid and uid not in result:
                            result[uid] = {
                                'full_name': row.get('full_name'),
                                'email': row.get('email'),
                            }
            except Exception:
                pass

            # Fallback to Auth Admin for missing
            missing = [i for i in ids if i not in result]
            for uid in missing:
                data = self._auth_admin_get_user(uid)
                if not data:
                    continue
                full_name = None
                # Supabase returns user_metadata or raw_user_meta_data depending on SDK
                meta = data.get('user_metadata') or data.get('raw_user_meta_data') or {}
                if isinstance(meta, dict):
                    full_name = meta.get('full_name') or meta.get('name')
                result[uid] = {
                    'full_name': full_name,
                    'email': data.get('email'),
                }
        except Exception as e:
            print(f"Error building user display map: {e}")
        return result
    
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
