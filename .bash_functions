#!/usr/bin/env bash

#====================================================
# Custom Bash Functions
#
# This script only needs to be sourced upon opening a new shell to configure the Bash shell environment.
#====================================================

#! Compress a file or folder into one of many types of archive formats.
# Compress a file or folder into one of many types of archive formats. Compression is based on the archive type specified.
# This function is based on http://bijayrungta.com/extract-and-compress-files-from-command-line-in-linux
#
# \param $1 Path to the file or folder to be archived.
# \param $2 Archive type; such as 'tar' or 'zip'.
compress()
{
	local dirPriorToExe=`pwd`
	local dirName=`dirname ${1}`
	local baseName=`basename ${1}`

	if [ -f "${1}" ]; then
		echo "Selected a file for compression. Changing directory to '${dirName}''."
		cd "${dirName}"
		case "${2}" in
			tar.bz2)   tar cjf ${baseName}.tar.bz2 ${baseName} ;;
			tar.gz)    tar czf ${baseName}.tar.gz ${baseName}  ;;
			gz)        gzip ${baseName}                        ;;
			tar)       tar -cvvf ${baseName}.tar ${baseName}   ;;
			zip)       zip -r ${baseName}.zip ${baseName}      ;;
			*)
				echo "A compression format was not chosen. Defaulting to tar.gz"
				tar czf ${baseName}.tar.gz ${baseName}
				;;
		esac
		echo "Navigating back to ${dirPriorToExe}"
		cd "${dirPriorToExe}"
	elif [ -d "${1}" ]; then
		echo "Selected a directory for compression. Changing directory to '${dirName}''."
		cd "${dirName}"
		case "${2}" in
			tar.bz2)   tar cjf ${baseName}.tar.bz2 ${baseName} ;;
			tar.gz)    tar czf ${baseName}.tar.gz ${baseName}  ;;
			gz)        gzip -r ${baseName}                     ;;
			tar)       tar -cvvf ${baseName}.tar ${baseName}   ;;
			zip)       zip -r ${baseName}.zip ${baseName}      ;;
			*)
				echo "A compression format was not chosen. Defaulting to tar.gz"
				tar czf ${baseName}.tar.gz ${baseName}
				;;
		esac
		echo "Navigating back to ${dirPriorToExe}"
		cd "${dirPriorToExe}"
	else
		echo "'${1}' is not a valid file or directory."
	fi
}

#! Extract multiple types of archive files.
# Extract multiple types of archive files. Extraction is based on the archive type, and whether they are compressed, and if so, the type of compression used.
# This function is based on https://github.com/xvoland/Extract.
#
# \param $1 Path to the archive file.
extract ()
{
	if [ -z "${1}" ]; then
		echo "Usage: extract <path/file_name>.<zip|rar|bz2|gz|tar|tbz2|tgz|Z|7z|xz|ex|tar.bz2|tar.gz|tar.xz>"
		exit
	fi

	if [ -f "${1}" ]; then
		case "${1}" in
			*.tar.bz2)   tar xvjf "${1}"    ;;
			*.tar.gz)    tar xvzf "${1}"    ;;
			*.tar.xz)    tar xvJf "${1}"    ;;
			*.lzma)      unlzma "${1}"      ;;
			*.bz2)       bunzip2 "${1}"     ;;
			*.rar)       unrar x -ad "${1}" ;;
			*.gz)        gunzip "${1}"      ;;
			*.tar)       tar xvf "${1}"     ;;
			*.tbz2)      tar xvjf "${1}"    ;;
			*.tgz)       tar xvzf "${1}"    ;;
			*.zip)       unzip "${1}"       ;;
			*.Z)         uncompress "${1}"  ;;
			*.7z)        7z x "${1}"        ;;
			*.xz)        unxz "${1}"        ;;
			*.exe)       cabextract "${1}"  ;;
			*)           echo "extract: '${1}' - unknown archive method" ;;
		esac
	else
		echo "${1} - file does not exist"
	fi
}

#! Setup a watch and run a command.
# Watch for changes to files that match a given file specification, and on change, run the given command.
#
# \param $1 A command accessible in the user's PATH to execute.
# \param $2 A filespec; for example '*' or '/home/user'.
# \param [$3=modify] Any combination of comma-delimited inotify events to listen for on the given filespec. Defaults to listening for "modify" events.
watch ()
{
	if [ -z `command -v inotifywait` ]; then
		echo "'inotifywait', needed to run the watch command, is not accessible in your PATH."
		return
	fi

	# Validate the command parameter.
	if [ -z "${1}" ]; then
		echo "Invalid command, ${1}, provided. This command does not exist in your PATH."
		return
	fi

	# Validate the filespec parameter.
	if [ -z "${2}" ]; then
		echo "Invalid filespec."
		return
	fi

	# Set an appropriate inotify watch event default.
	local default="modify"
	local events="${3:-$default}"

	while inotifywait -e "${events}" "${2}"; do

		# If the script failed (thereby returning an error), exit rather than loop again.
		if [ "${?}" -gt 0 ]; then
			return
		fi

		# Evaluate the expression passed to the watch command so that commands that include command line arguments can be properly executed.
		eval "${1}"

		# If the requested command fails, exit rather than loop again.
		if [ "${?}" -gt 0 ]; then
			return
		fi
	done
}

