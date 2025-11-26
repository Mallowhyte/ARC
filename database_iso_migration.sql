-- =====================================================
-- ISO DOCUMENT MANAGEMENT SYSTEM - DATABASE MIGRATION
-- =====================================================
-- Version: 1.0.0
-- Purpose: Add ISO-specific features to existing ARC system
-- =====================================================

-- =====================================================
-- STEP 1: Enhance Existing Documents Table
-- =====================================================

-- Add ISO-specific columns to documents table
ALTER TABLE documents 
ADD COLUMN IF NOT EXISTS document_number VARCHAR(50) UNIQUE,
ADD COLUMN IF NOT EXISTS version VARCHAR(20) DEFAULT '1.0',
ADD COLUMN IF NOT EXISTS document_status VARCHAR(20) DEFAULT 'draft',
ADD COLUMN IF NOT EXISTS document_level INTEGER CHECK (document_level BETWEEN 1 AND 4),
ADD COLUMN IF NOT EXISTS department VARCHAR(100),
ADD COLUMN IF NOT EXISTS effective_date DATE,
ADD COLUMN IF NOT EXISTS review_date DATE,
ADD COLUMN IF NOT EXISTS next_review_date DATE,
ADD COLUMN IF NOT EXISTS approved_by TEXT,
ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS is_obsolete BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS obsolete_date DATE,
ADD COLUMN IF NOT EXISTS retention_period_years INTEGER DEFAULT 5,
ADD COLUMN IF NOT EXISTS parent_document_id UUID REFERENCES documents(id);

-- Add comments for documentation
COMMENT ON COLUMN documents.document_number IS 'ISO document number (e.g., PROC-HR-2024-001)';
COMMENT ON COLUMN documents.version IS 'Document version (e.g., 1.0, 2.1)';
COMMENT ON COLUMN documents.document_status IS 'Status: draft, pending_approval, approved, obsolete';
COMMENT ON COLUMN documents.document_level IS 'ISO Level: 1=Manual/Policy, 2=Procedure, 3=Work Instruction, 4=Form/Record';
COMMENT ON COLUMN documents.department IS 'Owning department';
COMMENT ON COLUMN documents.effective_date IS 'Date document becomes effective';
COMMENT ON COLUMN documents.review_date IS 'Last review date';
COMMENT ON COLUMN documents.next_review_date IS 'When document should be reviewed next';

-- =====================================================
-- STEP 2: Create User Roles and Departments Table
-- =====================================================

CREATE TABLE IF NOT EXISTS user_roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id TEXT UNIQUE NOT NULL,
    email VARCHAR(255),
    full_name VARCHAR(255),
    role VARCHAR(50) NOT NULL CHECK (role IN ('instructor', 'department_head', 'quality_manager', 'admin')),
    department VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE user_roles IS 'User roles and department assignments for RBAC';

-- Sample data for testing
INSERT INTO user_roles (user_id, email, full_name, role, department, is_active) VALUES
('demo-instructor-1', 'instructor1@school.edu', 'John Doe', 'instructor', 'Academic Affairs', TRUE),
('demo-dept-head-1', 'depthead1@school.edu', 'Jane Smith', 'department_head', 'Academic Affairs', TRUE),
('demo-qm-1', 'qm@school.edu', 'Quality Manager', 'quality_manager', 'Quality Assurance', TRUE),
('demo-admin-1', 'admin@school.edu', 'System Admin', 'admin', 'IT Services', TRUE)
ON CONFLICT (user_id) DO NOTHING;

-- =====================================================
-- STEP 3: Create Document Versions Table
-- =====================================================

CREATE TABLE IF NOT EXISTS document_versions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    version VARCHAR(20) NOT NULL,
    storage_url TEXT NOT NULL,
    changes_description TEXT,
    file_size BIGINT,
    created_by TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_doc_version UNIQUE(document_id, version)
);

COMMENT ON TABLE document_versions IS 'Complete revision history for all documents';

-- =====================================================
-- STEP 4: Create Document Approvals Table
-- =====================================================

CREATE TABLE IF NOT EXISTS document_approvals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    approver_id TEXT NOT NULL,
    approver_role VARCHAR(50) NOT NULL,
    approval_level INTEGER, -- 1=first level, 2=second level, etc.
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    comments TEXT,
    approved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_doc_approver UNIQUE(document_id, approver_id)
);

COMMENT ON TABLE document_approvals IS 'Approval workflow tracking';

-- =====================================================
-- STEP 5: Create Audit Logs Table
-- =====================================================

CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id UUID REFERENCES documents(id) ON DELETE SET NULL,
    user_id TEXT NOT NULL,
    action VARCHAR(50) NOT NULL,
    action_details JSONB,
    ip_address INET,
    user_agent TEXT,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE audit_logs IS 'Complete audit trail for compliance and security';
COMMENT ON COLUMN audit_logs.action IS 'Actions: view, upload, edit, approve, reject, download, print, obsolete, restore';

-- =====================================================
-- STEP 6: Create Document Number Sequences Table
-- =====================================================

CREATE TABLE IF NOT EXISTS document_sequences (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    prefix VARCHAR(10) NOT NULL, -- PROC, POL, WI, FORM, etc.
    department_code VARCHAR(10) NOT NULL, -- HR, AA, FIN, etc.
    year INTEGER NOT NULL,
    current_sequence INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_sequence UNIQUE(prefix, department_code, year)
);

COMMENT ON TABLE document_sequences IS 'Auto-incrementing sequences for document numbering';

-- =====================================================
-- STEP 7: Create Departments Reference Table
-- =====================================================

CREATE TABLE IF NOT EXISTS departments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(10) UNIQUE NOT NULL, -- HR, AA, FIN, etc.
    name VARCHAR(100) NOT NULL,
    description TEXT,
    head_user_id TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE departments IS 'Master list of school departments';

-- Insert standard departments
INSERT INTO departments (code, name, description, is_active) VALUES
('AA', 'Academic Affairs', 'Academic programs and curriculum management', TRUE),
('HR', 'Human Resources', 'Personnel and employee management', TRUE),
('FIN', 'Finance', 'Financial operations and budgeting', TRUE),
('REG', 'Registrar', 'Student records and enrollment', TRUE),
('QA', 'Quality Assurance', 'ISO compliance and quality management', TRUE),
('IT', 'IT Services', 'Information technology and systems', TRUE),
('SS', 'Student Services', 'Student support and activities', TRUE),
('LIB', 'Library', 'Library and learning resources', TRUE),
('RES', 'Research', 'Research and development', TRUE),
('FAC', 'Facilities', 'Facilities and maintenance', TRUE)
ON CONFLICT (code) DO NOTHING;

-- =====================================================
-- STEP 8: Create Indexes for Performance
-- =====================================================

-- Documents table indexes
CREATE INDEX IF NOT EXISTS idx_documents_number ON documents(document_number);
CREATE INDEX IF NOT EXISTS idx_documents_status ON documents(document_status);
CREATE INDEX IF NOT EXISTS idx_documents_department ON documents(department);
CREATE INDEX IF NOT EXISTS idx_documents_level ON documents(document_level);
CREATE INDEX IF NOT EXISTS idx_documents_effective_date ON documents(effective_date);
CREATE INDEX IF NOT EXISTS idx_documents_obsolete ON documents(is_obsolete);
CREATE INDEX IF NOT EXISTS idx_documents_user_dept ON documents(user_id, department);

-- User roles indexes
CREATE INDEX IF NOT EXISTS idx_user_roles_role ON user_roles(role);
CREATE INDEX IF NOT EXISTS idx_user_roles_department ON user_roles(department);
CREATE INDEX IF NOT EXISTS idx_user_roles_active ON user_roles(is_active);

-- Document versions indexes
CREATE INDEX IF NOT EXISTS idx_doc_versions_doc_id ON document_versions(document_id);
CREATE INDEX IF NOT EXISTS idx_doc_versions_created ON document_versions(created_at);

-- Document approvals indexes
CREATE INDEX IF NOT EXISTS idx_approvals_document ON document_approvals(document_id);
CREATE INDEX IF NOT EXISTS idx_approvals_approver ON document_approvals(approver_id);
CREATE INDEX IF NOT EXISTS idx_approvals_status ON document_approvals(status);

-- Audit logs indexes
CREATE INDEX IF NOT EXISTS idx_audit_logs_document ON audit_logs(document_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp ON audit_logs(timestamp);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);

-- =====================================================
-- STEP 9: Update Row Level Security (RLS) Policies
-- =====================================================

-- Enable RLS on new tables
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE document_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE document_approvals ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;

-- User Roles Policies
CREATE POLICY "Users can view own role" ON user_roles
    FOR SELECT USING (user_id = auth.uid()::text);

CREATE POLICY "Admins can view all roles" ON user_roles
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM user_roles ur
            WHERE ur.user_id = auth.uid()::text
            AND ur.role = 'admin'
        )
    );

