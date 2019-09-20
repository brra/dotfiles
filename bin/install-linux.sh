#!/bin/bash
set -e
set -o pipefail

export DEBIAN_FRONTEND=noninteractive

# install-linux.sh
#	This script installs my basic setup for a linux workstation

# Choose a user account to use for this installation
get_user() {
	if [ -z "${TARGET_USER-}" ]; then
		mapfile -t options < <(find /home/* -maxdepth 0 -printf "%f\\n" -type d)
		# if there is only one option just use that user
		if [ "${#options[@]}" -eq "1" ]; then
			readonly TARGET_USER="${options[0]}"
			echo "Using user account: ${TARGET_USER}"
			return
		fi

		# iterate through the user options and print them
		PS3='Which user account should be used? '

		select opt in "${options[@]}"; do
			readonly TARGET_USER=$opt
			break
		done
	fi
}

check_is_sudo() {
	if [ "$EUID" -ne 0 ]; then
		echo "Please run as root."
		exit
	fi
}

# install/update golang from source
install_golang() {
	export GO_VERSION
	GO_VERSION=$(curl -sSL "https://golang.org/VERSION?m=text")
	export GO_SRC=/usr/local/go

	# if we are passing the version
	if [[ -n "$1" ]]; then
		GO_VERSION=$1
	fi

	# purge old src
	if [[ -d "$GO_SRC" ]]; then
		sudo rm -rf "$GO_SRC"
		sudo rm -rf "$GOPATH"
	fi

	GO_VERSION=${GO_VERSION#go}

	# subshell
	(
	kernel=$(uname -s | tr '[:upper:]' '[:lower:]')
	curl -sSL "https://dl.google.com/go/go${GO_VERSION}.${kernel}-amd64.tar.gz" | sudo tar -v -C /usr/local -xz
	local user="$USER"
	# rebuild stdlib for faster builds
	sudo chown -R "${user}" /usr/local/go/pkg
	CGO_ENABLED=0 go install -a -installsuffix cgo std
	)
}

install_npm() {
	npm install \
		@google/clasp -g
}

install_rubygems() {
	gem install \
		bundler
}

setup_docker(){
  if command -v docker >/dev/null 2>&1 ; then
    echo "Docker is already installed"
  else
    curl -sSL https://get.docker.com | sh

		# create docker group
		getent group docker >/dev/null 2>&1 || groupadd docker
		gpasswd -a "$TARGET_USER" docker
  fi

  if command -v docker-compose >/dev/null 2>&1 ; then
    echo "Docker Compose is already installed"
  else
    docker_compose_release="$(curl --silent "https://api.github.com/repos/docker/compose/releases/latest" |  grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')"
    curl -sL https://github.com/docker/compose/releases/download/"$docker_compose_release"/docker-compose-"$(uname -s)"-"$(uname -m)" -o /usr/local/bin/docker-compose
    chmod a+x /usr/local/bin/docker-compose
  fi
}

setup_dotfiles() {
	# create subshell
	(
	cd "/home/${TARGET_USER}"

	if [[ ! -d "/home/${TARGET_USER}/dotfiles" ]]; then
		# install dotfiles from repo
		git clone https://github.com/ferrarimarco/dotfiles.git "/home/${TARGET_USER}/dotfiles"
	fi

	cd "/home/${TARGET_USER}/dotfiles"

	# installs all the things
	make
	)
}

# setup sudo for a user
setup_sudo() {
	# add user to sudoers
	adduser "$TARGET_USER" sudo

	# add user to systemd groups
	# then you wont need sudo to view logs
	if [ "$(getent group systemd-journal)" ]; then
		gpasswd -a "$TARGET_USER" systemd-journal
	fi

	if [ "$(getent group systemd-journal)" ]; then
		gpasswd -a "$TARGET_USER" systemd-network
	fi
}

setup_user() {
  mkdir -p "/home/$TARGET_USER/Downloads"
  mkdir -p "/home/$TARGET_USER/Pictures/Screenshots"
}

setup_debian() {
	apt-get update || true
	apt-get install -y \
		apt-transport-https \
		ca-certificates \
		curl \
		dirmngr \
		gnupg2 \
		lsb-release \
		software-properties-common \
		--no-install-recommends

	add-apt-repository main
	add-apt-repository universe
	add-apt-repository multiverse
	add-apt-repository restricted

	# Add the Google Chrome distribution URI as a package source if needed
	if ! [ -d "/opt/google/cros-containers" ]; then
		echo "Installing Chrome browser..."
		curl https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o google-chrome-stable_current_amd64.deb
		apt install -y ./google-chrome-stable_current_amd64.deb
		rm ./google-chrome-stable_current_amd64.deb
		apt-get install -f
	fi

	apt-get update || true
	apt-get -y upgrade

	apt-get install -y \
		adduser \
		alsa-utils \
		apparmor \
		automake \
		bash-completion \
		bc \
		bridge-utils \
		bzip2 \
		coreutils \
		dbus-user-session \
		dnsutils \
		file \
		findutils \
		fwupd \
		fwupdate \
		gcc \
		git \
    glogg \
		gnupg \
		gnupg-agent \
		grep \
		gzip \
		hostname \
    imagemagick \
		indent \
		iptables \
    jmeter \
		less \
		libapparmor-dev \
		libc6-dev \
		libimobiledevice6 \
		libltdl-dev \
		libpam-systemd \
		libseccomp-dev \
		locales \
		lsof \
		make \
		mount \
    nano \
		net-tools \
		pinentry-curses \
		rxvt-unicode-256color \
		scdaemon \
		ssh \
		strace \
		sudo \
		systemd \
		tar \
		tree \
		tzdata \
		unzip \
		usbmuxd \
		xclip \
		xcompmgr \
		xz-utils \
		zip \
		--no-install-recommends

	apt-get autoremove
	apt-get autoclean
	apt-get clean
}

usage() {
  echo -e "install-linux.sh\\n\\tThis script installs my basic setup for a linux workstation\\n"
  echo "Usage:"
  echo "  base                                - setup sudo and docker"
  echo "  debian                              - install base packages on a Debian system"
  echo "  dotfiles                            - get dotfiles"
  echo "  golang                              - install golang and packages"
  echo "  npm                                 - install npm packages"
  echo "  rubygems                            - install Ruby gems"
  echo "  user                                - setup user"
}

main() {
	local cmd=$1

	if [[ -z "$cmd" ]]; then
		usage
		exit 1
	fi

	if [[ $cmd == "base" ]]; then
		check_is_sudo
		get_user
    setup_sudo
    setup_docker
  elif [[ $cmd == "debian" ]]; then
    check_is_sudo
		get_user
		setup_debian
  elif [[ $cmd == "dotfiles" ]]; then
		get_user
		setup_dotfiles
  elif [[ $cmd == "golang" ]]; then
		install_golang "$2"
	elif [[ $cmd == "npm" ]]; then
		install_npm
	elif [[ $cmd == "rubygems" ]]; then
		check_is_sudo
		install_rubygems
	elif [[ $cmd == "user" ]]; then
    get_user
    setup_user
	else
		usage
	fi
}

main "$@"
