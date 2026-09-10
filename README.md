# A status line that changes colour as you run out of room

This makes the little information bar at the bottom of Claude Code look like this:

```
139.1k [▓░░░░░░░░░] 14% | $2 | my-project | main
```

and — the point of the whole thing — it turns from mint green to red as your
conversation fills up, so you can tell at a glance how much room is left
without reading a single number.

```
139.1k [▓░░░░░░░░░] 14% | $2 | my-project | main     mint      plenty of room
330.0k [▓▓▓░░░░░░░] 33% | $2 | my-project | main     moss
620.0k [▓▓▓▓▓▓░░░░] 62% | $2 | my-project | main     gold
820.0k [▓▓▓▓▓▓▓▓░░] 82% | $2 | my-project | main     orange
960.0k [▓▓▓▓▓▓▓▓▓▓] 96% | $2 | my-project | main     red       nearly full
```

---

## What the parts mean

If some of these words are new, this section is for you — nothing here assumes
you write software.

| Part | Example | What it is |
|---|---|---|
| Token count | `139.1k` | Roughly, how much text Claude is currently holding in mind. A **token** is about three-quarters of an English word, so `139.1k` is about 100,000 words. |
| Bar | `[▓░░░░░░░░░]` | The same thing as a picture. Ten cells, filled left to right. |
| Percentage | `14%` | How full the **context window** is — the fixed amount of text Claude can keep in mind at once. At 100% the oldest parts start being summarised away. |
| Cost | `$2` | What this session has cost so far, in whole dollars. |
| Folder | `my-project` | The folder you're working in. |
| Branch | `main` | Which version of the project you have checked out, if it's tracked by git. Hidden when it isn't. |

The first three are one group and always share a colour. That colour is the
signal:

| Context used | Colour | Reading |
|---|---|---|
| under 25% | mint | lots of room |
| 25–49% | moss | comfortable |
| 50–74% | gold | over half gone |
| 75–89% | orange | start thinking about wrapping up |
| 90% and over | soft red | nearly out |

The scale runs cool to warm on purpose: mint is the one cool colour in the set,
so "plenty of room" looks visibly different from everything else rather than
just being one more shade of green.

---

## The second line: how much of your plan is left

Claude Code also knows how much of your Claude subscription you have used — the
5-hour window and the weekly one. It hands those figures to the status line and
to nothing else, so this is the only place they can be shown. When they are
available, a second row appears underneath the first:

```
139.1k [▓░░░░░░░░░] 14% | $2 | my-project | main
5h ▬▬░░░░░░░░  17%  ↻ 3PM   7d ▬▬▬▬░░░░░░  38%  ↻ Tue 6AM
```

Two meters, side by side. The left one is your 5-hour window, the right one your
week.

| Part | Example | What it is |
|---|---|---|
| Label | `5h` | Which window. `5h` is the rolling 5-hour limit, `7d` the weekly one. |
| Bar | `▬▬░░░░░░░░` | Ten cells, one per 10% of that window used. Any usage at all fills at least one cell, so "barely started" still looks different from "not started". |
| Percentage | `17%` | How much of the window is used up. This is the number the row is really about, so it is the brightest thing in it. |
| Reset time | `↻ 3PM` | The clock time the window empties again — not how long you have to wait. |

The bar is blue while there is room, turns orange at 75% used, and red at 90% —
the same two boundaries the first line uses, so those numbers mean one thing
wherever they appear on the status line.

The reset time is deliberately a clock time rather than "resets in 3 hr 13 min":
a countdown changes on every redraw and still has to be added to the current
time before it tells you anything. It is written three ways depending on how far
off it is:

| When it resets | Shown as |
|---|---|
| Later today | `3PM` |
| Later this week | `Tue 6AM` |
| A week or more away | `Sep 17` |

Windows reset on the hour, so the minutes are left off — `3PM`, not `3:00PM`.
They appear (`3:20PM`) on the rare occasion they are not zero.

### When it appears, and when it doesn't

The row draws itself only when there is something true to say. It is absent:

- **until Claude has replied once** in the session — Claude Code doesn't know
  your usage before then;
- **for accounts with no subscription limits** — API-key and other pay-as-you-go
  accounts have nothing to report here;
- **for a window that has already reset** — Claude Code drops it from the data,
  and it comes back on your next reply.

So a fresh session starts one line high and grows a second line once Claude
answers you. Nothing has gone wrong when you see only one line.

To keep the single-line look permanently, set `CCRAMP_PLAN_LINE=off` in the
environment Claude Code starts in.

---

## Before you start

You need three things. The installer checks for all of them and tells you what's
missing, so you don't have to verify them yourself first.

