database="${args[database]}" # directly from args, not SETTINGS.
owner="${args[owner]:-database}" # Default owner is the same as the database name.
pg_databases_create "$database" "$owner"