--- Setzt die Dokument-Metadaten `title` auf das erste H1, falls nicht gesetzt.
--- PDF/A verlangt einen Dokumenttitel; so ist dieser garantiert vorhanden.
function Pandoc(doc)
  if doc.meta.title == nil then
    for _, block in ipairs(doc.blocks) do
      if block.t == "Header" and block.level == 1 then
        doc.meta.title = pandoc.MetaInlines(block.content)
        break
      end
    end
  end
  return doc
end
