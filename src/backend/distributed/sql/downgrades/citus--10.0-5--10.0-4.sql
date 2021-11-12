-- citus--10.0-5--10.0-4.sql

-- Even if citus--10.0-4--10.0-5.sql includes columnar--10.0-4--10.0-5.sql
-- to insert missing pg_depend records for columnar, we don't revert those
-- changes here.
-- For this reason, this is a no-op downgrade path atm.
