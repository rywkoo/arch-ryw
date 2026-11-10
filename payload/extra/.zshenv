#!/usr/bin/env zsh

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export ZDOTDIR="${ZDOTDIR:-$XDG_CONFIG_HOME/zsh}"

if [[ ! -r "$ZDOTDIR/.zshenv" ]]; then
    print -u2 -- "FATAL: Zsh configuration entry point not found: $ZDOTDIR/.zshenv"
    return 1
fi

source "$ZDOTDIR/.zshenv" || {
    print -u2 -- "FATAL: Could not load $ZDOTDIR/.zshenv"
    return 1
}
