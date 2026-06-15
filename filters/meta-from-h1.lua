--- Setzt den Dokumenttitel (PDF/A-Pflicht) aus dem H1 und erzwingt, dass H1
--- genau einmal vorkommt – H1 ist der Dokumenttitel.
function Pandoc(doc)
  local h1 = {}
  for _, block in ipairs(doc.blocks) do
    if block.t == "Header" and block.level == 1 then
      h1[#h1 + 1] = block
    end
  end

  if #h1 > 1 then
    error(
      "Mehr als ein H1 gefunden (" .. #h1 .. "). "
      .. "H1 ist der Dokumenttitel und darf nur einmal vorkommen; "
      .. "nutze H2 fuer Kapitel."
    )
  end

  if doc.meta.title == nil and #h1 == 1 then
    doc.meta.title = pandoc.MetaInlines(h1[1].content)
  end

  return doc
end
