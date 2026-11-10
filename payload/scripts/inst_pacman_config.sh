#!/usr/bin/env bash
set -Eeuo pipefail

PACMAN_CONF="/etc/pacman.conf"
STAMP="${1:-$(date +%Y%m%d-%H%M%S)}"

[[ -r "$PACMAN_CONF" ]] || {
    echo "Cannot read $PACMAN_CONF. Skipping pacman display customization." >&2
    exit 1
}

TEMP_CONFIG="$(mktemp)"
cleanup() { rm -f "$TEMP_CONFIG"; }
trap cleanup EXIT

echo "Backing up the current pacman configuration..."
sudo cp -a "$PACMAN_CONF" "$PACMAN_CONF.ryw-backup-$STAMP"

# Enable Color and add ILoveCandy exactly once in the [options] section.
# Pacman reads ILoveCandy as an option; it must not be placed inside a repo section.
awk '
BEGIN {
    in_options = 0
    options_seen = 0
    color_seen = 0
    candy_seen = 0
}
# Entering a new section closes the previous section. Add missing options
# before leaving [options], not before its section header.
/^[[:space:]]*\[[^]]+\]/ {
    if (in_options && !color_seen) {
        print "Color"
        color_seen = 1
    }
    if (in_options && !candy_seen) {
        print "ILoveCandy"
        candy_seen = 1
    }

    if ($0 ~ /^[[:space:]]*\[[[:space:]]*options[[:space:]]*\]/) {
        in_options = 1
        options_seen = 1
    } else {
        in_options = 0
    }
    print
    next
}
# Remove existing candy directives anywhere and place exactly one in [options].
/^[[:space:]]*ILoveCandy([[:space:]]*(#.*)?)?$/ {
    next
}
# Activate an existing Color or #Color only while in [options].
in_options && /^[[:space:]]*#?[[:space:]]*Color([[:space:]]*(#.*)?)?$/ {
    if (!color_seen) {
        print "Color"
        color_seen = 1
    }
    if (!candy_seen) {
        print "ILoveCandy"
        candy_seen = 1
    }
    next
}
{
    print
}
END {
    if (!options_seen) {
        print ""
        print "[options]"
        print "Color"
        print "ILoveCandy"
    } else if (in_options) {
        if (!color_seen) {
            print "Color"
        }
        if (!candy_seen) {
            print "ILoveCandy"
        }
    }
}
' "$PACMAN_CONF" > "$TEMP_CONFIG"

sudo install -o root -g root -m 0644 "$TEMP_CONFIG" "$PACMAN_CONF"

if ! grep -Eq '^[[:space:]]*Color([[:space:]]|$)' "$PACMAN_CONF"; then
    echo "Pacman Color option could not be verified." >&2
    exit 1
fi
if ! grep -Eq '^[[:space:]]*ILoveCandy([[:space:]]|$)' "$PACMAN_CONF"; then
    echo "Pacman ILoveCandy option could not be verified." >&2
    exit 1
fi

echo "Pacman Color and ILoveCandy options are enabled."
