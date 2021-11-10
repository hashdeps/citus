-- To avoid adding another alternative output for upgrade_list_citus_objects,
-- let's run following three DDL's regardless of which postgres version we
-- are using.

-- Test if relying on topological sort of the objects, not their names, works
-- fine where re-creating objects during pg_upgrade.
ALTER SCHEMA public RENAME TO citus_schema;
SET search_path TO citus_schema;

-- As mentioned in https://github.com/citusdata/citus/issues/5447, it
-- is essential to already have public schema to be able to use
-- citus_prepare_pg_upgrade. Until fixing that bug, let's create public
-- schema here on all nodes.
CREATE SCHEMA IF NOT EXISTS public;

-- Do "SELECT 1" to hide port numbers
SELECT 1 FROM run_command_on_workers($$CREATE SCHEMA IF NOT EXISTS public$$);

SHOW server_version \gset
SELECT substring(:'server_version', '\d+')::int > 11 AS server_version_above_eleven
\gset
\if :server_version_above_eleven
\else
\q
\endif

-- create a columnar table within citus_schema
CREATE TABLE new_columnar_table (
  col_1 character varying(100),
  col_2 date,
  col_3 character varying(100),
  col_4 date
) USING columnar;

INSERT INTO new_columnar_table
SELECT ('1', '1999-01-01'::timestamp, '1', '1999-01-01'::timestamp)
FROM generate_series(1, 1000);

CREATE SCHEMA upgrade_columnar;
SET search_path TO upgrade_columnar, public;

CREATE TYPE compfoo AS (f1 int, f2 text);

CREATE TABLE test_retains_data (a int, b text, c compfoo, d int[]) USING columnar;

INSERT INTO test_retains_data VALUES
    (1, 'abc', (1, '4'), ARRAY[1,2,3,4]),
    (2, 'pi', (3, '192'), ARRAY[3,1,4,1,5]),
    (3, 'earth', (4, '22'), ARRAY[1,2,7,5,6]);

--
-- Verify that after upgrade we can read data for tables whose
-- relfilenode has changed before upgrade.
--

-- truncate
CREATE TABLE test_truncated (a int) USING columnar;
INSERT INTO test_truncated SELECT * FROM generate_series(1, 10);
SELECT count(*) FROM test_truncated;

SELECT relfilenode AS relfilenode_pre_truncate
FROM pg_class WHERE oid = 'test_truncated'::regclass::oid \gset

TRUNCATE test_truncated;

SELECT relfilenode AS relfilenode_post_truncate
FROM pg_class WHERE oid = 'test_truncated'::regclass::oid \gset

SELECT :relfilenode_post_truncate <> :relfilenode_pre_truncate AS relfilenode_changed;

INSERT INTO test_truncated SELECT * FROM generate_series(11, 13);
SELECT count(*) FROM test_truncated;

-- vacuum full
CREATE TABLE test_vacuum_full (a int) USING columnar;
INSERT INTO test_vacuum_full SELECT * FROM generate_series(1, 10);
SELECT count(*) FROM test_vacuum_full;

SELECT relfilenode AS relfilenode_pre_vacuum_full
FROM pg_class WHERE oid = 'test_vacuum_full'::regclass::oid \gset

VACUUM FULL test_vacuum_full;

SELECT relfilenode AS relfilenode_post_vacuum_full
FROM pg_class WHERE oid = 'test_vacuum_full'::regclass::oid \gset

SELECT :relfilenode_post_vacuum_full <> :relfilenode_pre_vacuum_full AS relfilenode_changed;

INSERT INTO test_vacuum_full SELECT * FROM generate_series(11, 13);
SELECT count(*) FROM test_vacuum_full;

-- alter column type
CREATE TABLE test_alter_type (a int) USING columnar;
INSERT INTO test_alter_type SELECT * FROM generate_series(1, 10);
SELECT count(*) FROM test_alter_type;

SELECT relfilenode AS relfilenode_pre_alter
FROM pg_class WHERE oid = 'test_alter_type'::regclass::oid \gset

ALTER TABLE test_alter_type ALTER COLUMN a TYPE text;

SELECT relfilenode AS relfilenode_post_alter
FROM pg_class WHERE oid = 'test_alter_type'::regclass::oid \gset

SELECT :relfilenode_pre_alter <> :relfilenode_post_alter AS relfilenode_changed;

INSERT INTO test_alter_type SELECT * FROM generate_series(11, 13);
SELECT count(*) FROM test_alter_type;

-- materialized view
CREATE MATERIALIZED VIEW matview(a, b) USING columnar AS
SELECT floor(a/3), array_agg(b) FROM test_retains_data GROUP BY 1;

SELECT relfilenode AS relfilenode_pre_refresh
FROM pg_class WHERE oid = 'matview'::regclass::oid \gset

REFRESH MATERIALIZED VIEW matview;

SELECT relfilenode AS relfilenode_post_refresh
FROM pg_class WHERE oid = 'matview'::regclass::oid \gset

SELECT :relfilenode_pre_alter <> :relfilenode_post_alter AS relfilenode_changed;

--
-- Test that we retain options
--

SET columnar.stripe_row_limit TO 5000;
SET columnar.chunk_group_row_limit TO 1000;
SET columnar.compression TO 'pglz';

CREATE TABLE test_options_1(a int, b int) USING columnar;
INSERT INTO test_options_1 SELECT i, floor(i/1000) FROM generate_series(1, 10000) i;

CREATE TABLE test_options_2(a int, b int) USING columnar;
INSERT INTO test_options_2 SELECT i, floor(i/1000) FROM generate_series(1, 10000) i;
SELECT alter_columnar_table_set('test_options_2', chunk_group_row_limit => 2000);
SELECT alter_columnar_table_set('test_options_2', stripe_row_limit => 6000);
SELECT alter_columnar_table_set('test_options_2', compression => 'none');
SELECT alter_columnar_table_set('test_options_2', compression_level => 13);
INSERT INTO test_options_2 SELECT i, floor(i/2000) FROM generate_series(1, 10000) i;
