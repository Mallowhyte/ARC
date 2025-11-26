# ISO Database Migration Guide

## 📋 Overview

This guide explains how to upgrade your ARC system to support ISO document management features.

---

## 🎯 What This Migration Adds

### New Features

1. **ISO Document Numbering**
   - Auto-generated document numbers (e.g., PROC-HR-2024-001)
   - Format: PREFIX-DEPARTMENT-YEAR-SEQUENCE

2. **Document Versioning**
   - Complete revision history
   - Track all document versions
   - Version comparison support

3. **Approval Workflows**
   - Multi-level approval process
   - Role-based approver assignment
   - Approval status tracking

4. **Audit Logging**
   - Complete audit trail
   - Track all document actions
   - Compliance reporting

5. **Department Organization**
   - 10 predefined departments
   - Department-based access control
   - Department statistics

6. **Role-Based Access Control (RBAC)**
   - 4 user roles: Instructor, Department Head, Quality Manager, Admin
   - Permission-based operations
   - Department-specific access

7. **ISO Hierarchy**
   - Level 1: Quality Manual / Policies
   - Level 2: Procedures (SOPs)
   - Level 3: Work Instructions
   - Level 4: Forms / Records

---

## 📊 New Database Tables

| Table | Purpose | Rows (Initial) |
|-------|---------|---------------|
| `user_roles` | User role and department assignments | 4 demo users |
| `document_versions` | Document revision history | 0 (auto-populated) |
| `document_approvals` | Approval workflow tracking | 0 (created on approval) |
| `audit_logs` | Complete audit trail | 0 (auto-populated) |
| `document_sequences` | Auto-incrementing document numbers | 0 (auto-created) |
| `departments` | Master department list | 10 departments |

---

## 🗄️ Enhanced Existing Tables

### Documents Table - New Columns

| Column | Type | Purpose | Example |
|--------|------|---------|---------|
| `document_number` | VARCHAR(50) | ISO document ID | PROC-HR-2024-001 |
| `version` | VARCHAR(20) | Version number | 1.0, 2.1 |
| `document_status` | VARCHAR(20) | Workflow status | draft, approved |
| `document_level` | INTEGER | ISO hierarchy level | 1, 2, 3, or 4 |
| `department` | VARCHAR(100) | Owning department | Academic Affairs |
| `effective_date` | DATE | When document goes live | 2024-11-13 |
| `review_date` | DATE | Last review date | 2024-11-13 |
| `next_review_date` | DATE | Next scheduled review | 2025-11-13 |
| `approved_by` | TEXT | Who approved it | user-id-123 |
| `approved_at` | TIMESTAMPTZ | Approval timestamp | 2024-11-13 10:30:00 |
| `is_obsolete` | BOOLEAN | Obsolete flag | false |
| `retention_period_years` | INTEGER | How long to keep | 5 |

---

## 🚀 How to Apply Migration

### Step 1: Backup Your Database

**IMPORTANT:** Always backup before migrations!

```bash
# If using local PostgreSQL
pg_dump -h localhost -U postgres -d arc_db > backup_before_iso_migration.sql

# For Supabase (via Dashboard)
# Go to Database → Backups → Create Backup
```

### Step 2: Open Supabase SQL Editor

1. Go to https://supabase.com
2. Select your project
3. Click **SQL Editor** in left sidebar
4. Click **New Query**

### Step 3: Run Migration Script

1. Open `database_iso_migration.sql`
2. Copy **entire contents**
3. Paste into Supabase SQL Editor
4. Click **Run** or press `Ctrl+Enter`

### Step 4: Verify Migration

Run verification queries at the end of the migration file:

```sql
-- Check all new tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('user_roles', 'document_versions', 'document_approvals', 
                   'audit_logs', 'document_sequences', 'departments')
ORDER BY table_name;
```

**Expected Result:** 6 tables listed

```sql
-- Check new columns in documents table
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'documents'
AND column_name IN ('document_number', 'version', 'document_status', 
                    'document_level', 'department')
ORDER BY column_name;
```

**Expected Result:** 5 columns listed

```sql
-- Check sample data
SELECT 
    (SELECT COUNT(*) FROM departments) as departments_count,
    (SELECT COUNT(*) FROM user_roles) as user_roles_count;
```

**Expected Result:** 
- departments_count: 10
- user_roles_count: 4 (demo users)

---

## 📋 Predefined Departments

| Code | Name | Description |
|------|------|-------------|
| AA | Academic Affairs | Academic programs and curriculum |
| HR | Human Resources | Personnel and employee management |
| FIN | Finance | Financial operations and budgeting |
| REG | Registrar | Student records and enrollment |
| QA | Quality Assurance | ISO compliance and quality |
| IT | IT Services | Information technology |
| SS | Student Services | Student support and activities |
| LIB | Library | Library and learning resources |
| RES | Research | Research and development |
| FAC | Facilities | Facilities and maintenance |

