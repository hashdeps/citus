-- columnar--10.0-4--10.0-5.sql

DO $proc$
BEGIN

IF substring(current_Setting('server_version'), '\d+')::int >= 12 THEN
EXECUTE $$

INSERT INTO pg_depend
SELECT -- Define a dependency edge from "columnar table access method" ..
       'pg_am'::regclass::oid as classid,
       (select oid from pg_am where amname = 'columnar') as objid,
       0 as objsubid,
       -- ... to each object that is registered to pg_class and that lives
       -- in "columnar" schema. That contains catalog tables, indexes
       -- created on them and the sequences created in "columnar" schema.
       --
       -- Given the possibility of user might have created their own objects
       -- in columnar schema, we explicitly specify list of objects that we
       -- are interested in.
       'pg_class'::regclass::oid as refclassid,
       columnar_schema_members::regclass::oid as refobjid,
       0 as refobjsubid,
       'n' as deptype
FROM unnest(ARRAY['columnar.chunk',
                  'columnar.chunk_group',
                  'columnar.chunk_group_pkey',
                  'columnar.chunk_pkey',
                  'columnar.options',
                  'columnar.options_pkey',
                  'columnar.storageid_seq',
                  'columnar.stripe',
                  'columnar.stripe_pkey'
                  ]) columnar_schema_members
-- Since we don't delete those records when downgrading citus, records might
-- already exists in pg_depend. But to be on the safe side, we don't want to
-- insert duplicate entries into pg_depend.
EXCEPT TABLE pg_depend;

$$;
END IF;
END$proc$;
