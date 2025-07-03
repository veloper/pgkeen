pg_client() {
    source_settings

    local host="${SETTINGS[host]}"
    local port="${SETTINGS[port]}"
    local user="${SETTINGS[user]}"

    if [[ -z "$user" || -z "$host" || -z "$port" ]]; then
        echo "[pg_psql] Missing required Postgres connection parameters." >&2
        return 1
    fi

    parts=()

    # Connection parameters
    parts+=("--host=$host")
    parts+=("--port=$port")
    parts+=("--username=$user")


    # Never issue a password prompt. If the server requires password authentication and a password is not available from
    # other sources such as a .pgpass file, the connection attempt will fail. This option can be useful in batch jobs
    # and scripts where no user is present to enter a password.
    parts+=("--no-password") 

    # Prevent asking for user interaction
    # Note: This also disables readline support so you can't use arrow keys, history, or tab completion
    parts+=("--no-readline")

    # Echo errors
    parts+=("--echo-errors")

    # Assemble the command
    cmd="${parts[*]}"

    # Execute the command
    # Disable pager
    (
        PAGER="" PSQL_PAGER="" psql $cmd "$@"
    )
}


# == User Management Functions =============================================================

pg_users_list() {
    # List all users in the Postgres database with detailed info
    pg_client -c "SELECT
        usename AS username,
        usesysid AS user_id,
        usecreatedb AS can_create_db,
        usesuper AS is_superuser,
        userepl AS can_replicate,
        (passwd IS NOT NULL) AS has_password,
        valuntil AS password_valid_until,
        useconnlimit AS connection_limit
    FROM pg_user;"
}

pg_users_show() {
    local username="$1"
    if [[ -z "$username" ]]; then
        echo "Username is required." >&2
        return 1
    fi
    # Show details of a specific user
    pg_client -c "SELECT
        usename AS username,
        usesysid AS user_id,
        usecreatedb AS can_create_db,
        usesuper AS is_superuser,
        userepl AS can_replicate,
        (passwd IS NOT NULL) AS has_password,
        valuntil AS password_valid_until,
        useconnlimit AS connection_limit
    FROM pg_user WHERE usename = '$username';"
}

pg_users_create() {
    local username="$1"
    local password="$2"

    if [[ -z "$username" ]]; then
        echo "Username is required." >&2
        return 1
    fi

    if pg_users_exists "$username"; then
        echo "User '$username' already exists." >&2
        return 0
    fi

    info "Creating user '$username' ..."
    if [[ -n "$password" ]]; then
        pg_client -c "CREATE ROLE \"$username\" WITH PASSWORD '$password';"
    else
        pg_client -c "CREATE ROLE \"$username\";"
    fi
    if [[ $? -ne 0 ]]; then
        error "Failed to create user '$username'."
        return 1
    else
        return 0
    fi
}


pg_users_drop() {
    local username="$1"
    if [[ -z "$username" ]]; then
        error "Username is required." >&2
        return 1
    fi
    if ! pg_users_exists "$username"; then
        echo "User '$username' does not exist." >&2
        return 1
    fi
    info "Dropping user '$username' ..."
    pg_client -c "DROP ROLE \"$username\";"
    if [[ $? -ne 0 ]]; then
        error "Failed to drop user '$username'."
        return 1
    fi
}

pg_users_set_password() {
    local username="$1"
    local password="$2"

    if [[ -z "$username" || -z "$password" ]]; then
        echo "Username and password are required." >&2
        return 1
    fi

    if ! pg_users_exists "$username"; then
        echo "User '$username' does not exist." >&2
        return 1
    fi


    info "Setting password for user '$username' ..."
    pg_client -c "ALTER ROLE \"$username\" WITH PASSWORD '$password';"
    if [[ $? -ne 0 ]]; then
        error "Failed to set password for user '$username'."
        return 1
    fi
    success "Password for user '$username' set successfully."   
}


pg_users_exists() {
    local username="$1"
    if [[ -z "$username" ]]; then
        echo "Username is required." >&2
        return 1
    fi
    local result
    result=$(pg_client -t -A -c "SELECT 1 FROM pg_user WHERE usename = '$username';" | tr -d '[:space:]')
    if [[ "$result" == "1" ]]; then
        return 0
    else
        return 1
    fi
}

# == Database Management Functions =============================================================

