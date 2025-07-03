#!/usr/bin/env bash

# filepath: /Users/daniel/projects/pgkeen/bin/admin.sh
#
# NOTE: This script has been refactored to use a consistent argument parsing
#       style. The new convention for all commands is:
#
#       $0 <group> <command> [OPTIONS]... [ARGUMENTS]...
#
#       - Options are long-form (e.g., --option=value) and appear before positional arguments.
#       - Positional arguments (e.g., a username or database name) come last.
#       - Use '--help' or '-h' on any command to see its specific usage.

set -euo pipefail

# --- Constants and Colors ---
readonly SCRIPT_NAME=$(basename "$0")
readonly PSQL="psql -U postgres -h localhost -p 5432 "
readonly RED=$'\033[0;31m'
readonly GRN=$'\033[0;32m'
readonly YEL=$'\033[0;33m'
readonly NC=$'\033[0m'

# --- Utility Functions ---

die() {
  echo "${RED}Error:${NC} $*" >&2
  exit 1
}

info() {
  echo "${GRN}$*${NC}"
}

warn() {
  echo "${YEL}$*${NC}"
}



get_first_help_line() {
  local func="$1"
  awk -v fn="$func" '
    $0 ~ "^" fn "[[:space:]]*\\(\\)" { found=1; next }
    found && /^[[:space:]]*#/ { gsub(/^[[:space:]]*# ?/,""); print; exit }
    found && !/^[[:space:]]*#/ { exit }
  ' "$(realpath "$0")"
}


show_help() {
  local func_name="$1"
  local help_text
  local this_file="$(realpath "$0")"
  
  cat "$(realpath "$0")" \
    | grep --after-context=15 -E "^"${func_name}"\(\) \{" \
    | grep -E "^\s\s#" \
    | sed -En 's/.*[[:space:]]+#(.*)/\1/p'

  exit 0
}

list_group_commands_with_help() {
  local group="$1"
  local prefix="${group}_"
  while read -r func_name; do
    if [[ "$func_name" == "$prefix"* ]]; then
      local cmd_name="${func_name#$prefix}"
      local display_cmd="${cmd_name//_/-}"
      local help_line
      help_line=$(get_first_help_line "$func_name")
      printf "  %-20s - %s\n" "$display_cmd" "$help_line"
    fi
  done < <(declare -F | awk '{print $3}') | sort
}

# --- SQL Helper Functions ---
_user_exists() {
  local username="$1"
  [[ -n "$($PSQL -tAc "SELECT 1 FROM pg_roles WHERE rolname='$username'")" ]]
}

_db_exists() {
  local dbname="$1"
  [[ -n "$($PSQL -tAc "SELECT 1 FROM pg_database WHERE datname='$dbname'")" ]]
}

# --- User Management Functions ---

user_list() {
  # Lists all users in the database.
  #
  # @usage user list [OPTIONS]
  #
  # Options:
  #   --help, -h               Show this help message
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) show_help "user_list" ;;
      *) die "Unknown option: '$1'" ;;
    esac
  done
  info "Listing users:"
  $PSQL -c "\du"
}

