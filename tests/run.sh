#!/usr/bin/env bash
#
# Every test drives the tool through the same interface a user would: the
# `vsc2zed` CLI, or the jq program it wraps. Nothing reaches past those.

set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
FIX="$ROOT/tests/fixtures"
PASS=0; FAIL=0

ok()   { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '  FAIL %s\n       expected: %s\n       actual:   %s\n' "$1" "$2" "$3"; }
is()   { [ "$2" = "$3" ] && ok "$1" || bad "$1" "$3" "$2"; }
isnt() { [ "$2" != "$3" ] && ok "$1" || bad "$1" "anything but $3" "$2"; }

# Run the converter on a fixture and echo one jq query against the result.
conv() { # conv <fixture> <jq-filter> [name] [appearance]
  jq -L "$ROOT/lib" --arg name "${3:-Test}" --arg appearance "${4:-}" \
     -f "$ROOT/lib/convert.jq" "$FIX/$1" | jq -r "$2"
}

echo "color normalization"
  is "8-digit hex passes through" \
     "$(conv mini-color-theme.json '.style.players[0].selection')" "#4080c055"
  is "6-digit hex gains alpha"  "$(conv mini-color-theme.json '.style["editor.background"]')" "#102030ff"
  is "explicit null falls through the chain" \
     "$(conv mini-color-theme.json '.style.error')" "#e06060ff"

echo "scope resolution"
  is "exact scope match"        "$(conv mini-color-theme.json '.style.syntax.comment.color')" "#5a6a7aff"
  is "prefix fallback: keyword.control.flow answers keyword" \
     "$(conv mini-color-theme.json '.style.syntax.keyword.color')" "#c060c0ff"
  is "bold becomes font_weight 700" \
     "$(conv mini-color-theme.json '.style.syntax.keyword.font_weight')" "700"
  is "color and fontStyle merge across two rules for one scope" \
     "$(conv mini-color-theme.json '[.style.syntax["function.call"].color, .style.syntax["function.call"].font_style] | join(" ")')" \
     "#40c0c0ff italic"
  is "style-only rule yields no color" \
     "$(conv mini-color-theme.json '.style.syntax["emphasis.strong"] | "\(.color) \(.font_weight)"')" \
     "null 700"

echo "semantic token fallback"
  is "string form"              "$(conv mini-color-theme.json '.style.syntax["variable.parameter"].color')" "#e0a060ff"
  is "object form keeps italic" \
     "$(conv mini-color-theme.json '.style.syntax["type.interface"] | "\(.color) \(.font_style)"')" \
     "#d0b040ff italic"

echo "derived palette"
  isnt "muted text differs from text when the source collapses them" \
     "$(conv mini-color-theme.json '.style["text.muted"]')" "$(conv mini-color-theme.json '.style.text')"
  isnt "icon.muted is not icon" \
     "$(conv mini-color-theme.json '.style["icon.muted"]')" "$(conv mini-color-theme.json '.style.icon')"
  is "dim ANSI is opaque, flattened onto the background" \
     "$(conv mini-color-theme.json '.style["terminal.ansi.dim_red"] | endswith("ff")')" "true"

echo "appearance"
  is "type: dark"               "$(conv mini-color-theme.json '.appearance')" "dark"
  is "explicit override wins"   "$(conv mini-color-theme.json '.appearance' Test light)" "light"

echo "jsonc"
  is "comments and trailing commas are stripped" \
     "$(awk -f "$ROOT/lib/jsonc.awk" "$FIX/jsonc-color-theme.json" | jq -r '.name')" "JSONC Theme"
  is "comment syntax inside a string survives" \
     "$(awk -f "$ROOT/lib/jsonc.awk" "$FIX/jsonc-color-theme.json" | jq -r '.colors.note')" \
     "not a // comment, and not a /* comment */ either"
  is "3-digit hex expands" \
     "$("$ROOT/vsc2zed" --stdout -q "$FIX/jsonc-color-theme.json" | jq -r '.themes[0].style["editor.background"]')" \
     "#ffffffff"
  is "light theme detected through jsonc" \
     "$("$ROOT/vsc2zed" --stdout -q "$FIX/jsonc-color-theme.json" | jq -r '.themes[0].appearance')" "light"

echo "include chains"
  out="$("$ROOT/vsc2zed" --stdout -q "$FIX/derived-color-theme.json")"
  is "child overrides the base"  "$(jq -r '.themes[0].style["editor.background"]' <<<"$out")" "#111111ff"
  is "base colors are inherited" "$(jq -r '.themes[0].style["border.focused"]'     <<<"$out")" "#ff0000ff"
  is "token colors concatenate"  "$(jq -r '[.themes[0].style.syntax.comment.color, .themes[0].style.syntax.keyword.color] | join(" ")' <<<"$out")" \
     "#444444ff #00ff00ff"

