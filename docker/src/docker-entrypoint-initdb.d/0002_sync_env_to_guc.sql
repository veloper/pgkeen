-- This script is intended to be run in a PostgreSQL container to sync environment variables
-- to PostgreSQL settings (GUCs) using the `envvar` and `pg_cron` extensions.
--
-- It creates a function that is able to check if standardized environment variables exist,
-- and if they do, it will update the corresponding PostgreSQL settings (GUCs) if they differ.
--
-- The function is scheduled to run every 5 minutes using `pg_cron` and is a workaround not being
-- able to specify the a 'run on container start' hook in the Dockerfile.
--
-- There are optimization that can be made in terms of saving 1 query per 5 minutes, but it
-- requires ephemeral state management to allow for a sentinel value to be stored and given
-- docker's many ways to run containers, it's not something worth the possible headache at 
-- this time.


CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS envvar;

CREATE OR REPLACE FUNCTION pg_settings_reflect_env() RETURNS VOID AS $$
DECLARE
  r RECORD;
BEGIN
  CREATE EXTENSION IF NOT EXISTS envvar;

  FOR r IN
    WITH base_settings AS (
      SELECT
        name AS pg_key,
        setting AS pg_value,
        boot_val AS pg_default_value,
        vartype AS cast_type,
        CONCAT('PG_', UPPER(REPLACE(name, '.', '__'))) AS env_key
      FROM pg_settings
      WHERE
        context IN ('user', 'superuser', 'sighup', 'backend')
        AND vartype NOT IN ('internal')
        AND name NOT LIKE 'local%'
        AND name NOT LIKE 'session%'
    ),
    env_value_settings AS (
      SELECT
        *,
        get_env(env_key) AS env_value
      FROM base_settings
    ),
    env_value_act AS (
      SELECT *,
        (
          CASE
            WHEN env_value IS NULL THEN '__NO_OP__'
            WHEN env_value::text = ''::text THEN '__UNSET__'
            ELSE (
              CASE
                WHEN pg_value::text != env_value::text THEN '__UPDATE__'
                ELSE '__NO_OP__'
              END
            )
          END
        ) AS act
      FROM env_value_settings
    ),
    env_value_cast AS (
      SELECT *,
        (
          CASE
          WHEN act = '__NO_OP__' THEN NULL
          WHEN act = '__UNSET__' THEN pg_default_value
          ELSE env_value
          END
        ) AS update_value
      FROM env_value_act
    )
    SELECT * FROM env_value_cast
    WHERE update_value IS NOT NULL
  LOOP
    RAISE NOTICE 'Syncing setting: % -> %', r.pg_key, r.update_value;
    EXECUTE format('ALTER SYSTEM SET %I = %L', r.pg_key, r.update_value);
  END LOOP;

  PERFORM pg_reload_conf();
END;
$$ LANGUAGE plpgsql;


SELECT cron.schedule( 'pg_settings_update', '*/5 * * * *', 'SELECT pg_settings_reflect_env()');