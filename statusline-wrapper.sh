#!/bin/bash
# Claude Code status line.
#
#   139.1k [▓░░░░░░░░░] 14% | $2 | my-project | main
#
# Renders via ccstatusline, then applies five fixes ccstatusline can't do itself:
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

line=$("$CCSTATUSLINE" | perl -0777 -pe '
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
