# lib/interactive.sh - find themes already installed locally, and pick one.
#
# Sourced by vsc2zed only for --interactive and --list-local, so the conversion
# path never depends on it. Everything here ends by setting the same variables a
# command line would have set: `sources`, `ONLY`, `out_dir`, `do_install`.
# Interactive mode fills in arguments. It is not a second pipeline.

# Where VS Code and its forks keep user-installed extensions. Same path on
# Linux, macOS, and Windows-with-Git-Bash, because the extensions directory
# hangs off $HOME rather than the platform's application data directory.
#
# Set VSC2ZED_EXTENSION_ROOTS to override. Entries are separated by ':' and are
# either a bare path or "Label|path".
extension_roots() {
  if [ -n "${VSC2ZED_EXTENSION_ROOTS:-}" ]; then
    local entry
    # The trailing newline matters: without it `read` drops the last entry.
    printf '%s\n' "$VSC2ZED_EXTENSION_ROOTS" | tr ':' '\n' | while IFS= read -r entry; do
      [ -n "$entry" ] || continue
      case "$entry" in
        *'|'*) printf '%s\n' "$entry" ;;
        *)
          # ~/.vscode/extensions should read as "vscode", so name it after the
          # parent when the directory itself is just called "extensions".
          label="$(basename -- "$entry")"
          [ "$label" = "extensions" ] && label="$(basename -- "$(dirname -- "$entry")")"
          printf '%s|%s\n' "${label#.}" "$entry"
          ;;
      esac
    done
    return
  fi

  cat <<ROOTS
VS Code|$HOME/.vscode/extensions
VS Code Insiders|$HOME/.vscode-insiders/extensions
VSCodium|$HOME/.vscode-oss/extensions
Cursor|$HOME/.cursor/extensions
Windsurf|$HOME/.windsurf/extensions
Trae|$HOME/.trae/extensions
VS Code (Flatpak)|$HOME/.var/app/com.visualstudio.code/data/vscode/extensions
VSCodium (Flatpak)|$HOME/.var/app/com.vscodium.codium/data/codium/extensions
Cursor (Flatpak)|$HOME/.var/app/co.anysphere.cursor/data/cursor/extensions
ROOTS
}

