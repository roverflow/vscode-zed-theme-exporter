# mappings.jq - the data tables. No logic lives here.
#
# Both tables map one Zed key to an ordered list of candidates. The first
# candidate that resolves to a real color wins, so the lists read as
# "ideal source, then progressively looser fallbacks".
#
# UI candidates are tokens in the small DSL that convert.jq resolves:
#
#   editor.background   a VS Code workbench color key
#   $accent             a slot in the derived base palette
#   #ff00ff             a literal
#   ...@40              take that color at alpha 0x40
#   ...!                composite the result onto the background, making it opaque
#
# Suffixes combine and are read left to right: `foreground@40!` means
# "the foreground at 25% alpha, flattened onto the background".

def ui_map:
{
  # Chrome and surfaces
  "background":                       ["editorGroupHeader.tabsBackground", "editor.background", "$bg"],
  "surface.background":               ["sideBar.background", "editorWidget.background", "$bg"],
  "elevated_surface.background":      ["editorWidget.background", "editorSuggestWidget.background", "menu.background", "dropdown.background", "$bg"],
  "panel.background":                 ["panel.background", "sideBar.background", "$bg"],
  "status_bar.background":            ["statusBar.background", "$bg"],
  "title_bar.background":             ["titleBar.activeBackground", "$bg"],
  "title_bar.inactive_background":    ["titleBar.inactiveBackground", "titleBar.activeBackground", "$bg"],
  "toolbar.background":               ["breadcrumb.background", "editor.background", "$bg"],
  "tab_bar.background":               ["editorGroupHeader.tabsBackground", "$bg"],
  "tab.active_background":            ["tab.activeBackground", "editor.background", "$bg"],
  "tab.inactive_background":          ["tab.inactiveBackground", "editorGroupHeader.tabsBackground", "$bg"],

  # Borders
  "border":                           ["editorGroup.border", "panel.border", "contrastBorder", "$border"],
  "border.variant":                   ["tab.border", "sideBar.border", "$border"],
  "border.focused":                   ["focusBorder", "$accent"],
  "border.selected":                  ["focusBorder", "$accent"],
  "border.transparent":               ["#00000000"],
  "border.disabled":                  ["editorGroup.border@80", "$border@80"],
  "pane_group.border":                ["editorGroup.border", "$border"],
  "pane.focused_border":              ["focusBorder", "$accent"],
  "panel.focused_border":             ["focusBorder", "$accent"],
  "panel.indent_guide":               ["tree.indentGuidesStroke", "editorIndentGuide.background", "$border"],
  "panel.indent_guide_active":        ["editorIndentGuide.activeBackground", "$accent"],
  "panel.indent_guide_hover":         ["editorIndentGuide.activeBackground", "$accent"],

  # Interactive elements
  "element.background":               ["input.background", "editorWidget.background", "$bg"],
  "element.hover":                    ["list.hoverBackground", "toolbar.hoverBackground", "$fg@14!"],
  "element.active":                   ["list.activeSelectionBackground", "toolbar.activeBackground", "$fg@1f!"],
  "element.selected":                 ["list.activeSelectionBackground", "$accent@33!"],
  "element.disabled":                 ["input.background", "editorWidget.background", "$bg"],
  "ghost_element.background":         ["#00000000"],
  "ghost_element.hover":              ["list.hoverBackground", "$fg@14!"],
  "ghost_element.active":             ["list.activeSelectionBackground", "$fg@1f!"],
  "ghost_element.selected":           ["list.activeSelectionBackground", "$accent@33!"],
  "ghost_element.disabled":           ["#00000000"],
  "drop_target.background":           ["list.dropBackground@66", "editorGroup.dropBackground@66", "$accent@40"],

  # Text
  "text":                             ["foreground", "editor.foreground", "$fg"],
  "text.muted":                       ["tab.inactiveForeground", "descriptionForeground", "$fg@b3!"],
  "text.placeholder":                 ["input.placeholderForeground", "$fg@80!"],
  "text.disabled":                    ["disabledForeground", "$fg@80!"],
  "text.accent":                      ["textLink.foreground", "$accent"],
  "link_text.hover":                  ["textLink.activeForeground", "textLink.foreground", "$accent"],

  # Icons
  "icon":                             ["icon.foreground", "foreground", "$fg"],
  "icon.muted":                       ["tab.inactiveForeground", "descriptionForeground", "$fg@b3!"],
  "icon.disabled":                    ["disabledForeground", "$fg@80!"],
  "icon.placeholder":                 ["tab.inactiveForeground", "descriptionForeground", "$fg@b3!"],
  "icon.accent":                      ["textLink.foreground", "$accent"],

  # Editor
  "editor.foreground":                ["editor.foreground", "$fg"],
  "editor.background":                ["editor.background", "$bg"],
  "editor.gutter.background":         ["editorGutter.background", "editor.background", "$bg"],
  "editor.subheader.background":      ["editorGroupHeader.tabsBackground", "$bg"],
  "editor.active_line.background":    ["editor.lineHighlightBackground", "$fg@0d"],
  "editor.highlighted_line.background": ["editor.rangeHighlightBackground", "editor.lineHighlightBackground", "$fg@0d"],
  "editor.line_number":               ["editorLineNumber.foreground", "$fg@59!"],
  "editor.active_line_number":        ["editorLineNumber.activeForeground", "$fg"],
  "editor.hover_line_number":         ["editorLineNumber.activeForeground", "$fg@b3!"],
  "editor.invisible":                 ["editorWhitespace.foreground", "$fg@40!"],
  "editor.wrap_guide":                ["editorRuler.foreground", "editorIndentGuide.background", "$fg@1a"],
  "editor.active_wrap_guide":         ["editorIndentGuide.activeBackground", "$fg@33"],
  "editor.indent_guide":              ["editorIndentGuide.background", "$fg@1a"],
  "editor.indent_guide_active":       ["editorIndentGuide.activeBackground", "$fg@33"],
  "editor.document_highlight.read_background":    ["editor.wordHighlightBackground", "editor.selectionHighlightBackground", "$accent@1a"],
  "editor.document_highlight.write_background":   ["editor.wordHighlightStrongBackground", "editor.wordHighlightBackground", "$accent@26"],
  "editor.document_highlight.bracket_background": ["editorBracketMatch.background", "editorBracketMatch.border@33", "$accent@26"],
  "search.match_background":          ["editor.findMatchHighlightBackground", "editor.findMatchBackground", "$accent@40"],
  "search.active_match_background":   ["editor.findMatchBackground", "editor.findMatchHighlightBackground", "$accent@66"],

  # Scrollbar
  "scrollbar.thumb.background":       ["scrollbarSlider.background", "$fg@33"],
  "scrollbar.thumb.hover_background": ["scrollbarSlider.hoverBackground", "$fg@4d"],
  "scrollbar.thumb.border":           ["scrollbarSlider.background", "$fg@33"],
  "scrollbar.track.background":       ["#00000000"],
  "scrollbar.track.border":           ["editorGroup.border", "$border"],

  # Terminal
  "terminal.background":              ["terminal.background", "editor.background", "$bg"],
  "terminal.foreground":              ["terminal.foreground", "editor.foreground", "$fg"],
  "terminal.bright_foreground":       ["terminal.ansiBrightWhite", "editor.foreground", "$fg"],
  "terminal.dim_foreground":          ["terminal.ansiWhite@a6!", "$fg@a6!"],
  "terminal.ansi.background":         ["terminal.background", "editor.background", "$bg"],
  "terminal.ansi.black":              ["terminal.ansiBlack", "$bg"],
  "terminal.ansi.bright_black":       ["terminal.ansiBrightBlack", "terminal.ansiBlack", "$bg"],
  "terminal.ansi.dim_black":          ["terminal.ansiBrightBlack@a6!", "terminal.ansiBlack", "$bg"],
  "terminal.ansi.red":                ["terminal.ansiRed", "$red"],
  "terminal.ansi.bright_red":         ["terminal.ansiBrightRed", "terminal.ansiRed", "$red"],
  "terminal.ansi.dim_red":            ["terminal.ansiRed@a6!", "$red@a6!"],
  "terminal.ansi.green":              ["terminal.ansiGreen", "$green"],
  "terminal.ansi.bright_green":       ["terminal.ansiBrightGreen", "terminal.ansiGreen", "$green"],
  "terminal.ansi.dim_green":          ["terminal.ansiGreen@a6!", "$green@a6!"],
  "terminal.ansi.yellow":             ["terminal.ansiYellow", "$yellow"],
  "terminal.ansi.bright_yellow":      ["terminal.ansiBrightYellow", "terminal.ansiYellow", "$yellow"],
  "terminal.ansi.dim_yellow":         ["terminal.ansiYellow@a6!", "$yellow@a6!"],
  "terminal.ansi.blue":               ["terminal.ansiBlue", "$blue"],
  "terminal.ansi.bright_blue":        ["terminal.ansiBrightBlue", "terminal.ansiBlue", "$blue"],
  "terminal.ansi.dim_blue":           ["terminal.ansiBlue@a6!", "$blue@a6!"],
  "terminal.ansi.magenta":            ["terminal.ansiMagenta", "$magenta"],
  "terminal.ansi.bright_magenta":     ["terminal.ansiBrightMagenta", "terminal.ansiMagenta", "$magenta"],
  "terminal.ansi.dim_magenta":        ["terminal.ansiMagenta@a6!", "$magenta@a6!"],
  "terminal.ansi.cyan":               ["terminal.ansiCyan", "$cyan"],
  "terminal.ansi.bright_cyan":        ["terminal.ansiBrightCyan", "terminal.ansiCyan", "$cyan"],
  "terminal.ansi.dim_cyan":           ["terminal.ansiCyan@a6!", "$cyan@a6!"],
  "terminal.ansi.white":              ["terminal.ansiWhite", "$fg"],
  "terminal.ansi.bright_white":       ["terminal.ansiBrightWhite", "terminal.ansiWhite", "$fg"],
  "terminal.ansi.dim_white":          ["terminal.ansiWhite@a6!", "$fg@a6!"],

  # Diagnostics and status
  "error":                            ["editorError.foreground", "errorForeground", "$red"],
  "error.background":                 ["editorError.foreground@1a", "$red@1a"],
  "error.border":                     ["editorError.foreground@40!", "$red@40!"],
  "warning":                          ["editorWarning.foreground", "$yellow"],
  "warning.background":               ["editorWarning.foreground@1a", "$yellow@1a"],
  "warning.border":                   ["editorWarning.foreground@40!", "$yellow@40!"],
  "info":                             ["editorInfo.foreground", "textLink.foreground", "$blue"],
  "info.background":                  ["editorInfo.foreground@1a", "$blue@1a"],
  "info.border":                      ["editorInfo.foreground@40!", "$blue@40!"],
  "hint":                             ["editorInlayHint.foreground", "editorCodeLens.foreground", "$blue@b3!"],
  "hint.background":                  ["editorCodeLens.foreground@1a", "$blue@1a"],
  "hint.border":                      ["editorCodeLens.foreground@40!", "$blue@40!"],
  "success":                          ["editorGutter.addedBackground", "terminal.ansiGreen", "$green"],
  "success.background":               ["editorGutter.addedBackground@1a", "$green@1a"],
  "success.border":                   ["editorGutter.addedBackground@40!", "$green@40!"],
  "predictive":                       ["editorGhostText.foreground", "editorCodeLens.foreground", "$fg@59!"],
  "predictive.background":            ["editorCodeLens.foreground@1a", "$fg@1a"],
  "predictive.border":                ["editorCodeLens.foreground@40!", "$fg@40!"],
  "unreachable":                      ["editorUnnecessaryCode.border", "tab.inactiveForeground", "$fg@80!"],
  "unreachable.background":           ["$fg@1a"],
  "unreachable.border":               ["$fg@40!"],

  # Version control
  "created":                          ["gitDecoration.addedResourceForeground", "editorGutter.addedBackground", "$green"],
  "created.background":               ["gitDecoration.addedResourceForeground@1a", "$green@1a"],
  "created.border":                   ["gitDecoration.addedResourceForeground@40!", "$green@40!"],
  "modified":                         ["gitDecoration.modifiedResourceForeground", "editorGutter.modifiedBackground", "$yellow"],
  "modified.background":              ["gitDecoration.modifiedResourceForeground@1a", "$yellow@1a"],
  "modified.border":                  ["gitDecoration.modifiedResourceForeground@40!", "$yellow@40!"],
  "deleted":                          ["gitDecoration.deletedResourceForeground", "editorGutter.deletedBackground", "$red"],
  "deleted.background":               ["gitDecoration.deletedResourceForeground@1a", "$red@1a"],
  "deleted.border":                   ["gitDecoration.deletedResourceForeground@40!", "$red@40!"],
  "conflict":                         ["gitDecoration.conflictingResourceForeground", "editorWarning.foreground", "$yellow"],
  "conflict.background":              ["gitDecoration.conflictingResourceForeground@1a", "$yellow@1a"],
  "conflict.border":                  ["gitDecoration.conflictingResourceForeground@40!", "$yellow@40!"],
  "ignored":                          ["gitDecoration.ignoredResourceForeground", "descriptionForeground", "$fg@80!"],
  "ignored.background":               ["gitDecoration.ignoredResourceForeground@1a", "$fg@1a"],
  "ignored.border":                   ["gitDecoration.ignoredResourceForeground@40!", "$border"],
  "renamed":                          ["gitDecoration.untrackedResourceForeground", "textLink.foreground", "$blue"],
  "renamed.background":               ["gitDecoration.untrackedResourceForeground@1a", "$blue@1a"],
  "renamed.border":                   ["gitDecoration.untrackedResourceForeground@40!", "$blue@40!"],
  "hidden":                           ["gitDecoration.ignoredResourceForeground", "descriptionForeground", "$fg@80!"],
  "hidden.background":                ["gitDecoration.ignoredResourceForeground@1a", "$fg@1a"],
  "hidden.border":                    ["editorGroup.border", "$border"],
  "version_control.added":            ["gitDecoration.addedResourceForeground", "editorGutter.addedBackground", "$green"],
  "version_control.modified":         ["gitDecoration.modifiedResourceForeground", "editorGutter.modifiedBackground", "$yellow"],
  "version_control.deleted":          ["gitDecoration.deletedResourceForeground", "editorGutter.deletedBackground", "$red"],
  "version_control.renamed":          ["gitDecoration.untrackedResourceForeground", "$blue"],
  "version_control.conflict":         ["gitDecoration.conflictingResourceForeground", "$yellow"],
  "version_control.ignored":          ["gitDecoration.ignoredResourceForeground", "$fg@80!"],
  "version_control.word_added":       ["diffEditor.insertedTextBackground", "editorGutter.addedBackground@40"],
  "version_control.word_deleted":     ["diffEditor.removedTextBackground", "editorGutter.deletedBackground@40"],
  "version_control.conflict_marker.ours":   ["merge.currentContentBackground", "editorGutter.addedBackground@1a"],
  "version_control.conflict_marker.theirs": ["merge.incomingContentBackground", "textLink.foreground@1a"]
};

