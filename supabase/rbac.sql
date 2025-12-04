-- ARC RBAC Setup
-- Roles: admin, auditor, faculty
-- Run this in Supabase SQL editor

-- 1) Base tables
create table if not exists public.departments (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  name text not null
);

create table if not exists public.user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('admin','auditor','faculty')),
  department_id uuid references public.departments(id) on delete set null,
  created_at timestamptz default now()
);

-- Backward compatibility: if legacy column 'department' exists, rename to 'department_id'
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'user_roles' and column_name = 'department'
  ) and not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'user_roles' and column_name = 'department_id'
  ) then
    execute 'alter table public.user_roles rename column department to department_id';
  end if;
end $$;

-- Ensure department_id column exists (for projects where user_roles pre-existed)
alter table public.user_roles
  add column if not exists department_id uuid references public.departments(id) on delete set null;

-- Enforce unique role per user with/without department using partial unique indexes
create unique index if not exists ux_user_roles_user_role_no_dept
  on public.user_roles (user_id, role)
  where department_id is null;

create unique index if not exists ux_user_roles_user_role_dept
  on public.user_roles (user_id, role, department_id)
  where department_id is not null;

-- 2) Documents table adjustments
alter table if exists public.documents
  add column if not exists owner_id uuid,
  add column if not exists department_id uuid references public.departments(id),
  add column if not exists storage_key text;

-- 2a) DPM schema
create table if not exists public.dpm_items (
  id uuid primary key default gen_random_uuid(),
  dpm_number text unique not null,         -- e.g., 'DPM-1.1'
  title text,
  description text,
  evidence_requirements jsonb,             -- optional JSON payload
  created_at timestamptz default now()
);

create table if not exists public.dpm_rules (
  id uuid primary key default gen_random_uuid(),
  dpm_item_id uuid not null references public.dpm_items(id) on delete cascade,
  pattern text not null,
  weight numeric default 1,
  created_at timestamptz default now(),
  unique(dpm_item_id, pattern)
);

-- Documents: DPM classification columns
alter table if exists public.documents
  add column if not exists dpm_number text,
  add column if not exists dpm_item_id uuid references public.dpm_items(id) on delete set null,
  add column if not exists dpm_confidence numeric;

-- Backfill existing rows
update public.documents
set owner_id = user_id::uuid
where owner_id is null
  and user_id::text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';

-- Helpful indexes
create index if not exists idx_documents_owner on public.documents(owner_id);
create index if not exists idx_documents_department on public.documents(department_id);
create index if not exists idx_user_roles_user on public.user_roles(user_id);
create index if not exists idx_documents_dpm on public.documents(dpm_number);
create index if not exists idx_documents_dpm_item on public.documents(dpm_item_id);

-- 3a) RLS on user_roles
alter table public.user_roles enable row level security;
drop policy if exists user_roles_self_read on public.user_roles;
create policy user_roles_self_read on public.user_roles
for select using (user_id::text = auth.uid()::text);
drop policy if exists user_roles_admin_read on public.user_roles;
create policy user_roles_admin_read on public.user_roles
for select using (user_is_admin());

-- Admin write access
drop policy if exists user_roles_admin_insert on public.user_roles;
create policy user_roles_admin_insert on public.user_roles
for insert with check (user_is_admin());

drop policy if exists user_roles_admin_update on public.user_roles;
create policy user_roles_admin_update on public.user_roles
for update using (user_is_admin()) with check (user_is_admin());

drop policy if exists user_roles_admin_delete on public.user_roles;
create policy user_roles_admin_delete on public.user_roles
for delete using (user_is_admin());

-- 3) Helper functions
create or replace function public.user_has_role(p_role text)
returns boolean language sql stable as $$
  select exists(
    select 1 from public.user_roles ur
    where ur.user_id::text = auth.uid()::text and ur.role = p_role
  );
$$;

-- SECURITY DEFINER helper to avoid recursive RLS when checking admin on user_roles
create or replace function public.user_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(
    select 1 from public.user_roles ur
    where ur.user_id::text = auth.uid()::text and ur.role = 'admin'
  );
$$;
grant execute on function public.user_is_admin() to anon, authenticated;

