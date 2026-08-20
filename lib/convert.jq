# convert.jq - a pure function: one VS Code theme in, one Zed theme out.
#
#   jq -L lib --arg name "My Theme" -f lib/convert.jq theme.json
#
# Input is a VS Code color theme object with `include` already resolved and
# comments already stripped. Output is a single entry for a Zed theme family's
# `themes` array. No file access, no side effects, so it is testable by feeding
# it JSON and diffing the result.

include "mappings";

# ---------------------------------------------------------------- color ----

# "3f" -> 63. Assumes two hex digits.
def hexbyte($s):
  ($s | ascii_downcase | explode | map(if . >= 97 then . - 87 else . - 48 end))
  | (.[0] * 16 + .[1]);

# 63 -> "3f", clamped to a byte and rounded.
def tohex:
  (if . < 0 then 0 elif . > 255 then 255 else . end | . + 0.5 | floor) as $v
  | ("0123456789abcdef" | .[($v / 16 | floor):($v / 16 | floor) + 1])
  + ("0123456789abcdef" | .[($v % 16):($v % 16) + 1]);

# Any CSS hex shorthand -> "#rrggbbaa". Anything else -> null.
def norm_color:
  if type != "string" then null
  else
    (ascii_downcase | ltrimstr("#") | gsub("\\s"; "")) as $h
    | if ($h | test("^[0-9a-f]+$") | not) then null
      elif ($h | length) == 3 then "#" + ($h[0:1] * 2) + ($h[1:2] * 2) + ($h[2:3] * 2) + "ff"
      elif ($h | length) == 4 then "#" + ($h[0:1] * 2) + ($h[1:2] * 2) + ($h[2:3] * 2) + ($h[3:4] * 2)
      elif ($h | length) == 6 then "#" + $h + "ff"
      elif ($h | length) == 8 then "#" + $h
      else null
      end
  end;

def with_alpha($a): if . == null then null else .[0:7] + $a end;

# Composite a translucent color onto an opaque one, yielding an opaque result.
# Zed renders alpha correctly, but a few slots (borders, dim ANSI) look better
# pre-flattened than stacked over whatever happens to be behind them.
def over($bg):
  . as $fg
  | if $fg == null or $bg == null then $fg
    else
      (hexbyte($fg[7:9]) / 255) as $a
      | "#"
      + ((hexbyte($fg[1:3]) * $a + hexbyte($bg[1:3]) * (1 - $a)) | tohex)
      + ((hexbyte($fg[3:5]) * $a + hexbyte($bg[3:5]) * (1 - $a)) | tohex)
      + ((hexbyte($fg[5:7]) * $a + hexbyte($bg[5:7]) * (1 - $a)) | tohex)
      + "ff"
    end;

# ------------------------------------------------------------- palette ----