user_show() {
  # Shows detailed information for a specific user.
  #
  # @usage user info [OPTIONS] <USERNAME>
  #
  # Arguments:
  #   USERNAME                 Username to show details for
  #
  # Options:
  #   --help, -h               Show this help message
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) show_help "user_show" ;;
      -*) die "Unknown option: '$1'" ;;
      *) break ;;
    esac
  done
  local username="${1?Username argument is required.}"
  info "Showing details for user '$username':"
  $PSQL -c "SELECT * FROM pg_user WHERE usename = '$username';"
}
user_create() {
  # Creates a new user idempotently, upserting if necessary.
  #
  # If the user already exists, it will force the existing user to be updated with the provided options.
  #
  # @usage user create [OPTIONS] <USERNAME>
  #
  # Arguments:
  #   USERNAME                 Username for the new user
  #
  # Options:
  #   --superuser              Create as a superuser
  #   --database[=<DBNAME>]    Also create a database for the user (default: same as USERNAME)
  #   --help, -h               Show this help message
  #
  # Environment Vars:
  #   PASSWORD                 Passwords must be passed via environment variable. If absent, user will have no password.
  local db_name=""
  local superuser_opt="NOSUPERUSER"
  local create_db=false
  local username=""
  # Parse options until first non-option argument (the username)
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --superuser) superuser_opt="SUPERUSER"; shift ;;
      --database)
        create_db=true
        shift
        ;;
      --database=*)
        db_name="${1#*=}"
        create_db=true
        shift
        ;;
      -h|--help) show_help "user_create" ;;
      --) shift; break ;; # end of options
      -*) die "Unknown option: '$1'." ;;
      *) username="$1"; shift; break ;; # first non-option is username
    esac
  done
  # Accept username as first non-option argument
  if [[ -z "$username" && $# -gt 0 ]]; then
    username="$1"; shift
  fi
  [[ -z "$username" ]] && die "Username argument is required."
  [[ $# -gt 0 ]] && die "Unexpected argument: '$1'."
  if $create_db && [[ -z "$db_name" ]]; then db_name="$username"; fi
  local password_sql=""
  if [[ -n "${PASSWORD:-}" ]]; then
    password_sql="PASSWORD '$PASSWORD'"
  else
    warn "No PASSWORD env var set: user will be created without a password."
  fi

  if _user_exists "$username"; then
    info "User '$username' already exists. Applying updates..."
    $PSQL -c "ALTER USER \"$username\" WITH $superuser_opt LOGIN $password_sql;"
    info "User '$username' updated."
  else
    info "User '$username' does not exist. Creating..."
    $PSQL -c "CREATE USER \"$username\" WITH $superuser_opt LOGIN $password_sql;"
    info "User '$username' created."
  fi
  
  if [[ -n "$db_name" ]]; then
    if ! _db_exists "$db_name"; then
      info "Database '$db_name' does not exist. Creating with owner '$username'..."
      $PSQL -c "CREATE DATABASE \"$db_name\" WITH OWNER \"$username\";"
      info "Database '$db_name' created."
    else
      warn "Database '$db_name' already exists. No action taken."
    fi
  fi
}

user_drop() {
  # Drops/deletes a user from the database.
  #
  # @usage user drop [OPTIONS] <USERNAME>
  #
  # Arguments:
  #   USERNAME                 Username to drop
  #
  # Options:
  #   --cascade                Drop user and all dependent objects
  #   --help, -h               Show this help message
  local cascade_opt=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cascade) cascade_opt="CASCADE"; shift ;;
      -h|--help) show_help "user_drop" ;;
      -*) die "Unknown option: '$1'." ;;
      *) break ;;
    esac
  done
  local username="${1?Username argument is required.}"
  $PSQL -c "DROP USER IF EXISTS \"$username\" $cascade_opt;"
  info "User '$username' dropped."
}