-- Department helper functions are not strictly required for Admin/Auditor/Faculty

-- 4) RLS on documents
alter table public.documents enable row level security;

-- SELECT
drop policy if exists documents_admin_read on public.documents;
create policy documents_admin_read on public.documents
for select using (user_has_role('admin'));

drop policy if exists documents_auditor_read on public.documents;
create policy documents_auditor_read on public.documents
for select using (user_has_role('auditor'));

drop policy if exists documents_owner_read on public.documents;
create policy documents_owner_read on public.documents
for select using (owner_id = auth.uid());

-- No department head role in this scheme

-- INSERT
drop policy if exists documents_admin_insert on public.documents;
create policy documents_admin_insert on public.documents
for insert with check (user_has_role('admin'));

drop policy if exists documents_faculty_insert on public.documents;
create policy documents_faculty_insert on public.documents
for insert with check (
  exists (select 1 from user_roles ur where ur.user_id::text = auth.uid()::text and ur.role = 'faculty')
  and owner_id = auth.uid()
);

-- UPDATE
drop policy if exists documents_admin_update on public.documents;
create policy documents_admin_update on public.documents
for update using (user_has_role('admin')) with check (true);

drop policy if exists documents_owner_update on public.documents;
create policy documents_owner_update on public.documents
for update using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- DELETE
drop policy if exists documents_admin_delete on public.documents;
create policy documents_admin_delete on public.documents
for delete using (user_has_role('admin'));

drop policy if exists documents_owner_delete on public.documents;
create policy documents_owner_delete on public.documents
for delete using (owner_id = auth.uid());

-- 5) Storage policies for bucket "documents"
-- Path convention: <dept_code>/<user_id>/<filename>
-- Ensure bucket exists in Supabase: Storage -> Create bucket "documents" (private)

-- Enable RLS for storage.objects is on by default in Supabase projects

drop policy if exists storage_admin_all on storage.objects;
create policy storage_admin_all on storage.objects
for all using (
  bucket_id = 'documents' and user_has_role('admin')
) with check (bucket_id = 'documents' and user_has_role('admin'));

drop policy if exists storage_auditor_read on storage.objects;
create policy storage_auditor_read on storage.objects
for select using (
  bucket_id = 'documents' and user_has_role('auditor')
);

drop policy if exists storage_faculty_rw_own on storage.objects;
create policy storage_faculty_rw_own on storage.objects
for all using (
  bucket_id = 'documents'
  and split_part(name, '/', 2) = auth.uid()::text
  and exists(select 1 from user_roles ur where ur.user_id::text = auth.uid()::text and ur.role = 'faculty')
) with check (
  bucket_id = 'documents'
  and split_part(name, '/', 2) = auth.uid()::text
);

-- 6) Audit Logs
-- Records who did what, when, and to which resource
create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_user_id text,
  action text not null check (action in ('upload','view','update','delete','list','stats_view')),
  resource_type text not null check (resource_type in ('document','system')),
  resource_id text,
  metadata jsonb,
  created_at timestamptz default now()
);

-- Backward compatibility if table existed without columns
alter table public.audit_logs add column if not exists actor_user_id text;
alter table public.audit_logs add column if not exists metadata jsonb;
alter table public.audit_logs add column if not exists created_at timestamptz;
alter table public.audit_logs alter column created_at set default now();

-- Ask PostgREST (Supabase API) to reload schema so new columns are visible
select pg_notify('pgrst', 'reload schema');

create index if not exists idx_audit_created_at on public.audit_logs(created_at desc);
create index if not exists idx_audit_actor on public.audit_logs(actor_user_id);

alter table public.audit_logs enable row level security;
drop policy if exists audit_admin_read on public.audit_logs;
create policy audit_admin_read on public.audit_logs
for select using (user_has_role('admin'));

drop policy if exists audit_actor_read on public.audit_logs;
create policy audit_actor_read on public.audit_logs
for select using (actor_user_id::text = auth.uid()::text);

-- Allow inserts from application (service role) and from any authenticated user
drop policy if exists audit_insert_any on public.audit_logs;
create policy audit_insert_any on public.audit_logs
for insert with check (true);