# The handful of colors every fallback chain in ui_map bottoms out at. Derived
# once so that a theme missing, say, `gitDecoration.addedResourceForeground`
# still gets a sensible green rather than a hole.
def palette($vs; $global):
  (($vs["editor.background"] // $global.background // "#1e1e1e") | norm_color) as $bg
  | (($vs["editor.foreground"] // $vs["foreground"] // $global.foreground // "#d4d4d4") | norm_color) as $fg
  | {
      bg: $bg,
      fg: $fg,
      accent:  (($vs["focusBorder"] // $vs["textLink.foreground"] // $vs["editorCursor.foreground"] // $fg) | norm_color),
      border:  (($vs["editorGroup.border"] // $vs["panel.border"] // $vs["contrastBorder"]
                 // ($fg | with_alpha("33") | over($bg))) | norm_color),
      red:     (($vs["terminal.ansiRed"]     // $vs["editorError.foreground"]        // "#f44747") | norm_color),
      green:   (($vs["terminal.ansiGreen"]   // $vs["editorGutter.addedBackground"]  // "#6a9955") | norm_color),
      yellow:  (($vs["terminal.ansiYellow"]  // $vs["editorWarning.foreground"]      // "#cca700") | norm_color),
      blue:    (($vs["terminal.ansiBlue"]    // $vs["textLink.foreground"]           // "#569cd6") | norm_color),
      magenta: (($vs["terminal.ansiMagenta"] // "#c586c0") | norm_color),
      cyan:    (($vs["terminal.ansiCyan"]    // "#4ec9b0") | norm_color)
    };

# ---------------------------------------------------------- ui resolve ----

# One token of the ui_map DSL. See lib/mappings.jq for the grammar.
def resolve_token($vs; $pal; $tok):
  ($tok | endswith("!")) as $flat
  | (if $flat then $tok[0:-1] else $tok end) as $t
  | (if ($t | test("@[0-9a-fA-F]{2}$")) then ($t[-2:] | ascii_downcase) else null end) as $alpha
  | (if $alpha then $t[0:-3] else $t end) as $key
  | (if ($key | startswith("#")) then $key
     elif ($key | startswith("$")) then $pal[$key[1:]]
     else $vs[$key]
     end) as $raw
  | ($raw | norm_color) as $c
  | if $c == null then null
    else ($c | if $alpha then with_alpha($alpha) else . end)
         | if $flat then over($pal.bg) else . end
    end;

def resolve_ui($vs; $pal):
  ui_map
  | with_entries(.value = (first(.value[] | resolve_token($vs; $pal; .) | values) // null))
  | with_entries(select(.value != null));

# ------------------------------------------------------------- syntax ----

# scope -> settings. Rules are merged in file order rather than replaced: a
# later rule that only sets `fontStyle` refines an earlier rule's `foreground`
# instead of erasing it, which is how VS Code resolves a scope with several
# matching rules. Night Wolf depends on this for `meta.function-call`, where the
# color and the italic arrive from two different rules.
def scope_index:
  reduce ((.tokenColors // [])[] | select(.settings != null)) as $r ({};
    ($r.settings | with_entries(select(.value != null and .value != ""))) as $set
    | reduce (
        $r.scope
        | if . == null then [] elif type == "string" then [.] else . end
        | map(tostring | split(",")) | flatten
        | map(gsub("^\\s+|\\s+$"; ""))
        | map(select(length > 0))
      )[] as $s (.; .[$s] = ((.[$s] // {}) + $set))
  );

# "a.b.c" -> ["a.b.c", "a.b", "a"], most specific first. Descendant selectors
# ("source.ts entity.name.type") only ever match themselves.
def scope_prefixes:
  . as $q
  | if ($q | test(" ")) then [$q]
    else ($q | split(".")) as $p | [range($p | length; 0; -1) | $p[0:.] | join(".")]
    end;

# Last resort when a theme only ever styles scopes narrower than the capture we
# are filling: a theme that colors `keyword.control.flow` but never `keyword`
# would otherwise leave Zed's `keyword` unstyled. Prefers the shortest, and so
# the most general, descendant.
def descendant_hit($idx; $scopes):
  [$idx | keys_unsorted[] | select(test(" ") | not)] as $keys
  | first(
      $scopes[] as $c
      | ($keys | map(select(startswith($c + "."))) | sort_by(length))[]?
      | $idx[.]
      | select(.foreground != null)
    ) // null;

# Color and font style are resolved separately. The color comes from the first
# candidate that defines one; the style may only come from that candidate or a
# more specific one, so a loose `string` italic never leaks onto a token that
# matched the tighter `string.quoted`.
def lookup_scopes($idx; $scopes):
  [ $scopes[] | scope_prefixes[] | $idx[.] | select(. != null) ] as $hits
  | ([ $hits | to_entries[] | select(.value.foreground != null) ][0]) as $fg_hit
  | (if $fg_hit == null then ($hits | length) else $fg_hit.key end) as $limit
  | ([ $hits[0:$limit + 1][] | select((.fontStyle // "") != "") ][0]) as $style_hit
  | if $fg_hit != null then
      { foreground: $fg_hit.value.foreground,
        background: $fg_hit.value.background,
        fontStyle: $style_hit.fontStyle }
    else
      descendant_hit($idx; $scopes) as $desc
      | if $desc != null then
          { foreground: $desc.foreground,
            background: $desc.background,
            fontStyle: ($style_hit.fontStyle // $desc.fontStyle) }
        elif $style_hit != null then { fontStyle: $style_hit.fontStyle }
        else null
        end
    end;

# semanticTokenColors values are either a bare color or an object.
def semantic_settings:
  if . == null then null
  elif type == "string" then { foreground: . }
  elif type == "object" then
    { foreground: .foreground,
      fontStyle: ([ (if .italic then "italic" else empty end),
                    (if .bold then "bold" else empty end),
                    (.fontStyle // empty) ] | join(" ")) }
  else null
  end;

# VS Code token settings -> Zed HighlightStyleContent, or null if it says nothing.
def to_highlight:
  if . == null then null
  else
    . as $s
    | ($s.fontStyle // "") as $fs
    | ($s.foreground | norm_color) as $color
    | ($s.background | norm_color) as $bgc
    | (if ($fs | test("italic")) then "italic"
       elif ($fs | test("oblique")) then "oblique"
       else null end) as $style
    | (if ($fs | test("bold")) then 700 else null end) as $weight
    | if $color == null and $bgc == null and $style == null and $weight == null then null
      else { color: $color, font_style: $style, font_weight: $weight }
           + (if $bgc == null then {} else { background_color: $bgc } end)
      end
  end;

def build_syntax($idx; $sem):
  syntax_map
  | with_entries(
      .key as $k
      | .value = (
          ( lookup_scopes($idx; .value)
            // first(semantic_map[$k][]? | $sem[.] | values | semantic_settings)
          ) | to_highlight
        )
    )
  | with_entries(select(.value != null));

# ------------------------------------------------------ players/accents ----

def build_players($vs; $pal):
  [ ($vs["editorCursor.foreground"] // $pal.accent),
    $pal.blue, $pal.green, $pal.magenta, $pal.yellow, $pal.red, $pal.cyan,
    ($vs["terminal.ansiBrightBlue"] // $pal.blue)
  ]
  | map(norm_color) | map(values)
  | (if length == 0 then [$pal.fg] else . end)
  | to_entries
  | map(
      .value as $c
      | { cursor: $c,
          background: $c,
          selection: (if .key == 0
                      then (($vs["editor.selectionBackground"] // ($c | with_alpha("3d"))) | norm_color)
                      else ($c | with_alpha("3d")) end) }
    );

def build_accents($vs; $pal):
  [ $vs["editorBracketHighlight.foreground1"], $vs["editorBracketHighlight.foreground2"],
    $vs["editorBracketHighlight.foreground3"], $vs["editorBracketHighlight.foreground4"],
    $vs["editorBracketHighlight.foreground5"], $vs["editorBracketHighlight.foreground6"] ]
  | map(norm_color) | map(values)
  | (if length == 0
     then [$pal.blue, $pal.green, $pal.yellow, $pal.red, $pal.magenta, $pal.cyan]
     else . end)
  | map(with_alpha("ff"));

# --------------------------------------------------------------- entry ----

def appearance_of($override):
  ($override // "") as $o
  | if $o == "dark" or $o == "light" then $o
    else ((.type // .uiTheme // "dark") | ascii_downcase
          | if . == "light" or . == "vs" or . == "hclight" or . == "hc-light"
            then "light" else "dark" end)
    end;

# Restore hierarchy where the source theme collapsed two roles onto one color.
def enforce_distinct($pal):
  reduce distinct_rules[] as $r (.;
    if .[$r.key] != null and .[$r.key] == .[$r.unlike]
    then .[$r.key] = (resolve_token({}; $pal; $r.use) // .[$r.key])
    else . end);

def theme_content($name; $appearance):
  . as $t
  | (.colors // {}) as $vs
  | (((.tokenColors // []) | map(select((.scope // "") == "")) | last | .settings) // {}) as $global
  | (.semanticTokenColors // {}) as $sem
  | palette($vs; $global) as $pal
  | (scope_index) as $idx
  | {
      name: $name,
      appearance: ($t | appearance_of($appearance)),
      style: ( (resolve_ui($vs; $pal) | enforce_distinct($pal))
             + { accents: build_accents($vs; $pal),
                 players: build_players($vs; $pal),
                 syntax:  build_syntax($idx; $sem) } )
    };

theme_content($name; $appearance)
