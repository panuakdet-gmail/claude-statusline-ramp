#!/bin/bash
#
# Installer for the Claude Code context-ramp status line.
#
# Safe to run more than once. The first run copies anything it would overwrite
# to a timestamped .backup-<date> file and prints where it went; later runs
# leave that first backup alone, so it always holds your setup as it was before
# any of this existed.

set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"

CCSTATUSLINE_CONFIG="$HOME/.config/ccstatusline/settings.json"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
WRAPPER_DEST="$HOME/.claude/statusline-wrapper.sh"

BACKUPS=()

say()  { printf '%s\n' "$*"; }
step() { printf '\n==> %s\n' "$*"; }
fail() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

back_up() {
    # $1 = file to preserve before we overwrite it
    # $2 = optional; the file about to be written over it
    #
    # Only ever keeps the FIRST backup. That one holds the file as it was
    # before this was ever installed, which is the only version worth
    # restoring. Backing up again on a re-run would bury it under a snapshot
    # of an already-installed state, and uninstalling would then "restore"
    # you to a broken half-installed setup.
    [ -f "$1" ] || return 0

    # Already byte-identical to what we are about to write? Then it is this
    # installer's own output from a previous run, not the user's work, and
    # there is nothing worth preserving. Skipping here is what lets the
    # uninstaller tell "I created this, remove it" apart from "this was here
    # before, put it back". A file the user has edited is not identical, so
    # their changes still get backed up.
    if [ -n "${2:-}" ] && cmp -s "$1" "$2"; then
        return 0
    fi

    local existing=""
    local candidate
    for candidate in "$1".backup-*; do
        if [ -f "$candidate" ]; then
            existing="$candidate"
            break
        fi
    done

    if [ -n "$existing" ]; then
        say "    your original is already saved as $(basename "$existing")"
        return 0
    fi

    cp "$1" "$1.backup-$STAMP"
    BACKUPS+=("$1.backup-$STAMP")
    say "    saved your existing file as $(basename "$1").backup-$STAMP"
}

say "Claude Code context-ramp status line — installer"

# ---------------------------------------------------------------- 1. Node.js

step "Checking for Node.js"
if ! command -v node >/dev/null 2>&1; then
    fail "Node.js is not installed.

ccstatusline is a Node package, so Node has to be present first.
Install it from https://nodejs.org (pick the LTS version), then run
this installer again."
fi
say "    found $(node --version)"

# ----------------------------------------------------------- 2. ccstatusline

step "Checking for ccstatusline"
if command -v ccstatusline >/dev/null 2>&1; then
    say "    already installed ($(ccstatusline --version 2>/dev/null || echo 'version unknown'))"
else
    say "    not found — installing it with npm"
    if ! command -v npm >/dev/null 2>&1; then
        fail "npm is not available, so ccstatusline can't be installed automatically.
npm normally ships with Node.js — reinstalling Node from https://nodejs.org
should fix it."
    fi
    if ! npm install -g ccstatusline; then
        fail "npm could not install ccstatusline.

If the error above mentions permissions (EACCES), the usual fix is to point
npm at a folder you own:

    npm config set prefix ~/.local
    npm install -g ccstatusline

Then make sure ~/.local/bin is on your PATH and run this installer again."
    fi
    say "    installed"
fi

# ------------------------------------------------- 3. ccstatusline's settings

step "Installing the widget layout"
mkdir -p "$(dirname "$CCSTATUSLINE_CONFIG")"
back_up "$CCSTATUSLINE_CONFIG" "$SOURCE_DIR/ccstatusline-settings.json"
cp "$SOURCE_DIR/ccstatusline-settings.json" "$CCSTATUSLINE_CONFIG"
say "    wrote $CCSTATUSLINE_CONFIG"

# ------------------------------------------------------------- 4. the wrapper

step "Installing the status line script"
mkdir -p "$(dirname "$WRAPPER_DEST")"
back_up "$WRAPPER_DEST" "$SOURCE_DIR/statusline-wrapper.sh"
cp "$SOURCE_DIR/statusline-wrapper.sh" "$WRAPPER_DEST"
chmod +x "$WRAPPER_DEST"
say "    wrote $WRAPPER_DEST"

# ------------------------------------------------- 5. point Claude Code at it

step "Telling Claude Code to use it"

# This file is patched rather than copied, so back_up's byte-comparison can't
# tell our own previous run from something worth keeping. Ask the equivalent
# question directly: is it already pointing at our wrapper?
already_ours="$(node -e '
const fs = require("fs");
const [settingsPath, command] = process.argv.slice(1);
const answer = (value) => { console.log(value); process.exit(0); };
if (!fs.existsSync(settingsPath)) answer("no");
const raw = fs.readFileSync(settingsPath, "utf8").trim();
if (!raw) answer("no");
let config;
try {
    config = JSON.parse(raw);
} catch (error) {
    answer("no");
}
answer(config.statusLine && config.statusLine.command === command ? "yes" : "no");
' "$CLAUDE_SETTINGS" "$WRAPPER_DEST")"

if [ "$already_ours" != "yes" ]; then
    back_up "$CLAUDE_SETTINGS"
fi

node -e '
const fs = require("fs");
const [settingsPath, command] = process.argv.slice(1);
let config = {};
if (fs.existsSync(settingsPath)) {
    const raw = fs.readFileSync(settingsPath, "utf8").trim();
    if (raw) {
        try {
            config = JSON.parse(raw);
        } catch (error) {
            console.error("Could not read " + settingsPath + " as JSON: " + error.message);
            console.error("A backup was already made. Fix or remove the file, then re-run.");
            process.exit(1);
        }
    }
}
config.statusLine = { type: "command", command: command };
fs.writeFileSync(settingsPath, JSON.stringify(config, null, 2) + "\n");
' "$CLAUDE_SETTINGS" "$WRAPPER_DEST"
say "    set statusLine.command in $CLAUDE_SETTINGS"

# ----------------------------------------------------------------- 6. wrap up

step "Done"
say ""
say "Restart Claude Code (or start a new session) and the status line will look"
say "like this, with the colour changing as the context fills up:"
say ""
say "    139.1k [▓░░░░░░░░░] 14% | \$2 | my-project | main"
say ""
say "If your account has Claude subscription limits, a second row appears under it"
say "once Claude replies, showing how much of the 5-hour and weekly windows you"
say "have used and when each one resets:"
say ""
say "    5h ▬▬░░░░░░░░  17%  ↻ 3PM   7d ▬▬▬▬░░░░░░  38%  ↻ Tue 6AM"
say ""
say "Run ./preview-plan.sh to see that row in every colour without waiting."
say ""

if [ ${#BACKUPS[@]} -gt 0 ]; then
    say "Backups of the files that were replaced:"
    for backup in "${BACKUPS[@]}"; do
        say "    $backup"
    done
    say ""
    say "Run ./uninstall.sh to put them back."
else
    say "Nothing needed backing up — none of these files existed before."
    say ""
    say "Run ./uninstall.sh to remove the status line again."
fi
