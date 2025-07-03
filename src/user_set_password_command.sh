username="${args[username]}"
if [[ -z "${ENV[PASSWORD]}" ]]; then
  password="${SETTINGS[password]:-''}"
fi
pg_users_set_password "$username" "$password"
