# vsc2zed

Export a VS Code color theme as a Zed theme family. One bash script, one jq
program, no build step.

```console
$ vsc2zed MaoSantaella.night-wolf
converting MaoSantaella.night-wolf
  fetching MaoSantaella.night-wolf from the marketplace
  - Night Wolf (dark blue)
  - Night Wolf (dark blue) (No Italics)
  - Night Wolf (dark gray)
  - Night Wolf (dark gray) (No Italics)
  - Night Wolf (gray)
  - Night Wolf (gray) (No Italics)
  - Night Wolf (black)
  - Night Wolf (black) (No Italics)
wrote themes/night-wolf.json
```

Add `--install` and the file lands in `~/.config/zed/themes/`, where Zed picks
it up the next time it starts. All eight Night Wolf variants show up in the
theme selector.

Or run it with no arguments and it finds the themes you already have installed
in VS Code or Cursor:

```console
$ vsc2zed
vsc2zed 1.0.0

Found 3 theme extension(s) installed locally:

   1  VS Code            Night Wolf                           8 theme(s)
   2  VS Code            Dracula Theme                        4 theme(s)
   3  Cursor             GitHub Theme                         9 theme(s)

  m   fetch from the marketplace instead
  p   give a path to a .vsix, folder, or theme file
  q   quit

> 1

This extension has 8 themes:
   1  Night Wolf (dark blue)
   2  Night Wolf (dark blue) (No Italics)
   ...

Install all 8, or pick some (e.g. 1,3)? [all] 1,5

Install into /home/you/.config/zed/themes? [Y/n] y

converting /home/you/.vscode/extensions/maosantaella.night-wolf-2.5.0
  - Night Wolf (dark blue)
  - Night Wolf (gray)
wrote /home/you/.config/zed/themes/night-wolf.json
```

## Why another one of these

There is a Rust port already. It works, but installing a toolchain to move a
JSON file into a different JSON file is more than the job needs. This does the
same work with tools you already have: bash, jq, awk, and unzip.

The interesting part is not the file I/O. It is deciding that Zed's
`element.hover` should come from VS Code's `list.hoverBackground`, and that when
a theme leaves that key out you fall back to the foreground at 8% over the
background. That knowledge lives in one table in `lib/mappings.jq`, which is the
file you will actually want to read or edit.

## Install

```sh
git clone https://github.com/YOUR-USERNAME/vscode-zed-theme-exporter
cd vscode-zed-theme-exporter
./vsc2zed --help
```

Or put `vsc2zed` and `lib/` somewhere on your `PATH`. The script finds `lib/`
relative to itself.

Requirements: bash 4+, jq 1.6+, awk, unzip. `curl` only if you pass a
marketplace ID.

## Usage

```
vsc2zed [OPTIONS] <SOURCE>...
```

`SOURCE` is whichever form of the theme you happen to have:

```sh
vsc2zed MaoSantaella.night-wolf            # marketplace publisher.extension
vsc2zed ~/Downloads/night-wolf-2.5.0.vsix  # a downloaded package
vsc2zed ~/src/my-theme/                    # an unpacked extension
vsc2zed themes/my-color-theme.json         # a single theme file
```

Options:

| Option | Effect |
| --- | --- |
| `-o, --out DIR` | Where to write. Defaults to `./themes`. |
| `--name NAME` | Override the theme family name. |
| `--author NAME` | Override the author. Defaults to the extension publisher. |
| `--appearance dark\|light` | Force the appearance for every theme. |
| `--install` | Also copy into Zed's user themes directory. |
| `--stdout` | Write to stdout instead of a file. |
| `-q, --quiet` | Errors only. |
| `-i, --interactive` | Pick from what VS Code or Cursor already has installed. |
| `--list-local` | Print that list and exit. |
| `--only GLOB` | Convert only matching themes. Repeatable. |

With no `SOURCE` at a terminal, `vsc2zed` goes interactive.

`--only` takes a case-insensitive glob matched against the whole theme name.
Parentheses are literal, since theme names are full of them:

```sh
vsc2zed --only '*(black)' --install MaoSantaella.night-wolf
```

Because the glob is anchored, that selects `Night Wolf (black)` and leaves
`Night Wolf (black) (No Italics)` alone.

One extension becomes one Zed theme family. An extension shipping eight themes
produces one file with eight entries, which is how Zed expects related themes to
be packaged.

## Finding local themes

`--list-local` and interactive mode look for user-installed extensions in the
usual places: `~/.vscode/extensions`, plus the equivalent directories for VS
Code Insiders, VSCodium, Cursor, Windsurf, Trae, and the Flatpak builds. The
path hangs off `$HOME` on every platform, so there is no per-OS special casing.

Point it somewhere else with `VSC2ZED_EXTENSION_ROOTS`, a `:`-separated list of
directories. An entry can be a bare path or `Label|path`:

