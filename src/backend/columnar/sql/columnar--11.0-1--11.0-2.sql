-- columnar--11.0-1--11.0-2.sql

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
                  'columnar.stripe_first_row_number_idx',
                  'columnar.stripe_pkey'
                  ]) columnar_schema_members;