---

## 👥 User Roles and Permissions

### Instructor
- ✅ Upload documents to own department
- ✅ Edit own documents
- ✅ View department documents
- ❌ Cannot approve documents
- **Levels:** 3, 4 (Work Instructions, Forms)

### Department Head
- ✅ All Instructor permissions
- ✅ Edit department documents
- ✅ Approve Level 2-4 documents
- ✅ View department statistics
- **Levels:** 2, 3, 4 (Procedures, Instructions, Forms)

### Quality Manager
- ✅ Upload/edit any document
- ✅ Approve any document (all levels)
- ✅ Mark documents obsolete
- ✅ View all departments
- ✅ Access audit logs
- **Levels:** 1, 2, 3, 4 (All)

### Admin
- ✅ All Quality Manager permissions
- ✅ Manage users and roles
- ✅ Delete documents
- ✅ System configuration
- **Levels:** 1, 2, 3, 4 (All)

---

## 🔐 Security Enhancements

### Row-Level Security (RLS) Policies

**What Changed:**
- ✅ Department-based access control
- ✅ Role-based document visibility
- ✅ Approval permission checks
- ✅ Audit log access restrictions

**Who Can See What:**

| Role | Own Docs | Dept Docs | All Docs |
|------|----------|-----------|----------|
| Instructor | ✅ | ✅ | ❌ |
| Dept Head | ✅ | ✅ | ❌ |
| Quality Mgr | ✅ | ✅ | ✅ |
| Admin | ✅ | ✅ | ✅ |

---

## 🔢 Document Numbering System

### Format
```
[PREFIX]-[DEPT]-[YEAR]-[SEQ]
```

### Prefixes

| Prefix | Document Type |
|--------|--------------|
| QM | Quality Manual |
| POL | Policy |
| PROC | Procedure/SOP |
| WI | Work Instruction |
| FORM | Form/Template |
| REC | Completed Record |
| AUD | Audit Report |
| CAR | Corrective Action |

### Examples
```
PROC-HR-2024-001  → First HR Procedure in 2024
FORM-AA-2024-015  → 15th Academic Affairs Form in 2024
POL-QA-2024-003   → 3rd Quality Assurance Policy in 2024
WI-IT-2024-007    → 7th IT Work Instruction in 2024
```

### How It Works

1. **Auto-generated** by `get_next_document_number()` function
2. **Unique** - No duplicates possible
3. **Sequential** - Automatically increments
4. **Year-based** - Resets each year

---

## 📈 Document Status Workflow

```
┌──────────┐
│  DRAFT   │ ← User uploads document
└────┬─────┘
     │ Submit for Approval
     ▼
┌──────────────────┐
│ PENDING_APPROVAL │ ← Waiting for approvers
└────┬─────────────┘
     │ All approvals received
     ▼
┌──────────┐
│ APPROVED │ ← Document becomes effective
└────┬─────┘
     │ Mark as obsolete
     ▼
┌──────────┐
│ OBSOLETE │ ← Replaced by newer version
└──────────┘
```

**Status Values:**
- `draft` - Being edited
- `pending_approval` - Awaiting approval
- `approved` - Active and effective
- `obsolete` - No longer valid

---

## 🔍 Audit Actions Tracked

All actions are automatically logged:

- ✅ `view` - Document viewed
- ✅ `upload` - New document uploaded
- ✅ `edit` - Document modified
- ✅ `approve` - Document approved
- ✅ `reject` - Document rejected
- ✅ `download` - Document downloaded
- ✅ `print` - Document printed
- ✅ `obsolete` - Document marked obsolete
- ✅ `restore` - Document restored from obsolete

**Captured Information:**
- Who (user_id)
- What (action)
- When (timestamp)
- Where (IP address)
- Details (JSON metadata)

---

## 📊 New Database Views

### `v_documents_with_approvals`
Shows documents with approval counts:
```sql
SELECT * FROM v_documents_with_approvals
WHERE document_status = 'pending_approval';
```

### `v_pending_approvals`
Shows pending approvals for current user:
```sql
SELECT * FROM v_pending_approvals
WHERE approver_id = 'current-user-id';
```

### `v_department_statistics`
Shows document statistics by department:
```sql
SELECT * FROM v_department_statistics
ORDER BY total_documents DESC;
```

---

## 🛠️ Utility Functions

### 1. Get Next Document Number
```sql
SELECT get_next_document_number('PROC', 'HR', 2024);
-- Returns: PROC-HR-2024-001
```