# Every locally installed extension that contributes at least one theme, as
# tab-separated "editor, name, theme count, path".
discover_extensions() {
  local app root dir summary count name
  while IFS='|' read -r app root; do
    [ -d "$root" ] || continue
    for dir in "$root"/*/; do
      dir="${dir%/}"
      [ -f "$dir/package.json" ] || continue
      summary="$(strip_jsonc "$dir/package.json" 2>/dev/null | jq -r '
        ((.contributes.themes // []) | length) as $n
        | if $n == 0 then empty else "\($n)\t\(.displayName // .name // "")" end' 2>/dev/null)" || continue
      [ -n "$summary" ] || continue
      count="${summary%%$'\t'*}"
      name="$(resolve_nls_name "$dir" "${summary#*$'\t'}")"
      [ -n "$name" ] || name="$(basename -- "$dir")"
      printf '%s\t%s\t%s\t%s\n' "$app" "$name" "$count" "$dir"
    done
  done < <(extension_roots)
}

list_local() {
  local rows found=0 app name count dir
  rows="$(discover_extensions)"
  if [ -z "$rows" ]; then
    log "No VS Code or Cursor theme extensions found. Searched:"
    while IFS='|' read -r app root; do log "  $root"; done < <(extension_roots)
    return 0
  fi
  printf '%-20s %-38s %s\n' "EDITOR" "EXTENSION" "THEMES"
  while IFS=$'\t' read -r app name count dir; do
    printf '%-20s %-38s %s\n' "$app" "$name" "$count"
    found=$((found + 1))
  done <<<"$rows"
  log ""
  log "$found extension(s). Convert one with: vsc2zed <path>, or vsc2zed --interactive"
}

# ------------------------------------------------------------- prompting ----

_say()  { printf '%s\n' "$*" >&2; }
_ask()  { local r; printf '%s' "$1" >&2; read -r r || r=""; printf '%s' "$r"; }

# "1,3 5" over a list of `max` items -> sorted unique valid indices.
_parse_selection() {
  local input="${1//,/ }" max="$2" tok
  for tok in $input; do
    case "$tok" in ''|*[!0-9]*) continue ;; esac
    if [ "$tok" -ge 1 ] && [ "$tok" -le "$max" ]; then printf '%s\n' "$tok"; fi
  done | sort -un
}

_choose_extension() {
  local rows lines=() app name count dir i choice picked
  rows="$(discover_extensions)"

  if [ -n "$rows" ]; then
    while IFS= read -r line; do lines+=("$line"); done <<<"$rows"
    _say ""
    _say "Found ${#lines[@]} theme extension(s) installed locally:"
    _say ""
    i=0
    for line in "${lines[@]}"; do
      i=$((i + 1))
      IFS=$'\t' read -r app name count dir <<<"$line"
      printf '  %2d  %-18s %-36s %s theme(s)\n' "$i" "$app" "$name" "$count" >&2
    done
    _say ""
    _say "  m   fetch from the marketplace instead"
    _say "  p   give a path to a .vsix, folder, or theme file"
    _say "  q   quit"
    _say ""
  else
    _say ""
    _say "No locally installed theme extensions found."
    _say ""
    _say "  m   fetch from the marketplace"
    _say "  p   give a path to a .vsix, folder, or theme file"
    _say "  q   quit"
    _say ""
  fi

  while :; do
    choice="$(_ask '> ')"
    case "$choice" in
      q|Q|"") return 1 ;;
      m|M)
        choice="$(_ask 'publisher.extension: ')"
        [ -n "$choice" ] || continue
        printf '%s\n' "$choice"; return 0 ;;
      p|P)
        choice="$(_ask 'path: ')"
        choice="${choice/#\~/$HOME}"
        [ -e "$choice" ] || { _say "no such path: $choice"; continue; }
        printf '%s\n' "$choice"; return 0 ;;
      *)
        picked="$(_parse_selection "$choice" "${#lines[@]}" | head -1)"
        [ -n "$picked" ] || { _say "pick a number, or m, p, or q"; continue; }
        IFS=$'\t' read -r app name count dir <<<"${lines[$((picked - 1))]}"
        printf '%s\n' "$dir"; return 0 ;;
    esac
  done
}

# Offer the themes inside an already-resolved extension, and echo the labels to
# keep. Echoes nothing for "all", which leaves ONLY empty.
_choose_themes() {
  local ext="$1" labels=() line i choice n
  while IFS= read -r line; do [ -n "$line" ] && labels+=("$line"); done \
    < <(strip_jsonc "$ext/package.json" | jq -r '.contributes.themes[]?.label // empty')

  [ "${#labels[@]}" -gt 1 ] || return 0

  _say ""
  _say "This extension has ${#labels[@]} themes:"
  i=0
  for line in "${labels[@]}"; do
    i=$((i + 1))
    printf '  %2d  %s\n' "$i" "$line" >&2
  done
  _say ""
  choice="$(_ask "Install all ${#labels[@]}, or pick some (e.g. 1,3)? [all] ")"
  case "$choice" in ""|a|A|all|ALL) return 0 ;; esac

  while IFS= read -r n; do printf '%s\n' "${labels[$((n - 1))]}"; done \
    < <(_parse_selection "$choice" "${#labels[@]}")
}

# Fills in `sources`, `ONLY`, `out_dir`, and `do_install` for main.
prompt_interactive() {
  [ -t 0 ] || die "--interactive needs a terminal"

  _say "vsc2zed $VERSION"
  local chosen ext label reply zed_dir
  chosen="$(_choose_extension)" || { _say "nothing to do"; return 1; }

  # Resolve once here and hand main the unpacked directory, so choosing a
  # marketplace extension does not download it a second time.
  ext="$(resolve_source "$chosen" "$STAGE")"
  sources=("$ext")

  ONLY=()
  while IFS= read -r label; do [ -n "$label" ] && ONLY+=("$label"); done \
    < <(_choose_themes "$ext")

  zed_dir="$(zed_themes_dir)"
  _say ""
  reply="$(_ask "Install into $zed_dir? [Y/n] ")"
  case "$reply" in
    n|N|no|NO) do_install=0 ;;
    *)         do_install=1 ;;
  esac
  _say ""
  return 0
}
