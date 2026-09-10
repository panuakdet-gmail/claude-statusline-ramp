#!/bin/bash
# Claude Code status line.
#
#   139.1k [▓░░░░░░░░░] 14% | $2 | my-project | main
#
# Renders via ccstatusline, then applies six fixes ccstatusline can't do itself:
#
#   1. Rounds the context percentage to a whole number. ccstatusline hardcodes
#      one decimal place (`toFixed(1)` in ContextPercentageWidget) with no config
#      option, so the rounding happens here on its output. The regex only touches
#      a digit.digit pair immediately followed by "%", so the token count
#      (e.g. "117.3k") is left alone.
#
#   2. Drops the ".../" prefix the current-working-dir widget adds when it is
#      limited to one path segment, leaving just the folder name.
#
#   3. Rounds the session cost to whole dollars. The widget always prints cents
#      and has no precision option, so the ".NN" is folded into the dollars here.
#      The "$" anchor keeps it off the token count, which has no currency sign.
#
#   4. Recolors the whole context group -- token count, bar, and percentage --
#      by how full the context is. ccstatusline gives a widget one fixed color,
#      so the ramp is applied here instead.
#
#   5. Folds 24-bit color down to the 256-color cube. A "hex:RRGGBB" widget
#      color (the session cost uses one, since no named color is a mid grey)
#      makes chalk emit a truecolor sequence no matter what the config's
#      colorLevel says -- and Apple Terminal has no 24-bit support, so it would
#      drop the color entirely. The fold is general rather than keyed to one
#      value, so changing that hex in the config keeps working.
#
#   6. Tells ccstatusline how wide the terminal is, via CCSTATUSLINE_WIDTH.
#      See "WHY THE WIDTH IS PASSED IN" below.
#
# WHY THE WIDTH IS PASSED IN:
#
# ccstatusline truncates its own output with "..." once the line exceeds the
# width it thinks the terminal has, and it works that width out for itself:
# `probeTerminalWidth` walks up the process tree with `ps -o ppid=`, looking for
# an ancestor with a real tty, then reads the size with `stty -f /dev/ttysNNN`.
# When any step of that fails it falls back to `tput cols`, which -- with stdout
# a pipe and stderr discarded -- has no terminal to ask and returns the terminfo
# default of 80. The line then gets cut well short of the real edge.
#
# CCSTATUSLINE_WIDTH is checked before all of that, so setting it takes the
# guesswork out. The probe below is the same idea but starts one process closer
# to the tty, and -- the part that matters -- when it comes up empty it reuses
# the last width that did work for this session instead of assuming 80.
#
# HOW THE RECOLOR FINDS ITS TARGETS -- this couples this file to
# ccstatusline-settings.json:
#
# The bar glyphs are U+2588..U+2593, which in UTF-8 are the bytes E2 96 88..93.
# They are matched as raw bytes, so no encoding layer is needed, and they are
# the only unambiguous landmark in the line. The color code sitting immediately
# in front of them is whatever color the config gives the context widgets; it is
# captured as a sentinel and every occurrence of it in the line is swapped for
# the ramp color. That recolors all three context elements in one pass, and
# survives changing the color in ccstatusline's editor.
#
# The catch: it works only while the three context widgets share a color that no
# other widget uses (yellow today). Give another widget that same color and it
# will be dragged along with the ramp.

# Claude Code may run this with a minimal PATH, so fall back to the usual
# install locations before giving up.
CCSTATUSLINE=$(command -v ccstatusline 2>/dev/null)
if [ -z "$CCSTATUSLINE" ]; then
    for candidate in \
        "$HOME/.local/bin/ccstatusline" \
        "$HOME/.bun/bin/ccstatusline" \
        "$HOME/.npm-global/bin/ccstatusline" \
        /opt/homebrew/bin/ccstatusline \
        /usr/local/bin/ccstatusline
    do
        if [ -x "$candidate" ]; then
            CCSTATUSLINE="$candidate"
            break
        fi
    done
fi

# The status line shows whatever this script prints, so a missing dependency
# has to explain itself here or it looks like nothing happened at all.
if [ -z "$CCSTATUSLINE" ]; then
    printf 'status line: ccstatusline not found — run the installer, or see the README\n'
    exit 0
fi

# Claude Code feeds the session as JSON on stdin, and ccstatusline needs it, so
# it is read here and handed on rather than left to flow through untouched.
payload=$(cat)