### 2. Log Audit Action
```sql
SELECT log_audit_action(
    '123e4567-e89b-12d3-a456-426614174000'::uuid,  -- document_id
    'user-123',                                     -- user_id
    'view',                                         -- action
    '{"page": 1}'::jsonb,                          -- details
    '192.168.1.100'::inet                          -- ip_address
);
```

### 3. Check Approval Permission
```sql
SELECT can_user_approve('user-123', 2);  -- Check if user can approve level 2 docs
-- Returns: true or false
```

---

## ⚠️ Important Notes

### Existing Documents
- ✅ All existing documents preserved
- ✅ New columns default to NULL
- ⚠️ Need to update existing records with department/status
- ⚠️ Existing documents won't have document_number (assign manually or via script)

### Backward Compatibility
- ✅ All existing queries still work
- ✅ Old documents remain accessible
- ✅ No data loss
- ⚠️ Update backend to use new fields

### Performance
- ✅ Indexes added for fast queries
- ✅ Views for common reports
- ✅ Efficient RLS policies
- ⚠️ May be slower with large datasets (>100k documents)

---

## 🧪 Testing the Migration

### Test 1: Check Tables
```sql
SELECT COUNT(*) FROM user_roles;        -- Should be 4
SELECT COUNT(*) FROM departments;       -- Should be 10
SELECT COUNT(*) FROM document_versions; -- May be 0
```

### Test 2: Check Functions
```sql
-- Test document numbering
SELECT get_next_document_number('PROC', 'HR', 2024);
SELECT get_next_document_number('PROC', 'HR', 2024);
-- Second call should increment: PROC-HR-2024-002
```

### Test 3: Check Permissions
```sql
-- Test approval permission check
SELECT can_user_approve('demo-dept-head-1', 2);  -- Should be true
SELECT can_user_approve('demo-instructor-1', 2); -- Should be false
```

### Test 4: Check Views
```sql
-- View departments
SELECT * FROM departments ORDER BY code;

-- View user roles
SELECT * FROM user_roles ORDER BY role;
```

---

## 🔄 Rolling Back Migration

If something goes wrong:

```sql
-- Drop new tables (CAUTION: Deletes all data)
DROP TABLE IF EXISTS audit_logs CASCADE;
DROP TABLE IF EXISTS document_approvals CASCADE;
DROP TABLE IF EXISTS document_versions CASCADE;
DROP TABLE IF EXISTS document_sequences CASCADE;
DROP TABLE IF EXISTS user_roles CASCADE;
DROP TABLE IF EXISTS departments CASCADE;

-- Remove new columns from documents table
ALTER TABLE documents 
DROP COLUMN IF EXISTS document_number,
DROP COLUMN IF EXISTS version,
DROP COLUMN IF EXISTS document_status,
DROP COLUMN IF EXISTS document_level,
DROP COLUMN IF EXISTS department,
DROP COLUMN IF EXISTS effective_date,
DROP COLUMN IF EXISTS review_date,
DROP COLUMN IF EXISTS next_review_date,
DROP COLUMN IF EXISTS approved_by,
DROP COLUMN IF EXISTS approved_at,
DROP COLUMN IF EXISTS is_obsolete,
DROP COLUMN IF EXISTS retention_period_years;

-- Restore from backup
-- psql -h localhost -U postgres -d arc_db < backup_before_iso_migration.sql
```

---

## ✅ Next Steps After Migration

1. **Update Backend API** - Add ISO endpoints (Step 2)
2. **Update Flutter Models** - Add new fields
3. **Create UI for ISO Features** - Department view, approvals
4. **Assign User Roles** - Map real users to roles
5. **Test Workflows** - Upload → Approve → Effective
6. **Update Documentation** - Update user guides

---

## 📞 Troubleshooting

### Error: "relation already exists"
**Solution:** Migration already applied or partial run. Check if tables exist:
```sql
SELECT table_name FROM information_schema.tables 
WHERE table_name = 'user_roles';
```

### Error: "column already exists"
**Solution:** Some columns already added. Safe to ignore or drop and re-add.

### Error: "permission denied"
**Solution:** Use Supabase service role key or database owner account.

### Error: RLS policies block operations
**Solution:** Temporarily disable RLS for testing:
```sql
ALTER TABLE documents DISABLE ROW LEVEL SECURITY;
-- Remember to re-enable after testing!
```

---

## 📚 Related Documentation

- **SYSTEM_OVERVIEW.md** - Overall architecture
- **API_DOCUMENTATION.md** - Backend API reference  
- **TROUBLESHOOTING.md** - Common issues
- **database_iso_migration.sql** - Full migration script

---

**Migration Created:** November 13, 2024  
**Version:** 1.0.0  
**Status:** Ready for Production
