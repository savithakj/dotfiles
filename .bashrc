#!/usr/bin/env bash

#====================================================
# Bash Environment Configuration
#
# This script only needs to be sourced upon opening a new shell to configure the Bash shell environment.
#====================================================

# BEGIN HISTORY

# Don't push duplicate lines, or lines starting with a space, in the history. The second ignore condition allows you to execute commands with a leading space, thereby instructing Bash to not place them into history.
HISTCONTROL=ignoreboth

# For setting history length see HISTSIZE and HISTFILESIZE.
HISTSIZE=32768
HISTFILESIZE=${HISTSIZE:-}

# Include date and timestamps in history output.
HISTTIMEFORMAT='%F %T '

# Ignore certain commands given by the user, for the sake of history, such that they don't show up in Bash history.
HISTIGNORE="ls:bg:fg:history:exit"

# Append command to the bash command history file instead of overwriting it.
shopt -s histappend

# Append command to the history file after every display of the command prompt, instead of after terminating the session (the current shell).
# We no longer reload the contents of the history file into the history list (which is kept in memory). By reloading the history file (history -r) after appending commands to the file, we could have loaded history saved by other sessions currently running. However, that can cause commands from multiple sessions to intermix, making it difficult to re-produce your actions within the current session by following the command history in a linear fashion.
PROMPT_COMMAND='history -a'

# END HISTORY

# Correct minor spelling errors in a `cd` command; such as transposed, missing, or extra, characters without the need for retyping.
shopt -s cdspell

# Correct minor spelling errors in when completing a directory path; such as transposed, missing, or extra, characters without the need for retyping.
shopt -s dirspell
shopt -s direxpand

# Check the window size after each command and, if necessary update the values of LINES and COLUMNS.
shopt -s checkwinsize

# Enable programmable completion features (you don't need to enable this, if it's already enabled in /etc/bash.bashrc and /etc/profile sources /etc/bash.bashrc).
if ! shopt -oq posix; then
	if [ -f /usr/share/bash-completion/bash_completion ]; then
		source  /usr/share/bash-completion/bash_completion
	elif [ -f /etc/bash_completion ]; then
		source /etc/bash_completion
	fi
fi

# Setup Bash prompt auto-completion for PIP; Python's package manager.
# This step is incredibly slow to execute.
# command -v pip >/dev/null 2>&1 && eval "$(pip completion --bash)"

# Source the Brew bash completion initialization script if it exists, otherwise, just source each tool's completion script.
if type brew &>/dev/null; then
  HOMEBREW_PREFIX="$(brew --prefix)"
  if [[ -r "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh" ]]; then
    source "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh"
  else
    for COMPLETION in "${HOMEBREW_PREFIX}/etc/bash_completion.d/"*; do
      [[ -r "$COMPLETION" ]] && source "$COMPLETION"
    done
  fi
fi

# Execute `nvm` script to configure our local environment to work with `nvm`.
command -v brew >/dev/null 2>&1 && source "$(brew --prefix nvm)/nvm.sh"
command -v yarn --version >/dev/null 2>&1 && export PATH="$(yarn global bin):${PATH}"

# Invoke Powerline setup script to configure our shell prompt.
if [ -f "${PREFIX_DIRECTORY}/lib/python3.7/site-packages/powerline/bindings/bash/powerline.sh" ]; then
	# The following is to improve performance - https://powerline.readthedocs.io/en/latest/usage/shell-prompts.html#bash-prompt
	powerline-daemon -q
	POWERLINE_BASH_CONTINUATION=1
	POWERLINE_BASH_SELECT=1

	source "${PREFIX_DIRECTORY}/lib/python3.7/site-packages/powerline/bindings/bash/powerline.sh"
fi

# tabtab source for yarn package
# uninstall by removing these lines or running `tabtab uninstall yarn`
[ -f /home/hutson/.local/share/yarn/global/node_modules/tabtab/.completions/yarn.bash ] && . /home/hutson/.local/share/yarn/global/node_modules/tabtab/.completions/yarn.bash

# Source our custom shell aliases. All custom shell aliases should be in this external file rather than cluttering up this file.
if [ -f "${HOME}/.bash_aliases" ]; then
	source "${HOME}/.bash_aliases"
fi

# Source our custom bash functions.
if [ -f "${HOME}/.bash_functions" ]; then
	source "${HOME}/.bash_functions"
fi
