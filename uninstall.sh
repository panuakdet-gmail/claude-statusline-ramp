#!/bin/bash
#
# Removes the context-ramp status line.
#
# If install.sh made backups, the most recent one is put back. If there was
# nothing to back up (the files did not exist before), they are removed and
# Claude Code is told to stop using a custom status line.

set -euo pipefail

CCSTATUSLINE_CONFIG="$HOME/.config/ccstatusline/settings.json"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
WRAPPER_DEST="$HOME/.claude/statusline-wrapper.sh"

say()  { printf '%s\n' "$*"; }
step() { printf '\n==> %s\n' "$*"; }

original_backup() {
    # Prints the OLDEST backup of $1, or nothing if there are none.
    #
    # Oldest, not newest: the first backup is the one taken before this was
    # ever installed, so it is the only one that restores you to where you
    # started. The installer avoids making later ones, but a hand-made copy
    # could still be lying around.
    local oldest=""
    local candidate
    for candidate in "$1".backup-*; do
        [ -f "$candidate" ] || continue
        if [ -z "$oldest" ] || [ "$candidate" \< "$oldest" ]; then
            oldest="$candidate"
        fi
    done
    if [ -n "$oldest" ]; then
        printf '%s' "$oldest"
    fi
}

restore_or_remove() {
    # $1 = the installed file to undo
    local backup
    backup="$(original_backup "$1")"
    if [ -n "$backup" ]; then
        mv "$backup" "$1"
        say "    restored $1 from $(basename "$backup")"
    elif [ -f "$1" ]; then
        rm "$1"
        say "    removed $1"
    else
        say "    nothing to undo at $1"
    fi
}

say "Claude Code context-ramp status line — uninstaller"

step "Widget layout"
restore_or_remove "$CCSTATUSLINE_CONFIG"

step "Status line script"
restore_or_remove "$WRAPPER_DEST"

step "Claude Code settings"
backup="$(original_backup "$CLAUDE_SETTINGS")"
if [ -n "$backup" ]; then
    mv "$backup" "$CLAUDE_SETTINGS"
    say "    restored $CLAUDE_SETTINGS from $(basename "$backup")"
elif [ -f "$CLAUDE_SETTINGS" ] && command -v node >/dev/null 2>&1; then
    node -e '
    const fs = require("fs");
    const settingsPath = process.argv[1];
    const raw = fs.readFileSync(settingsPath, "utf8").trim();
    if (!raw) process.exit(0);
    const config = JSON.parse(raw);
    delete config.statusLine;
    fs.writeFileSync(settingsPath, JSON.stringify(config, null, 2) + "\n");
    ' "$CLAUDE_SETTINGS"
    say "    removed statusLine from $CLAUDE_SETTINGS"
else
    say "    nothing to undo in $CLAUDE_SETTINGS"
fi

step "Done"
say ""
say "ccstatusline itself was left installed. To remove that too:"
say ""
say "    npm uninstall -g ccstatusline"
say ""
say "Restart Claude Code to see the change."