```sh
VSC2ZED_EXTENSION_ROOTS="Work Cursor|/opt/cursor/extensions" vsc2zed --list-local
```

Extensions that store their display name as a `%key%` reference into
`package.nls.json` get resolved, so the picker shows `Localized Name` rather
than `%ext.displayName%`.

## What it handles

VS Code themes are messier than the format suggests, so the converter deals with
a few things you would otherwise hit by hand.

**Comments and trailing commas.** VS Code reads theme files with a permissive
parser. jq will not. `lib/jsonc.awk` strips both, and only runs when jq has
already refused the file.

**`include` chains.** A theme can extend another and override parts of it.
Colors merge key by key, token rules concatenate with the base first.

**Placeholder names.** Night Wolf ships all eight of its themes with
`"name": "themename"`. The label in `package.json` is authoritative, so that is
what the converter uses.

**Rules that split color and style.** Night Wolf colors `meta.function-call` in
one rule and italicizes it in another. VS Code merges those. Replacing the first
with the second, which is the obvious implementation, silently drops the color.
The scope index merges instead.

**Scopes narrower than the capture.** A theme that colors
`keyword.control.flow` but never `keyword` leaves Zed's `keyword` capture
unstyled. When no prefix match exists, the converter takes the shortest
descendant scope instead.

**Colors Zed has and VS Code does not.** Dim ANSI colors, player colors past the
first, and the `.background` and `.border` variants of every git status. These
are derived from the palette rather than left empty.

The output covers 141 of the 142 color keys in Zed's theme schema. The one gap
is `background.appearance`, a window transparency setting with no VS Code
equivalent.

## Extending the mapping

`lib/mappings.jq` holds two tables. Each maps a Zed key to an ordered list of
candidates, and the first candidate that resolves wins:

```jq
"element.hover": ["list.hoverBackground", "toolbar.hoverBackground", "$fg@14!"],
"keyword":      ["keyword.control", "keyword", "storage.type", "storage.modifier"],
```

UI candidates use a four-part notation:

| Form | Meaning |
| --- | --- |
| `list.hoverBackground` | A VS Code workbench color key. |
| `$accent` | A slot in the derived base palette (`bg`, `fg`, `accent`, `border`, and six hues). |
| `#ff00ff` | A literal. |
| `...@40` | That color at alpha `0x40`. |
| `...!` | Composite the result onto the background, making it opaque. |

Suffixes combine left to right, so `foreground@40!` is the foreground at 25%
flattened onto the background.

Syntax candidates are TextMate scopes. Lookup walks each scope's dotted
prefixes, so listing `keyword.control` also catches a theme that only wrote a
rule for `keyword`.

If a mapping produces a bad color for some theme, the fix is usually one line in
that file. You should not need to touch `lib/convert.jq`.

## Layout

```
vsc2zed              CLI. Argument parsing, source adapters, file I/O.
lib/mappings.jq      The two tables. Data only.
lib/convert.jq       One VS Code theme in, one Zed theme out. A pure function.
lib/jsonc.awk        JSONC to strict JSON.
lib/interactive.sh   Local editor discovery and the picker.
tests/run.sh         67 assertions, no framework.
tests/drive_tty.py   Runs the picker on a pseudo-terminal so it can be tested.
themes/              Output.
```

`lib/interactive.sh` is sourced only for `--interactive` and `--list-local`, and
it ends by setting the same variables a command line would have set. Interactive
mode fills in arguments. It is not a second conversion path, so nothing in it
can change how a theme converts.

`lib/convert.jq` never touches the filesystem, so you can drive it directly:

```sh
jq -L lib --arg name "My Theme" --arg appearance "" -f lib/convert.jq theme.json
```

That is also how most of the tests call it.

## Tests

```sh
./tests/run.sh
```

The suite covers color normalization, scope resolution, `include` chains, JSONC
edge cases, the CLI flags, local discovery, and the shape of the output. The
picker is driven through a real pseudo-terminal, because it refuses to run
without one and a plain pipe cannot test it. Those tests skip if `python3` is
missing.

The checked-in Night Wolf export doubles as the end-to-end regression test,
since it is the only artifact built from a real published extension.

## Known limits

Some VS Code concepts have no Zed equivalent and are dropped: the minimap,
peek view, notification, and debug toolbar colors, bracket pair guide
backgrounds, and per-language `tokenColors` overrides. Nothing is lost that Zed
could render.

Light themes work. I checked against GitHub's theme extension, which ships four
light variants alongside its dark ones, including a high contrast one. Still,
far more dark themes have been through this than light ones, so if a light theme
comes out wrong, the mapping table is the place to look.

## License

MIT. The themes under `themes/` remain the property of their original authors,
whose licenses apply to them.
