
debug() {
  local message="$1"
  if [[ -n "$message" ]]; then
    if [[ "${NO_COLOR:-}" == "" ]]; then
      printf "%s %s\n" "$(magenta_bold "[DEBUG]")" "$(magenta "$message")"
    else
      printf "[DEBUG] %s\n" "$message"
    fi
  fi
}

info() {
  local message="$1"
  if [[ -n "$message" ]]; then
    if [[ "${NO_COLOR:-}" == "" ]]; then
      printf "%s %s\n" "$(cyan_bold "[INFO]")" "$(cyan "$message")"
    else
      printf "[INFO] %s\n" "$message"
    fi
  fi
}

warning() {
  local message="$1"
  if [[ -n "$message" ]]; then
    if [[ "${NO_COLOR:-}" == "" ]]; then
      printf "%s %s\n" "$(yellow_bold "[WARNING]")" "$(yellow "$message")"
    else
      printf "[WARNING] %s\n" "$message"
    fi
  fi
}

error() {
  local message="$1"
  if [[ -n "$message" ]]; then
    if [[ "${NO_COLOR:-}" == "" ]]; then
      printf "%s %s\n" "$(red_bold "[ERROR]")" "$(red "$message")"
    else
      printf "[ERROR] %s\n" "$message"
    fi
  fi
}

success() {
  local message="$1"
  if [[ -n "$message" ]]; then
    if [[ "${NO_COLOR:-}" == "" ]]; then
      printf "%s %s\n" "$(green_bold "[SUCCESS]")" "$(green "$message")"
    else
      printf "[SUCCESS] %s\n" "$message"
    fi
  fi
}
