-- columnar--11.0-2--11.0-1.sql

-- delete pg_depend records inserted in columnar--11.0-1--11.0-2.sql
DELETE FROM pg_depend
WHERE classid = 'pg_am'::regclass::oid AND
      objid = (select oid from pg_am where amname = 'columnar') AND
      objsubid = 0 AND
      refclassid = 'pg_class'::regclass::oid AND
      refobjid IN (
          SELECT unnest(ARRAY['columnar.chunk',
                              'columnar.chunk_group',
                              'columnar.chunk_group_pkey',
                              'columnar.chunk_pkey',
                              'columnar.options',
                              'columnar.options_pkey',
                              'columnar.storageid_seq',
                              'columnar.stripe',
                              'columnar.stripe_first_row_number_idx',
                              'columnar.stripe_pkey'
                              ])::regclass::oid
      ) AND
      refobjsubid = 0 AND
      deptype = 'n';
