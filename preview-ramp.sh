#!/bin/bash
#
# Prints one sample status line per colour band, so you can see the whole ramp
# without waiting for a session to fill up.
#
# It works by standing in a fake `ccstatusline` on the PATH that emits a
# made-up line at a chosen percentage, then running the real
# statusline-wrapper.sh against it. So this exercises the actual script you
# installed, start to finish, rather than a copy of its logic that could drift.
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

cat > "$STAGE/ccstatusline" <<'FAKE'
#!/bin/bash
printf '%s' "$SAMPLE_LINE"
FAKE
chmod +x "$STAGE/ccstatusline"

bar() {  # $1 = percent -> a ten-cell bar, filled cells rounded to the nearest tenth
    local filled=$(( ($1 + 5) / 10 )) i out=""
    for ((i = 0; i < 10; i++)); do
        if ((i < filled)); then out+="▓"; else out+="░"; fi
    done
    printf '%s' "$out"
}

sample() {  # $1 = percent, $2 = token count -> a line shaped like ccstatusline's
    printf '\e[0m\e[1m\e[38;5;178m%s\e[39m\e[22m\e[38;5;59m [\e[39m\e[38;5;178m%s\e[39m\e[38;5;59m] \e[39m\e[38;5;178m%s%%\e[39m | \e[38;2;138;138;138m$1.76\e[39m | \e[38;5;30m.../my-project\e[39m | \e[38;5;96mmain\e[39m' \
        "$2" "$(bar "$1")" "$1"
}

printf '\n  \e[1mContext colour ramp\e[22m  —  live output of %s\n\n' "$(basename "$WRAPPER")"

for spec in \
    "14:139.1k:under 25%   mint" \
    "24:240.0k:under 25%   mint" \
    "25:250.0k:25-49%      moss" \
    "33:330.0k:25-49%      moss" \
    "49:490.0k:25-49%      moss" \
    "50:500.0k:50-74%      gold" \
    "62:620.0k:50-74%      gold" \
    "74:740.0k:50-74%      gold" \
    "75:750.0k:75-89%      orange" \
    "82:820.0k:75-89%      orange" \
    "89:890.0k:75-89%      orange" \
    "90:900.0k:90%+        soft red" \
    "96:960.0k:90%+        soft red" \
    "99:990.0k:90%+        soft red"
do
    IFS=: read -r pct tokens label <<< "$spec"
    rendered="$(SAMPLE_LINE="$(sample "$pct" "$tokens")" PATH="$STAGE:$PATH" "$WRAPPER")"
    printf '  %s   \e[38;5;59m%s\e[39m\n' "$rendered" "$label"
done

printf '\n  \e[38;5;59mBoundaries: 25 / 50 / 75 / 90. The band follows the rounded percentage.\e[39m\n\n'
