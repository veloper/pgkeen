: <<'UNIX_PRECEDENCE_DOC'
Idiomatic Unix precedence (sometimes called "Unix precedence order" 
or "conventional precedence") refers to the order in which a CLI tool 
or script resolves configuration values. 

The classic idiom is:

  1. Command-line arguments (highest precedence)
  2. Command-line flags
  2. Environment variables
  3. Configuration files
  4. Hard-coded Defaults (lowest precedence)

UNIX_PRECEDENCE_DOC

source_settings() {

    declare -gA SETTINGS=()

    # convert env to lowercase version of themselves using str_to_lower
    # e.g. HOST -> host
    declare -gA env=()
    for k in "${!ENV[@]}"; do
        env["$(str_to_lower "$k")"]="${ENV[$k]}"
    done

    declare -gA arguments=() # args would override the built-in args array
    declare -gA flags=()    
    for k in "${!args[@]}"; do
        if [[ "$k" == --* ]]; then
            flags["$(str_to_lower "${k:2}")"]="${args[$k]}"
        elif [[ "$k" == -* ]]; then
            flags["$(str_to_lower "${k:1}")"]="${args[$k]}"
        else
            arguments["$(str_to_lower "$k")"]="${args[$k]}"
        fi
    done


    # Now, we merge into SETTINGS in order of precedence: arguments > flags > env

    for k in "${!env[@]}"; do
        SETTINGS["$k"]="${env[$k]}"
    done

    for k in "${!flags[@]}"; do
        SETTINGS["$k"]="${flags[$k]}"
    done

    for k in "${!arguments[@]}"; do
        SETTINGS["$k"]="${arguments[$k]}"
    done

    # at this point, SETTINGS contains the merged configuration values
    # and can be accessed similarly to args: `value="${SETTINGS[key]}"`

}