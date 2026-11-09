# 👉 Force Qt6 apps to use qt6ct and Kvantum
export QT_QPA_PLATFORMTHEME=qt6ct
export QT_STYLE_OVERRIDE=kvantum

#  Startup 
# Commands to execute on startup (before the prompt is shown)
# Check if the interactive shell option is set
if [[ $- == *i* ]]; then
    # This is a good place to load graphic/ascii art, display system information, etc.
    if command -v pokego >/dev/null; then
        pokego --no-title -r 1,3,6
    elif command -v pokemon-colorscripts >/dev/null; then
        pokemon-colorscripts --no-title -r 1,3,6
   elif command -v fastfetch >/dev/null; then
       if command -v fastfetch &> /dev/null; then
            fastfetch --config "$HOME/.config/fastfetch/config.json"
        fi

    fi
fi
[[ -r "$HOME/.cache/wal/sequences" ]] && (cat "$HOME/.cache/wal/sequences" &)
#  Plugins 
# manually add your oh-my-zsh plugins here
plugins=(
    "sudo"
)

#   Overrides 
# unset HYDE_ZSH_NO_PLUGINS # Set to 1 to disable loading of oh-my-zsh plugins, useful if you want to use your zsh plugins system 
# unset HYDE_ZSH_PROMPT # Uncomment to unset/disable loading of prompts from HyDE and let you load your own prompts
# HYDE_ZSH_COMPINIT_CHECK=1 # Set 24 (hours) per compinit security check // lessens startup time
# HYDE_ZSH_OMZ_DEFER=1 # Set to 1 to defer loading of oh-my-zsh plugins ONLY if prompt is already loaded
#
# #  Custom Prompt 
# Show full current directory in green, prompt char, then current time in yellow

PROMPT='%F{green}%d%f %# %F{yellow}%*%f '

# Hide the default tilde (~) lines when scrolling beyond history
setopt NO_PROMPT_CR
unsetopt PROMPT_SP

# Optional: clear right prompt to avoid clutter
RPROMPT=''