# Zed syntax captures, from the list in
# https://zed.dev/docs/extensions/languages#syntax-highlighting, plus the extra
# captures Zed's own bundled themes define (diff.*, selector.*, punctuation.markup).
#
# Values are TextMate scopes. Lookup walks each scope's dotted prefixes, so
# listing "keyword.control" also picks up a theme rule written for "keyword".
def syntax_map:
{
  "attribute":              ["entity.other.attribute-name", "meta.attribute", "meta.decorator"],
  "boolean":                ["constant.language.boolean", "constant.language"],
  "comment":                ["comment", "punctuation.definition.comment"],
  "comment.doc":            ["comment.block.documentation", "comment.documentation", "comment.block"],
  "constant":               ["constant.other", "constant.character", "variable.other.constant", "constant"],
  "constant.builtin":       ["constant.language", "support.constant"],
  "constructor":            ["entity.name.function.constructor", "entity.name.type.class", "entity.name.class", "meta.class"],
  "diff.plus":              ["markup.inserted.diff", "markup.inserted"],
  "diff.minus":             ["markup.deleted.diff", "markup.deleted"],
  "embedded":               ["meta.embedded", "meta.jsx.children", "text.html"],
  "emphasis":               ["markup.italic", "italic"],
  "emphasis.strong":        ["markup.bold", "bold"],
  "enum":                   ["entity.name.type.enum", "support.type.enum", "entity.name.type"],
  "function":               ["entity.name.function", "support.function", "meta.function-call"],
  "function.builtin":       ["support.function.builtin", "support.function"],
  "function.call":          ["meta.function-call entity.name.function", "meta.function-call", "entity.name.function"],
  "function.decorator":     ["entity.name.function.decorator", "meta.decorator", "punctuation.decorator"],
  "function.definition":    ["entity.name.function", "meta.function"],
  "function.method":        ["entity.name.function.member", "meta.method.declaration", "entity.name.function"],
  "function.special.definition": ["entity.name.function.preprocessor", "entity.name.function"],
  "hint":                   ["comment"],
  "keyword":                ["keyword.control", "keyword", "storage.type", "storage.modifier"],
  "label":                  ["entity.name.label", "constant.other.label", "meta.object-literal.key"],
  "link_text":              ["string.other.link", "markup.underline.link.image", "markup.underline.link"],
  "link_uri":               ["markup.underline.link", "string.other.link"],
  "namespace":              ["entity.name.namespace", "entity.name.type.namespace", "entity.name.scope-resolution", "support.other.namespace"],
  "number":                 ["constant.numeric", "constant.character.numeric"],
  "operator":               ["keyword.operator", "punctuation.separator.key-value"],
  "predictive":             ["comment"],
  "preproc":                ["meta.preprocessor", "keyword.control.directive", "keyword.other.preprocessor"],
  "primary":                ["variable", "source"],
  "property":               ["variable.other.property", "support.type.property-name", "meta.object-literal.key", "variable.other.object.property", "variable.other.member"],
  "punctuation":            ["punctuation", "meta.brace"],
  "punctuation.bracket":    ["punctuation.definition.bracket", "meta.brace", "punctuation.section", "punctuation"],
  "punctuation.delimiter":  ["punctuation.separator", "punctuation.terminator", "meta.delimiter", "punctuation"],
  "punctuation.list_marker":["punctuation.definition.list.begin.markdown", "markup.list", "punctuation.definition.list", "punctuation"],
  "punctuation.markup":     ["punctuation.definition.heading", "punctuation.definition.bold", "punctuation"],
  "punctuation.special":    ["punctuation.definition.template-expression", "punctuation.section.embedded", "keyword.control.interpolation", "punctuation"],
  "selector":               ["entity.name.tag.css", "entity.other.attribute-name.class.css", "entity.name.tag"],
  "selector.pseudo":        ["entity.other.attribute-name.pseudo-class.css", "entity.other.attribute-name.pseudo-element.css", "entity.other.attribute-name"],
  "string":                 ["string.quoted", "string"],
  "string.escape":          ["constant.character.escape", "constant.character"],
  "string.regex":           ["string.regexp", "string.regex"],
  "string.special":         ["string.other", "string.unquoted", "string"],
  "string.special.symbol":  ["constant.other.symbol", "string.unquoted", "constant.other"],
  "tag":                    ["entity.name.tag", "meta.tag"],
  "tag.doctype":            ["entity.name.tag.doctype", "entity.name.tag", "meta.tag.sgml.doctype"],
  "text.literal":           ["markup.inline.raw", "markup.raw", "string"],
  "title":                  ["markup.heading", "entity.name.section"],
  "type":                   ["entity.name.type", "support.type", "storage.type", "support.class"],
  "type.builtin":           ["support.type.builtin", "support.class.builtin", "support.type"],
  "type.interface":         ["entity.name.type.interface", "keyword.interface", "entity.name.type"],
  "type.super":             ["entity.other.inherited-class", "entity.name.type"],
  "variable":               ["variable", "variable.other.readwrite", "variable.other"],
  "variable.member":        ["variable.other.property", "variable.other.member", "variable.other.object.property"],
  "variable.parameter":     ["variable.parameter", "variable.other.parameter"],
  "variable.special":       ["variable.language", "variable.language.this", "variable.other.constant"],
  "variant":                ["entity.name.type.enum", "constant.other.enum", "entity.name.type"]
};