user_rename() {
  # Renames an existing user, reassigning all owned objects and privileges.
  #
  # @usage user rename [OPTIONS] <OLD_USERNAME> <NEW_USERNAME>
  #
  # Arguments:
  #   OLD_USERNAME             Current username
  #   NEW_USERNAME             New username to set
  #
  # Options:
  #   --objects                Reassign all owned objects to new user
  #   --privileges             Reassign all granted privileges to new user
  #   --help, -h               Show this help message
  local do_objects=false
  local do_privileges=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --objects) do_objects=true; shift ;;
      --privileges) do_privileges=true; shift ;;
      -h|--help) show_help "user_rename" ;;
      -*) die "Unknown option: '$1'." ;;
      *) break ;;
    esac
  done
  local old_username="${1?Old username argument is required.}"
  local new_username="${2?New username argument is required.}"

  if ! _user_exists "$old_username"; then
    die "User '$old_username' does not exist."
  fi
  if _user_exists "$new_username"; then
    die "User '$new_username' already exists."
  fi

  # Fetch the old user's attributes and password hash
  local attrs password_hash
  attrs=$($PSQL -tAc "SELECT CASE WHEN rolsuper THEN 'SUPERUSER' ELSE 'NOSUPERUSER' END || ' ' || CASE WHEN rolcreatdb THEN 'CREATEDB' ELSE 'NOCREATEDB' END || ' ' || CASE WHEN rolcreaterole THEN 'CREATEROLE' ELSE 'NOCREATEROLE' END || ' ' || CASE WHEN rolreplication THEN 'REPLICATION' ELSE 'NOREPLICATION' END FROM pg_roles WHERE rolname='$old_username'")
  password_hash=$($PSQL -tAc "SELECT passwd FROM pg_shadow WHERE usename='$old_username'")
  # Do not attempt to set password using hash; warn user instead
  if [[ -z "$password_hash" || "$password_hash" == "null" ]]; then
    $PSQL -c "CREATE USER \"$new_username\" WITH $attrs LOGIN;"
  else
    warn "Cannot migrate password for '$old_username' (PostgreSQL stores only password hashes). The new user '$new_username' will be created without a password. Please set it manually."
    $PSQL -c "CREATE USER \"$new_username\" WITH $attrs LOGIN;"
  fi

  # For each database, optionally reassign objects and/or privileges
  if $do_objects || $do_privileges; then
    while read -r db; do
      info "Processing database '$db'..."
      if $do_objects; then
        info "  Reassigning all owned objects from '$old_username' to '$new_username'..."
        $PSQL -d "$db" -c "REASSIGN OWNED BY \"$old_username\" TO \"$new_username\";"
      fi
      if $do_privileges; then
        info "  Migrating all granted privileges from '$old_username' to '$new_username'..."
        # For each object type, generate GRANT statements for the new user
        $PSQL -d "$db" -Atc "
          SELECT
            'GRANT ' || privilege_type || ' ON ' || table_schema || '.' || table_name || ' TO \"$new_username\";'
          FROM information_schema.table_privileges
          WHERE grantee = '$old_username'
        " | while read -r grant; do
          [[ -n \$grant ]] && $PSQL -d "$db" -c "\$grant"
        done

        $PSQL -d "$db" -Atc "
          SELECT
            'GRANT ' || privilege_type || ' ON SEQUENCE ' || sequence_schema || '.' || sequence_name || ' TO \"$new_username\";'
          FROM information_schema.sequence_privileges
          WHERE grantee = '$old_username'
        " | while read -r grant; do
          [[ -n \$grant ]] && $PSQL -d "$db" -c "\$grant"
        done

        $PSQL -d "$db" -Atc "
          SELECT
            'GRANT ' || privilege_type || ' ON ' || routine_schema || '.' || routine_name || ' TO \"$new_username\";'
          FROM information_schema.routine_privileges
          WHERE grantee = '$old_username'
        " | while read -r grant; do
          [[ -n \$grant ]] && $PSQL -d "$db" -c "\$grant"
        done

        $PSQL -d "$db" -Atc "
          SELECT
            'GRANT ' || privilege_type || ' ON SCHEMA ' || schema_name || ' TO \"$new_username\";'
          FROM information_schema.schema_privileges
          WHERE grantee = '$old_username'
        " | while read -r grant; do
          [[ -n \$grant ]] && $PSQL -d "$db" -c "\$grant"
        done

        $PSQL -d "$db" -Atc "
          SELECT
            'GRANT ' || privilege_type || ' ON DATABASE ' || datname || ' TO \"$new_username\";'
          FROM pg_database d
          JOIN information_schema.database_privileges p ON d.datname = p.catalog_name
          WHERE grantee = '$old_username'
        " | while read -r grant; do
          [[ -n \$grant ]] && $PSQL -d "$db" -c "\$grant"
        done

        info "  Dropping all privileges from '$old_username' in '$db'..."
        $PSQL -d "$db" -c "DROP OWNED BY \"$old_username\";"
      fi
    done < <($PSQL -tAc "SELECT datname FROM pg_database WHERE datallowconn AND datistemplate = false")
  fi

  # Remove old user
  $PSQL -c "DROP USER \"$old_username\";"

  info "User '$old_username' renamed to '$new_username'."
}

user_set_password() {
  # Sets or changes a user's password.
  #
  # @usage user set-password [OPTIONS] <USERNAME>
  #
  # Arguments:
  #   USERNAME                 User whose password will be changed
  #
  # Options:
  #   --help, -h               Show this help message
  #
  # Environment Vars:
  #   PASSWORD                 The new password. Must be passed as an env var.
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) show_help "user_set_password" ;;
      -*) die "Unknown option: '$1'." ;;
      *) break ;;
    esac
  done
  local username="${1?Username argument is required.}"
  [[ -z "${PASSWORD:-}" ]] && die "PASSWORD environment variable must be set."
  $PSQL -c "ALTER USER \"$username\" WITH PASSWORD '$PASSWORD';"
  info "Password updated for user '$username'."
}



# --- Database Management Functions ---

