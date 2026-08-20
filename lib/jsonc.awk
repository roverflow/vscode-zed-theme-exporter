# jsonc.awk - JSONC to strict JSON.
#
# VS Code reads theme files with a permissive parser, so published themes may
# carry // and /* */ comments and trailing commas. jq will not. This strips
# both without touching anything inside a string literal.
#
# Only runs when jq has already failed to parse the file, so it trades speed
# for being easy to follow.

BEGIN { pc_line = -1 }

{
  line = $0
  o = ""
  n = length(line)
  i = 1

  while (i <= n) {
    c = substr(line, i, 1)

    if (inblock) {
      if (c == "*" && substr(line, i + 1, 1) == "/") { inblock = 0; i += 2 } else i++
      continue
    }

    if (instr) {
      o = o c
      if (c == "\\") { i++; o = o substr(line, i, 1); i++ }
      else { if (c == "\"") instr = 0; i++ }
      continue
    }

    if (c == "\"")                                    { instr = 1; o = o c; i++; continue }
    if (c == "/" && substr(line, i + 1, 1) == "/")    { break }
    if (c == "/" && substr(line, i + 1, 1) == "*")    { inblock = 1; i += 2; continue }

    # A comma is only trailing if the next structural character closes the
    # container, which may be several lines later. Remember where it was.
    if (c == ",") { pc_line = nb; pc_pos = length(o) + 1; o = o c; i++; continue }

    if (c == "}" || c == "]") {
      if (pc_line >= 0) {
        if (pc_line == nb) o = substr(o, 1, pc_pos - 1) " " substr(o, pc_pos + 1)
        else buf[pc_line] = substr(buf[pc_line], 1, pc_pos - 1) " " substr(buf[pc_line], pc_pos + 1)
        pc_line = -1
      }
      o = o c; i++; continue
    }

    if (c != " " && c != "\t" && c != "\r") pc_line = -1
    o = o c
    i++
  }

  buf[nb++] = o
}

END { for (j = 0; j < nb; j++) print buf[j] }