CREATE POLICY "Admins can manage roles" ON user_roles
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM user_roles ur
            WHERE ur.user_id = auth.uid()::text
            AND ur.role = 'admin'
        )
    );

-- Document Versions Policies
CREATE POLICY "Users can view versions of accessible documents" ON document_versions
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM documents d
            WHERE d.id = document_versions.document_id
            AND (
                d.user_id = auth.uid()::text
                OR d.department IN (
                    SELECT department FROM user_roles
                    WHERE user_id = auth.uid()::text
                )
            )
        )
    );

-- Document Approvals Policies
CREATE POLICY "Approvers can view their approvals" ON document_approvals
    FOR SELECT USING (approver_id = auth.uid()::text);

CREATE POLICY "Document owners can view approvals" ON document_approvals
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM documents d
            WHERE d.id = document_approvals.document_id
            AND d.user_id = auth.uid()::text
        )
    );

CREATE POLICY "Approvers can update their approvals" ON document_approvals
    FOR UPDATE USING (approver_id = auth.uid()::text);

-- Audit Logs Policies (Read-only for most users)
CREATE POLICY "Admins and QM can view all audit logs" ON audit_logs
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM user_roles ur
            WHERE ur.user_id = auth.uid()::text
            AND ur.role IN ('admin', 'quality_manager')
        )
    );

CREATE POLICY "Users can view their own audit logs" ON audit_logs
    FOR SELECT USING (user_id = auth.uid()::text);

-- Departments Policies (Read-only for most)
CREATE POLICY "All authenticated users can view departments" ON departments
    FOR SELECT USING (auth.uid() IS NOT NULL);

-- Updated Documents Policies for ISO
DROP POLICY IF EXISTS "Users can view own documents" ON documents;
DROP POLICY IF EXISTS "Users can insert own documents" ON documents;

CREATE POLICY "Users can view documents in their department" ON documents
    FOR SELECT USING (
        user_id = auth.uid()::text
        OR department IN (
            SELECT department FROM user_roles
            WHERE user_id = auth.uid()::text
        )
        OR EXISTS (
            SELECT 1 FROM user_roles ur
            WHERE ur.user_id = auth.uid()::text
            AND ur.role IN ('quality_manager', 'admin')
        )
    );

CREATE POLICY "Users can insert documents" ON documents
    FOR INSERT WITH CHECK (
        user_id = auth.uid()::text
        AND (
            department IN (
                SELECT department FROM user_roles
                WHERE user_id = auth.uid()::text
            )
            OR EXISTS (
                SELECT 1 FROM user_roles ur
                WHERE ur.user_id = auth.uid()::text
                AND ur.role IN ('quality_manager', 'admin')
            )
        )
    );

CREATE POLICY "Users can update own documents or dept docs if authorized" ON documents
    FOR UPDATE USING (
        user_id = auth.uid()::text
        OR (
            department IN (
                SELECT department FROM user_roles
                WHERE user_id = auth.uid()::text
                AND role IN ('department_head', 'quality_manager', 'admin')
            )
        )
    );

-- =====================================================
-- STEP 10: Create Utility Functions
-- =====================================================

-- Function to get next document number
CREATE OR REPLACE FUNCTION get_next_document_number(
    p_prefix VARCHAR(10),
    p_department_code VARCHAR(10),
    p_year INTEGER
)
RETURNS VARCHAR(50)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sequence INTEGER;
    v_doc_number VARCHAR(50);
BEGIN
    -- Get or create sequence
    INSERT INTO document_sequences (prefix, department_code, year, current_sequence)
    VALUES (p_prefix, p_department_code, p_year, 1)
    ON CONFLICT (prefix, department_code, year)
    DO UPDATE SET 
        current_sequence = document_sequences.current_sequence + 1,
        updated_at = NOW()
    RETURNING current_sequence INTO v_sequence;
    
    -- Format: PREFIX-DEPT-YEAR-SEQ (e.g., PROC-HR-2024-001)
    v_doc_number := p_prefix || '-' || p_department_code || '-' || p_year || '-' || LPAD(v_sequence::TEXT, 3, '0');
    
    RETURN v_doc_number;
END;
$$;