db_list() {
  # Lists all databases on the server.
  #
  # @usage db list [OPTIONS]
  #
  # Options:
  #   --help, -h               Show this help message
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) show_help "db_list" ;;
      *) die "Unknown option: '$1'" ;;
    esac
  done
  info "Listing databases:"
  $PSQL -c "\l"
}
db_show() {
  # Shows detailed information for a specific database.
  #
  # @usage db show [OPTIONS] <DBNAME>
  #
  # Arguments:
  #   DBNAME                   Database to show details for
  #
  # Options:
  #   --help, -h               Show this help message
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) show_help "db_show" ;;
      -*) die "Unknown option: '$1'" ;;
      *) break ;;
    esac
  done
  local dbname="${1?Database name argument is required.}"
  info "Showing details for database '$dbname':"
  $PSQL -c "SELECT
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

db_create() {
  # Creates a new database idempotently, upserting if necessary.
  #
  # If the database already exists, it will update the owner if different.
  #
  # @usage db create [OPTIONS] <DBNAME> <OWNER>
  #
  # Arguments:
  #   DBNAME                   Name for the new database
  #   OWNER                    Set the database owner (required)
  #
  # Options:
  #   --help, -h               Show this help message
  local dbname=""
  local owner=""
  # Parse options until first non-option argument (the dbname)
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) show_help "db_create" ;;
      --) shift; break ;;
      -*) die "Unknown option: '$1'." ;;
      *) dbname="$1"; shift; break ;;
    esac
  done
  # Accept dbname as first non-option argument
  if [[ -z "$dbname" && $# -gt 0 ]]; then
    dbname="$1"; shift
  fi
  [[ -z "$dbname" ]] && die "Database name argument is required."
  # Accept owner as required second argument
  if [[ $# -gt 0 ]]; then
    owner="$1"
    shift
  fi
  [[ -z "$owner" ]] && die "Owner argument is required."
  [[ $# -gt 0 ]] && die "Unexpected argument: '$1'."
  if _db_exists "$dbname"; then
    # Check current owner
    local current_owner
    current_owner=$($PSQL -tAc "SELECT u.usename FROM pg_database d JOIN pg_user u ON d.datdba = u.usesysid WHERE d.datname = '$dbname'")
    if [[ "$current_owner" != "$owner" ]]; then
      info "Database '$dbname' exists but owner is '$current_owner'. Changing owner to '$owner'..."
      $PSQL -c "ALTER DATABASE \"$dbname\" OWNER TO \"$owner\";"
      info "Owner of database '$dbname' changed to '$owner'."
    else
      info "Database '$dbname' already exists with correct owner '$owner'. No action taken."
    fi
  else
    info "Database '$dbname' does not exist. Creating..."
    $PSQL -c "CREATE DATABASE \"$dbname\" OWNER \"$owner\";"
    info "Database '$dbname' created."
  fi
}


db_drop() {
  # Drops/deletes a database.
  #
  # @usage db drop [OPTIONS] <DBNAME>
  #
  # Arguments:
  #   DBNAME                   Database to drop
  #
  # Options:
  #   --force                  Forcibly disconnect users (Postgres 13+)
  #   --help, -h               Show this help message
  local force_opt=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force) force_opt="WITH (FORCE)"; shift ;;
      -h|--help) show_help "db_drop" ;;
      -*) die "Unknown option: '$1'." ;;
      *) break ;;
    esac
  done
  local dbname="${1?Database name argument is required.}"
  [[ $# -gt 1 ]] && die "Unexpected argument: '$2'."
  if ! _db_exists "$dbname"; then
    warn "Database '$dbname' does not exist. No action taken."
    return 0
  fi
  $PSQL -c "DROP DATABASE \"$dbname\" $force_opt;"
  info "Database '$dbname' dropped."
}

db_rename() {
  # Renames an existing database, handling active connections and optionally migrating extensions.
  #
  # @usage db rename [OPTIONS] <OLD_DBNAME> <NEW_DBNAME>
  #
  # Arguments:
  #   OLD_DBNAME               Current database name
  #   NEW_DBNAME               New database name to set
  #
  # Options:
  #   --force                  Terminate all connections to the old database before renaming
  #   --migrate-extensions     Recreate extensions in the new database if rename fails due to extension issues
  #   --help, -h               Show this help message
  local force=false
  local migrate_extensions=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force) force=true; shift ;;
      --migrate-extensions) migrate_extensions=true; shift ;;
      -h|--help) show_help "db_rename" ;;
      -*) die "Unknown option: '$1'." ;;
      *) break ;;
    esac
  done
  local old_dbname="${1?Old database name argument is required.}"
  local new_dbname="${2?New database name argument is required.}"

  # Idempotency: If old doesn't exist but new does, treat as already renamed.
  if ! _db_exists "$old_dbname"; then
    if _db_exists "$new_dbname"; then
      info "Database already renamed from '$old_dbname' to '$new_dbname'. No action taken."
      return 0
    else
      die "Database '$old_dbname' does not exist."
    fi
  fi
  if _db_exists "$new_dbname"; then
    info "Database '$new_dbname' already exists. No action taken."
    return 0
  fi

  if $force; then
    info "Terminating all connections to '$old_dbname'..."
    $PSQL -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$old_dbname' AND pid <> pg_backend_pid();"
  fi

  if $PSQL -c "ALTER DATABASE \"$old_dbname\" RENAME TO \"$new_dbname\";"; then
    info "Database '$old_dbname' renamed to '$new_dbname'."
  else
    local rc=$?
    warn "Rename failed. Checking for extension or connection issues..."
    if $migrate_extensions; then
      info "Attempting extension migration workaround..."
      # List extensions in old database
      extensions=$($PSQL -d "$old_dbname" -Atc "SELECT extname FROM pg_extension;")
      # Create new database if not already present
      if ! _db_exists "$new_dbname"; then
        $PSQL -c "CREATE DATABASE \"$new_dbname\";"
      else
        warn "Database '$new_dbname' already exists. Skipping creation."
      fi
      # Recreate extensions in new database
      for ext in $extensions; do
        info "  Creating extension '$ext' in '$new_dbname'..."
        $PSQL -d "$new_dbname" -c "CREATE EXTENSION IF NOT EXISTS \"$ext\";"
      done
      info "Extension migration complete. You may need to manually migrate data."
      return 0
    fi
    exit $rc
  fi
}