1. **Claude Code**, already installed and working.
2. **Node.js**, version 14 or newer. This is a program that runs
   JavaScript outside a web browser. If you don't have it, get the "LTS" version
   from [nodejs.org](https://nodejs.org) — the installer walks you through it.
3. **macOS or Linux.** The scripts are written in `bash` and `perl`, which both
   systems already include. On Windows they work inside WSL (Windows Subsystem
   for Linux) but not in plain PowerShell.

This project also needs [ccstatusline](https://github.com/sirmalloc/ccstatusline)
— a separate, free tool that does the real work of measuring your session. You
do **not** need to install it yourself; the installer does it for you. See
[Credits](#credits) for what it is and why it's here.

---

## Installing

Pick whichever of these three you're most comfortable with. They all end up in
the same place.

### Option A — ask Claude Code to do it

Easiest if you'd rather not touch a terminal at all.

**If you have already downloaded this folder**, open Claude Code in it and paste:

```
Please install the status line in this folder for me.

Run ./install.sh and tell me if anything goes wrong. If Node.js turns out to be
missing, explain how I should install it rather than installing it yourself.
When it's finished, run ./preview-ramp.sh so I can see what the colours look
like.
```

**If you haven't downloaded it yet**, open Claude Code anywhere and paste this,
replacing the address with wherever this project lives:

```
Please install this Claude Code status line for me:
https://github.com/panuakdet-gmail/claude-statusline-ramp

Download it somewhere sensible, read its README, then run its install.sh and
tell me if anything goes wrong. When it's finished, run ./preview-ramp.sh so I
can see what the colours look like.
```

Claude Code will ask your permission before running anything. It's fine to say
yes to the steps above; they only write to your own Claude Code settings, and
they back up anything they replace.

### Option B — run the installer yourself

Open Terminal, go to this folder, and run:

```bash
./install.sh
```

That's the whole thing. It will:

- check that Node.js is present,
- install `ccstatusline` if you don't already have it,
- copy the two configuration files into place,
- and tell Claude Code to start using them.

Anything of yours it replaces is backed up first, and it prints where those
backups went. Running it again later is harmless — it won't overwrite that first
backup, so the copy of your original setup stays intact however many times you
re-run it.

If your terminal says `permission denied`, the file just needs marking as
runnable once:

```bash
chmod +x install.sh uninstall.sh preview-ramp.sh preview-plan.sh
```

### Option C — do it by hand

For people who'd rather see every step. Four moves:

1. Install ccstatusline: `npm install -g ccstatusline`
2. Copy `ccstatusline-settings.json` to `~/.config/ccstatusline/settings.json`
3. Copy `statusline-wrapper.sh` to `~/.claude/statusline-wrapper.sh` and run
   `chmod +x ~/.claude/statusline-wrapper.sh`
4. In `~/.claude/settings.json`, add (or replace) this entry:

```json
"statusLine": {
  "type": "command",
  "command": "/Users/YOUR-USERNAME/.claude/statusline-wrapper.sh"
}
```

Use the real full path — that setting doesn't understand the `~` shorthand.

---

## Seeing it work

Restart Claude Code, or just start a new session. The status line appears at the
bottom of the window and updates as you go.

To see every colour immediately without waiting for a long conversation:

```bash
./preview-ramp.sh
```

That prints one sample line per band, including both sides of every boundary.
It builds those samples and pushes them through the real script, so it can't
drift out of step with what you'll actually see.

And for the plan-usage row, which otherwise takes a busy week to show you all of
itself:

```bash
./preview-plan.sh
```

That one prints a sample meter per colour band and per reset-time format, the
same way — real script, made-up figures.

---

## Changing it to taste

### Where the colours live

Open `statusline-wrapper.sh` and find this block:

```perl
my $ramp = $pct >= 90 ? "38;5;167"   # soft red   #D75F5F
         : $pct >= 75 ? "38;5;208"   # orange     #FF8700
         : $pct >= 50 ? "38;5;178"   # gold       #D7AF00
         : $pct >= 25 ? "38;5;107"   # moss       #87AF5F
         :              "38;5;79";   # mint       #5FD7AF
```

The numbers on the left (`90`, `75`, `50`, `25`) are the percentages where the
colour changes. The `38;5;NNN` values are colours — terminals number their
colours 0 to 255, and `NNN` is the number. Change either, save, and the next
redraw picks it up. There's nothing to rebuild or restart.

To browse the available colour numbers:

```bash
for i in {0..255}; do printf '\e[38;5;%dm %3d \e[0m' "$i" "$i"; done; echo
```

After any change, run `./preview-ramp.sh` to see all five bands at once.

### The plan row's colours

The second line has its own, shorter ramp, further down the same file:

```perl
my $fill = $whole >= 90 ? "38;5;167"   # soft red   #D75F5F
         : $whole >= 75 ? "38;5;208"   # orange     #FF8700
         :                "38;5;74";   # steel blue #5FAFD7
```

That one colours the bar only. The three text colours sit just below it, in the
`sprintf` calls: `38;5;59` for the label, `38;5;255` for the percentage,
`38;5;145` for the reset time. They are meant to be read as an order — dimmest
label, brightest percentage — so if you change one, change it in a way that
keeps the percentage the easiest thing to find.

Run `./preview-plan.sh` afterwards to see the result.

### Rearranging the pieces

The order of the items — token count, bar, percentage, cost, folder, branch —
lives in `ccstatusline-settings.json`. The friendliest way to change it is
ccstatusline's own editor:

```bash
ccstatusline
```

**One rule if you use that editor:** the token count, the bar, and the
percentage must all keep the *same* colour as each other, and no other item may
use that colour. That shared colour is how the script recognises which pieces to
recolour. Give the folder name the same yellow and the folder will start
changing colour along with your context.

---

## Removing it

```bash
./uninstall.sh
```

This puts back whatever the installer replaced. If there was nothing to put back
— because you had no status line before — it removes the files it added and
tells Claude Code to stop using them.

It deliberately leaves `ccstatusline` installed, since you may be using it for
other things. To remove that too:

```bash
npm uninstall -g ccstatusline
```

---

## When something looks wrong

**The status line is blank.**
Claude Code shows whatever the script prints, so a blank line means the script
produced nothing. Run it directly to see the error:
`~/.claude/statusline-wrapper.sh < /dev/null`

**It says "ccstatusline not found".**
Exactly what it sounds like. Run `npm install -g ccstatusline`, or re-run
`./install.sh`.

**It says "ccstatusline produced no output".**
ccstatusline was found but couldn't run. Almost always this means Node.js isn't
where the script can see it. Check with `node --version`; if that works in your
terminal but the status line still complains, your terminal and Claude Code are
starting with different settings — installing Node system-wide rather than
through a version manager usually settles it.

**Everything is there but nothing is coloured.**
Your terminal may be set to a limited colour mode. Check with the colour-listing
command above — if that prints 256 coloured blocks, colours work and something
else is wrong.

**The bar shows boxes or question marks instead of `▓░`.**
Your terminal font is missing those two characters. Most monospace fonts have
them; Menlo, Monaco, SF Mono, JetBrains Mono, and Fira Code all do.

**The plan-usage row never appears.**
Most likely there is nothing to show: it needs a Claude subscription, and it
stays hidden until Claude has replied once in the session. Send a message and
look again. If it still doesn't appear, check that `CCRAMP_PLAN_LINE` isn't set
to `off`.

**The plan-usage bar shows boxes instead of `▬░`.**
Same as above — a font gap. `▬` is the one to check; it is less common than the
block characters used on the first line.

**The colours never change.**
Something else is probably using the same colour as the context items, or they
no longer share one. See the rule in "Rearranging the pieces" above.

---

## How it works, for the curious

Claude Code lets you nominate any program as your status line. It runs that
program on every redraw, hands it a blob of information about the session, and
prints whatever comes back.

Here that program is `statusline-wrapper.sh`, which doesn't measure anything
itself. It runs `ccstatusline` — which does the genuinely hard part, working out
how many tokens are in play by reading the session transcript — and then edits
the text on its way out.

Five edits, and each exists because ccstatusline has no setting for it:

1. Rounds `14.2%` to `14%`.
2. Trims the folder path down to just the folder name.
3. Rounds `$1.76` to `$2`.
4. Recolours the token count, bar, and percentage by how full the context is.
5. Converts any 24-bit colour to the nearest of the standard 256, because Apple
   Terminal doesn't support 24-bit colour and would otherwise drop it.

Number 4 is the interesting one. It finds the bar by looking for the block
characters, notes which colour code sits in front of them, and then swaps every
occurrence of that same code in the line. That's why the three context items
have to share a colour — it's the handle the script grabs them by. The upside is
that it keeps working if you change that colour in ccstatusline's editor, rather
than silently doing nothing.

The second line is not ccstatusline's work at all. Claude Code puts your
subscription's usage figures — percentage used and reset time for each window —
into the same blob of session information, and `statusline-wrapper.sh` reads
them straight out of it and draws the two meters itself. That data is given to
the status line and to nothing else in Claude Code, which is why it lives here
rather than in a hook or a separate widget.

The comments in `statusline-wrapper.sh` go further if you want the details.

---

## Credits

The measuring is done by [**ccstatusline**](https://github.com/sirmalloc/ccstatusline)
by Matthew Breedlove, used under the MIT licence. It's an excellent tool on its
own and worth a look — it has a full configuration editor, many more widgets
than are used here, Powerline styling, and much else.

This project is a thin layer on top of it: a widget arrangement, and a script
that adjusts ccstatusline's output in a few ways its settings don't reach. No
ccstatusline code is included or modified here.

## Licence

MIT — see [LICENSE](LICENSE).