echo "cli"
  out="$("$ROOT/vsc2zed" --stdout -q "$FIX/pkg-extension")"
  is "one family per extension"     "$(jq -r '.themes | length' <<<"$out")" "3"
  is "family name from displayName" "$(jq -r '.name'   <<<"$out")" "Mini Suite"
  is "author from publisher"        "$(jq -r '.author' <<<"$out")" "example"
  is "theme names from labels"      "$(jq -r '[.themes[].name] | join(", ")' <<<"$out")" "Mini Dark, Mini Light, Mini Contrast"
  is "uiTheme drives appearance"    "$(jq -r '[.themes[].appearance] | join(", ")' <<<"$out")" "dark, light, light"
  is "schema is declared"           "$(jq -r '."$schema"' <<<"$out")" "https://zed.dev/schema/themes/v0.2.0.json"
  is "hc-light counts as light, and the theme file's own type does not override it" \
     "$(jq -r '.themes[2].appearance' <<<"$out")" "light"

  out2="$("$ROOT/vsc2zed" --stdout -q --name Renamed --author Someone --appearance light "$FIX/pkg-extension")"
  is "--name overrides"      "$(jq -r '.name'   <<<"$out2")" "Renamed"
  is "--author overrides"    "$(jq -r '.author' <<<"$out2")" "Someone"
  is "--appearance forces"   "$(jq -r '[.themes[].appearance] | unique | join(",")' <<<"$out2")" "light"

  tmp="$(mktemp -d)"; trap 'rm -rf -- "$tmp"' EXIT
  "$ROOT/vsc2zed" -q -o "$tmp" "$FIX/pkg-extension"
  is "writes a slugified filename" "$(basename "$(ls "$tmp")")" "mini-suite.json"
  "$ROOT/vsc2zed" --stdout -q nosuchfile.json >/dev/null 2>&1
  is "unknown source exits nonzero" "$?" "1"

echo "output shape"
  fam="$("$ROOT/vsc2zed" --stdout -q "$FIX/pkg-extension")"
  is "every UI color is #rrggbbaa" \
     "$(jq -r '[.themes[].style | to_entries[] | select(.key | test("^(syntax|players|accents)$") | not)
               | select((.value | type) != "string" or (.value | test("^#[0-9a-f]{8}$") | not)) | .key] | length' <<<"$fam")" "0"
  is "every syntax color is #rrggbbaa" \
     "$(jq -r '[.themes[].style.syntax[] | select(.color != null) | select(.color | test("^#[0-9a-f]{8}$") | not)] | length' <<<"$fam")" "0"
  is "font_weight stays in the schema's enum" \
     "$(jq -r '[.themes[].style.syntax[].font_weight | select(. != null) | select([100,200,300,400,500,600,700,800,900] | index(.) | not)] | length' <<<"$fam")" "0"
  is "eight players"  "$(jq -r '[.themes[].style.players | length] | unique | join(",")' <<<"$fam")" "8"
  is "six accents"    "$(jq -r '[.themes[].style.accents | length] | unique | join(",")' <<<"$fam")" "6"

echo "--only"
  nw() { "$ROOT/vsc2zed" --stdout -q "$@" "$FIX/pkg-extension" | jq -r '[.themes[].name] | join("/")'; }
  is "a plain glob"        "$(nw --only 'Mini D*')" "Mini Dark"
  is "repeatable"          "$(nw --only 'Mini Dark' --only 'Mini Contrast')" "Mini Dark/Mini Contrast"
  is "case insensitive"    "$(nw --only 'mini light')" "Mini Light"
  is "parentheses are literal, not an extglob group" \
     "$("$ROOT/vsc2zed" --stdout -q --only '*(black)' "$FIX/parens-extension" | jq -r '[.themes[].name] | join("/")')" \
     "Wolf (black)"
  is "the glob is anchored, so a longer sibling label is not caught" \
     "$("$ROOT/vsc2zed" --stdout -q --only 'Wolf (black)' "$FIX/parens-extension" | jq -r '[.themes[].name] | join("/")')" \
     "Wolf (black)"
  "$ROOT/vsc2zed" --stdout -q --only 'nothing like this' "$FIX/pkg-extension" >/dev/null 2>&1
  is "matching nothing exits nonzero" "$?" "1"

