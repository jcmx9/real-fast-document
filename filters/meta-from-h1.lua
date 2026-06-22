--- Aufgabenlisten (`- [ ]` / `- [x]`) rendern in Pandoc als normale Liste,
--- deren Items mit ☐/☒ beginnen. Mit dem Quadrat-Marker des Templates gäbe das
--- zwei Marker (Bullet + Checkbox). Solche Listen daher ohne Listen-Marker
--- setzen, sodass nur die Checkbox bleibt.
local task_boxes = { ["☐"] = true, ["☒"] = true, ["☑"] = true }

local function starts_with_checkbox(item)
  local first = item[1]
  if not first or not first.content then return false end
  local inl = first.content[1]
  if inl == nil or inl.t ~= "Str" then return false end
  -- Praefix-Vergleich (nicht exakt): toleriert, wenn Pandoc die Box mit dem
  -- folgenden Text/Leerzeichen in *einem* Str zusammenfasst.
  for box in pairs(task_boxes) do
    if inl.text:sub(1, #box) == box then return true end
  end
  return false
end

-- Liste mit mindestens einem Task-Item ohne Listen-Marker rendern, sodass Tasks
-- nur die Checkbox zeigen. In gemischten Listen (normale Punkte + Tasks) behalten
-- die Nicht-Task-Items ihr Quadrat: dazu den Template-Marker (#rfd-list-marker)
-- manuell voranstellen. Frueher verlangte der Filter, dass *alle* Items Tasks
-- sind -> gemischte Listen behielten faelschlich den Marker (Quadrat + Checkbox).
function BulletList(el)
  local has_task = false
  for _, item in ipairs(el.content) do
    if starts_with_checkbox(item) then
      has_task = true
      break
    end
  end
  if not has_task then return nil end

  for _, item in ipairs(el.content) do
    if not starts_with_checkbox(item) then
      local first = item[1]
      if first and first.content then
        table.insert(first.content, 1, pandoc.RawInline("typst", "#rfd-list-marker "))
      end
    end
  end

  return {
    pandoc.RawBlock("typst", "#[\n#set list(marker: none)"),
    el,
    pandoc.RawBlock("typst", "]"),
  }
end

--- Nicht-ladbare Bilder entfernen. Typst hat bewusst keinen Netzwerkzugriff
--- (`network access is not supported`); ein `image("https://…")` würde den Build
--- hart abbrechen. Da wir offline bauen, werden solche Bilder vor der Typst-Stufe
--- verworfen. Betroffen sind http(s)-URLs, protokoll-relative URLs (`//host/…`)
--- und `data:`-URIs (die Typst als Dateipfad nähme und nicht fände). Lokale
--- Bilder bleiben unberührt.
local function is_unloadable(src)
  if src == nil then return false end
  return src:match("^https?://") ~= nil
    or src:match("^//") ~= nil
    or src:match("^data:") ~= nil
end

-- Ein entferntes Bild hinterlässt einen markierten Platzhalter (leerer Span mit
-- dieser Klasse), damit ein Container, der *nur* daraus bestand, gezielt mit-
-- entfernt werden kann – ohne zufällig leere Container anzufassen, die so im
-- Quelltext standen.
local REMOVED_MARK = "rfd-removed-remote-image"

function Image(el)
  if is_unloadable(el.src) then
    io.stderr:write(
      "Hinweis: Remote-Bild entfernt (Typst hat keinen Netzzugriff): "
      .. el.src .. "\n"
    )
    return pandoc.Span({}, pandoc.Attr("", { REMOVED_MARK }))
  end
  return nil
end

-- true, wenn die Inlines ausschließlich aus entfernten Bild-Platzhaltern (und
-- Leerraum) bestehen – der Container trug also nichts außer Remote-Bildern.
local function only_removed(inlines)
  local saw = false
  for _, x in ipairs(inlines) do
    if x.t == "Span" and x.classes:includes(REMOVED_MARK) then
      saw = true
    elseif x.t == "Space" or x.t == "SoftBreak" or x.t == "LineBreak" then
      -- Leerraum ignorieren
    else
      return false
    end
  end
  return saw
end

--- Ein Link, der nur ein entferntes Remote-Bild umschloss (häufiges
--- `[![alt](img)](url)`-Muster), bliebe sonst als leerer Geister-Link zurück.
function Link(el)
  if only_removed(el.content) then return {} end
  return nil
end

--- Ein Absatz, der nur aus entfernten Remote-Bildern bestand, würde sonst als
--- leerer Block toten vertikalen Raum erzeugen – ebenfalls entfernen.
function Para(el)
  if only_removed(el.content) then return {} end
  return nil
end

function Plain(el)
  if only_removed(el.content) then return {} end
  return nil
end

--- Ein allein stehendes `![untertitel](url)` rendert Pandoc als `Figure` (Bild +
--- Untertitel). Ist das Bild ein entferntes Remote-Bild, leert sich der Figure-
--- Inhalt (der innere Plain ist oben schon weg) – sonst bliebe der Untertitel als
--- Geister-Abbildung stehen. Dann die ganze Abbildung inkl. Untertitel entfernen.
function Figure(el)
  if #el.content == 0 then return {} end
  return nil
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

  -- Übrig gebliebene Platzhalter restlos entfernen: ein Remote-Bild mitten in
  -- einem sonst nicht-leeren Absatz hinterlässt einen Marker, der hier (nach dem
  -- Haupt-Traversal) spurlos getilgt wird.
  doc = doc:walk {
    Span = function(s)
      if s.classes:includes(REMOVED_MARK) then return {} end
      return nil
    end,
  }

  return doc
end