#! Setup a local environment.
# Setup a local environment that contains all the tools and libraries needed for development work, and play.
setupEnvironment ()
{
	printf "\n> Removing ${PREFIX_DIRECTORY} directory.\n"

	# Clear out our local system directory.
	if [ -d "${PREFIX_DIRECTORY}" ]; then
		rm -fr "${PREFIX_DIRECTORY}" &> /dev/null
	fi

	# Create our local tmp directory for use by tools that cache compilation artifacts there. This directory must exist before those tools can create sub-directories within it.
	mkdir -p "${PREFIX_DIRECTORY}/tmp"

	# Setup Brew.
	setupHomeBrew
	installBrewPackages

	# Execute `nvm` script to configure our local environment to work with `nvm`.
	source "$(brew --prefix nvm)/nvm.sh"

	# Install additional tools.
	installNodePackages
	installPythonPackages

	# Install Firefox on personal laptop.
	if [ `uname -n` == "startopia" ]; then
		installFirefox
	fi
}

#! Update environment.
# Update our development environment by installing the latest version of our desired tools.
updateEnvironment ()
{
	# Update Brew.
	brew update

	# Upgrade all Brew-installed packages.
	brew upgrade

	# Cleanup Brew installation.
	brew cleanup -s

	# Update general tools.
	installNodePackages
	installPythonPackages
}

#! Setup HomeBrew.
# Install HomeBrew locally so that we can download, build, and install tools from source.
setupHomeBrew ()
{
	printf "\n> Installing HomeBrew.\n"

	# Create a local binary directory before any setup steps require its existence. It must exist for the tar extraction process to extract the contents of Brew into the `.local/` directory.
	mkdir -p "${HOME}/.local/bin"

	# Download an archive version of the #master branch of Brew to the local system for future extraction. We download an archive version of Brew, rather than cloning the #master branch, because we must assume that the local system does not have the `git` tool available (A tool that will be installed later using Brew).
	curl -L https://github.com/Homebrew/brew/archive/master.tar.gz -o "/tmp/homebrew.tar.gz"

	# Extract archive file into local system directory.
	tar -xf "/tmp/homebrew.tar.gz" -C "${HOME}/.local/" --strip-components=1

	# Cleanup.
	rm -f "/tmp/homebrew.tar.gz"
}

#! Install packages via Brew.
# Install packages via Brew's `brew` CLI tool.
installBrewPackages()
{
	if command -v brew &> /dev/null; then
		printf "\n> Installing Brew packages.\n"

		# Install the latest Bash shell environment. This will give us access to the latest features in our primary work environment.
		brew install bash

		# Install bash-completion. This allows us to leverage bash completion scripts installed by our brew installed packages. Version @2 is required for Bash > 2.
		brew install bash-completion@2

		# Install python version 3, which `pip` is also included, as the header files are required by natively-built pip packages.
		brew install python

		# Install Go compiler and development stack.
		brew install go

		# Install nvm, a CLI tool for managing Node interpreter versions within the current shell environment.
		brew install nvm

		# Install alternative JavaScript package manager called `yarn`. Install without the Node dependency, as we will use the Node installation provided by the `nvm` tool.
		brew install yarn

		# Install htop, a human-readable version of top.
		brew install htop

		# Install git, a distributed source code management tool.
		brew install git

		# Install the Large File Storage (LFS) git extension. The Large File Storage extension replaces large files that would normally be committed into the git repository, with a text pointer. Each revision of a file managed by the Large File Storage extension is stored server-side. Requires a remote git server with support for the Large File Storage extension.
		brew install git-lfs

		# Install ncdu, a command line tool for displaying disk usage information.
		brew install ncdu

		# Install scrub, a command line tool for securely deleting files.
		brew install scrub

		# Static site generator and build tool.
		brew install hugo

		# Install resource orchestration tool.
		brew install terraform

		# Install terminal multiplexer.
		brew install tmux

		# Install network traffic inspection tool.
		brew install tcpdump

		# Install Docker image analysis tool.
		brew install dive

		# Install tflint, a linter/validator for Terraform files.
		brew tap wata727/tflint
		brew install tflint

		# Install shell script linter. (Force install the pre-compiled binary as a full compile requires _lots_ of additional packages that have to be compiled and installed)
		brew install shellcheck --force-bottle

		# Cloud tools
		brew install awscli
		brew install aws-iam-authenticator
		brew install kubectl

		if [ "$(uname)" == "Darwin" ]; then
			# Latest GNU core utilities, such as `rm`, `ls`, etc.
			brew install coreutils

			# Store Docker Hub credentials in the OSX Keychain for improved security.
			brew install docker-credential-helper

			brew install wget
			brew install pinentry-mac

			brew cask install firefox
			brew cask install visual-studio-code
			brew cask install keepassxc
			brew cask install gpg-suite
			brew cask install joplin # For taking and organizing notes.
			brew cask install vlc
			brew cask install iterm2
			brew cask install slack
			brew cask install spectacle
			brew cask install keka # General purpose archive/extractor tool.
			brew cask install wireshark # For network debugging.
		fi

		if [ "$(uname -n)" == "startopia" ]; then
			# Install flac, a command line tool for re-encoding audio files into Flac format.
			brew install flac

			# GNU data recovery tool.
			brew install ddrescue

			# Tool for ripping DVD's from the command line.
			brew install dvdbackup
		fi
	else
		echo "ERROR: `brew` is required for building and installing tools from source, but it's not available in your PATH. Please install `brew` and ensure it's in your PATH. Then re-run `installBrewPackages`."
	fi
}

