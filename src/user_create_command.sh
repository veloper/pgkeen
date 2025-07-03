username="${args[username]}"

# Check if the username is provided via environment variable or settings
# if there's still nothing, then hard-fail
if [[ -z "${ENV[PASSWORD]}" ]]; then
  password=""
fi

if [[ -z "$password" ]]; then
  warning "No password provided and thus not password has been set for this user. Be aware if your postgres is configured to allow passwordless access, this user will be able to connect without a password."
fi

pg_users_create "$username" "$password"

