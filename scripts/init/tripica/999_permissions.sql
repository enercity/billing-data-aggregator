-- allow regular users to view oibl data
DO $$
DECLARE
tbl_name varchar;
usr_name varchar;
BEGIN
	FOR usr_name IN SELECT usename FROM pg_catalog.pg_user WHERE (usename NOT IN ('octopus', 'rdsadmin') AND usename NOT LIKE '%service_%') or (usename in ('service_metabase_full'))
	LOOP
		RAISE NOTICE '%', usr_name;
	
		EXECUTE 'GRANT USAGE ON SCHEMA report_oibl TO "' || usr_name || '"';
		EXECUTE 'ALTER DEFAULT PRIVILEGES IN SCHEMA report_oibl GRANT SELECT ON TABLES TO "' || usr_name || '"';

		FOR tbl_name IN select concat(table_schema, '."', table_name, '"') FROM information_schema.tables WHERE table_schema = 'report_oibl'
		loop
			EXECUTE 'GRANT SELECT ON ' || tbl_name || ' TO "' || usr_name || '"';
		END LOOP;

	END LOOP;

	-- metabase read only user
	IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'service_metabase') THEN
		GRANT USAGE ON SCHEMA report_oibl TO service_metabase;
		GRANT SELECT ON report_oibl.oibl_customer TO service_metabase;
	END IF;
END$$;