#! Install NodeJS packages.
# Install NodeJS packages via `yarn`.
installNodePackages ()
{
	if command -v yarn &> /dev/null; then
		printf "\n> Installing Node packages.\n"

		# Tool to update a markdown file, such as a `README.md` file, with a Table of Contents.
		yarn global add doctoc

		# Terminal GUI for managing Docker containers.
		yarn global add dockly
	else
		echo "ERROR: `yarn` is required for installing NodeJS packages, but it's not available in your PATH. Please install `yarn` and ensure it's in your PATH. Then re-run `installNodePackages`."
	fi
}

#! Install Python packages.
# Install Python packages via `pip`.
installPythonPackages ()
{
	if command -v pip &> /dev/null; then
		printf "\n> Installing Python packages.\n"

		# Using `pip3` to install other packages is necessary to avoid errors like `pkg_resources.VersionConflict: (pip 19.0.3 (~.local/lib/python3.7/site-packages), Requirement.parse('pip==19.0.2'))`

		# Update the version of `pip` installed in our environment.
		pip3 install pip --upgrade

		# Package and virtual environment manager for Python.
		pip3 install pipenv --upgrade

		# Shell prompt configuration and theming tool.
		pip3 install powerline-status --upgrade

		# Install and configure powerline font.
		mkdir -p "${XDG_DATA_HOME}/fonts/"
		curl -L https://github.com/powerline/powerline/raw/develop/font/PowerlineSymbols.otf -o "${XDG_DATA_HOME}/fonts/PowerlineSymbols.otf"
		fc-cache -vf "${XDG_DATA_HOME}/fonts/"
		mkdir -p "${XDG_CONFIG_HOME}/fontconfig/conf.d/"
		curl -L https://github.com/powerline/powerline/raw/develop/font/10-powerline-symbols.conf -o "${XDG_CONFIG_HOME}/fontconfig/conf.d/10-powerline-symbols.conf"
	else
		echo "ERROR: `pip` is required for installing Python packages, but it's not available in your PATH. Please install `pip` and ensure it's in your PATH. Then re-run `installPythonPackages`."
	fi
}

#! Install Visual Studio Code extensions.
# If running on a desktop with Visual Studio Code installed, install our selection of Visual Studio Code extensions.
installVisualStudioCodeExtensions ()
{

	if command -v $(code --help) &> /dev/null; then
		printf "\n> Installing Visual Studio Code extensions.\n"

		# General, offline, spell checker.
		code --install-extension streetsidesoftware.code-spell-checker

		# Support for Git blame annotations.
		code --install-extension eamodio.gitlens

		# Docker support.
		code --install-extension PeterJausovec.vscode-docker

		# Go support.
		code --install-extension ms-vscode.go

		# Terraform support.
		code --install-extension mauve.terraform

		# Nice icon theme.
		code --install-extension vscode-icons-team.vscode-icons
	else
		echo "ERROR: `code` is required for installing Visual Studio Code extensions, but it's not available in your PATH. Please install Visual Studio Code and ensure it's in your PATH. Then re-run `installVisualStudioCodeExtensions`."
	fi
}

#! Find all file types in use and convert to standard types.
# Find all file types in use within a given directory and offer to convert files to a known set of standard file types, such as WAV to FLAC, using appropriate permissions (not globally readable).
checkAndConvert ()
{
	# TODO: Prompt user whether global permissions should be revoked from listed files.
	printf "\n> List of globally accessible files.\n"
	find . \( -perm -o+r -or -perm -o+w -or -perm -o+x \) | xargs ls -l

	## TODO: Rename all files to be all lower-case.
	# for i in $( ls | grep [A-Z] ); do mv -i $i `echo $i | tr 'A-Z' 'a-z'`; done
	# ls | sed -n 's/.*/mv "&" $(tr "[A-Z]" "[a-z]" <<< "&")/p' | bash

	# TODO: Convert some known file formats to an alternative, "open", file format.
	# To convert Office documents to ODF formats such as `.ods`.
	# lowriter --headless --convert-to ods *.xlsx
}