echo "local discovery"
  export VSC2ZED_EXTENSION_ROOTS="VS Code|$FIX/editors/vscode:Cursor|$FIX/editors/cursor"
  listing="$("$ROOT/vsc2zed" --list-local 2>&1)"
  is "finds extensions under every configured root" \
     "$(grep -c 'VS Code\|Cursor' <<<"$listing")" "2"
  is "skips extensions that contribute no themes" \
     "$(grep -c 'Not A Theme' <<<"$listing")" "0"
  is "resolves a %nls% display name" \
     "$(grep -c 'Localized Name' <<<"$listing")" "1"
  is "counts the themes in each extension" \
     "$(awk '/Mini Suite/ {print $NF}' <<<"$listing")" "3"

  export VSC2ZED_EXTENSION_ROOTS="$FIX/editors/vscode"
  is "a bare path gets its label from the directory name" \
     "$("$ROOT/vsc2zed" --list-local 2>&1 | grep -c '^vscode')" "1"

  export VSC2ZED_EXTENSION_ROOTS="$FIX/editors/nope"
  is "no roots is not an error" \
     "$("$ROOT/vsc2zed" --list-local >/dev/null 2>&1; echo $?)" "0"

  # The %nls% name has to reach the pipeline too: it becomes the filename.
  export VSC2ZED_EXTENSION_ROOTS="VS Code|$FIX/editors/vscode:Cursor|$FIX/editors/cursor"
  is "the resolved name reaches the output family" \
     "$("$ROOT/vsc2zed" --stdout -q "$FIX/editors/cursor/example.nls-1.0.0" | jq -r '.name')" "Localized Name"

echo "interactive"
  "$ROOT/vsc2zed" -q --interactive >/dev/null 2>&1
  is "--quiet and --interactive are refused" "$?" "1"
  "$ROOT/vsc2zed" --interactive </dev/null >/dev/null 2>&1
  is "without a terminal it refuses" "$?" "1"

  if command -v python3 >/dev/null 2>&1; then
    itmp="$(mktemp -d)"
    drive() { DRIVE_INPUT="$1" python3 "$ROOT/tests/drive_tty.py" "$ROOT/vsc2zed" -o "$itmp" --interactive 2>&1; }

    out="$(drive 'q')"
    is "q quits without writing"     "$(ls "$itmp" | wc -l)" "0"
    is "q says so"                   "$(grep -c 'nothing to do' <<<"$out")" "1"

    out="$(drive '1|1,3|n')"
    is "picking an extension and a subset converts just those" \
       "$(jq -r '[.themes[].name] | join("/")' "$itmp/mini-suite.json")" "Mini Dark/Mini Contrast"
    is "declining the install writes to --out instead" \
       "$(grep -c "wrote $itmp/mini-suite.json" <<<"$out")" "1"

    rm -f "$itmp"/*.json
    out="$(drive '1||n')"
    is "an empty answer means all of them" \
       "$(jq -r '.themes | length' "$itmp/mini-suite.json")" "3"

    rm -rf "${itmp:?}"/*
    xdg="$(mktemp -d)"
    out="$(XDG_CONFIG_HOME="$xdg" DRIVE_INPUT='2||y' python3 "$ROOT/tests/drive_tty.py" "$ROOT/vsc2zed" --interactive 2>&1)"
    is "accepting the install writes into Zed's themes directory" \
       "$(basename "$(ls "$xdg/zed/themes")")" "localized-name.json"
    is "and does not also leave a copy in ./themes" \
       "$(ls "$itmp" | wc -l)" "0"
    rm -rf -- "$itmp" "$xdg"
  else
    echo "  skip interactive pty tests (no python3)"
  fi
  unset VSC2ZED_EXTENSION_ROOTS

# The checked-in Night Wolf export is the end-to-end regression test: it is the
# only artifact produced from a real published extension.
if [ -f "$ROOT/themes/night-wolf.json" ]; then
  echo "night wolf export"
    nw="$ROOT/themes/night-wolf.json"
    is "eight themes"       "$(jq -r '.themes | length' "$nw")" "8"
    is "all dark"           "$(jq -r '[.themes[].appearance] | unique | join(",")' "$nw")" "dark"
    is "names came from the manifest, not the placeholder" \
       "$(jq -r '[.themes[].name | select(. == "themename")] | length' "$nw")" "0"
    is "four distinct backgrounds" \
       "$(jq -r '[.themes[].style["editor.background"]] | unique | length' "$nw")" "4"
    is "italic variants are italic" \
       "$(jq -r '.themes[0].style.syntax.comment.font_style' "$nw")" "italic"
    is "no-italics variants are not" \
       "$(jq -r '.themes[1].style.syntax.comment.font_style' "$nw")" "null"
fi

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
