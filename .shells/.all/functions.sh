#!/usr/bin/env sh

# Define this first, so sourcing other files becomes easier
source_file_if_available() {
  FILE="${1}"
  VARIABLE_NAME="${2}"
  if [ -f "$FILE" ]; then
    # shellcheck source=/dev/null
    . "$FILE"
  else
    echo "WARNING: Cannot source $VARIABLE_NAME (set to: $FILE) because the destination doesn't exist or the variable is set to an empty value."
    return 1
  fi
  return 0
}

# Source Docker functions if docker is installed
if command -v docker >/dev/null 2>&1 && [ -e /var/run/docker.sock ]; then
  DOCKERFUNCTIONS_PATH="${HOME}"/.shells/.all/dockerfunctions.sh
  source_file_if_available "${DOCKERFUNCTIONS_PATH}" "DOCKERFUNCTIONS_PATH" || true
  unset DOCKERFUNCTIONS_PATH
fi

# Create a new directory and enter it
mkd() {
  mkdir -p "$@"
  cd "$@" || exit
}

dump_defaults() {
  dir=
  if [ $# -eq 0 ]; then
    dir="$(pwd)"
  else
    dir="${1}"
  fi
  echo "Reading defaults..."
  defaults read NSGlobalDomain >"$dir"/NSGlobalDomain-before.out
  defaults read >"$dir"/read-before.out

  defaults -currentHost read NSGlobalDomain >"$dir"/NSGlobalDomain-currentHost-before.out
  defaults -currentHost read >"$dir"/read-currentHost-before.out

  echo "Change the settings, close the settings app, and press any key to continue..."
  read -r _
  unset _

  defaults read NSGlobalDomain >"$dir"/NSGlobalDomain-after.out
  defaults read >"$dir"/read-after.out

  defaults -currentHost read NSGlobalDomain >"$dir"/NSGlobalDomain-currentHost-after.out
  defaults -currentHost read >"$dir"/read-currentHost-after.out

  echo "Diffing..."
  diff "$dir"/NSGlobalDomain-before.out "$dir"/NSGlobalDomain-after.out
  diff "$dir"/NSGlobalDomain-currentHost-before.out "$dir"/NSGlobalDomain-currentHost-after.out
  diff "$dir"/read-currentHost-before.out "$dir"/read-currentHost-after.out
}

clone_git_repository_if_not_cloned_already() {
  destination_dir="$1"
  git_repository_url="$2"

  if [ -z "$destination_dir" ]; then
    echo "ERROR while cloning the $git_repository_url git repository: The destination_dir variable is not set, or set to an empty string"
    exit 1
  fi

  if [ -d "$destination_dir" ]; then
    echo "$destination_dir already exists. Skipping..."
  else
    mkdir -p "$destination_dir"
    echo "Cloning $git_repository_url in $destination_dir"
    git clone "$git_repository_url" "$destination_dir"
  fi
  unset destination_dir
  unset git_repository_url
}

create_python_venv() {
  destination_dir="$1"

  if [ -z "$destination_dir" ]; then
    echo "ERROR while creating the Python virtual environment in $destination_dir: The destination_dir variable is not set, or set to an empty string"
    return 1
  fi

  if [ -d "$destination_dir" ]; then
    echo "$destination_dir already exists. Skipping..."
  else
    echo "Creating a Python virtual environment in $destination_dir"
    python3 -m venv "$destination_dir"
  fi

  echo "You can activate the new environment by running: . $destination_dir/bin/activate"
}

is_linux() {
  os_name="$(uname -s)"
  if test "${os_name#*"Linux"}" != "$os_name"; then
    unset os_name
    return 0
  else
    unset os_name
    return 1
  fi
}

is_macos() {
  os_name="$(uname -s)"
  if test "${os_name#*"Darwin"}" != "$os_name"; then
    unset os_name
    return 0
  else
    unset os_name
    return 1
  fi
}

is_wsl() {
  VERSION_FILE_PATH=/proc/version
  if [ -f "$VERSION_FILE_PATH" ] && grep -q "Microsoft" "$VERSION_FILE_PATH"; then
    unset VERSION_FILE_PATH
    return 0
  else
    unset VERSION_FILE_PATH
    return 1
  fi
}

update_brew() {
  echo "Upgrading brew and formulae"
  brew update
  brew upgrade

  echo "Cleaning up brew..."
  brew cleanup -s

  echo "Checking for missing brew formula kegs..."
  brew missing
}

pull_from_git_repository() {
  destination_dir="$1"
  program_name="$2"
  if [ -d "$destination_dir/.git" ]; then
    echo "Updating $program_name in: $destination_dir"
    git -C "$destination_dir" pull
  else
    echo "WARNING: $destination_dir doesn't exists"
  fi
  unset destination_dir
  unset program_name
}

update_system() {
  if is_macos; then
    echo "Updating macOS..."
    sudo softwareupdate -ia
    if command -v brew >/dev/null 2>&1; then
      update_brew
    fi
  elif is_linux; then
    echo "Updating linux..."
    sudo apt-get -q update
    sudo apt-get -qy upgrade
    pull_from_git_repository "$(dirname "$ZSH_AUTOSUGGESTIONS_CONFIGURATION_PATH")" "zsh-autosuggestions"
    pull_from_git_repository "$(dirname "$ZSH_COMPLETIONS_PATH")" "zsh-completions"
    pull_from_git_repository "$(dirname "$ZSH_THEME_PATH")" "powerlevel10k"
  fi
}

# Make a temporary directory and enter it
tmpd() {
  dir=
  if [ $# -eq 0 ]; then
    dir=$(mktemp -d)
  else
    dir=$(mktemp -d -t "${1}.XXXXXXXXXX")
  fi
  cd "$dir" || exit
  unset dir
}

# Use Git’s colored diff when available
if command -v git >/dev/null 2>&1; then
  diff() {
    git diff --no-index --color-words "$@"
  }
fi

# Get colors in manual pages
man() {
  env \
    LESS_TERMCAP_mb="$(printf '\e[1;31m')" \
    LESS_TERMCAP_md="$(printf '\e[1;31m')" \
    LESS_TERMCAP_me="$(printf '\e[0m')" \
    LESS_TERMCAP_se="$(printf '\e[0m')" \
    LESS_TERMCAP_so="$(printf '\e[1;44;33m')" \
    LESS_TERMCAP_ue="$(printf '\e[0m')" \
    LESS_TERMCAP_us="$(printf '\e[1;32m')" \
    man "$@"
}