db_vacuum() {
  # Vacuums a database.
  #
  # @usage db vacuum [OPTIONS] <DBNAME>
  #
  # Arguments:
  #   DBNAME                   Database to vacuum
  #
  # Options:
  #   --help, -h               Show this help message
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) show_help "db_vacuum" ;;
      -*) die "Unknown option: '$1'." ;;
      *) break ;;
    esac
  done
  local dbname="${1?Database name argument is required.}"
  info "Vacuuming database '$dbname'..."
  $PSQL -d "$dbname" -c "VACUUM (VERBOSE);"
  info "Vacuum complete."
}

db_analyze() {
  # Analyzes a database.
  #
  # @usage db analyze [OPTIONS] <DBNAME>
  #
  # Arguments:
  #   DBNAME                   Database to analyze
  #
  # Options:
  #   --help, -h               Show this help message
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) show_help "db_analyze" ;;
      -*) die "Unknown option: '$1'." ;;
      *) break ;;
    esac
  done
  local dbname="${1?Database name argument is required.}"
  info "Analyzing database '$dbname'..."
  $PSQL -d "$dbname" -c "ANALYZE (VERBOSE);"
  info "Analysis complete."
}


# --- Main Function and Argument Parsing ---

main() {
  local group="${1:-}"
  local cmd_orig="${2:-}"

  if [[ "$group" == "--help" || -z "$group" ]]; then
    echo "Usage: $SCRIPT_NAME <group> <command> [OPTIONS] [ARGUMENTS...]"
    echo ""
    echo "A tool for managing a PostgreSQL database."
    echo ""
    echo "Groups:"
    echo "  user              - User management commands"
    echo "  db                - Database management commands"
    echo ""
    echo "Run '$SCRIPT_NAME <group> --help' to see commands for a group."
    exit 0
  fi

  if [[ "$cmd_orig" == "--help" || -z "$cmd_orig" ]]; then
    echo "Usage: $SCRIPT_NAME $group <command> [OPTIONS] [ARGUMENTS...]"
    echo ""
    echo "Available '$group' commands:"
    list_group_commands_with_help "$group"
    exit 0
  fi

  local cmd_func="${group}_${cmd_orig//-/_}"
  shift 2
  if declare -f "$cmd_func" &>/dev/null; then
    "$cmd_func" "$@"
  else
    die "Unknown command: '$cmd_orig' for group '$group'. See '$SCRIPT_NAME $group --help'."
  fi
}

main "$@"