// Markdown-Vorverarbeitung VOR cmarker – reine String-Arbeit in Typst.
//
// Warum in Typst und nicht in build.sh (awk) / convert.ps1: so existiert jede
// Umformung genau EINMAL und gilt auf macOS, Linux und Windows identisch. Die
// Shell-Skripte parsen nur noch das Frontmatter und kümmern sich um Dateipfade.
//
// Alle Funktionen arbeiten zeilenweise und lassen Code-Blöcke (``` / ~~~)
// unangetastet (siehe code-mask).

#let blank(s) = s.trim() == ""

// Zeilen, die zu einem umzäunten Code-Block gehören (inkl. der Zaunzeilen).
// Ein Zaun ist ``` oder ~~~ (mind. 3, bis 3 Leerzeichen eingerückt); er endet
// an einem Zaun derselben Art, der mindestens so lang ist.
#let code-mask(lines) = {
  let mask = ()
  let fence = none
  for l in lines {
    let m = l.match(regex("^ {0,3}(`{3,}|~{3,})"))
    if fence == none {
      if m != none {
        fence = m.captures.at(0)
        mask.push(true)
      } else {
        mask.push(false)
      }
    } else {
      mask.push(true)
      let t = l.trim()
      if (m != none and m.captures.at(0).first() == fence.first()
          and m.captures.at(0).len() >= fence.len() and t.trim(fence.first()) == "") {
        fence = none
      }
    }
  }
  mask
}

// Führendes YAML-Frontmatter (--- … --- bzw. …) entfernen; CRLF -> LF.
#let strip-frontmatter(src) = {
  let lines = src.replace("\r\n", "\n").replace("\r", "\n").split("\n")
  if lines.len() > 0 and lines.first().trim(at: end) == "---" {
    for (i, l) in lines.enumerate() {
      if i > 0 and (l.trim(at: end) == "---" or l.trim(at: end) == "...") {
        return lines.slice(i + 1)
      }
    }
  }
  lines
}

// Pandoc-Definitionslisten (Begriff + Folgezeile ": Definition") in HTML <dl>
// übersetzen – cmarker kennt nur <dl>. Block-Form (Leerzeile nach <dd>), damit
// Inline-Markdown in der Definition rendert. Eingerückte Fortsetzungszeilen der
// Definition werden angehängt (sonst landen sie als Fließtext am linken Rand).
#let deflists(lines) = {
  let mask = code-mask(lines)
  let is-def(s) = s.match(regex("^:[ \t]+")) != none
  let n = lines.len()
  let out = ()
  let i = 0
  while i < n {
    let l = lines.at(i)
    if (not mask.at(i) and not blank(l) and not l.starts-with(":")
        and (i == 0 or blank(lines.at(i - 1)))
        and i + 1 < n and is-def(lines.at(i + 1))) {
      out.push("<dl>")
      while true {
        if (i + 1 >= n or blank(lines.at(i)) or lines.at(i).starts-with(":")
            or not is-def(lines.at(i + 1))) { break }
        let term = lines.at(i)
        let def = lines.at(i + 1).replace(regex("^:[ \t]+"), "")
        let k = i + 2
        while (k < n and not blank(lines.at(k)) and lines.at(k).match(regex("^[ \t]+")) != none
               and lines.at(k).match(regex("^[ \t]*:[ \t]+")) == none) {
          def += " " + lines.at(k).trim(at: start)
          k += 1
        }
        out += ("<dt>" + term + "</dt>", "<dd>", "", def, "</dd>")
        i = k
        let j = i
        while j < n and blank(lines.at(j)) { j += 1 }
        if j + 1 < n and not lines.at(j).starts-with(":") and is-def(lines.at(j + 1)) { i = j }
      }
      out.push("</dl>")
      continue
    }
    out.push(l)
    i += 1
  }
  out
}

// Gesamte Vorverarbeitung: Markdown-String für cmarker.
#let preprocess(src) = {
  let lines = strip-frontmatter(src)
  lines = deflists(lines)
  lines.join("\n") + "\n"
}
