--- Aufgabenlisten (`- [ ]` / `- [x]`) rendern in Pandoc als normale Liste,
--- deren Items mit ☐/☒ beginnen. Mit dem Quadrat-Marker des Templates gäbe das
--- zwei Marker (Bullet + Checkbox). Solche Listen daher ohne Listen-Marker
--- setzen, sodass nur die Checkbox bleibt.
local task_boxes = { ["☐"] = true, ["☒"] = true, ["☑"] = true }

local function starts_with_checkbox(item)
  local first = item[1]
  if not first or not first.content then return false end
  local inl = first.content[1]
  return inl ~= nil and inl.t == "Str" and task_boxes[inl.text] == true
end

function BulletList(el)
  for _, item in ipairs(el.content) do
    if not starts_with_checkbox(item) then return nil end
  end
  -- alle Items sind Task-Items -> Liste ohne Marker rendern (nur Checkbox)
  return {
    pandoc.RawBlock("typst", "#[\n#set list(marker: none)"),
    el,
    pandoc.RawBlock("typst", "]"),
  }
end

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