pg_databases_analyze() {
    local dbname="$1"
    if [[ -z "$dbname" ]]; then
        echo "Database name is required." >&2
        return 1
    fi
    info "Analyzing database '$dbname' ..."
    pg_client -d "$dbname" -c "ANALYZE;"
    if [[ $? -ne 0 ]]; then
        error "Failed to analyze database '$dbname'."
        return 1
    fi
    success "Database '$dbname' analyzed successfully."
}

pg_databases_vacuum() {
    local dbname="$1"
    if [[ -z "$dbname" ]]; then
        echo "Database name is required." >&2
        return 1
    fi
    info "Vacuuming database '$dbname' ..."
    pg_client -d "$dbname" -c "VACUUM;"
    if [[ $? -ne 0 ]]; then
        error "Failed to vacuum database '$dbname'."
        return 1
    fi
    success "Database '$dbname' vacuumed successfully."
}


pg_databases_list() {
    # List all databases in the Postgres server
    pg_client -c "SELECT
        d.datname AS dbname,
        pg_size_pretty(pg_database_size(d.datname)) AS size,
        d.datdba AS owner_id,
        u.usename AS owner,
        CONCAT(d.datdba, ' (', u.usename, ')') AS owner,
        d.datcollate AS collate,
        d.datctype AS ctype,
        CASE WHEN d.datistemplate THEN 'Yes' ELSE 'No' END AS is_tmpl,
        CASE WHEN d.datallowconn THEN 'Yes' ELSE 'No' END AS can_conn,
        d.datconnlimit AS conn_limit,
        CONCAT(d.dattablespace, ' (', t.spcname, ')') AS tablespace
    FROM pg_database d
    LEFT JOIN pg_user u ON d.datdba = u.usesysid
    LEFT JOIN pg_tablespace t ON d.dattablespace = t.oid";
}

pg_databases_show() {
    local dbname="$1"
    if [[ -z "$dbname" ]]; then
        echo "Database name is required." >&2
        return 1
    fi
    # Show details of a specific database
    pg_client -c "SELECT
        d.datname AS name,
        pg_size_pretty(pg_database_size(d.datname)) AS size,
        d.datdba AS owner_id,
        u.usename AS owner,
        d.encoding,
        d.datcollate AS collate,
        d.datctype AS ctype,
        d.datistemplate AS is_template,
        d.datallowconn AS allow_conn,
        d.datconnlimit AS conn_limit,
        d.datfrozenxid AS frozen_xid,
        d.datminmxid AS min_multixid,
        d.dattablespace AS tablespace_id,
        t.spcname AS tablespace
    FROM pg_database d
    LEFT JOIN pg_user u ON d.datdba = u.usesysid
    LEFT JOIN pg_tablespace t ON d.dattablespace = t.oid
    WHERE d.datname = '$dbname';"
}


pg_databases_create_extension_if_not_exists() {
    local dbname="$1"
    local extension_name="$2"
    if [[ -z "$dbname" || -z "$extension_name" ]]; then
        echo "Database name and extension name are required." >&2
        return 1
    fi
    pg_client -d "$dbname" -c "CREATE EXTENSION IF NOT EXISTS \"$extension_name\";"
}

pg_databases_exists() {
    local dbname="$1"
    if [[ -z "$dbname" ]]; then
        echo "Database name is required." >&2
        return 1
    fi
    local result
    result=$(pg_client -t -A -c "SELECT 1 FROM pg_database WHERE datname = '$dbname';")
    if [[ "$result" == "1" ]]; then
        return 0
    else
        return 1
    fi
}

pg_databases_get_owner() {
    local dbname="$1"
    if [[ -z "$dbname" ]]; then
        echo "Database name is required." >&2
        return 1
    fi
    pg_client -t -c "SELECT u.usename FROM pg_database d JOIN pg_user u ON d.datdba = u.usesysid WHERE d.datname = '$dbname';"
}

pg_databases_drop() {
    local dbname="$1"
    if [[ -z "$dbname" ]]; then
        echo "Database name is required." >&2
        return 1
    fi
    if ! pg_databases_exists "$dbname"; then
        echo "Database '$dbname' does not exist." >&2
        return 1
    fi
    info "Dropping database '$dbname' ..."

    # Must run as postgres user to avoid connecting to the database being dropped
    pg_client --dbname="postgres" -c "DROP DATABASE \"$dbname\";"
    if [[ $? -ne 0 ]]; then
        error "Failed to drop database '$dbname'."
        return 1
    fi
    success "Database '$dbname' dropped successfully."
    return 0
}