# Zed reads these from `semanticTokenColors` when no TextMate rule matched.
def semantic_map:
{
  "comment":            ["comment"],
  "constructor":        ["class"],
  "enum":               ["enum"],
  "function":           ["function"],
  "function.method":    ["method"],
  "keyword":            ["keyword"],
  "number":             ["number"],
  "property":           ["property"],
  "string":             ["string"],
  "string.regex":       ["regexp"],
  "type":               ["type", "class"],
  "type.builtin":       ["class.defaultLibrary"],
  "type.interface":     ["interface"],
  "variable":           ["variable"],
  "variable.parameter": ["parameter"]
};

# A theme is free to give two VS Code keys the same value: Night Wolf sets
# `descriptionForeground` equal to `foreground`, for instance. Zed relies on
# these pairs differing to show hierarchy, so where a mapping collapses, fall
# back to a derived tone. `unlike` names another Zed key, already resolved.
def distinct_rules:
[
  { key: "text.muted",         unlike: "text",   use: "$fg@b3!" },
  { key: "text.placeholder",   unlike: "text",   use: "$fg@80!" },
  { key: "text.disabled",      unlike: "text",   use: "$fg@80!" },
  { key: "icon.muted",         unlike: "icon",   use: "$fg@b3!" },
  { key: "icon.placeholder",   unlike: "icon",   use: "$fg@b3!" },
  { key: "icon.disabled",      unlike: "icon",   use: "$fg@80!" },
  { key: "unreachable",        unlike: "text",   use: "$fg@80!" },
  { key: "ignored",            unlike: "text",   use: "$fg@80!" },
  { key: "hidden",             unlike: "text",   use: "$fg@80!" },
  { key: "border.variant",     unlike: "border", use: "$border@80!" },
  { key: "editor.line_number", unlike: "editor.foreground", use: "$fg@59!" }
];
