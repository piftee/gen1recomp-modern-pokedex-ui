-- Gen 2's Pokedex owns the 251-species list, search, area and Unown views.
-- This wrapper keeps those controllers intact and adds the Modern Pokedex
-- theme/status treatment to every native view.
return function(mod)
  local cutoutSource = assert(mod:read("gen2_portrait_cutouts.lua"))
  local PortraitCutouts = assert(load(cutoutSource, "@" .. mod.path
    .. "/gen2_portrait_cutouts.lua"))()
  local PokedexMenu = require("src.ui.gen2.PokedexMenu")
  local Chrome = require("src.ui.gen2.Chrome")
  local Font = require("src.render.Font")
  local GbcPalette = require("src.render.GbcPalette")
  local Assets = require("src.render.Assets")
  local Palettes = require("src.world.gen2.Palettes")
  local TypeChart = require("src.battle.TypeChart")

  local INK_BLACK = { 0, 0, 0 }
  local INK_WHITE = { 1, 1, 1 }
  local INK_LIGHT = { 0.48, 0.90, 0.94 }
  local RED = { 0.98, 0.10, 0.08 }
  local ORANGE = { 1.00, 0.48, 0.06 }
  local BLUE = { 0.17, 0.43, 0.91 }
  local BLUE_DARK = { 0.05, 0.15, 0.54 }
  local PAPER = { 0.96, 0.97, 0.98 }
  local PAPER_ALT = { 0.82, 0.84, 0.87 }
  local SELECTED = { 0.18, 0.20, 0.24 }

  local TYPE_COLORS = {
    normal = { 144 / 255, 152 / 255, 162 / 255 },
    fighting = { 206 / 255, 63 / 255, 107 / 255 },
    flying = { 143 / 255, 168 / 255, 222 / 255 },
    poison = { 171 / 255, 106 / 255, 200 / 255 },
    ground = { 217 / 255, 119 / 255, 70 / 255 },
    rock = { 201 / 255, 182 / 255, 139 / 255 },
    bug = { 144 / 255, 192 / 255, 44 / 255 },
    ghost = { 82 / 255, 105 / 255, 173 / 255 },
    fire = { 254 / 255, 156 / 255, 85 / 255 },
    water = { 77 / 255, 144 / 255, 214 / 255 },
    grass = { 101 / 255, 188 / 255, 94 / 255 },
    electric = { 244 / 255, 210 / 255, 59 / 255 },
    psychic = { 249 / 255, 113 / 255, 119 / 255 },
    ice = { 115 / 255, 206 / 255, 191 / 255 },
    dragon = { 9 / 255, 109 / 255, 195 / 255 },
    dark = { 91 / 255, 82 / 255, 101 / 255 },
    steel = { 91 / 255, 142 / 255, 161 / 255 },
    fairy = { 236 / 255, 144 / 255, 231 / 255 },
  }

  local function setColor(color, alpha)
    love.graphics.setColor(color[1], color[2], color[3], alpha or 1)
  end

  local function inkPalette(color)
    color = color or INK_BLACK
    local ink = {}
    for i = 1, 3 do
      local value = color[i] or 0
      ink[i] = math.floor((value <= 1 and value * 255 or value) + 0.5)
    end
    return {
      { 255, 255, 255 },
      { math.floor((255 + ink[1]) / 2), math.floor((255 + ink[2]) / 2),
        math.floor((255 + ink[3]) / 2) },
      { math.floor(ink[1] / 2), math.floor(ink[2] / 2),
        math.floor(ink[3] / 2) }, ink,
    }
  end

  local function fitText(text, maxWidth)
    text = tostring(text or "")
    if not maxWidth or Font.width(text) <= maxWidth then return text end
    local budget = math.max(0, maxWidth - Font.width("."))
    if Font.split and Font.spansFitting then
      local spans = Font.split(text)
      local count = Font.spansFitting(spans, budget)
      return count > 0 and text:sub(1, spans[count].to) .. "." or ""
    end
    while #text > 0 and Font.width(text) > budget do text = text:sub(1, -2) end
    return text .. "."
  end

  local function drawInk(text, x, y, maxWidth, color)
    text = fitText(text, maxWidth)
    local palette, drawGlyph, finish = Chrome.paletteGlyphs(
      inkPalette(color), false, true)
    if not palette then
      love.graphics.setColor(0, 0, 0, 1)
      Font.draw(text, math.floor(x), math.floor(y))
      return Font.width(text)
    end
    local pen = math.floor(x)
    for _, code in ipairs(Font.encode(text)) do
      drawGlyph(code, pen, math.floor(y))
      pen = pen + Font.advanceOf(code)
    end
    finish()
    return pen - math.floor(x)
  end

  local function drawInkRight(text, right, y, maxWidth, color)
    text = fitText(text, maxWidth)
    local width = Font.width(text)
    drawInk(text, right - width, y, width, color)
  end

  local function drawInkCentered(text, x, y, width, color)
    text = fitText(text, width)
    drawInk(text, x + math.floor((width - Font.width(text)) / 2), y,
      width, color)
  end

  local function chamfer(mode, x, y, w, h, cut)
    cut = math.max(0, math.min(cut or 0, math.floor(math.min(w, h) / 2)))
    if cut == 0 or not love.graphics.polygon then
      love.graphics.rectangle(mode, x, y, w, h)
      return
    end
    love.graphics.polygon(mode, {
      x + cut, y, x + w - cut, y, x + w, y + cut,
      x + w, y + h - cut, x + w - cut, y + h,
      x + cut, y + h, x, y + h - cut, x, y + cut,
    })
  end

  local function colorForType(typeId)
    local key = tostring(typeId or "normal"):lower():gsub("_type$", "")
    return TYPE_COLORS[key] or TYPE_COLORS.normal
  end

  local function typeColor(menu, species)
    local def = species and menu.pokemon and menu.pokemon[species]
    local types = def and def.types or {}
    return colorForType(types[1]), types
  end

  local function typeName(menu, typeId)
    local types = menu.data and menu.data.type_chart
      and menu.data.type_chart.types or {}
    local record = types[typeId]
    local name = record and record.name
    if not name and type(TypeChart.displayName) == "function" then
      local ok, value = pcall(TypeChart.displayName, typeId, menu.data)
      if ok then name = value end
    end
    return tostring(name or typeId or "---"):upper()
  end

  local function screenWidth(menu)
    return menu.modernPokedexWideWidth or 160
  end

  local function installWideDraw(menu, drawPanel)
    menu.drawWidescreen = function(self, winW, winH)
      local G = love.graphics
      local scale = math.max(1, math.floor(math.min(winH / 144, winW / 160)))
      local width = math.max(160, math.min(640, math.floor(winW / scale)))
      local ox = math.floor((winW - width * scale) / 2)
      local oy = math.floor((winH - 144 * scale) / 2)
      setColor({ 0.95, 0.95, 0.98 })
      G.rectangle("fill", 0, 0, winW, winH)
      G.push()
      G.translate(ox, oy)
      G.scale(scale, scale)
      self.modernPokedexLastWideWidth = width
      self.modernPokedexWideWidth = width
      drawPanel(self)
      self.modernPokedexWideWidth = nil
      G.pop()
      G.setColor(1, 1, 1, 1)
    end
  end

  local function drawHeader(menu, title, showCount)
    local G = love.graphics
    local width = screenWidth(menu)
    setColor(RED)
    G.rectangle("fill", 0, 0, width, 18)
    setColor(ORANGE)
    G.rectangle("fill", 0, 16, width, 2)
    title = title or "POKéDEX"
    local _, caught = menu:totals()
    if title == "POKéDEX" then
      drawInk(title, 4, 5, 74, INK_WHITE)
      drawInkRight(("C %03d/%03d"):format(caught,
        menu.modernDexCount or #(menu.rows or {})), width - 4, 5, 76, INK_WHITE)
    else
      drawInk(title, 4, 5, 112, INK_WHITE)
      if showCount ~= false then
        drawInkRight(("C%d"):format(caught), width - 4, 5, 24, INK_WHITE)
      end
    end
  end

  local function drawFooter(menu, left, right)
    local G = love.graphics
    local width = screenWidth(menu)
    setColor(BLUE)
    G.rectangle("fill", 0, 132, width, 12)
    drawInk(left or "A ACTIONS", 4, 134, math.floor(width / 2) - 6,
      INK_WHITE)
    drawInkRight(right or "B BACK", width - 4, 134,
      math.floor(width / 2) - 6, INK_LIGHT)
  end

  local function drawBackdrop(menu)
    local G = love.graphics
    local width = screenWidth(menu)
    setColor({ 0.95, 0.95, 0.98 })
    G.rectangle("fill", 0, 0, width, 144)
    setColor({ 0.75, 0.78, 0.95 })
    for x = -144, width, 16 do
      G.line(x, 18, x + 112, 132)
      G.line(x + 112, 18, x, 132)
    end
  end

  local PIC_PAD = { [7] = { 0, 0 }, [6] = { 1, 1 }, [5] = { 1, 2 } }

  -- Crystal supplies both coloured and pre-baked monochrome frames. Its
  -- image predicate also recognizes animated frames without a filename;
  -- a species flag alone could exempt an unrelated/native replacement.
  local function drawPortrait(image, colors, body, def)
    local provider = mod.find and mod.find("crystal_animated_sprites_with_shiny_visuals")
    local api = provider and provider.exports
    local authored = api and type(api.isCrystalImage) == "function" and api.isCrystalImage(image)
    -- Assets loads static pictures through ImageData, so those Images have
    -- no filename for Crystal's predicate. Match the exact registered source.
    if not authored and def and def.trueColor and def.spriteFront then
      local ok, source = pcall(Assets.image, def.spriteFront)
      authored = ok and source == image
    end
    if authored then
      local shader = love.graphics.getShader()
      love.graphics.setShader()
      body()
      love.graphics.setShader(shader)
    elseif colors and GbcPalette.available() then
      GbcPalette.with(colors, body)
    else
      body()
    end
  end

  -- Native drawPic first paints a 56x56 cartridge-paper tile block. Modern
  -- Pokedex panels already provide the type-coloured face, so draw only the
  -- transparent sprite pixels and let that face show through behind them.
  local function drawPanelPic(menu, row, x, y, ownColors)
    local image, colors
    if row and row.seen then
      image = menu:picFor(row.species)
      colors = ownColors and menu.palettes
        and Palettes.monColors(menu.palettes, row.species)
        or menu.gfx and menu.gfx.questionMarkPalette
    else
      image = menu:questionMark()
      colors = menu.gfx and menu.gfx.questionMarkPalette
    end
    if not image then return end
    local tiles = math.floor(image:getWidth() / 8)
    local pad = PIC_PAD[tiles] or PIC_PAD[7]
    love.graphics.setColor(1, 1, 1, 1)
    local function body()
      love.graphics.draw(image, x + pad[1] * 8, y + pad[2] * 8)
    end
    drawPortrait(image, colors, body, row and row.seen
      and menu.pokemon and menu.pokemon[row.species])
  end

  local function drawList(menu)
    local G = love.graphics
    local width = screenWidth(menu)
    local wide = width >= 240
    local listW = wide and math.max(150, math.floor(width * 0.58)) or 100
    local previewX = listW + 4
    local previewW = width - previewX - 2
    drawBackdrop(menu)
    drawHeader(menu, "POKéDEX")
    for visible = 1, 7 do
      local i = visible + (menu.scroll or 0)
      local row = menu.rows[i]
      local y = 19 + (visible - 1) * 16
      local selected = i == menu.index
      setColor(selected and SELECTED or (visible % 2 == 0 and PAPER_ALT or PAPER))
      chamfer("fill", 2, y, listW, 14, 2)
      local ink = selected and INK_WHITE or INK_BLACK
      if row then
        if row.caught then
          setColor({ 0.44, 0.74, 0.14 })
          G.rectangle("fill", 6, y + 5, 5, 5)
        elseif row.seen then
          setColor({ 0.58, 0.61, 0.66 })
          G.rectangle("line", 6.5, y + 5.5, 4, 4)
        end
        drawInk(("%03d"):format(row.dex or i), 15, y + 3, 24, ink)
        -- Leave two clear logical pixels after the three fixed-width digits.
        -- The old x=37 origin intruded into the number's 24px text cell, so
        -- entries such as 155 CYNDAQUIL appeared to run together at scale.
        local nameX = 41
        drawInk(row.seen and menu:monName(row.species) or "-----", nameX,
          y + 3, listW - nameX - 4, ink)
      end
    end

    local row = menu:current()
    local species = row and row.species
    local face, types = typeColor(menu, species)
    setColor(row and row.seen and face or { 0.70, 0.72, 0.75 })
    chamfer("fill", previewX, 19, previewW, 111, 3)
    if row then
      local picX = previewX + math.max(0, math.floor((previewW - 56) / 2))
      drawPanelPic(menu, row, picX, 23, true)
      drawInk(("No.%03d"):format(row.dex or 0), previewX + 5, 83,
        previewW - 10,
        row.seen and INK_BLACK or { 0.35, 0.35, 0.37 })
      drawInkCentered(row.seen and menu:monName(species) or "-----",
        previewX + 3, 95, previewW - 6,
        row.seen and INK_WHITE or INK_BLACK)
      if row.seen then
        drawInk(tostring(types[1] or "---"):upper(), previewX + 5, 108,
          previewW - 10, INK_BLACK)
        if types[2] and types[2] ~= types[1] then
          drawInk(tostring(types[2]):upper(), previewX + 5, 118,
            previewW - 10, INK_BLACK)
        end
      end
    end
    drawFooter(menu, "A DATA", "SEL OPTION")
  end

  local function descriptionLines(text, width)
    local out = {}
    for part in (tostring(text or ""):gsub("<NEXT>", "\n") .. "\n")
        :gmatch("(.-)\n") do
      for _, line in ipairs(Chrome.wrap(part, width)) do out[#out + 1] = line end
    end
    return out
  end

  local function evolutionTarget(edge)
    if type(edge) ~= "table" then return nil end
    -- Gen 2's extractor calls the destination `into`; Gen 1 content and a
    -- handful of cross-generation mods use `species`. Supporting both keeps
    -- the family view attached to the merged data rather than to a hard-coded
    -- table of the original 251.
    return edge.into or edge.species
  end

  local function speciesId(key, def)
    return type(def) == "table" and (def.id or key) or key
  end

  local function evolutionFamily(menu, species)
    if not species then return {} end
    menu.modernGen2FamilyCache = menu.modernGen2FamilyCache or {}
    local cached = menu.modernGen2FamilyCache[species]
    if cached then return cached end

    local pokemon = menu.pokemon or (menu.data and menu.data.pokemon) or {}
    local parents = {}
    for key, def in pairs(pokemon) do
      local parentSpecies = speciesId(key, def)
      for _, edge in ipairs(type(def) == "table" and def.evolutions or {}) do
        local child = evolutionTarget(edge)
        if child and pokemon[child] then
          parents[child] = parents[child] or {}
          parents[child][#parents[child] + 1] = {
            species = parentSpecies, def = def, edge = edge,
          }
        end
      end
    end
    -- A mod can technically make two species converge on one evolution.
    -- Prefer the lowest Pokédex number so the chosen root is deterministic.
    for _, choices in pairs(parents) do
      table.sort(choices, function(a, b)
        local ad = type(a.def) == "table" and a.def.dex or math.huge
        local bd = type(b.def) == "table" and b.def.dex or math.huge
        if ad ~= bd then return ad < bd end
        return tostring(a.species) < tostring(b.species)
      end)
    end

    local root, walked = species, {}
    while parents[root] and parents[root][1] and not walked[root] do
      walked[root] = true
      root = parents[root][1].species
    end

    local family, queue, seen = {}, {
      { species = root, depth = 0, parent = nil },
    }, {}
    while #queue > 0 do
      local member = table.remove(queue, 1)
      local def = pokemon[member.species]
      if def and not seen[member.species] then
        seen[member.species] = true
        member.def = def
        family[#family + 1] = member
        for _, edge in ipairs(def.evolutions or {}) do
          local child = evolutionTarget(edge)
          if child and pokemon[child] and not seen[child] then
            queue[#queue + 1] = {
              species = child, depth = member.depth + 1,
              parent = { species = member.species, def = def, edge = edge },
            }
          end
        end
      end
    end
    -- Bad or partial mod data should still leave the selected species usable.
    if #family == 0 and pokemon[species] then
      family[1] = { species = species, def = pokemon[species], depth = 0 }
    end
    -- Keep generations in evolution order while making branches predictable.
    -- This puts Pichu ahead of Pikachu despite its later National Dex number,
    -- but orders Eevee's five same-stage branches by their familiar dex order.
    table.sort(family, function(a, b)
      if a.depth ~= b.depth then return a.depth < b.depth end
      local ad = type(a.def) == "table" and a.def.dex or math.huge
      local bd = type(b.def) == "table" and b.def.dex or math.huge
      if ad ~= bd then return ad < bd end
      return tostring(a.species) < tostring(b.species)
    end)
    for _, member in ipairs(family) do
      menu.modernGen2FamilyCache[member.species] = family
    end
    return family
  end

  local function itemName(menu, id)
    local item = id and menu.data and menu.data.items and menu.data.items[id]
    return tostring(item and item.name or id or "ITEM"):gsub("_", " ")
  end

  local function evolutionLabel(menu, parent)
    if not parent then return "BASIC SPECIES" end
    local edge = parent.edge or {}
    local method = tostring(edge.method or "")
    if method == "EVOLVE_LEVEL" or method == "LEVEL" then
      return ("EVOLVES AT LV%d"):format(tonumber(edge.level) or 1)
    elseif method == "EVOLVE_ITEM" or method == "ITEM" then
      return "USE " .. itemName(menu, edge.item)
    elseif method == "EVOLVE_TRADE" or method == "TRADE" then
      if edge.item then return "TRADE: " .. itemName(menu, edge.item) end
      return "EVOLVES BY TRADE"
    elseif method == "EVOLVE_HAPPINESS" or method == "HAPPINESS" then
      local time = tostring(edge.time or "ANYTIME"):upper()
      if time == "MORNDAY" or time == "DAY" then
        return "HAPPINESS, DAY"
      elseif time == "NITE" or time == "NIGHT" then
        return "HAPPINESS, NIGHT"
      end
      return "HIGH HAPPINESS"
    elseif method == "EVOLVE_STAT" or method == "STAT" then
      local comparison = ({
        ATK_GT_DEF = "ATTACK HIGHER", ATK_LT_DEF = "DEFENSE HIGHER",
        ATK_EQ_DEF = "ATK = DEF",
      })[edge.comparison] or tostring(edge.comparison or "STATS")
          :gsub("_", " ")
      return ("LV%d: %s"):format(tonumber(edge.level) or 1, comparison)
    end
    local readable = method:gsub("^EVOLVE_", ""):gsub("_", " ")
    if readable == "" then readable = "EVOLUTION" end
    if edge.level then
      return ("LV%d: %s"):format(tonumber(edge.level) or 1, readable)
    end
    return readable
  end

  -- Wide rows carry a compact condition beside every known family member;
  -- the complete wording remains at the bottom for the current selection.
  local function evolutionShortLabel(menu, parent)
    if not parent then return "BASIC" end
    local edge = parent.edge or {}
    local method = tostring(edge.method or "")
    if method == "EVOLVE_LEVEL" or method == "LEVEL" then
      return ("LV%d"):format(tonumber(edge.level) or 1)
    elseif method == "EVOLVE_ITEM" or method == "ITEM" then
      return itemName(menu, edge.item)
    elseif method == "EVOLVE_TRADE" or method == "TRADE" then
      return edge.item and ("TRADE " .. itemName(menu, edge.item)) or "TRADE"
    elseif method == "EVOLVE_HAPPINESS" or method == "HAPPINESS" then
      local time = tostring(edge.time or "ANYTIME"):upper()
      if time == "MORNDAY" or time == "DAY" then return "HAPPY DAY" end
      if time == "NITE" or time == "NIGHT" then return "HAPPY NIGHT" end
      return "HAPPINESS"
    elseif method == "EVOLVE_STAT" or method == "STAT" then
      local comparison = ({
        ATK_GT_DEF = "ATK HIGH", ATK_LT_DEF = "DEF HIGH",
        ATK_EQ_DEF = "ATK=DEF",
      })[edge.comparison] or "STATS"
      return ("LV%d %s"):format(tonumber(edge.level) or 1, comparison)
    end
    return evolutionLabel(menu, parent)
  end

  local function familyKnown(menu, species)
    local dex = menu.save and menu.save.pokedex or {}
    if type(dex.seen) == "table" and dex.seen[species] then return true end
    if type(dex.caught) == "table" and dex.caught[species] then return true end
    if type(dex.owned) == "table" and dex.owned[species] then return true end
    for _, row in ipairs(menu.rows or {}) do
      if row.species == species then
        return row.seen == true or row.caught == true or row.owned == true
      end
    end
    return false
  end

  local function familySelection(menu)
    local row = menu:current()
    local species = row and row.species
    if menu.modernGen2FamilySpecies ~= species then
      menu.modernGen2FamilySpecies = species
      menu.modernGen2Family = evolutionFamily(menu, species)
      menu.modernGen2FamilyCursor = nil
      menu.modernGen2FamilyScroll = 0
    end
    local family = menu.modernGen2Family or {}
    local cursor = math.floor(tonumber(menu.modernGen2FamilyCursor) or 0)
    if cursor < 1 or cursor > #family then
      cursor = 1
      for index, member in ipairs(family) do
        if member.species == species then cursor = index break end
      end
    end
    menu.modernGen2FamilyCursor = cursor
    local visible = 6
    local scroll = math.max(0, math.floor(menu.modernGen2FamilyScroll or 0))
    if cursor <= scroll then
      scroll = cursor - 1
    elseif cursor > scroll + visible then
      scroll = cursor - visible
    end
    menu.modernGen2FamilyScroll = math.max(0,
      math.min(scroll, math.max(0, #family - visible)))
    return family, cursor, family[cursor]
  end

  local function machineSources(menu)
    if menu.modernGen2MachineSources then
      return menu.modernGen2MachineSources
    end
    local sources = {}
    for id, item in pairs(menu.data and menu.data.items or {}) do
      if type(item) == "table" then
        local move, kind, number
        if type(item.machine) == "table" then
          move = item.machine.move
          kind = tostring(item.machine.kind or "TM"):upper()
          number = tonumber(item.machine.number)
        elseif item.teaches then
          move = item.teaches
          local label = tostring(item.tmLabel or item.name or id or ""):upper()
          kind, number = label:match("^(TM)(%d+)$")
          if not kind then kind, number = label:match("^(HM)(%d+)$") end
          number = tonumber(number)
        end
        if move then
          kind = kind == "HM" and "HM" or "TM"
          local full = number and ("%s%02d"):format(kind, number)
            or tostring(item.tmLabel or item.name or id or kind):upper()
          sources[move] = {
            short = kind, full = full,
            kind = kind == "HM" and "hm" or "machine",
          }
        end
      end
    end

    -- Generated Gen 2 data also publishes its machine order. It is a useful
    -- fallback for mods that merge the compatibility list but omit item
    -- records: 50 TMs, seven HMs, then Crystal's three move tutors.
    local machineOrder = menu.pokemon and menu.pokemon.tmhmMoves
      or (menu.data and menu.data.pokemon and menu.data.pokemon.tmhmMoves)
      or (menu.data and menu.data.tmhmMoves)
    for index, move in ipairs(type(machineOrder) == "table"
        and machineOrder or {}) do
      if not sources[move] then
        if index <= 50 then
          sources[move] = { short = "TM", full = ("TM%02d"):format(index),
            kind = "machine" }
        elseif index <= 57 then
          sources[move] = { short = "HM",
            full = ("HM%02d"):format(index - 50), kind = "hm" }
        else
          sources[move] = { short = "TUTOR", full = "TUTOR",
            kind = "tutor" }
        end
      end
    end
    menu.modernGen2MachineSources = sources
    return sources
  end

  local function resetMoveSelection(menu)
    menu.modernGen2MoveSpecies = nil
    menu.modernGen2MoveRows = nil
    menu.modernGen2MoveCursor = 1
    menu.modernGen2MoveScroll = 0
    menu.modernGen2MoveDetail = false
  end

  local function moveRows(menu, species)
    species = species or (menu:current() and menu:current().species)
    if menu.modernGen2MoveSpecies == species
        and type(menu.modernGen2MoveRows) == "table" then
      return menu.modernGen2MoveRows
    end
    local pokemon = menu.pokemon or (menu.data and menu.data.pokemon) or {}
    local def = species and pokemon[species] or nil
    local moves = menu.data and menu.data.moves or {}
    local levelRows, rows, added = {}, {}, {}
    local ordinal = 0
    local function addLevel(level, move)
      if not move then return end
      level = tonumber(level) or 1
      local key = tostring(level) .. ":" .. tostring(move)
      if added[key] then return end
      ordinal = ordinal + 1
      levelRows[#levelRows + 1] = {
        source = tostring(level), sourceDetail = "LEVEL " .. tostring(level),
        level = level, id = move, kind = "level", ordinal = ordinal,
        move = moves[move],
      }
      added[key] = true
    end
    for _, move in ipairs(def and def.level1Moves or {}) do addLevel(1, move) end
    for _, learned in ipairs(def and def.levelMoves or {}) do
      if type(learned) == "table" then addLevel(learned.level, learned.move) end
    end
    -- A few cross-generation content mods retain the Gen 1 field name while
    -- running on Gen 2. Treat it as another source without duplicating rows.
    for _, learned in ipairs(def and def.learnset or {}) do
      if type(learned) == "table" then addLevel(learned.level, learned.move) end
    end
    table.sort(levelRows, function(a, b)
      if a.level ~= b.level then return a.level < b.level end
      return a.ordinal < b.ordinal
    end)
    for _, row in ipairs(levelRows) do rows[#rows + 1] = row end

    local sources = machineSources(menu)
    menu.modernGen2MoveMachineStart = #rows + 1
    for _, move in ipairs(def and def.tmhm or {}) do
      local source = sources[move] or {
        short = "TM/HM", full = "TM/HM", kind = "compatibility",
      }
      rows[#rows + 1] = {
        source = source.short, sourceDetail = source.full,
        id = move, kind = source.kind, move = moves[move],
      }
    end
    for _, move in ipairs(def and def.tutorMoves or {}) do
      rows[#rows + 1] = {
        source = "TUTOR", sourceDetail = "TUTOR", id = move,
        kind = "tutor", move = moves[move],
      }
    end

    menu.modernGen2MoveSpecies = species
    menu.modernGen2MoveRows = rows
    menu.modernGen2MoveCursor = math.max(1,
      math.min(math.floor(menu.modernGen2MoveCursor or 1),
        math.max(1, #rows)))
    menu.modernGen2MoveScroll = math.max(0,
      math.floor(menu.modernGen2MoveScroll or 0))
    menu.modernGen2MoveDetail = false
    return rows
  end

  local function moveListState(menu)
    local rows = moveRows(menu)
    local maxVisible = screenWidth(menu) >= 240 and 7 or 6
    local count = #rows
    menu.modernGen2MoveCursor = math.max(1,
      math.min(math.floor(menu.modernGen2MoveCursor or 1),
        math.max(1, count)))
    local maxScroll = math.max(0, count - maxVisible)
    menu.modernGen2MoveScroll = math.max(0,
      math.min(math.floor(menu.modernGen2MoveScroll or 0), maxScroll))
    if menu.modernGen2MoveCursor <= menu.modernGen2MoveScroll then
      menu.modernGen2MoveScroll = menu.modernGen2MoveCursor - 1
    elseif menu.modernGen2MoveCursor
        > menu.modernGen2MoveScroll + maxVisible then
      menu.modernGen2MoveScroll = menu.modernGen2MoveCursor - maxVisible
    end
    return rows, maxVisible
  end

  local function selectedMoveRow(menu)
    local rows = moveListState(menu)
    return rows[menu.modernGen2MoveCursor], rows
  end

  local function moveCategory(menu, move)
    if type(move) ~= "table" then return nil end
    local category = move.category
    if category == nil and move.power ~= nil then
      if tonumber(move.power) == 0 then
        category = "status"
      else
        local types = menu.data and menu.data.type_chart
          and menu.data.type_chart.types or {}
        local record = types[move.type]
        category = record and record.category
        if category == nil and type(TypeChart.category) == "function" then
          local ok, value = pcall(TypeChart.category, move.type)
          if ok then category = value end
        end
      end
    end
    category = category and tostring(category):upper() or nil
    if category == "PHYSICAL" then return "PHYS" end
    if category == "SPECIAL" then return "SPEC" end
    return category
  end

  local function moveDescription(menu, move)
    if type(move) ~= "table" then return nil end
    local supplied = move.description or move.desc or move.text
    if supplied == nil or tostring(supplied) == "" then return nil end
    if type(supplied) == "string" and menu.data and menu.data.text
        and menu.data.text[supplied] ~= nil then
      supplied = menu.data.text[supplied]
    end
    return tostring(supplied)
  end

  local function entryActions(menu)
    local row = menu:current()
    local family = evolutionFamily(menu, row and row.species)
    local actions = { "PAGE", "AREA" }
    if #family > 1 then actions[#actions + 1] = "EVO" end
    if #moveRows(menu, row and row.species) > 0 then
      actions[#actions + 1] = "MOVE"
    end
    actions[#actions + 1] = "CRY"
    actions[#actions + 1] = "PRNT"
    menu.modernGen2EntryActions = actions
    return actions
  end

  local function drawEntry(menu)
    local G = love.graphics
    local width = screenWidth(menu)
    local railW = width >= 196
      and math.min(92, math.max(60, math.floor(width * 0.31))) or 58
    local mainX = railW + 4
    local mainW = width - mainX - 2
    drawBackdrop(menu)
    local row = menu:current()
    if not row then return drawList(menu) end
    local entry = menu.dex and menu.dex.entries and menu.dex.entries[row.species]
      or {}
    drawHeader(menu, "POKéDEX DATA")
    local face, types = typeColor(menu, row.species)
    setColor(face)
    chamfer("fill", 2, 20, railW - 2, 110, 4)
    local picX = 3 + math.max(0, math.floor((railW - 58) / 2))
    drawPanelPic(menu, row, picX, 22, true)
    drawInkCentered(row.seen and menu:monName(row.species) or "-----",
      6, 82, railW - 12, INK_WHITE)
    drawInk(("No.%03d"):format(entry.dex or row.dex or 0), 7, 95,
      railW - 12,
      INK_BLACK)
    drawInk(tostring(types[1] or "---"):upper(), 7, 106,
      railW - 12, INK_BLACK)
    if types[2] and types[2] ~= types[1] then
      drawInk(tostring(types[2]):upper(), 7, 117, railW - 12, INK_BLACK)
    end

    setColor(PAPER)
    chamfer("fill", mainX, 20, mainW, 110, 3)
    drawInk(("No.%03d  %s"):format(entry.dex or row.dex or 0,
      menu:monName(row.species)), mainX + 6, 25, mainW - 12,
      { 0.38, 0.66, 0.10 })
    drawInk(tostring(entry.kind or "POKéMON"), mainX + 6, 36,
      mainW - 12, INK_BLACK)
    setColor(colorForType(types[1]))
    local typeW = math.min(64, math.max(39, math.floor((mainW - 17) / 2)))
    chamfer("fill", mainX + 6, 49, typeW, 14, 2)
    drawInkCentered(tostring(types[1] or "---"):upper(), mainX + 8, 52,
      typeW - 4,
      INK_WHITE)
    if types[2] and types[2] ~= types[1] then
      setColor(colorForType(types[2]))
      local type2X = mainX + 11 + typeW
      chamfer("fill", type2X, 49, typeW, 14, 2)
      drawInkCentered(tostring(types[2]):upper(), type2X + 2, 52,
        typeW - 4, INK_WHITE)
    end
    drawInk("HT " .. tostring(entry.height or "?"), mainX + 6, 66,
      mainW - 12, BLUE_DARK)
    drawInk("WT " .. tostring(entry.weight or "?") .. "lb",
      mainX + 6, 75, mainW - 12, BLUE_DARK)
    local description = menu.page == 2 and entry.text2 or entry.text
    for i, line in ipairs(descriptionLines(description,
        math.max(11, math.floor((mainW - 12) / 8)))) do
      if i > 6 then break end
      drawInk(line, mainX + 6, 84 + (i - 1) * 8, mainW - 12, INK_BLACK)
    end
    local actions = entryActions(menu)
    menu.entryAction = math.max(1,
      math.min(menu.entryAction or 1, #actions))
    setColor(BLUE)
    G.rectangle("fill", 0, 132, width, 12)
    local actionW = math.floor(width / #actions)
    local compactAction = {
      PAGE = "PG", AREA = "AR", EVO = "EV", MOVE = "MV",
      CRY = "CR", PRNT = "PR",
    }
    for i, label in ipairs(actions) do
      local x = (i - 1) * actionW
      if i == (menu.entryAction or 1) then
        setColor(BLUE_DARK)
        G.rectangle("fill", x + 1, 132, actionW - 2, 12)
      end
      local shown = Font.width(label) <= actionW - 2
        and label or compactAction[label] or label
      drawInkCentered(shown, x + 1, 134, actionW - 2,
        i == (menu.entryAction or 1) and INK_WHITE or INK_LIGHT)
    end
  end

  local function drawFamily(menu)
    local G = love.graphics
    local width = screenWidth(menu)
    drawBackdrop(menu)
    drawHeader(menu, "EVOLUTION", false)
    setColor(PAPER)
    chamfer("fill", 2, 20, width - 4, 110, 3)

    local family, cursor = familySelection(menu)
    drawInk(width >= 240 and "EVOLUTION FAMILY" or "FAMILY",
      8, 25, math.floor(width * 0.58), BLUE_DARK)
    drawInkRight(("%d SPECIES"):format(#family), width - 8, 25,
      math.floor(width * 0.38), BLUE_DARK)

    local scroll = menu.modernGen2FamilyScroll or 0
    local rowStep, rowHeight, rowStart = 13, 12, 37
    if #family <= 4 then
      rowStep, rowHeight, rowStart = 18, 14, 40
    elseif #family == 5 then
      rowStep, rowHeight, rowStart = 14, 13, 39
    end
    for visible = 1, 6 do
      local index = scroll + visible
      local member = family[index]
      if not member then break end
      local y = rowStart + (visible - 1) * rowStep
      local textY = y + math.floor((rowHeight - 8) / 2)
      local selected = index == cursor
      setColor(selected and SELECTED
        or (visible % 2 == 0 and PAPER_ALT or PAPER))
      chamfer("fill", 6, y, width - 12, rowHeight, 2)
      local face = typeColor(menu, member.species)
      setColor(face)
      G.rectangle("fill", 8, y + 2, 3, rowHeight - 4)
      local known = familyKnown(menu, member.species)
      local ink = selected and INK_WHITE or INK_BLACK
      local indent = math.min(3, tonumber(member.depth) or 0) * 5
      if indent > 0 then
        setColor(selected and INK_LIGHT or BLUE_DARK)
        G.line(14, textY, 14, textY + 4, 12 + indent, textY + 4)
      end
      local dex = member.def and member.def.dex
      drawInk(known and dex and ("%03d"):format(dex) or "---",
        14 + indent, textY, 27, ink)
      local name = known and (member.def.name or member.species) or "-----"
      local nameX = 43 + indent
      local nameW = width - nameX - 10
      local showConditions = width >= 232
      local conditionW = showConditions
        and math.min(112, math.floor((width - 22) * 0.43)) or 0
      if showConditions then
        nameW = math.max(24, width - nameX - conditionW - 18)
      end
      drawInk(name, nameX, textY, nameW, ink)
      if showConditions then
        drawInkRight(known and evolutionShortLabel(menu, member.parent)
            or "UNKNOWN", width - 10, textY, conditionW,
          selected and INK_LIGHT or BLUE_DARK)
      end
    end

    local selected = family[cursor]
    drawInkCentered(selected and familyKnown(menu, selected.species)
        and evolutionLabel(menu, selected.parent) or "UNDISCOVERED",
      8, 117, width - 16, BLUE_DARK)
    drawFooter(menu, width >= 240 and "UP/DOWN SELECT" or "U/D PICK",
      width >= 240 and "A DATA B BACK" or "A VIEW B")
  end

  local function drawMoves(menu)
    local G = love.graphics
    local width = screenWidth(menu)
    local wide = width >= 240
    drawBackdrop(menu)
    drawHeader(menu, "MOVE LIST", false)
    setColor(PAPER)
    chamfer("fill", 2, 20, width - 4, 110, 3)

    local rows, maxVisible = moveListState(menu)
    local hasTutor = false
    for _, row in ipairs(rows) do
      if row.kind == "tutor" then hasTutor = true break end
    end
    local heading = hasTutor
      and (wide and "LEVEL UP / TM-HM / TUTOR" or "LV/TM/HM/TUT")
      or (wide and "LEVEL UP / TM-HM" or "LV/TM-HM")
    drawInk(heading, 8, 25, width - 48, BLUE_DARK)
    drawInkRight("PP", width - 8, 25, 24, BLUE_DARK)

    local rowStep = wide and 13 or 14
    local rowY = 37
    for visible = 1, maxVisible do
      local index = (menu.modernGen2MoveScroll or 0) + visible
      local row = rows[index]
      if not row then break end
      local move = row.move or { name = row.id }
      local selected = index == menu.modernGen2MoveCursor
      setColor(selected and SELECTED or colorForType(move.type))
      chamfer("fill", 6, rowY, width - 12, 12, 2)
      if selected then
        setColor(INK_WHITE)
        G.rectangle("fill", 9, rowY + 4, 3, 3)
      end
      local source = row.kind == "level"
        and row.source or (row.sourceDetail or row.source)
      local sourceW = row.kind == "level" and 17
        or math.min(44, Font.width(tostring(source or "")) + 2)
      local ink = selected and INK_WHITE or INK_BLACK
      drawInk(source, 14, rowY + 2, sourceW, ink)
      drawInk(move.name or row.id, 16 + sourceW, rowY + 2,
        width - sourceW - 51, ink)
      if move.pp ~= nil then
        drawInkRight(tostring(move.pp), width - 10, rowY + 2, 24, ink)
      end
      rowY = rowY + rowStep
    end
    drawFooter(menu, wide and "UP/DOWN MOVE" or "U/D MOVE",
      wide and "A DATA B BACK" or "A VIEW B")
  end

  local function drawMoveDetail(menu)
    local width = screenWidth(menu)
    local wide = width >= 240
    drawBackdrop(menu)
    drawHeader(menu, "MOVE DATA", false)
    setColor(PAPER)
    chamfer("fill", 2, 20, width - 4, 110, 3)

    local row = selectedMoveRow(menu)
    if not row then
      drawInkCentered("NO MOVE DATA", 8, 69, width - 16, BLUE_DARK)
      return drawFooter(menu, "MOVE DETAILS", "B LIST")
    end
    local move = row.move or { name = row.id }
    local x, y, w = 6, 23, width - 12
    setColor(colorForType(move.type))
    chamfer("fill", x, y, w, 27, 3)
    local typeW = wide and 68 or 44
    drawInk(move.name or row.id, x + 6, y + 4, w - typeW - 14,
      INK_BLACK)
    local source = row.kind == "level"
      and ("LEVEL " .. tostring(row.source or "?"))
      or tostring(row.sourceDetail or row.source or "COMPATIBLE")
    drawInk(source, x + 6, y + 15, w - typeW - 14, INK_BLACK)
    setColor(SELECTED)
    chamfer("fill", x + w - typeW - 4, y + 7, typeW, 14, 2)
    drawInkCentered(typeName(menu, move.type), x + w - typeW - 2,
      y + 10, typeW - 4, INK_WHITE)

    local facts = {}
    if move.power ~= nil then facts[#facts + 1] = { "PWR", move.power } end
    if move.accuracy ~= nil then
      -- The cartridge font has no percent glyph and the native move-data
      -- screens present accuracy as the bare 0-100 value.
      facts[#facts + 1] = { "ACC", move.accuracy }
    end
    if move.pp ~= nil then facts[#facts + 1] = { "PP", move.pp } end
    local category = moveCategory(menu, move)
    if category then facts[#facts + 1] = { "CLASS", category } end
    if move.priority ~= nil then
      facts[#facts + 1] = { "PRIORITY", move.priority }
    end

    local columns = math.min(wide and 5 or 4, math.max(1, #facts))
    local factRows = #facts > 0 and math.ceil(#facts / columns) or 0
    local factY, cellH = y + 32, wide and 25 or 22
    for index, fact in ipairs(facts) do
      local zero = index - 1
      local column, factRow = zero % columns, math.floor(zero / columns)
      local x1 = x + math.floor(column * w / columns)
      local x2 = x + math.floor((column + 1) * w / columns)
      local cellY = factY + factRow * cellH
      setColor(PAPER_ALT)
      chamfer("fill", x1 + 1, cellY, x2 - x1 - 3, cellH - 3, 2)
      local label = fact[1]
      if not wide or columns >= 5 then
        label = ({ CLASS = "CAT", PRIORITY = "PRI" })[label] or label
      end
      drawInkCentered(label, x1 + 2, cellY + 2, x2 - x1 - 5, BLUE_DARK)
      drawInkCentered(tostring(fact[2]), x1 + 2, cellY + 11,
        x2 - x1 - 5, INK_BLACK)
    end

    local detailY = factY + factRows * cellH + 1
    local detailH = 128 - detailY
    if detailH >= 16 then
      setColor(PAPER_ALT)
      chamfer("fill", x + 1, detailY, w - 2, detailH, 2)
      drawInk("EFFECT", x + 6, detailY + 3, 48, BLUE_DARK)
      local detail = moveDescription(menu, move)
        or "NO DESCRIPTION AVAILABLE."
      local lineWidth = math.max(8, math.floor((w - 12) / 8))
      local maxLines = math.max(1, math.floor((detailH - 12) / 9))
      for index, line in ipairs(descriptionLines(detail, lineWidth)) do
        if index > maxLines then break end
        drawInk(line, x + 6, detailY + 12 + (index - 1) * 9,
          w - 12, INK_BLACK)
      end
    end
    drawFooter(menu, wide and "MOVE DETAILS" or "MOVE DATA", "B LIST")
  end

  local function focusFamilyMember(menu, member)
    if not member or not familyKnown(menu, member.species) then return false end
    local function findRow()
      for index, row in ipairs(menu.rows or {}) do
        if row.species == member.species then return index end
      end
    end
    local index = findRow()
    -- Search results replace the native row list. Rebuilding restores the
    -- selected NEW/OLD/A-Z order so a relative outside the active search can
    -- still be opened and remain selected when the player returns to the list.
    if not index and type(menu.rebuild) == "function" then
      menu.searchResults = nil
      menu:rebuild()
      menu.modernDexEntries = menu.rows
      index = findRow()
    end
    if not index then return false end
    menu.index = index
    if type(menu.ensureVisible) == "function" then menu:ensureVisible() end
    menu.view = "entry"
    menu.page = 1
    menu.entryAction = 1
    menu.modernGen2FamilySpecies = nil
    menu.modernGen2Family = nil
    menu.modernGen2FamilyCursor = nil
    menu.modernGen2FamilyScroll = 0
    resetMoveSelection(menu)
    if type(menu.playCry) == "function" then menu:playCry(member.species) end
    return true
  end

  local function updateFamily(menu, input)
    local family, cursor, member = familySelection(menu)
    if #family == 0 then
      if input:wasPressed("a") or input:wasPressed("b") then
        menu.view = "entry"
      end
      return
    end
    if input:wasPressed("b") then
      menu.view = "entry"
    elseif input:wasPressed("up") then
      menu.modernGen2FamilyCursor = (cursor - 2) % #family + 1
      familySelection(menu)
    elseif input:wasPressed("down") then
      menu.modernGen2FamilyCursor = cursor % #family + 1
      familySelection(menu)
    elseif input:wasPressed("a") then
      focusFamilyMember(menu, member)
    end
  end

  local function updateMoves(menu, input)
    local rows = moveListState(menu)
    if menu.modernGen2MoveDetail then
      if input:wasPressed("b") then menu.modernGen2MoveDetail = false end
      return
    end
    if input:wasPressed("b") then
      menu.view = "entry"
    elseif input:wasPressed("up") and #rows > 0 then
      menu.modernGen2MoveCursor = math.max(1,
        menu.modernGen2MoveCursor - 1)
      moveListState(menu)
    elseif input:wasPressed("down") and #rows > 0 then
      menu.modernGen2MoveCursor = math.min(#rows,
        menu.modernGen2MoveCursor + 1)
      moveListState(menu)
    elseif input:wasPressed("a") and #rows > 0 then
      menu.modernGen2MoveDetail = true
    end
  end

  local function updateEntry(menu, input)
    local actions = entryActions(menu)
    menu.entryAction = math.max(1,
      math.min(menu.entryAction or 1, #actions))
    if input:wasPressed("right") then
      menu.entryAction = menu.entryAction % #actions + 1
    elseif input:wasPressed("left") then
      menu.entryAction = (menu.entryAction - 2) % #actions + 1
    elseif input:wasPressed("a") then
      local action = actions[menu.entryAction]
      if action == "PAGE" then
        menu.page = menu.page == 1 and 2 or 1
      elseif action == "AREA" then
        menu.view = "area"
        menu.areaRegion = nil
      elseif action == "EVO" then
        menu.view = "family"
        menu.modernGen2FamilySpecies = nil
        familySelection(menu)
      elseif action == "MOVE" then
        resetMoveSelection(menu)
        moveListState(menu)
        menu.view = "moves"
      elseif action == "CRY" and type(menu.playCry) == "function" then
        local row = menu:current()
        menu:playCry(row and row.species)
      elseif action == "PRNT" and type(menu.printEntry) == "function" then
        menu:printEntry()
      end
    elseif input:wasPressed("b") then
      menu.view = "list"
    end
  end

  local function drawOption(menu)
    local G = love.graphics
    local width = screenWidth(menu)
    local wide = width >= 240
    drawBackdrop(menu)
    drawHeader(menu, "OPTIONS")
    local rows = menu:optionRows()
    local shortLabel = {
      NEW = "NEW DEX MODE", OLD = "OLD DEX MODE", ["A-Z"] = "A-Z MODE",
      UNOWN = "UNOWN MODE",
    }
    for i, row in ipairs(rows) do
      local col = wide and (i - 1) % 2 or 0
      local rowIndex = wide and math.floor((i - 1) / 2) or (i - 1)
      local cardW = wide and math.floor((width - 17) / 2) or width - 14
      local x = 7 + col * (cardW + 3)
      local y = 23 + rowIndex * (wide and 36 or 21)
      local selected = i == menu.optionIndex
      setColor(selected and BLUE_DARK or (i % 2 == 0 and PAPER_ALT or PAPER))
      chamfer("fill", x, y, cardW, wide and 31 or 18, 3)
      if selected then
        setColor(INK_WHITE)
        G.rectangle("fill", x + 5, y + 5, 3, wide and 21 or 8)
      end
      drawInk(shortLabel[row.mode] or row.label, x + 13, y + 5, cardW - 20,
        selected and INK_WHITE or INK_BLACK)
    end
    local current = rows[menu.optionIndex]
    if current then
      drawInk(current.lines[1], 8, 111, width - 16, BLUE_DARK)
      drawInk(current.lines[2], 8, 121, width - 16, INK_BLACK)
    end
    drawFooter(menu, "A CHOOSE", "B BACK")
  end

  local function drawSearch(menu)
    local G = love.graphics
    local width = screenWidth(menu)
    local wide = width >= 240
    drawBackdrop(menu)
    drawHeader(menu, "SEARCH")
    local entries = {
      { "TYPE 1", menu:searchTypeName(1) },
      { "TYPE 2", menu:searchTypeName(2) },
      { "BEGIN SEARCH", "" }, { "CANCEL", "" },
    }
    for i, entry in ipairs(entries) do
      local col = wide and (i - 1) % 2 or 0
      local rowIndex = wide and math.floor((i - 1) / 2) or (i - 1)
      local cardW = wide and math.floor((width - 21) / 2) or width - 18
      local x = 9 + col * (cardW + 3)
      local y = 25 + rowIndex * (wide and 43 or 24)
      local selected = i == menu.searchIndex
      setColor(selected and BLUE_DARK or (i <= 2 and PAPER_ALT or PAPER))
      chamfer("fill", x, y, cardW, wide and 38 or 20, 3)
      drawInk(entry[1], x + 8, y + 6,
        entry[2] ~= "" and cardW - 16 or cardW - 15,
        selected and INK_WHITE or INK_BLACK)
      if entry[2] ~= "" then
        drawInkRight(entry[2], x + cardW - 7, y + (wide and 22 or 6),
          cardW - 14,
          selected and INK_WHITE or BLUE_DARK)
      end
    end
    if menu.searchMessage then
      drawInkCentered(menu.searchMessage, 8, 121, width - 16, BLUE_DARK)
    end
    drawFooter(menu, "L/R TYPE", "A CHOOSE B BACK")
  end

  local function drawToolFrame(menu)
    local width = screenWidth(menu)
    local title
    if menu.view == "area" then
      local row = menu:current()
      title = row and (menu:monName(row.species) .. " AREA") or "AREA"
    else
      title = "UNOWN MODE"
    end
    setColor(RED)
    love.graphics.rectangle("fill", 0, 0, width, 18)
    setColor(ORANGE)
    love.graphics.rectangle("fill", 0, 16, width, 2)
    drawInk(title, 4, 5, width - 8, INK_WHITE)
    if menu.view == "area" then
      drawFooter(menu, "L/R MAP", "A/B BACK")
    else
      drawFooter(menu, "L/R FORM", "A/B BACK")
    end
  end

  local function drawWideTool(menu, nativePanel)
    local G = love.graphics
    local width = screenWidth(menu)
    if width <= 160 then
      nativePanel(menu)
      drawToolFrame(menu)
      G.setColor(1, 1, 1, 1)
      return
    end
    drawBackdrop(menu)
    local nativeX = math.floor((width - 160) / 2)
    G.push()
    G.translate(nativeX, 0)
    nativePanel(menu)
    G.pop()

    -- The native map/form canvas remains pixel-faithful in the middle, while
    -- the extra columns become useful context rails instead of letterboxing.
    local railW = math.max(18, nativeX - 3)
    setColor(BLUE_DARK)
    chamfer("fill", 2, 21, railW, 108, 3)
    chamfer("fill", width - railW - 2, 21, railW, 108, 3)
    drawInkCentered(menu.view == "area" and "JOHTO" or "FORMS",
      4, 30, railW - 4, INK_WHITE)
    drawInkCentered(menu.view == "area" and "MAP" or "A-Z",
      width - railW, 30, railW - 4, INK_WHITE)
    drawInkCentered("L/R", 4, 113, railW - 4, INK_LIGHT)
    drawInkCentered("BACK", width - railW, 113, railW - 4, INK_LIGHT)
    drawToolFrame(menu)
    G.setColor(1, 1, 1, 1)
  end

  local inherited = mod.content.screens:get("Gen2PokedexMenu")
  local provider = inherited or PokedexMenu
  local record = {
    new = function(game, ...)
      if type(mod.exports.reconcileOwnedPokemon) == "function" then
        mod.exports.reconcileOwnedPokemon(game)
      end
      local menu = provider.new(game, ...)
      if type(menu) ~= "table" or menu.modernPokedexGeneration == 2 then
        return menu
      end
      local nativePanel = menu.drawPanel
      local nativeUpdate = menu.update
      menu.modernPokedexUI = true
      menu.modernPokedexGeneration = 2
      PortraitCutouts.attachPokedex(menu)
      menu.modernDexEntries = menu.rows
      menu.modernDexCount = #(menu.rows or {})
      menu.classicGen2PokedexPanel = nativePanel
      menu.modernGen2EvolutionFamily = function(self, species)
        return evolutionFamily(self, species)
      end
      menu.modernGen2EvolutionLabel = function(self, parent)
        return evolutionLabel(self, parent)
      end
      menu.modernGen2MoveRowsFor = function(self, species)
        return moveRows(self, species)
      end
      menu.modernGen2MoveCategory = function(self, move)
        return moveCategory(self, move)
      end
      menu.update = function(self, dt)
        local input = self.game and self.game.input
        if input and self.view == "family" then
          return updateFamily(self, input)
        elseif input and self.view == "moves" then
          return updateMoves(self, input)
        elseif input and self.view == "entry" and not self.newEntry then
          self.entryBlink = (self.entryBlink or 0) + 1
          return updateEntry(self, input)
        end
        if type(nativeUpdate) == "function" then return nativeUpdate(self, dt) end
      end
      menu.drawPanel = function(self)
        if self.view == "entry" then
          drawEntry(self)
        elseif self.view == "family" then
          drawFamily(self)
        elseif self.view == "moves" then
          if self.modernGen2MoveDetail then
            drawMoveDetail(self)
          else
            drawMoves(self)
          end
        elseif self.view == "option" then
          drawOption(self)
        elseif self.view == "search" then
          drawSearch(self)
        elseif self.view == "list" or self.view == "results" then
          drawList(self)
        else
          -- AREA and UNOWN are Gen 2-only tools with no Gen 1 counterpart.
          -- Retain their controller-authored maps/glyphs, then frame them with
          -- the same red header and blue footer as the Gen 1 presentation.
          drawWideTool(self, nativePanel)
        end
      end
      installWideDraw(menu, menu.drawPanel)
      return menu
    end,
  }

  if inherited then
    mod.content.screens:override("Gen2PokedexMenu", record)
  else
    mod.content.screens:register("Gen2PokedexMenu", record)
  end
  mod.exports.generation = 2
  mod.exports.dexSize = 251
  mod.log:info("modern native 251-species Gen 2 Pokedex enabled")
end
