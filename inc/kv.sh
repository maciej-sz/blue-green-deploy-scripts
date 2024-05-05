#!/usr/bin/env sh

# Function: kv_get
# Description: Retrieves the value of a key from a key-value pair file.
#
# Parameters:
#   key (string)   - The variable name (key) to retrieve the value for.
#   file (string)  - The path to the file where the key-value pairs are stored.
#
# Returns:
#   The value associated with the key if it exists, otherwise an error message.
#
# Usage:
#   value=$(get_var_from_file "config.txt" "USERNAME")
#
kv_get() {
  file="$1"
  key="$2"
  if [ -f "$file" ]; then
    value=$(grep "^${key}=" "$file" | cut -d '=' -f2-)
    echo "$value"
  else
    echo "File not found: $file" >&2
    return 1
  fi
}

# Function: kv_set
# Description: Writes or updates a key-value pair in a file.
#
# Parameters:
#   key (string)   - The variable name (key) to write/update.
#   value (string) - The value associated with the key.
#   file (string)  - The path to the file where the key-value pair will be written/updated.
#
# Usage:
#   set_var_to_file "config.txt" "USERNAME" "new_user123"
#
kv_set() {
  file="$1"
  key="$2"
  value="$3"

  if [ ! -f "$file" ]; then
    touch "$file"
  fi

  if grep -q "^${key}=" "$file"; then
    sed -i "s/^${key}=.*/${key}=${value}/" "$file"
  else
    echo "${key}=${value}" >> "$file"
  fi
}
