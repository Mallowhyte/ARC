-- Seed DPM-USTP-ACAD-001 and initial evidence rules
-- Run this in Supabase SQL editor (or via psql). Safe to re-run.

-- 1) Upsert the DPM item
with upsert_item as (
  insert into public.dpm_items (dpm_number, title, description)
  values (
    'DPM-USTP-ACAD-001',
    'Academic Procedures 001',
    'Initial seed for syllabus-related evidence (SRF/Syllabus). Update title/description as needed.'
  )
  on conflict (dpm_number) do update set
    title = excluded.title,
    description = excluded.description
  returning id
)
-- 2) Upsert rules with weights
insert into public.dpm_rules (dpm_item_id, pattern, weight)
select u.id, v.pattern, v.weight
from upsert_item u
cross join (
  -- Regex rules use the 're:' prefix; others are case-insensitive substrings.
  values
    ('re:\bsyllabus\s*review\s*form\b', 1.0), -- exact phrase SRF
    ('re:\bsrf\b', 1.0),                            -- acronym SRF
    ('syllabus review', 0.6),                            -- generic phrase
    ('course syllabus', 0.5),                            -- common header
    ('syllabus', 0.4)                                    -- fallback keyword
) as v(pattern, weight)
on conflict (dpm_item_id, pattern) do update set weight = excluded.weight;

-- 3) Make PostgREST reload schema (optional but harmless)
select pg_notify('pgrst', 'reload schema');
