#!/bin/bash
#
# Prints sample plan-usage rows -- the optional second line of the status line
# -- so you can see every colour band and every reset-time format without
# waiting for your plan to fill up or for the week to roll over.
#
# Like preview-ramp.sh, it stands in a fake `ccstatusline` on the PATH and runs
# the real statusline-wrapper.sh against made-up payloads, so what you see here
# is the actual script you installed rather than a copy of its logic.
#
# Run it in a terminal. Piping it into a file, or a pager that strips colour,
# will reasonably enough show you no colour.

set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SOURCE_DIR/statusline-wrapper.sh" ]; then
    WRAPPER="$SOURCE_DIR/statusline-wrapper.sh"
elif [ -f "$HOME/.claude/statusline-wrapper.sh" ]; then
    WRAPPER="$HOME/.claude/statusline-wrapper.sh"
else
    printf 'Could not find statusline-wrapper.sh next to this script or in ~/.claude/\n' >&2
    exit 1
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

# The wrapper always draws its first line, so the stand-in has to print
# something -- an empty line would trip the "produced no output" warning. Only
# the second line is shown below.
cat > "$STAGE/ccstatusline" <<'FAKE'
#!/bin/bash
printf 'first line'
FAKE
chmod +x "$STAGE/ccstatusline"

NOW="$(date +%s)"

# The next whole hour, which is when real windows reset. Offsets are added to
# this so the samples read like the real thing rather than showing stray minutes.
HOUR="$(( (NOW / 3600 + 1) * 3600 ))"

row() {  # $1 = 5h percent, $2 = 5h reset epoch, $3 = 7d percent, $4 = 7d reset epoch
    local payload
    payload="$(printf '{"session_id":"preview","rate_limits":{"five_hour":{"used_percentage":%s,"resets_at":%s},"seven_day":{"used_percentage":%s,"resets_at":%s}}}' "$1" "$2" "$3" "$4")"
    printf '%s' "$payload" | PATH="$STAGE:$PATH" "$WRAPPER" | sed -n '2p'
}

printf '\n  \e[1mPlan usage — live output of %s\e[22m\n\n' "$(basename "$WRAPPER")"

printf '  \e[1mColour bands\e[22m  \e[38;5;59m(blue, then orange from 75%%, then red from 90%%)\e[39m\n\n'
for spec in \
    "0:0" \
    "6:3" \
    "34:22" \
    "74:60" \
    "75:75" \
    "89:88" \
    "90:90" \
    "100:97"
do
    IFS=: read -r five seven <<< "$spec"
    printf '  %s\n' "$(row "$five" "$((HOUR + 3600))" "$seven" "$((HOUR + 3 * 86400))")"
done

printf '\n  \e[1mReset times\e[22m  \e[38;5;59m(clock time today, weekday later this week, date beyond that)\e[39m\n\n'
for spec in \
    "$((HOUR)):later today, on the hour" \
    "$((HOUR + 1800)):off the hour — the minutes only appear when they are not zero" \
    "$((HOUR + 2 * 86400)):two days out" \
    "$((HOUR + 6 * 86400)):six days out" \
    "$((HOUR + 7 * 86400)):seven days out — a weekday name would read as today"
do
    IFS=: read -r at label <<< "$spec"
    printf '  %s   \e[38;5;59m%s\e[39m\n' "$(row 42 "$at" 42 "$at")" "$label"
done

printf '\n  \e[38;5;59mNothing is printed at all when the payload has no rate_limits — no\e[39m\n'
printf '  \e[38;5;59msubscription limits, or Claude has not replied yet this session.\e[39m\n'
printf '  \e[38;5;59mSet CCRAMP_PLAN_LINE=off to switch the row off for good.\e[39m\n\n'
