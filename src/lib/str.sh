# src/lib/str.sh
# String manipulation and interrogation functions library


str_trim() {
    local input="$1"
    [[ -z "$input" ]] && read -r input
    printf '%s\n' "$input" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}


# Bitmask constants
CAMEL_CASE=1
SNAKE_CASE=2
SCREAMING_SNAKE_CASE=4
PASCAL_CASE=8
KEBAB_CASE=16
TITLE_CASE=32

str_to_lower() {
    local input="$1"
    [[ -z "$input" ]] && read -r input
    printf '%s\n' "$input" | tr '[:upper:]' '[:lower:]'
}

str_to_upper() {
    local input="$1"
    [[ -z "$input" ]] && read -r input
    printf '%s\n' "$input" | tr '[:lower:]' '[:upper:]'
}

is_snake_case() {
    local input="$1"
    [[ -z "$input" ]] && read -r input
    [[ "$input" =~ ^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$ ]]
}

is_screaming_snake_case() {
    local input="$1"
    [[ -z "$input" ]] && read -r input
    [[ "$input" =~ ^[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)*$ ]]
}

is_pascal_case() {
    local input="$1"
    [[ -z "$input" ]] && read -r input
    [[ "$input" =~ ^([A-Z][a-z0-9]*)+$ ]]
}

is_camel_case() {
    local input="$1"
    [[ -z "$input" ]] && read -r input
    [[ "$input" =~ ^[a-z]+([A-Z][a-z0-9]*)*$ ]]
}

is_kebab_case() {
    local input="$1"
    [[ -z "$input" ]] && read -r input
    [[ "$input" =~ ^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$ ]]
}

is_title_case() {
    local input="$1"
    [[ -z "$input" ]] && read -r input
    [[ "$input" =~ ^([A-Z][a-z0-9]*)( [A-Z][a-z0-9]*)*$ ]]
}

str_is() {
    local input="$1"
    local mask="$2"
    (( mask & CAMEL_CASE ))           && is_camel_case "$input"           && return 0
    (( mask & SNAKE_CASE ))           && is_snake_case "$input"           && return 0
    (( mask & SCREAMING_SNAKE_CASE )) && is_screaming_snake_case "$input" && return 0
    (( mask & PASCAL_CASE ))          && is_pascal_case "$input"          && return 0
    (( mask & KEBAB_CASE ))           && is_kebab_case "$input"           && return 0
    (( mask & TITLE_CASE ))           && is_title_case "$input"           && return 0
    return 1
}

str_to_camel_case() {
    local input="$1"
    local result
    [[ -z "$input" ]] && read -r input

    if str_is "$input" $(( SNAKE_CASE | KEBAB_CASE | SCREAMING_SNAKE_CASE )); then
        result="$(printf '%s\n' "$input" | tr '[:upper:]' '[:lower:]' | awk -F'[_-]' '{
            for(i=1;i<=NF;i++) {
                if(i==1) printf "%s", $i;
                else printf "%s", toupper(substr($i,1,1)) tolower(substr($i,2));
            }
            printf "\n"
        }')"
    elif str_is "$input" $PASCAL_CASE; then
        result="$(printf '%s\n' "$input" | awk '{printf "%s%s\n", tolower(substr($0,1,1)), substr($0,2)}')"
    else
        result="$input"
    fi

    printf '%s\n' "$result"
}

str_to_pascal_case() {
    local input="$1"
    local result
    [[ -z "$input" ]] && read -r input

    if str_is "$input" $(( SNAKE_CASE | KEBAB_CASE | SCREAMING_SNAKE_CASE )); then
        result="$(printf '%s\n' "$input" | tr '[:upper:]' '[:lower:]' | awk -F'[_-]' '{
            for(i=1;i<=NF;i++) {
                printf "%s", toupper(substr($i,1,1)) tolower(substr($i,2));
            }
            printf "\n"
        }')"
    elif str_is "$input" $CAMEL_CASE; then
        result="$(printf '%s\n' "$input" | awk '{printf "%s%s\n", toupper(substr($0,1,1)), substr($0,2)}')"
    else
        result="$input"
    fi

    printf '%s\n' "$result"
}

str_to_screaming_snake_case() {
    local input="$1"
    local result
    [[ -z "$input" ]] && read -r input

    if str_is "$input" $(( SNAKE_CASE | KEBAB_CASE )); then
        result="$(printf '%s\n' "$input" | tr '-' '_' | tr '[:lower:]' '[:upper:]')"
    elif str_is "$input" $(( CAMEL_CASE | PASCAL_CASE )); then
        result="$(printf '%s\n' "$input" | awk '{
            gsub(/([A-Z])/, "_&");
            gsub(/^_/, "");
            print toupper($0)
        }')"
    else
        result="$input"
    fi

    printf '%s\n' "$result"
}

str_to_snake_case() {
    local input="$1"
    local result
    [[ -z "$input" ]] && read -r input

    if str_is "$input" $(( CAMEL_CASE | PASCAL_CASE )); then
        result="$(printf '%s\n' "$input" | awk '{
            gsub(/([A-Z])/, "_&");
            gsub(/^_/, "");
            print tolower($0)
        }')"
    elif str_is "$input" $KEBAB_CASE; then
        result="$(printf '%s\n' "$input" | tr '-' '_' | tr '[:upper:]' '[:lower:]')"
    else
        result="$input"
    fi

    printf '%s\n' "$result"
}

str_to_kebab_case() {
    local input="$1"
    local result
    [[ -z "$input" ]] && read -r input

    if str_is "$input" $(( CAMEL_CASE | PASCAL_CASE )); then
        result="$(printf '%s\n' "$input" | awk '{
            gsub(/([A-Z])/, "-&");
            gsub(/^-/, "");
            print tolower($0)
        }')"
    elif str_is "$input" $SNAKE_CASE; then
        result="$(printf '%s\n' "$input" | tr '_' '-' | tr '[:upper:]' '[:lower:]')"
    else
        result="$input"
    fi

    printf '%s\n' "$result"
}

str_to_title_case() {
    local input="$1"
    local result
    [[ -z "$input" ]] && read -r input

    if str_is "$input" $(( SNAKE_CASE | KEBAB_CASE | SCREAMING_SNAKE_CASE )); then
        result="$(printf '%s\n' "$input" | tr '_-' '  ' | awk '{
            for(i=1;i<=NF;i++) {
                $i = toupper(substr($i,1,1)) tolower(substr($i,2))
            }
            print $0
        }')"
    elif str_is "$input" $CAMEL_CASE; then
        result="$(printf '%s\n' "$input" | awk '{
            gsub(/([A-Z])/, " \\1");
            for(i=1;i<=NF;i++) {
                $i = toupper(substr($i,1,1)) tolower(substr($i,2))
            }
            print $0
        }')"
    else
        result="$input"
    fi

    printf '%s\n' "$result"
}


