database="${args[database]}"

warning "This command will drop the database '$database', please type in the database name in all CAPS to confirm:"

CONFIRMATION=""
read -r CONFIRMATION

EXPECTED_CONFIRMATION="$(str_to_upper "$database")"

if [[ "$CONFIRMATION" != "$EXPECTED_CONFIRMATION" ]]; then
    red "Confirmation failed. Database '$database' was not dropped."
    exit 1
else
    info "Confirmation successful. Proceeding to drop database '$database'... "
fi

# Ensure the database exists before attempting to drop it
if ! pg_databases_exists "$database"; then
    success "Database '$database' does not exist. Nothing to drop."
    exit 0
fi

pg_databases_drop "$database"