# Walk up from this script looking for an ancestor with a controlling terminal.
# This script itself has none (Claude Code runs it with pipes), but its parent
# -- the Claude Code process -- does. Eight levels is far more than that needs
# and stops the loop from running away if `ps` starts returning nonsense.
detect_width() {
    local pid=$$ parent tty cols _i
    for _i in 1 2 3 4 5 6 7 8; do
        parent=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d '[:space:]')
        case "$parent" in ''|0|*[!0-9]*) return 1 ;; esac
        pid=$parent
        tty=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d '[:space:]')
        # "?" and "??" are how ps spells "this process has no terminal".
        case "$tty" in ''|'?'|'??') continue ;; esac
        cols=$(stty -f "/dev/$tty" size 2>/dev/null | awk '{print $2}')
        case "$cols" in ''|*[!0-9]*|0) continue ;; esac
        printf '%s' "$cols"
        return 0
    done
    return 1
}

# One cache file per session, so two terminals of different widths can't hand
# each other a stale answer. The id is scrubbed because it becomes a filename.
session_id=$(printf '%s' "$payload" \
    | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    | tr -cd 'A-Za-z0-9._-')
width_cache="${TMPDIR:-/tmp}/ccstatusline-width-${session_id:-default}"

if width=$(detect_width); then
    printf '%s\n' "$width" > "$width_cache" 2>/dev/null
elif [ -r "$width_cache" ]; then
    width=$(tr -cd '0-9' < "$width_cache")
fi
# Left unset when there is nothing trustworthy to say, which puts ccstatusline
# back on its own detection rather than on a number this script invented.
if [ -n "$width" ]; then
    export CCSTATUSLINE_WIDTH="$width"
fi

line=$(printf '%s' "$payload" | "$CCSTATUSLINE" | perl -0777 -pe '
  s/(\d+)\.(\d)%/sprintf("%d%%", $1 + ($2 >= 5 ? 1 : 0))/ge;

  s/(\e\[[0-9;]*m)\.\.\.\//$1/g;

  s/\$(\d+)\.(\d\d)\b/"\$" . ($1 + ($2 >= 50 ? 1 : 0))/ge;

  # No bar means no transcript yet (start of session) -- leave the line alone.
  my ($sentinel) = /\e\[([0-9;]+)m(?:\xe2\x96[\x88-\x93])/;
  if (defined $sentinel) {
      # Band comes off the rounded percentage, so the color never disagrees
      # with the digits printed next to it.
      my ($pct) = /(\d+)%/;
      $pct = 0 unless defined $pct;
      my $ramp = $pct >= 90 ? "38;5;167"   # soft red   #D75F5F
               : $pct >= 75 ? "38;5;208"   # orange     #FF8700
               : $pct >= 50 ? "38;5;178"   # gold       #D7AF00
               : $pct >= 25 ? "38;5;107"   # moss       #87AF5F
               :              "38;5;79";   # mint       #5FD7AF
      # Only the color code is replaced, so the token count keeps its \e[1m bold
      # (emitted ahead of the color).
      s/\e\[\Q$sentinel\Em/\e[${ramp}m/g;
  }

  s/\e\[38;2;(\d+);(\d+);(\d+)m/"\e[38;5;" . rgb_to_xterm256($1, $2, $3) . "m"/ge;

  sub rgb_to_xterm256 {
      my ($r, $g, $b) = @_;
      # Greys have their own 24-step ramp at 232..255, which tracks a neutral
      # far more closely than the colour cube can.
      if ($r == $g && $g == $b) {
          return 16  if $r < 8;
          return 231 if $r > 248;
          return 232 + int(($r - 8) * 24 / 247 + 0.5);
      }
      my @level = (0, 95, 135, 175, 215, 255);
      my @axis = map {
          my $v = $_;
          my $best = 0;
          for my $i (1 .. 5) {
              $best = $i if abs($level[$i] - $v) < abs($level[$best] - $v);
          }
          $best;
      } ($r, $g, $b);
      return 16 + 36 * $axis[0] + 6 * $axis[1] + $axis[2];
  }
')

# ccstatusline runs on Node, so it goes quiet if Node is missing from the PATH
# Claude Code happens to invoke this with. Saying so beats an empty status line
# that looks like nothing is installed at all.
if [ -z "$line" ]; then
    printf 'status line: ccstatusline produced no output — see the README (When something looks wrong)\n'
    exit 0
fi

printf '%s\n' "$line"