-- Function to create audit log entry
CREATE OR REPLACE FUNCTION log_audit_action(
    p_document_id UUID,
    p_user_id TEXT,
    p_action VARCHAR(50),
    p_details JSONB DEFAULT NULL,
    p_ip_address INET DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_log_id UUID;
BEGIN
    INSERT INTO audit_logs (document_id, user_id, action, action_details, ip_address)
    VALUES (p_document_id, p_user_id, p_action, p_details, p_ip_address)
    RETURNING id INTO v_log_id;
    
    RETURN v_log_id;
END;
$$;

-- Function to check if user can approve document
CREATE OR REPLACE FUNCTION can_user_approve(
    p_user_id TEXT,
    p_document_level INTEGER
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_role VARCHAR(50);
    v_can_approve BOOLEAN := FALSE;
BEGIN
    SELECT role INTO v_user_role
    FROM user_roles
    WHERE user_id = p_user_id;
    
    -- Admin and Quality Manager can approve all
    IF v_user_role IN ('admin', 'quality_manager') THEN
        v_can_approve := TRUE;
    -- Department Head can approve level 2-4
    ELSIF v_user_role = 'department_head' AND p_document_level >= 2 THEN
        v_can_approve := TRUE;
    END IF;
    
    RETURN v_can_approve;
END;
$$;

-- =====================================================
-- STEP 11: Create Views for Reporting
-- =====================================================

-- View: Documents with approval status
CREATE OR REPLACE VIEW v_documents_with_approvals AS
SELECT 
    d.*,
    COUNT(DISTINCT da.id) as total_approvals_required,
    COUNT(DISTINCT CASE WHEN da.status = 'approved' THEN da.id END) as approvals_received,
    COUNT(DISTINCT CASE WHEN da.status = 'pending' THEN da.id END) as approvals_pending,
    COUNT(DISTINCT CASE WHEN da.status = 'rejected' THEN da.id END) as approvals_rejected
FROM documents d
LEFT JOIN document_approvals da ON d.id = da.document_id
GROUP BY d.id;

-- View: Pending approvals for users
CREATE OR REPLACE VIEW v_pending_approvals AS
SELECT 
    da.id as approval_id,
    da.document_id,
    da.approver_id,
    da.approver_role,
    da.created_at as approval_requested_at,
    d.document_number,
    d.filename,
    d.document_type,
    d.document_level,
    d.department,
    d.user_id as document_owner,
    d.version
FROM document_approvals da
JOIN documents d ON da.document_id = d.id
WHERE da.status = 'pending'
ORDER BY da.created_at;

-- View: Document statistics by department
CREATE OR REPLACE VIEW v_department_statistics AS
SELECT 
    department,
    COUNT(*) as total_documents,
    COUNT(CASE WHEN document_status = 'draft' THEN 1 END) as draft_count,
    COUNT(CASE WHEN document_status = 'pending_approval' THEN 1 END) as pending_approval_count,
    COUNT(CASE WHEN document_status = 'approved' THEN 1 END) as approved_count,
    COUNT(CASE WHEN is_obsolete = TRUE THEN 1 END) as obsolete_count,
    COUNT(CASE WHEN document_level = 1 THEN 1 END) as level_1_count,
    COUNT(CASE WHEN document_level = 2 THEN 1 END) as level_2_count,
    COUNT(CASE WHEN document_level = 3 THEN 1 END) as level_3_count,
    COUNT(CASE WHEN document_level = 4 THEN 1 END) as level_4_count
FROM documents
GROUP BY department;

-- =====================================================
-- STEP 12: Create Triggers
-- =====================================================

-- Trigger: Update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_user_roles_updated_at
    BEFORE UPDATE ON user_roles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_documents_updated_at
    BEFORE UPDATE ON documents
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

-- Trigger: Auto-create version entry on document update
CREATE OR REPLACE FUNCTION create_document_version()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.version IS DISTINCT FROM NEW.version AND NEW.storage_url IS NOT NULL THEN
        INSERT INTO document_versions (
            document_id,
            version,
            storage_url,
            changes_description,
            created_by
        ) VALUES (
            NEW.id,
            NEW.version,
            NEW.storage_url,
            'Version ' || NEW.version,
            NEW.user_id
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_auto_version
    AFTER UPDATE ON documents
    FOR EACH ROW
    EXECUTE FUNCTION create_document_version();

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- Check all new tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('user_roles', 'document_versions', 'document_approvals', 'audit_logs', 'document_sequences', 'departments')
ORDER BY table_name;

-- Check new columns in documents table
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'documents'
AND column_name IN ('document_number', 'version', 'document_status', 'document_level', 'department')
ORDER BY ordinal_position;

-- Count of sample data
SELECT 
    (SELECT COUNT(*) FROM departments) as departments_count,
    (SELECT COUNT(*) FROM user_roles) as user_roles_count;

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================
-- Run verification queries above to confirm success
-- Next steps: Update backend API and Flutter frontend
-- =====================================================
