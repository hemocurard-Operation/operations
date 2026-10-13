-- ISOLATED TEST RECONSTRUCTION ONLY. Never apply this fixture to a hosted project.
-- The live HemoCura donations table has collected_at (timestamptz), verified by
-- information_schema. The older v0.23 SQL reconstruction omits that column.
-- Add the observed column so the full-suite fixture can exercise the same view.
alter table public.donations add column if not exists collected_at timestamptz;