pg_databases_change_owner() {
    local dbname="$1"
    local new_owner="$2"

    if [[ -z "$dbname" || -z "$new_owner" ]]; then
        error "Database name and new owner are required." >&2
        return 1
    fi

    if ! pg_databases_exists "$dbname"; then
        error "Database '$dbname' does not exist." >&2
        return 1
    fi

    if ! pg_users_exists "$new_owner"; then
        error "User '$new_owner' does not exist." >&2
        return 1
    fi

    # Change the owner of the database
    
    info "Changing owner of database '$dbname' to '$new_owner' ..."
    pg_client -c "ALTER DATABASE $dbname OWNER TO $new_owner;"
    if [[ $? -ne 0 ]]; then
        error "Failed to change owner for database '$dbname' to '$new_owner'."
        return 1
    fi

    success "Owner of database '$dbname' changed to '$new_owner'."
    return 0
}

pg_databases_create() {
    local dbname="$1"
    local owner="$2"

    if [[ -z "$dbname" || -z "$owner" ]]; then
        echo "Database name and owner are required." >&2
        return 1
    fi

    # Ensure USER exists
    if ! pg_users_exists "$owner"; then
        info "Creating user '$owner' ..."
        pg_client -c "CREATE USER \"$owner\" WITH PASSWORD NULL;"
        if [[ $? -ne 0 ]]; then
            error "Failed to create user '$owner'."
            return 1
        fi
    else
        info "User '$owner' already exists."
    fi

    
    # Handle DATABASE creation
    if ! pg_databases_exists "$dbname"; then
        info "Creating NEW database '$dbname'..."
        pg_client -c "CREATE DATABASE \"$dbname\";"
        if [[ $? -ne 0 ]]; then
            error "Failed to create database '$dbname'."
            return 1
        fi
        info "Database '$dbname' created successfully."
    else
        info "Found EXISTING database '$dbname'."    
    fi

    # Handle OWNERSHIP
    local current_owner=$(pg_databases_get_owner "$dbname")
    if [[ "$current_owner" != "$owner" ]]; then
        info "Setting owner of database '$dbname' to '$owner' ..."
        pg_databases_change_owner "$dbname" "$owner"
    else
        info "Database '$dbname' already owned by '$owner'."
    fi
   

    # Ensure owner has CREATE privileges (for extensions)
    info "Ensuring '$owner' has CREATE privilege on database '$dbname' for extensions ..."
    pg_client -c "GRANT CREATE ON DATABASE \"$dbname\" TO \"$owner\";"
    if [[ $? -ne 0 ]]; then
        error "Failed to grant CREATE privilege on database '$dbname' to '$owner'."
        return 1
    fi

    success "Database '$dbname' and user '$owner' setup completed successfully."
    warning "Run 'pgkeen db enable-extensions $dbname' to enable all extensions."
    
    return 0
}

pg_databases_create_all_extensions_if_not_exists() {
    local dbname="$1"
    if [[ -z "$dbname" ]]; then
        error "Database name is required." >&2
        return 1
    fi

    declare -a extensions=(
        "embedding"
        "vector"
        "age"
        "pg_partman"
        "pg_trgm"
        "http"
        "plpython3u"
        "pg_net"
        "pg_jsonschema"
        "hstore"
        "ltree"
        "dict_int"
        "intarray"
        "intagg"
        "fuzzystrmatch"
        "bloom"
        "uuid-ossp"
        "xml2"
        "pg_hashids"
        "autoinc"
        "address_standardizer_data_us"
        "citext"
        "envvar"
        # Some are missing due to only being able to be installed on the postgres database
        # "pgml"
        # "pg_cron"
        # "pgmq"
        # "vectorize"
    )

    local items="$(printf "%s\n" "${extensions[@]}")"



    for ext in $items; do
        local output=$(pg_client --dbname="$dbname" -c "CREATE EXTENSION IF NOT EXISTS \"$ext\" CASCADE;" 2>&1)
        if [[ -n $output && "$output" != *"already exists"* ]]; then
            warning "Failed to install extension '$ext' in database '$dbname'."
            warning "> Output: $output"
            continue
        else
            success "Extension '$ext' installed."
        fi
    done
}

