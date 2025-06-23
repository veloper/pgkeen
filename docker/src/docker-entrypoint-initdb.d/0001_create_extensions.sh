#!/bin/bash

log() {
    local message=$1
    echo -en "$message" >&2 # Print to stderr to ensure visibility in logs, prevent auto newline, respect newline characters
}

error() {
    local message=$1
    log "\n\nError: $message\n"
}

# Right pad a string to a certain length with a specified character
# Example usage: rpad "Hello" 10 "-" will output "Hello-----"
# IN: "Hello my friend" 20 "."
# OUT: "Hello my friend....."
rpad() {
    local str="$1"
    local len="$2"
    local char="${3:- }"
    local pad_len=$((len - ${#str}))
    if (( pad_len > 0 )); then
        printf "%s" "$str"
        printf "%*s" "$pad_len" "" | tr ' ' "$char"
    else
        printf "%s" "$str"
    fi
}

prefix_all_lines() {
    local input=$1
    local prefix=$2

    while IFS= read -r line; do
        echo "$prefix$line"
    done <<< "$input"
}

create_extension() {
    local extension_name=$1

    MSG=$(rpad "Installing $extension_name extension" 50 ".")

    log "$MSG"
    SQL="CREATE EXTENSION IF NOT EXISTS \"$extension_name\" CASCADE;"
    
    OUT_AND_ERR=$(psql -d postgres -c "$SQL" 2>&1) 
    
    OUT_AND_ERR=$(prefix_all_lines "$OUT_AND_ERR" "| ")

    if [ $? -ne 0 ]; then
        log "Warning.\n"

        error "Error occurred while installing '$extension_name' extension.\n"
        error "...still continuing with init script.\n"
    else
        log "Success!\n"
    fi

    IGNORE_LIST=(
        "CREATE EXTENSION"
    )

    # Filter out lines that should be ignored
    for ignore in "${IGNORE_LIST[@]}"; do
        OUT_AND_ERR=$(echo "$OUT_AND_ERR" | grep -v "^| $ignore")
    done

    if [ -n "$OUT_AND_ERR" ]; then
        log "Possible issues found:\n"
        log "$OUT_AND_ERR\n"
    fi
}

# Order matches trunk installation logs

create_extension "embedding"
create_extension "vector"
create_extension "age"
create_extension "pg_partman"
create_extension "pg_trgm"
create_extension "http"
create_extension "plpython3u"
create_extension "pg_net"
create_extension "pg_jsonschema"
create_extension "hstore"
create_extension "ltree"
create_extension "dict_int"
create_extension "intarray"
create_extension "intagg"
create_extension "fuzzystrmatch"
create_extension "bloom"
create_extension "uuid-ossp"
create_extension "xml2"
create_extension "pg_hashids"
create_extension "autoinc"
create_extension "address_standardizer_data_us"
create_extension "citext"
create_extension "pgml"
create_extension "pg_cron"
create_extension "pgmq"
create_extension "vectorize"
create_extension "envvar"

