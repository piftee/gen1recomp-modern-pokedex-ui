-- Responsive modern-retro presentation for the Pokédex list and data page.
-- Native list/action behavior remains authoritative; this module owns layout,
-- icon fitting, palette zones, and the entry renderer.
return function(mod, compatibility)
  compatibility = compatibility or {}
  local Assets = require("src.render.Assets")
  local BuiltinDexEntry = require("src.ui.DexEntryMenu")
  local BuiltinPokedex = require("src.ui.PokedexMenu")
  local Font = require("src.render.Font")
  local Logger = require("src.core.Logger")
  local PaletteFX = require("src.render.PaletteFX")
  local PartyMenu = require("src.ui.PartyMenu")
  local Renderer = require("src.render.Renderer")
  local Runtime = require("src.mods.Runtime")
  local Sprites = require("src.pokemon.Sprites")
  local Strings = require("src.core.Strings")
  local TypeChart = require("src.battle.TypeChart")

  local SCREEN_H = 144
  local HEADER_H = 18
  local FOOTER_H = 12
  local ROW_H = 21
  local WHITE = 1
  local LIGHT = 170 / 255
  local DARK = 85 / 255
  local BLACK = 0

  -- Crystal stores its three Move Tutor compatibility bits immediately after
  -- the 50 TMs and seven HMs. They live in the same species field, but there
  -- is deliberately no numbered machine item for any of them.
  local CRYSTAL_TUTOR_MOVES = {
    FLAMETHROWER = true,
    THUNDERBOLT = true,
    ICE_BEAM = true,
  }

  -- Shared with Modern Party UI so a species has the same colour everywhere.
  local TYPE_BASE = {
    NORMAL = { 144, 152, 162 }, FIGHTING = { 206, 63, 107 },
    FLYING = { 143, 168, 222 }, POISON = { 171, 106, 200 },
    GROUND = { 217, 119, 70 }, ROCK = { 201, 182, 139 },
    BUG = { 144, 192, 44 }, GHOST = { 82, 105, 173 },
    FIRE = { 254, 156, 85 }, WATER = { 77, 144, 214 },
    GRASS = { 101, 188, 94 }, ELECTRIC = { 244, 210, 59 },
    PSYCHIC_TYPE = { 249, 113, 119 }, PSYCHIC = { 249, 113, 119 },
    ICE = { 115, 206, 191 }, DRAGON = { 9, 109, 195 },
    DARK = { 91, 82, 101 }, FAIRY = { 236, 144, 231 },
    STEEL = { 91, 142, 161 },
  }

  local function typeRamp(base)
    local lighter = {}
    for i = 1, 3 do
      lighter[i] = math.floor(base[i] + (255 - base[i]) * 0.30 + 0.5)
    end
    return { { 255, 255, 255 }, lighter,
      { base[1], base[2], base[3] }, { 0, 0, 0 } }
  end
  local TYPE_COLORS = {}
  for id, color in pairs(TYPE_BASE) do TYPE_COLORS[id] = typeRamp(color) end

  local fittedHgss = {}
  local authoredIconRunCache = {}
  local wildsIconDefs = {}
  local wildsIconAlphaMasks = {}
  local spriteCache = {}
  local spriteRunCache = {}
  local inkShader

  if Assets.register then
    Assets.register(function()
      fittedHgss = {}
      authoredIconRunCache = {}
      wildsIconDefs = {}
      wildsIconAlphaMasks = {}
      spriteCache = {}
      spriteRunCache = {}
    end)
  end

  local function gray(value)
    love.graphics.setColor(value, value, value, 1)
  end

  local function setting(key, fallback)
    local ok, value = pcall(mod.options.get, mod.options, key)
    if not ok or value == nil then return fallback end
    return value
  end

  local function shaderForInk()
    if inkShader == nil then
      if not love.graphics.newShader then
        inkShader = false
      else
        local ok, shader = pcall(love.graphics.newShader, [[
          vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
            vec4 pixel = Texel(tex, tc);
            return vec4(color.rgb, pixel.a * color.a);
          }
        ]])
        inkShader = ok and shader or false
      end
    end
    return inkShader or nil
  end

  local function fitText(text, maxWidth)
    text = tostring(text or "")
    maxWidth = math.max(0, math.floor(maxWidth or Font.width(text)))
    if Font.width(text) <= maxWidth then return text end
    local spans = Font.split(text)
    local count = Font.spansFitting(spans, math.max(0, maxWidth - 8))
    if count < 1 then return "" end
    return text:sub(1, spans[count].to) .. "."
  end

  local function drawRawText(text, x, y, maxWidth, shade)
    text = tostring(text or "")
    text = fitText(text, maxWidth or Font.width(text))
    love.graphics.push("all")
    local shader = shaderForInk()
    if shader then
      love.graphics.setShader(shader)
      gray(shade == nil and WHITE or shade)
    else
      gray(BLACK)
    end
    Font.draw(text, math.floor(x), math.floor(y))
    love.graphics.pop()
    return Font.width(text)
  end

  local function drawText(text, x, y, maxWidth, shade)
    return drawRawText(Strings(tostring(text or "")), x, y, maxWidth, shade)
  end

  local function drawRight(text, right, y, maxWidth, shade)
    text = fitText(Strings(tostring(text or "")), maxWidth)
    local width = Font.width(text)
    drawText(text, right - width, y, maxWidth, shade)
    return width
  end

  local function drawCentered(text, x, y, width, shade)
    text = fitText(Strings(tostring(text or "")), width)
    drawRawText(text, x + math.floor((width - Font.width(text)) / 2),
      y, width, shade)
  end

  local function drawRawCentered(text, x, y, width, shade)
    text = fitText(tostring(text or ""), width)
    drawRawText(text, x + math.floor((width - Font.width(text)) / 2),
      y, width, shade)
  end

  local function chamfer(mode, x, y, w, h, cut)
    cut = math.max(0, math.min(cut or 0,
      math.floor(math.min(w, h) / 2)))
    if cut <= 0 or not love.graphics.polygon then
      love.graphics.rectangle(mode, x, y, w, h)
      return
    end
    love.graphics.polygon(mode, {
      x + cut, y, x + w - cut, y,
      x + w, y + cut, x + w, y + h - cut,
      x + w - cut, y + h, x + cut, y + h,
      x, y + h - cut, x, y + cut,
    })
  end

  local function panel(x, y, w, h, selected)
    gray(BLACK)
    chamfer("fill", x + 2, y + 2, w - 2, h - 2, 3)
    gray(selected and BLACK or WHITE)
    chamfer("fill", x, y, w - 2, h - 2, 3)
    gray(selected and LIGHT or WHITE)
    chamfer("fill", x + 2, y + 2, w - 6, h - 6, 2)
    if selected then
      gray(DARK)
      love.graphics.rectangle("fill", x + 2, y + 6, 2,
        math.max(1, h - 12))
    end
  end

  local function windowSize()
    if not setting("responsive", true) then return 160, SCREEN_H end
    local width, height
    if love.graphics.getPixelDimensions then
      width, height = love.graphics.getPixelDimensions()
    else
      width, height = love.graphics.getDimensions()
    end
    width, height = tonumber(width) or 160, tonumber(height) or SCREEN_H
    local scale = math.max(1, math.floor(math.min(width / 160,
      height / SCREEN_H)))
    return math.min(Renderer.MAX_UI_WIDTH or 640,
      math.max(160, math.floor(width / scale))), SCREEN_H
  end

  local function uiSize()
    return windowSize()
  end

  local function layoutFor(width)
    width = math.max(160, math.floor(tonumber(width) or select(1, uiSize())))
    local wide = width >= 240
    local listX, listY = 4, HEADER_H + 3
    local listH = SCREEN_H - FOOTER_H - listY - 2
    local listW = wide and math.max(154, math.floor(width * 0.56))
      or width - 8
    local previewX = listX + listW + 4
    return {
      width = width, height = SCREEN_H, wide = wide,
      list = { x = listX, y = listY, w = listW, h = listH },
      preview = wide and { x = previewX, y = listY,
        w = width - previewX - 4, h = listH } or nil,
      footerY = SCREEN_H - FOOTER_H,
      rows = math.max(1, math.floor(listH / ROW_H)),
    }
  end

  local function activeLayout(screen)
    local width = select(1, screen:uiSize())
    local renderer = screen.game and screen.game.renderer
    if renderer and renderer.uiSize then
      width = select(1, renderer:uiSize()) or width
    end
    return layoutFor(width)
  end

  local function paletteFor(def)
    local id = def and def.types and def.types[1] or "NORMAL"
    return TYPE_COLORS[tostring(id):upper()] or TYPE_COLORS.NORMAL
  end

  local function basePalette(game)
    return PaletteFX.pal(game.data, "BLUEMON")
      or PaletteFX.pal(game.data, "MEWMON") or PaletteFX.GRAYS
  end

  local function backdrop(layout)
    gray(WHITE)
    love.graphics.rectangle("fill", 0, 0, layout.width, layout.height)
    if setting("pattern", "grid") ~= "grid" then return end
    gray(LIGHT)
    for x = -SCREEN_H, layout.width, 16 do
      love.graphics.line(x, HEADER_H, x + SCREEN_H, layout.footerY)
      love.graphics.line(x + SCREEN_H, HEADER_H, x, layout.footerY)
    end
  end

  local function dexRows(game)
    local dex = game.save.pokedex or { seen = {}, owned = {} }
    local byDex = {}
    for _, def in pairs(game.data.pokemon or {}) do
      if def.dex then byDex[def.dex] = def end
    end
    local rows = {}
    local constants = game.data.constants or {}
    for number = 1, constants.dexSize or 151 do
      local def = byDex[number]
      if def then
        rows[#rows + 1] = {
          def = def,
          seen = dex.seen and dex.seen[def.id] == true
            or dex.owned and dex.owned[def.id] == true,
          owned = dex.owned and dex.owned[def.id] == true,
        }
      end
    end
    return rows
  end

  local function syntheticMon(def)
    return { species = def.id, level = 1, hp = 1, stats = { hp = 1 } }
  end

  local function iconEntry(game, mon)
    local icons = game.data.icons or {}
    local def = game.data.pokemon[mon.species]
    local entry = icons.bySpecies and icons.bySpecies[mon.species]
      or def and def.icon
    if type(entry) ~= "table" then return nil, "" end
    return entry, tostring(entry.image or ""):lower()
  end

  local function authoredIcon(entry, path)
    if type(entry) ~= "table" then return false end
    local paletteAware = path:find("icons_original", 1, true) ~= nil
      or path:find("icon_original", 1, true) ~= nil
    return not paletteAware
      or PartyMenu._uniqueMenuIconsTrueColorWrapped == true
  end

  local function isHgss(entry, path)
    return compatibility.hgssSprites and type(entry) == "table"
      and entry.trueColor == true
      and path:find("hgss", 1, true) ~= nil
  end

  -- Full-colour menu icons need to bypass the later screen-palette pass, but
  -- only where the icon actually has a visible pixel.  Protecting the whole
  -- 16x16 slot also restores its transparent source pixels, which appear as
  -- a white square on top of a selected/type-coloured card.
  local function authoredIconRuns(game, mon, entry)
    if type(entry) ~= "table" then return nil end
    local path = Sprites.iconPath(game.data, mon, entry.image, {})
    if type(path) ~= "string" then return nil end
    local cached = authoredIconRunCache[path]
    if cached ~= nil then return cached or nil end
    local ok, data = pcall(Assets.imageData, path)
    if not ok or not data or type(data.getDimensions) ~= "function"
        or type(data.getPixel) ~= "function" then
      authoredIconRunCache[path] = false
      return nil
    end
    local iw, ih = data:getDimensions()
    -- PartyMenu draws frame zero when the Pokédex deliberately requests the
    -- resting state. Multi-frame sheets use a 16x16 first frame; a genuine
    -- single-frame mod image is drawn at its authored dimensions.
    local width = ih > 16 and math.min(16, iw) or iw
    local height = ih > 16 and math.min(16, ih) or ih
    local runs = {}
    for py = 0, math.max(0, height - 1) do
      local start
      for px = 0, math.max(0, width - 1) do
        local _, _, _, alpha = data:getPixel(px, py)
        local opaque = (alpha or 0) > 0.01
        if opaque and start == nil then start = px end
        if start and (not opaque or px == width - 1) then
          local finish = opaque and px or px - 1
          runs[#runs + 1] = {
            x = start, y = py, w = finish - start + 1,
          }
          start = nil
        end
      end
    end
    authoredIconRunCache[path] = runs
    return runs
  end

  local function collectSharedIcon(game, mon, x, y, selected, counter,
      regions, exactRuns)
    local original = PaletteFX.markTrueColor
    PaletteFX.markTrueColor = function(rx, ry, rw, rh)
      rx, ry, rw, rh = tonumber(rx), tonumber(ry), tonumber(rw), tonumber(rh)
      -- A mod may publish a fixed rectangular PartyMenu claim. Once the
      -- asset's alpha has supplied an exact mask, that broad claim would put
      -- the transparent square straight back, so prefer the exact mask.
      if not exactRuns and rx and ry and rw and rh and rw > 0 and rh > 0 then
        regions[#regions + 1] = { x = rx, y = ry, w = rw, h = rh }
      end
    end
    -- Card drawing leaves the active tint at its face shade. On a selected
    -- row that shade is deliberately darker; letting the shared icon draw
    -- inherit it permanently multiplies every authored colour, even though
    -- the icon renderer itself was correctly given selected=false.
    love.graphics.push("all")
    love.graphics.setColor(1, 1, 1, 1)
    local ok, err = pcall(PartyMenu.drawIcon,
      game, mon, x, y, selected, counter or 0)
    love.graphics.pop()
    PaletteFX.markTrueColor = original
    if not ok then error(err, 0) end
    for _, run in ipairs(exactRuns or {}) do
      regions[#regions + 1] = {
        x = x + run.x, y = y + run.y, w = run.w, h = 1,
      }
    end
  end

  local function hgssAsset(game, mon, entry)
    local path = Sprites.iconPath(game.data, mon, entry.image, {})
    if type(path) ~= "string" then return nil end
    local cached = fittedHgss[path]
    if cached ~= nil then return cached or nil end
    if not (love.image and love.image.newImageData and love.graphics.newQuad) then
      fittedHgss[path] = false
      return nil
    end
    local okData, data = pcall(Assets.imageData, path)
    local okImage, image = pcall(Assets.image, path)
    if not okData or not data or not okImage or not image then
      fittedHgss[path] = false
      return nil
    end
    local iw, ih = data:getDimensions()
    local rawFrames = {}
    for frame = 0, math.min(1, math.floor(ih / 32) - 1) do
      local minX, minY, maxX, maxY = 32, 32, -1, -1
      local runs = {}
      for py = 0, math.min(31, ih - frame * 32 - 1) do
        local start
        for px = 0, math.min(31, iw - 1) do
          local _, _, _, alpha = data:getPixel(px, frame * 32 + py)
          local opaque = (alpha or 0) > 0.01
          if opaque then
            minX, minY = math.min(minX, px), math.min(minY, py)
            maxX, maxY = math.max(maxX, px), math.max(maxY, py)
          end
          if opaque and start == nil then start = px end
          if start and (not opaque or px == math.min(31, iw - 1)) then
            local finish = opaque and px or px - 1
            runs[#runs + 1] = { x = start, y = py,
              w = finish - start + 1 }
            start = nil
          end
        end
      end
      if maxX >= minX and maxY >= minY then
        rawFrames[frame] = { minX = minX, minY = minY,
          maxX = maxX, maxY = maxY, runs = runs }
      end
    end
    local ux1, uy1, ux2, uy2
    for _, raw in pairs(rawFrames) do
      ux1 = ux1 and math.min(ux1, raw.minX) or raw.minX
      uy1 = uy1 and math.min(uy1, raw.minY) or raw.minY
      ux2 = ux2 and math.max(ux2, raw.maxX) or raw.maxX
      uy2 = uy2 and math.max(uy2, raw.maxY) or raw.maxY
    end
    local frames = {}
    if ux1 then
      for frame, raw in pairs(rawFrames) do
        frames[frame] = { x = ux1, y = frame * 32 + uy1,
          w = ux2 - ux1 + 1, h = uy2 - uy1 + 1, runs = raw.runs }
      end
    end
    cached = { image = image, iw = iw, ih = ih, frames = frames }
    fittedHgss[path] = cached
    return cached
  end

  local function drawHgss(game, mon, entry, x, y, target, animate, counter,
      regions)
    local cached = hgssAsset(game, mon, entry)
    if not cached then return false end
    local alt = animate and math.floor((counter or 0) / 5) % 2 == 1
    local bounds = cached.frames[alt and 1 or 0] or cached.frames[0]
    if not bounds then return false end
    local scale = math.min(target / bounds.w, target / bounds.h)
    local drawX = math.floor(x + (target - bounds.w * scale) / 2 + 0.5)
    local drawY = math.floor(y + (target - bounds.h * scale) / 2 + 0.5)
    local quad = love.graphics.newQuad(bounds.x, bounds.y,
      bounds.w, bounds.h, cached.iw, cached.ih)
    love.graphics.push("all")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(cached.image, quad, drawX, drawY, 0, scale, scale)
    love.graphics.pop()
    for _, run in ipairs(bounds.runs or {}) do
      regions[#regions + 1] = {
        x = drawX + (run.x - bounds.x) * scale,
        y = drawY + (run.y - (bounds.y % 32)) * scale,
        w = math.max(1, run.w * scale), h = math.max(1, scale),
      }
    end
    return true
  end

  -- Wilds of Kanto publishes its configured follower sheets through a stable
  -- resolver. Use that API directly so a later icon mod can replace the
  -- shared PartyMenu hook without making Wilds artwork disappear here.
  local function wildsIconDef(game, mon)
    local exports = compatibility.wildsOfKantoExports
    local resolve = exports and exports.resolveFollowerSprite
    if type(resolve) ~= "function" then return nil end
    local key = table.concat({
      tostring(mon.species or ""), mon.shiny and "s" or "n",
      tostring(mon.form or ""),
    }, "|")
    local cached = wildsIconDefs[key]
    if cached ~= nil then return cached or nil end
    local ok, def = pcall(resolve, {
      species = mon.species,
      shiny = mon.shiny == true,
      form = mon.form,
      surface = "land",
      role = "party_menu",
      game = game,
    })
    if not ok or type(def) ~= "table" or type(def.image) ~= "string"
        or def.image == "" then
      wildsIconDefs[key] = false
      return nil
    end
    wildsIconDefs[key] = def
    return def
  end

  local function wildsOpaqueRuns(path, frameX, frameY, frameW, frameH)
    local cached = wildsIconAlphaMasks[path]
    if cached == nil then
      local ok, data, iw, ih = pcall(function()
        local decoded = Assets.imageData(path)
        local width, height = decoded:getDimensions()
        return decoded, width, height
      end)
      if not ok or not data or not iw or not ih then
        wildsIconAlphaMasks[path] = false
        return nil
      end
      cached = { data = data, iw = iw, ih = ih, frames = {} }
      wildsIconAlphaMasks[path] = cached
    elseif cached == false then
      return nil
    end

    frameX = math.max(0, math.floor(tonumber(frameX) or 0))
    frameY = math.max(0, math.floor(tonumber(frameY) or 0))
    frameW = math.min(math.floor(tonumber(frameW) or cached.iw),
      cached.iw - frameX)
    frameH = math.min(math.floor(tonumber(frameH) or cached.ih),
      cached.ih - frameY)
    if frameW <= 0 or frameH <= 0 then return nil end
    local key = table.concat({ frameX, frameY, frameW, frameH }, ":")
    if cached.frames[key] ~= nil then return cached.frames[key] or nil end

    local ok, runs = pcall(function()
      local result = {}
      for py = 0, frameH - 1 do
        local start
        for px = 0, frameW - 1 do
          local _, _, _, alpha = cached.data:getPixel(frameX + px, frameY + py)
          local opaque = alpha == nil or alpha > 0.01
          if opaque and start == nil then start = px end
          if start ~= nil and (not opaque or px == frameW - 1) then
            local finish = opaque and px or px - 1
            result[#result + 1] = {
              x = start, y = py, w = finish - start + 1,
            }
            start = nil
          end
        end
      end
      return result
    end)
    if not ok or #runs == 0 then
      cached.frames[key] = false
      return nil
    end
    cached.frames[key] = runs
    return runs
  end

  local function drawWildsIcon(game, mon, x, y, target, focused, counter,
      regions)
    local def = wildsIconDef(game, mon)
    if not def then return false end
    local okImage, image = pcall(Assets.image, def.image)
    if not okImage or not image then return false end

    local iw, ih
    if type(image.getDimensions) == "function" then
      iw, ih = image:getDimensions()
    elseif type(image.getWidth) == "function"
        and type(image.getHeight) == "function" then
      iw, ih = image:getWidth(), image:getHeight()
    end
    iw, ih = tonumber(iw), tonumber(ih)
    if not iw or not ih or iw <= 0 or ih <= 0
        or not love.graphics.newQuad then return false end

    local frames = math.max(1, math.floor(tonumber(def.frames) or 1))
    local frameW = math.min(iw,
      math.max(1, math.floor(tonumber(def.frameWidth) or iw)))
    local defaultFrameH = frames > 1 and math.floor(ih / frames) or ih
    local frameH = math.min(ih,
      math.max(1, math.floor(tonumber(def.frameHeight) or defaultFrameH)))
    local frame = 0
    if focused and frames >= 4
        and math.floor((tonumber(counter) or 0) / 5) % 2 == 1 then
      frame = 3
    end
    frame = math.min(frames - 1, frame)
    local frameY = math.min(math.max(0, ih - frameH), frame * frameH)
    local quad = love.graphics.newQuad(0, frameY, frameW, frameH, iw, ih)
    local scale = math.min(1, target / frameW, target / frameH)
    local drawW, drawH = frameW * scale, frameH * scale
    local drawX = math.floor(x + (target - drawW) / 2 + 0.5)
    local drawY = math.floor(y + (target - drawH) / 2 + 0.5)

    love.graphics.push("all")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, quad, drawX, drawY, 0, scale, scale)
    love.graphics.pop()
    if def.trueColor ~= false then
      for _, run in ipairs(wildsOpaqueRuns(
          def.image, 0, frameY, frameW, frameH) or {}) do
        regions[#regions + 1] = {
          x = drawX + run.x * scale, y = drawY + run.y * scale,
          w = math.max(1, run.w * scale), h = math.max(1, scale),
        }
      end
    end
    return true
  end

  local function drawIcon(game, def, x, y, target, selected, counter,
      regions)
    if not (def and game.data.icons) then return end
    local mon = syntheticMon(def)
    if compatibility.wildsOfKanto and drawWildsIcon(game, mon, x, y,
        target, selected, counter, regions) then return end
    local entry, path = iconEntry(game, mon)
    if isHgss(entry, path) and drawHgss(game, mon, entry, x, y, target,
        false, counter, regions) then return end
    local exactRuns = authoredIcon(entry, path)
      and authoredIconRuns(game, mon, entry) or nil
    collectSharedIcon(game, mon,
      x + math.floor((target - 16) / 2),
      y + math.floor((target - 16) / 2), false, counter,
      regions, exactRuns)
  end

  local function visibleRuns(data)
    if not data or type(data.getDimensions) ~= "function"
        or type(data.getPixel) ~= "function" then return nil end
    local width, height = data:getDimensions()
    local runs = {}
    for y = 0, height - 1 do
      local start
      for x = 0, width do
        local visible = false
        if x < width then
          local _, _, _, alpha = data:getPixel(x, y)
          visible = (alpha or 1) > 0
        end
        if visible and not start then
          start = x
        elseif not visible and start then
          runs[#runs + 1] = { x = start, y = y, w = x - start }
          start = nil
        end
      end
    end
    return runs
  end

  local function preparedSprite(path, key, colors)
    local cached = spriteCache[key]
    if cached ~= nil then return cached or nil, spriteRunCache[key] end
    cached = false
    local runs
    if love.image and love.image.newImageData then
      local okData, data = pcall(Assets.imageData, path)
      if okData and data and type(data.mapPixel) == "function" then
        local width, height = data:getDimensions()
        local outside, queueX, queueY, head = {}, {}, {}, 1
        local function pixelIndex(x, y) return y * width + x + 1 end
        local function matte(x, y)
          local r, g, b, a = data:getPixel(x, y)
          return a <= 0 or (r > 0.83 and g > 0.83 and b > 0.83)
        end
        local function visit(x, y)
          if x < 0 or y < 0 or x >= width or y >= height then return end
          local index = pixelIndex(x, y)
          if outside[index] or not matte(x, y) then return end
          outside[index] = true
          queueX[#queueX + 1], queueY[#queueY + 1] = x, y
        end
        for x = 0, width - 1 do visit(x, 0); visit(x, height - 1) end
        for y = 1, height - 2 do visit(0, y); visit(width - 1, y) end
        while head <= #queueX do
          local x, y = queueX[head], queueY[head]
          head = head + 1
          visit(x - 1, y); visit(x + 1, y)
          visit(x, y - 1); visit(x, y + 1)
        end
        data:mapPixel(function(x, y, r, g, b, a)
          if a <= 0 or outside[pixelIndex(x, y)] then return r, g, b, 0 end
          if colors then
            local color = r > 0.83 and colors[1]
              or r > 0.5 and colors[2]
              or r > 0.17 and colors[3] or colors[4]
            return color[1] / 255, color[2] / 255,
              color[3] / 255, a
          end
          return r, g, b, a
        end)
        runs = visibleRuns(data)
        local made, image = pcall(love.graphics.newImage, data)
        cached = made and image or false
        if cached and cached.setFilter then cached:setFilter("nearest", "nearest") end
      end
    end
    if not cached then
      local ok, image = pcall(Assets.image, path)
      cached = ok and image or false
    end
    spriteCache[key], spriteRunCache[key] = cached, runs
    return cached or nil, runs
  end

  local function spriteFor(game, def)
    if not def then return nil, false end
    -- Deliberately ask for the battle presentation. Sprite selectors are
    -- allowed to vary by context; the Pokedex must show the exact front art
    -- the player will meet in battle, not a separate dex-only fallback.
    local path, trueColor = Sprites.path(game.data, def.id, "front",
      { kind = "battle" })
    if not path then return nil, false end

    local function rawSprite()
      local image, runs = preparedSprite(path, path .. "#raw")
      return image, runs
    end

    if trueColor then
      local image, runs = rawSprite()
      return image, true, nil, runs
    end

    -- Bake the grayscale battle artwork through the species' own Pokémon
    -- palette. The surrounding card remains type-coloured, but its portrait
    -- no longer inherits that card palette (e.g. Pidgey stays brown on a
    -- neutral Normal card). Edge-connected white is matte; enclosed white
    -- details such as eyes and highlights remain part of the artwork.
    local artPalette = PaletteFX.monPal(game.data, def.id)
      or PaletteFX.pal(game.data, "MEWMON") or PaletteFX.GRAYS
    local colors = PaletteFX.effectiveColors(artPalette)
    local values = {}
    for index = 1, 4 do
      local color = colors and colors[index] or {}
      values[#values + 1] = tostring(color[1] or 0)
      values[#values + 1] = tostring(color[2] or 0)
      values[#values + 1] = tostring(color[3] or 0)
    end
    local key = path .. "#species:" .. table.concat(values, ":")
    local image, runs = preparedSprite(path, key, colors)
    if image then return image, true, artPalette, runs end
    local raw, rawRuns = rawSprite()
    return raw, false, artPalette, rawRuns
  end

  local function drawSprite(game, def, rect, regions, known, colors, faceShade)
    if not known then
      drawCentered("?", rect.x, rect.y + math.floor((rect.h - 8) / 2),
        rect.w, DARK)
      return
    end
    local image, protected, artPalette, runs = spriteFor(game, def)
    if not image then return end
    local sw, sh = image:getDimensions()
    local scale = math.min(1, rect.w / math.max(1, sw),
      rect.h / math.max(1, sh))
    local x = math.floor(rect.x + (rect.w - sw * scale) / 2 + 0.5)
    local y = math.floor(rect.y + (rect.h - sh * scale) / 2 + 0.5)
    local shader
    if not protected then
      shader = PaletteFX.keyedShader and PaletteFX.keyedShader() or nil
      protected = shader ~= nil
    end
    love.graphics.push("all")
    if shader then
      love.graphics.setShader(shader)
      PaletteFX.sendColors(shader, artPalette)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, x, y, 0, scale, scale)
    love.graphics.pop()
    if protected then
      for _, run in ipairs(runs or {}) do
        regions[#regions + 1] = {
          x = x + run.x * scale, y = y + run.y * scale,
          w = math.max(1, run.w * scale), h = math.max(1, scale),
        }
      end
    end
  end

  local function translatedTypeName(id)
    if not id then return "---" end
    return Strings(TypeChart.displayName(id), "pokedex.type")
  end

  local function shortTypeName(id)
    local name = translatedTypeName(id)
    local spans = Font.split(name)
    if #spans <= 3 then return name end
    return name:sub(1, spans[3].to)
  end

  local function drawBall(x, y, caught)
    gray(caught and BLACK or DARK)
    love.graphics.circle("fill", x, y, 3.5)
    gray(caught and WHITE or LIGHT)
    love.graphics.rectangle("fill", x - 3.5, y - 0.5, 7, 1)
    love.graphics.circle("fill", x, y, 1.2)
  end

  local function actionGeometry(menu, owner, layout)
    local count = math.max(1, #menu.items)
    local width = math.min(126, layout.wide and layout.preview.w - 12
      or layout.width - 36)
    width = math.max(72, width)
    -- Header (17px), menu rows (14px each), and a small lower inset.  The
    -- previous height counted only the rows, which put QUIT through the frame.
    local height = count * 14 + 20
    local x = layout.wide
      and layout.preview.x + math.floor((layout.preview.w - width) / 2)
      or math.floor((layout.width - width) / 2)
    local y = math.floor((SCREEN_H - FOOTER_H - height) / 2) + 4
    return { x = x, y = y, w = width, h = height }
  end

  local function markOutside(rect, cutout)
    if not cutout then
      PaletteFX.markTrueColor(rect.x, rect.y, rect.w, rect.h)
      return
    end
    local x1, y1, x2, y2 = rect.x, rect.y,
      rect.x + rect.w, rect.y + rect.h
    local cx1, cy1, cx2, cy2 = cutout.x, cutout.y,
      cutout.x + cutout.w, cutout.y + cutout.h
    local ix1, iy1 = math.max(x1, cx1), math.max(y1, cy1)
    local ix2, iy2 = math.min(x2, cx2), math.min(y2, cy2)
    if ix1 >= ix2 or iy1 >= iy2 then
      PaletteFX.markTrueColor(x1, y1, rect.w, rect.h)
      return
    end
    if y1 < iy1 then PaletteFX.markTrueColor(x1, y1, rect.w, iy1 - y1) end
    if iy2 < y2 then PaletteFX.markTrueColor(x1, iy2, rect.w, y2 - iy2) end
    if x1 < ix1 then PaletteFX.markTrueColor(x1, iy1, ix1 - x1, iy2 - iy1) end
    if ix2 < x2 then PaletteFX.markTrueColor(ix2, iy1, x2 - ix2, iy2 - iy1) end
  end

  -- Opaque Pokédex screens replace whatever UI was drawn earlier in the
  -- frame.  Full-colour icon mods publish re-blit rectangles for that earlier
  -- UI; carrying them forward would reveal as grey blocks in our new layout.
  -- Clear only the UI pass, then publish this screen's own icon/sprite regions.
  local function clearInheritedUiTrueColor()
    local rects = PaletteFX.trueColorRects
      and PaletteFX.trueColorRects("ui") or nil
    if type(rects) ~= "table" then return end
    for index = #rects, 1, -1 do rects[index] = nil end
  end

  local function counts(screen)
    local seen, owned = 0, 0
    local rows = screen.modernDexAllEntries or screen.modernDexEntries or {}
    for _, row in ipairs(rows) do
      if row.seen then seen = seen + 1 end
      if row.owned then owned = owned + 1 end
    end
    return seen, owned, #rows
  end

  local function startingGlyph(name)
    local text = tostring(name or ""):match("^%s*(.-)%s*$") or ""
    local spans = Font.split(text)
    local first = spans[1]
    return first and text:sub(first.from, first.to):upper() or nil
  end

  local function searchOptions(screen)
    local letters, types = {}, {}
    for _, row in ipairs(screen.modernDexAllEntries or {}) do
      -- Search must not reveal an undiscovered species' name or typing.
      if row.seen and row.def then
        local letter = startingGlyph(row.def.name)
        if letter then letters[letter] = true end
        for _, typeId in ipairs(row.def.types or {}) do
          if typeId then types[tostring(typeId)] = true end
        end
      end
    end
    local letterList, typeList = { false }, { false }
    for letter in pairs(letters) do letterList[#letterList + 1] = letter end
    for typeId in pairs(types) do typeList[#typeList + 1] = typeId end
    local function optionLess(a, b)
      if a == b then return false end
      if a == false then return true end
      if b == false then return false end
      return tostring(a) < tostring(b)
    end
    table.sort(letterList, optionLess)
    table.sort(typeList, function(a, b)
      if a == b then return false end
      if a == false then return true end
      if b == false then return false end
      return translatedTypeName(a) < translatedTypeName(b)
    end)
    return letterList, typeList
  end

  local function optionIndex(options, value)
    for index, option in ipairs(options or {}) do
      if option == (value or false) then return index end
    end
    return 1
  end

  local function applyDexFilter(screen, letter, typeId)
    letter = letter or false
    typeId = typeId or false
    local current = screen.modernDexEntries
      and screen.modernDexEntries[screen.index]
    local currentId = current and current.def and current.def.id
    local filtered, items = {}, {}
    local active = letter ~= false or typeId ~= false
    for _, row in ipairs(screen.modernDexAllEntries or {}) do
      local matches = not active or row.seen
      if matches and letter ~= false then
        local initial = startingGlyph(row.def.name)
        matches = initial == letter
      end
      if matches and typeId ~= false then
        matches = false
        for _, candidate in ipairs(row.def.types or {}) do
          if tostring(candidate) == typeId then matches = true break end
        end
      end
      if matches then
        filtered[#filtered + 1] = row
        items[#items + 1] = row.item
      end
    end
    screen.modernDexLetter = letter
    screen.modernDexType = typeId
    screen.modernDexEntries = filtered
    screen.items = items
    screen.index, screen.scroll = 1, 0
    if currentId then
      for index, row in ipairs(filtered) do
        if row.def and row.def.id == currentId then
          screen.index = index
          break
        end
      end
    end
  end

  local function openDexSearch(screen)
    local letters, types = searchOptions(screen)
    screen.modernDexSearchLetters = letters
    screen.modernDexSearchTypes = types
    screen.modernDexSearchLetterIndex = optionIndex(
      letters, screen.modernDexLetter)
    screen.modernDexSearchTypeIndex = optionIndex(
      types, screen.modernDexType)
    screen.modernDexSearchCursor = 1
    screen.modernDexSearchOpen = true
  end

  local function searchGeometry(layout)
    local width = math.min(152, layout.width - 16)
    return { x = math.floor((layout.width - width) / 2),
      y = 40, w = width, h = 58 }
  end

  local function searchValue(screen, field)
    if field == 1 then
      return screen.modernDexSearchLetters
        [screen.modernDexSearchLetterIndex or 1] or "ALL"
    end
    local value = screen.modernDexSearchTypes
      [screen.modernDexSearchTypeIndex or 1]
    return value and translatedTypeName(value) or "ALL"
  end

  local function drawDexSearch(screen, layout)
    local rect = searchGeometry(layout)
    gray(BLACK)
    chamfer("fill", rect.x + 2, rect.y + 2, rect.w, rect.h, 4)
    gray(WHITE)
    chamfer("fill", rect.x, rect.y, rect.w, rect.h, 4)
    drawCentered("SEARCH", rect.x + 5, rect.y + 5, rect.w - 10, DARK)
    for field, label in ipairs({ "LETTER", "TYPE" }) do
      local y = rect.y + 18 + (field - 1) * 15
      local selected = field == screen.modernDexSearchCursor
      if selected then
        gray(DARK)
        chamfer("fill", rect.x + 5, y - 2, rect.w - 10, 13, 2)
      end
      drawText(label, rect.x + 10, y, 48, selected and WHITE or BLACK)
      drawRight(searchValue(screen, field), rect.x + rect.w - 10, y,
        math.max(24, rect.w - 70), selected and WHITE or DARK)
    end
    drawCentered("A APPLY", rect.x + 5, rect.y + rect.h - 12,
      rect.w - 10, DARK)

    gray(DARK)
    love.graphics.rectangle("fill", 0, layout.footerY,
      layout.width, SCREEN_H - layout.footerY)
    if layout.wide then
      drawText("UP/DOWN FIELD", 5, layout.footerY + 2, 104, WHITE)
      drawRight("L/R CHANGE B BACK", layout.width - 5,
        layout.footerY + 2, 136, LIGHT)
    else
      drawText("U/D", 5, layout.footerY + 2, 24, WHITE)
      drawRight("L/R PICK B", layout.width - 5,
        layout.footerY + 2, 80, LIGHT)
    end
  end

  local function drawHeader(screen, layout)
    gray(DARK)
    love.graphics.rectangle("fill", 0, 0, layout.width, HEADER_H)
    gray(LIGHT)
    love.graphics.rectangle("fill", 0, HEADER_H - 2, layout.width, 2)
    drawText("POKéDEX", 5, 4, 64, WHITE)
    local _, owned, total = counts(screen)
    if layout.wide then
      drawRight(("CAUGHT %03d/%03d"):format(owned, total),
        layout.width - 5, 4, 112, WHITE)
    else
      drawRight(("%03d/%03d"):format(owned, total),
        layout.width - 5, 4, 56, WHITE)
    end
  end

  local function rowRect(layout, visibleRow)
    return { x = layout.list.x, y = layout.list.y + (visibleRow - 1) * ROW_H,
      w = layout.list.w, h = ROW_H - 2 }
  end

  local function drawList(screen, layout, regions)
    if #(screen.modernDexEntries or {}) == 0 then
      drawCentered("NO MATCHES", layout.list.x + 4,
        layout.list.y + math.floor((layout.list.h - 8) / 2),
        layout.list.w - 8, DARK)
      return
    end
    for visible = 1, layout.rows do
      local index = screen.scroll + visible
      local row = screen.modernDexEntries[index]
      if not row then break end
      local rect = rowRect(layout, visible)
      local selected = index == screen.index
      panel(rect.x, rect.y, rect.w, rect.h, selected)
      local def = row.def
      local colors = row.seen and paletteFor(def) or basePalette(screen.game)
      if row.seen then
        drawIcon(screen.game, def, rect.x + 4, rect.y + 1, 17,
          selected, screen.modernDexClock, regions)
      else
        drawCentered("?", rect.x + 4, rect.y + 6, 17, DARK)
      end
      local digits = (screen.game.data.constants or {}).dexDigits or 3
      local number = ("%0" .. digits .. "d"):format(def.dex or index)
      drawText(number, rect.x + 24, rect.y + 6, digits * 8, DARK)
      local nameX = rect.x + 24 + digits * 8 + 4
      drawText(row.seen and def.name or "-----", nameX, rect.y + 6,
        rect.w - (nameX - rect.x) - 16,
        selected and WHITE or BLACK)
      if row.owned then drawBall(rect.x + rect.w - 10, rect.y + 9, true) end
    end
    local total = #screen.modernDexEntries
    if total > layout.rows then
      local trackX = layout.list.x + layout.list.w - 3
      local trackY, trackH = layout.list.y + 2, layout.list.h - 6
      gray(LIGHT)
      love.graphics.rectangle("fill", trackX, trackY, 2, trackH)
      local thumbH = math.max(8, math.floor(trackH * layout.rows / total))
      local travel = math.max(0, trackH - thumbH)
      local thumbY = trackY + math.floor(travel
        * screen.scroll / math.max(1, total - layout.rows))
      gray(DARK)
      love.graphics.rectangle("fill", trackX, thumbY, 2, thumbH)
    end
  end

  local function drawPreview(screen, layout, regions)
    local rect = layout.preview
    if not rect then return end
    local row = screen.modernDexEntries[screen.index]
    panel(rect.x, rect.y, rect.w, rect.h, true)
    if not row then return end
    local def, known = row.def, row.seen
    local pad = 6
    local spriteH = math.max(40, math.min(62, rect.h - 45))
    drawSprite(screen.game, def, { x = rect.x + pad, y = rect.y + 5,
      w = rect.w - pad * 2, h = spriteH }, regions, known,
      paletteFor(def), LIGHT)
    local infoY = rect.y + spriteH + 5
    local digits = (screen.game.data.constants or {}).dexDigits or 3
    drawText(("No.%0" .. digits .. "d"):format(def.dex or 0),
      rect.x + pad, infoY, 56, DARK)
    if row.owned then drawBall(rect.x + rect.w - 11, infoY + 4, true) end
    drawCentered(known and def.name or "UNKNOWN", rect.x + pad,
      infoY + 10, rect.w - pad * 2, WHITE)
    local kind = known and def.dexEntry and def.dexEntry.kind or nil
    if kind then
      drawCentered(kind, rect.x + pad, infoY + 20,
        rect.w - pad * 2, DARK)
    end
    if known then
      local types = def.types or {}
      local label = types[1] and translatedTypeName(types[1]) or nil
      if label and types[2] and types[2] ~= types[1] then
        label = label .. "/" .. translatedTypeName(types[2])
        if Font.width(label) > rect.w - pad * 2 then
          label = shortTypeName(types[1]) .. "/" .. shortTypeName(types[2])
        end
      end
      if label then
        drawRawCentered(label, rect.x + pad, rect.y + rect.h - 14,
          rect.w - pad * 2, WHITE)
      end
    end
  end

  local function drawFooter(screen, layout)
    gray(DARK)
    love.graphics.rectangle("fill", 0, layout.footerY,
      layout.width, FOOTER_H)
    local seen, owned, total = counts(screen)
    if layout.wide then
      drawText("A ACTIONS", 5, layout.footerY + 2, 72, WHITE)
      local filtered = screen.modernDexLetter or screen.modernDexType
      local center = filtered
        and ("FOUND %03d"):format(#(screen.modernDexEntries or {}))
        or "SEL FIND"
      drawCentered(center, 84,
        layout.footerY + 2, layout.width - 168, LIGHT)
      drawRight("B BACK", layout.width - 5, layout.footerY + 2, 56, WHITE)
    else
      local filtered = screen.modernDexLetter or screen.modernDexType
      local seenLabel = filtered
        and ("FOUND %03d"):format(#(screen.modernDexEntries or {}))
        or ("SEEN %03d"):format(seen)
      local seenWidth = drawText(seenLabel,
        5, layout.footerY + 2, Font.width(seenLabel), WHITE)
      local action = "SEL SEARCH"
      drawRight(action, layout.width - 5, layout.footerY + 2,
        math.max(0, layout.width - 16 - seenWidth), WHITE)
    end
    local meterW = math.max(1, layout.width - 10)
    local ownedW = math.floor(meterW * owned / math.max(1, total))
    gray(LIGHT)
    love.graphics.rectangle("fill", 5, layout.footerY, meterW, 1)
    gray(WHITE)
    love.graphics.rectangle("fill", 5, layout.footerY, ownedW, 1)
  end

  local function drawActions(menu)
    local owner = menu.modernDexOwner
    local layout = activeLayout(owner)
    local rect = actionGeometry(menu, owner, layout)
    gray(BLACK)
    chamfer("fill", rect.x + 2, rect.y + 2, rect.w, rect.h, 4)
    gray(WHITE)
    chamfer("fill", rect.x, rect.y, rect.w, rect.h, 4)
    drawCentered("ACTIONS", rect.x + 4, rect.y + 4,
      rect.w - 8, DARK)
    for index, item in ipairs(menu.items) do
      local y = rect.y + 7 + index * 14
      local selected = index == menu.index
      if selected then
        gray(DARK)
        chamfer("fill", rect.x + 5, y - 2, rect.w - 10, 12, 2)
      end
      drawText(item.label, rect.x + 16, y,
        rect.w - 24, selected and WHITE or BLACK)
      if selected then
        gray(WHITE)
        love.graphics.rectangle("fill", rect.x + 9, y + 2, 3, 3)
      end
    end
    gray(WHITE)
  end

  local function paletteZones(screen, game)
    local layout = activeLayout(screen)
    local base = basePalette(game)
    local zones = { { colors = base, x = 0, y = 0,
      w = layout.width, h = layout.height } }
    zones[#zones + 1] = { colors = PaletteFX.pal(game.data, "REDMON") or base,
      x = 0, y = 0, w = layout.width, h = HEADER_H }
    for visible = 1, layout.rows do
      local index = screen.scroll + visible
      local row = screen.modernDexEntries[index]
      if not row then break end
      if row.seen then
        local rect = rowRect(layout, visible)
        zones[#zones + 1] = { colors = paletteFor(row.def),
          x = rect.x, y = rect.y, w = rect.w, h = rect.h }
      end
    end
    if layout.preview then
      local row = screen.modernDexEntries[screen.index]
      zones[#zones + 1] = { colors = row and row.seen
          and paletteFor(row.def) or base,
        x = layout.preview.x, y = layout.preview.y,
        w = layout.preview.w, h = layout.preview.h }
    end
    if screen.modernDexSearchOpen then
      local rect = searchGeometry(layout)
      zones[#zones + 1] = { colors = PaletteFX.GRAYS,
        x = rect.x, y = rect.y, w = rect.w + 2, h = rect.h + 2 }
    end
    zones[#zones + 1] = { colors = PaletteFX.pal(game.data, "CYANMON") or base,
      x = 0, y = layout.footerY, w = layout.width, h = FOOTER_H }
    return zones
  end

  local function decorateActionMenu(screen)
    local top = screen.game.stack and screen.game.stack:top()
    if not top or top == screen or top.modernDexOwner == screen then return end
    if type(top.items) ~= "table" or type(top.update) ~= "function" then return end
    -- Gen1 Modern UI cannot transactionally present its Town Map while this
    -- source-owned Pokédex remains underneath: our adapter intentionally
    -- declines suppression so this mod keeps its own canvas. Mark AREA maps
    -- as source-owned opaque screens, allowing the native map renderer to
    -- remain visible instead of being hidden behind the Pokédex.
    if compatibility.gen1ModernUi and not top.modernDexAreaBridge then
      local area = top.items[3]
      if area and area.label == Strings("AREA")
          and type(area.onSelect) == "function" then
        local openArea = area.onSelect
        area.onSelect = function(...)
          local result = openArea(...)
          local map = screen.game.stack and screen.game.stack:top()
          if map and map.nestSpecies then
            map.screenId = "ModernPokedexAreaMap"
            map.modernPokedexAreaMap = true
            map.isOpaque = true
          end
          return result
        end
      end
      top.modernDexAreaBridge = true
    end
    top.modernDexOwner = screen
    top.draw = drawActions
    top.uiSize = function() return screen:uiSize() end
    top.isWideBattleLayout = function()
      return setting("responsive", true)
    end
    top.sgbPalettes = function(_, game)
      local zones = paletteZones(screen, game)
      local layout = activeLayout(screen)
      local rect = actionGeometry(top, screen, layout)
      zones[#zones + 1] = {
        colors = PaletteFX.GRAYS,
        x = rect.x, y = rect.y, w = rect.w, h = rect.h,
      }
      return zones
    end
  end

  local function makePokedex(game, opts)
    local screen = BuiltinPokedex.new(game, opts)
    local nativeUpdate = screen.update
    screen.modernPokedexUI = true
    screen.modernDexAllEntries = dexRows(game)
    for index, row in ipairs(screen.modernDexAllEntries) do
      row.item = screen.items[index]
    end
    screen.modernDexEntries = screen.modernDexAllEntries
    screen.modernDexClock = 0
    screen.uiSize = uiSize
    screen.isWideBattleLayout = function()
      return setting("responsive", true)
    end
    screen.update = function(self, dt)
      local layout = activeLayout(self)
      self.rows = layout.rows
      self.modernDexClock = (self.modernDexClock + 1) % 32000
      local input = self.game.input
      if self.modernDexSearchOpen then
        if input:wasPressed("b") then
          self.modernDexSearchOpen = false
        elseif input:wasPressed("up") or input:wasPressed("down") then
          self.modernDexSearchCursor = 3 - (self.modernDexSearchCursor or 1)
        elseif input:wasPressed("left") or input:wasPressed("right") then
          local delta = input:wasPressed("left") and -1 or 1
          local field = self.modernDexSearchCursor or 1
          local options = field == 1 and self.modernDexSearchLetters
            or self.modernDexSearchTypes
          local key = field == 1 and "modernDexSearchLetterIndex"
            or "modernDexSearchTypeIndex"
          self[key] = ((self[key] or 1) - 1 + delta) % #options + 1
        elseif input:wasPressed("a") or input:wasPressed("select") then
          local letter = self.modernDexSearchLetters
            [self.modernDexSearchLetterIndex or 1] or false
          local typeId = self.modernDexSearchTypes
            [self.modernDexSearchTypeIndex or 1] or false
          applyDexFilter(self, letter, typeId)
          self.modernDexSearchOpen = false
        end
        return
      elseif input:wasPressed("select") then
        openDexSearch(self)
        require("src.core.Sound").play(self.game.data, "Press_AB")
        return
      elseif #self.items == 0 and input:wasPressed("a") then
        openDexSearch(self)
        require("src.core.Sound").play(self.game.data, "Press_AB")
        return
      end
      nativeUpdate(self, dt)
      -- B/QUIT may pop this list and synchronously reopen the Start menu.
      -- Do not mistake that newly pushed menu for our DATA/CRY side menu or
      -- it inherits the side menu's yellow palette treatment.
      local stillOpen = false
      for _, state in ipairs(self.game.stack and self.game.stack.states or {}) do
        if state == self then stillOpen = true break end
      end
      if stillOpen then decorateActionMenu(self) end
    end
    screen.draw = function(self)
      clearInheritedUiTrueColor()
      local layout = activeLayout(self)
      self.rows = layout.rows
      local regions = {}
      backdrop(layout)
      drawHeader(self, layout)
      drawList(self, layout, regions)
      drawPreview(self, layout, regions)
      drawFooter(self, layout)
      local top = self.game.stack and self.game.stack:top()
      local cutout
      if self.modernDexSearchOpen then
        cutout = searchGeometry(layout)
      elseif top and top.modernDexOwner == self then
        cutout = actionGeometry(top, self, layout)
      end
      if self.modernDexSearchOpen then drawDexSearch(self, layout) end
      for _, rect in ipairs(regions) do markOutside(rect, cutout) end
      gray(WHITE)
    end
    screen.sgbPalettes = paletteZones
    return screen
  end

  local function wrappedLines(text, maxWidth, maxLines)
    maxLines = maxLines or math.huge
    text = tostring(text or ""):gsub("\v", " "):gsub("\f", " ")
    local lines, current = {}, ""
    for word in text:gmatch("%S+") do
      local candidate = current == "" and word or (current .. " " .. word)
      if current ~= "" and Font.width(candidate) > maxWidth then
        lines[#lines + 1] = fitText(current, maxWidth)
        current = word
        if #lines >= maxLines then break end
      else
        current = candidate
      end
    end
    if #lines < maxLines and current ~= "" then lines[#lines + 1] = current end
    if #lines > maxLines then
      while #lines > maxLines do table.remove(lines) end
    end
    return lines
  end

  local function entryPages(state)
    local pages = state.modernDexPages
    if type(pages) == "table" and #pages > 0 then return pages end
    return { { id = "info", label = "INFO" } }
  end

  local function entryPage(state)
    local pages = entryPages(state)
    return pages[state.modernDexPage or 1] or pages[1]
  end

  local function entryLayout(width)
    width = math.max(160, math.floor(width or 160))
    local wide = width >= 240
    local profileW = wide and 96 or 58
    local profile = { x = 4, y = 21, w = profileW, h = 109 }
    local infoProfile = wide and profile
      or { x = 4, y = 21, w = 52, h = 52 }
    local statsProfile = wide and profile
      or { x = 4, y = 21, w = 52, h = 52 }
    return {
      width = width, wide = wide, footerY = 134,
      content = { x = 4, y = 21, w = width - 8, h = 109 },
      profile = profile,
      infoProfile = infoProfile,
      statsProfile = statsProfile,
      statsSummary = wide and nil
        or { x = 60, y = 21, w = width - 64, h = 52 },
      statsMain = wide and nil
        or { x = 4, y = 77, w = width - 8, h = 53 },
      main = { x = 8 + profileW, y = 21,
        w = width - profileW - 12, h = 109 },
      info = wide and { x = 8 + profileW, y = 21,
        w = width - profileW - 12, h = 49 }
        or { x = 60, y = 21, w = width - 64, h = 52 },
      description = { x = wide and (8 + profileW) or 4,
        y = wide and 74 or 77,
        w = wide and (width - profileW - 12) or (width - 8),
        -- Compact INFO has four 8px note rows. Let the card use the small
        -- gap above the footer so the fourth row stays inside its inner face
        -- instead of being bisected by the lower frame.
        h = 56 },
    }
  end

  local function entryOwned(state)
    return state.forceOwned or state.game.save.pokedex
      and state.game.save.pokedex.owned
      and state.game.save.pokedex.owned[state.def.id]
  end

  local function dexText(state, owned)
    if not owned then return Strings("Data unknown.") end
    local key = state.def.dexEntry and state.def.dexEntry.text
    if not key then return nil end
    local text = state.game.data.text and state.game.data.text[key]
    return Strings(text or key)
  end

  local function drawTypeChip(label, x, y, width)
    gray(DARK)
    chamfer("fill", x, y, width, 11, 2)
    drawRawCentered(label, x + 2, y + 2, width - 4, WHITE)
  end

  local function drawEntryHeader(state, layout)
    gray(DARK)
    love.graphics.rectangle("fill", 0, 0, layout.width, HEADER_H)
    if state.modernDexTabbed then
      local pages = entryPages(state)
      local maxTabs = math.max(3, math.floor(layout.width / 40))
      local visible = math.min(#pages, maxTabs)
      local first = math.max(1, math.min(#pages - visible + 1,
        (state.modernDexPage or 1) - math.floor(visible / 2)))
      local tabW = math.floor(layout.width / visible)
      for slot = 1, visible do
        local index = first + slot - 1
        local page = pages[index]
        local x = (slot - 1) * tabW
        local w = slot == visible and layout.width - x or tabW
        local selected = index == state.modernDexPage
        gray(selected and BLACK or DARK)
        love.graphics.rectangle("fill", x + 1, 1, w - 2, HEADER_H - 3)
        if selected then
          gray(WHITE)
          love.graphics.rectangle("fill", x + 3, HEADER_H - 4, w - 6, 2)
        end
        local label = not layout.wide and page.shortLabel or page.label
        drawCentered(label or page.id or "DATA", x + 2, 4, w - 4,
          selected and WHITE or LIGHT)
      end
    else
      drawText("POKéDEX DATA", 5, 4, 96, WHITE)
      drawRight(state.def.name or "?", layout.width - 5, 4,
        layout.width - 108, WHITE)
    end
    gray(LIGHT)
    love.graphics.rectangle("fill", 0, HEADER_H - 2, layout.width, 2)
  end

  local function drawProfileCard(state, layout, regions, metadata)
    panel(layout.profile.x, layout.profile.y,
      layout.profile.w, layout.profile.h, true)
    local spriteH = metadata and (layout.wide and 54 or 42)
      or (layout.wide and 67 or 51)
    drawSprite(state.game, state.def, {
      x = layout.profile.x + 4, y = layout.profile.y + 4,
      w = layout.profile.w - 8, h = spriteH,
    }, regions, true, paletteFor(state.def), LIGHT)
    drawCentered(state.def.name or "?", layout.profile.x + 4,
      layout.profile.y + spriteH + 5, layout.profile.w - 8, WHITE)
    local iconSize = layout.wide and 22 or 17
    if not metadata then
      drawIcon(state.game, state.def,
        layout.profile.x + layout.profile.w - iconSize - 5,
        layout.profile.y + layout.profile.h - iconSize - 5,
        iconSize, false, state.modernDexClock, regions)
    end
    if metadata then
      local y = layout.profile.y + spriteH + 17
      for _, line in ipairs(metadata) do
        drawText(line, layout.profile.x + 5, y,
          layout.profile.w - 10, DARK)
        y = y + 10
      end
    end
  end

  local function drawInfoPage(state, layout, regions)
    local owned = entryOwned(state)
    local digits = (state.game.data.constants or {}).dexDigits or 3
    local e = state.def.dexEntry or {}
    local types = state.def.types or {}
    if layout.wide then
      drawProfileCard(state, layout, regions)
    else
      local profile = layout.infoProfile
      panel(profile.x, profile.y, profile.w, profile.h, true)
      drawSprite(state.game, state.def, {
        x = profile.x + 4, y = profile.y + 4,
        w = profile.w - 8, h = profile.h - 8,
      }, regions, true, paletteFor(state.def), LIGHT)
    end
    panel(layout.info.x, layout.info.y, layout.info.w, layout.info.h, false)
    drawText(("No.%0" .. digits .. "d"):format(state.def.dex or 0),
      layout.info.x + 6, layout.info.y + 5,
      layout.wide and 72 or 56, DARK)
    if layout.wide then
      drawRight(owned and "CAUGHT" or "SEEN",
        layout.info.x + layout.info.w - 6,
        layout.info.y + 5, 64, DARK)
    elseif owned then
      drawBall(layout.info.x + layout.info.w - 10,
        layout.info.y + 9, true)
    else
      drawRight("SEEN", layout.info.x + layout.info.w - 6,
        layout.info.y + 5, 40, DARK)
    end
    if not layout.wide then
      drawText(state.def.name or "?", layout.info.x + 6,
        layout.info.y + 17, layout.info.w - 12, BLACK)
    end
    if e.kind then
      drawText(e.kind, layout.info.x + 6,
        layout.info.y + (layout.wide and 16 or 27),
        layout.info.w - 12, layout.wide and BLACK or DARK)
    end
    local chipY = layout.info.y + layout.info.h - 16
    local available = layout.info.w - 12
    local two = types[2] and types[2] ~= types[1]
    local chipW = two and math.floor((available - 3) / 2) or available
    if types[1] then
      local label = layout.wide and translatedTypeName(types[1])
        or shortTypeName(types[1])
      drawTypeChip(label, layout.info.x + 6, chipY, chipW)
    end
    if types[1] and two then
      local label = layout.wide and translatedTypeName(types[2])
        or shortTypeName(types[2])
      drawTypeChip(label, layout.info.x + 9 + chipW,
        chipY, chipW)
    end

    local notes = dexText(state, owned)
    if not notes then
      state.modernInfoLines = nil
      state.modernInfoVisible = nil
      state.modernInfoCanScroll = false
      return
    end
    panel(layout.description.x, layout.description.y,
      layout.description.w, layout.description.h, false)
    local descX = layout.description.x + 6
    local descW = layout.description.w - 12
    local measurements = {}
    if owned then
      if e.heightM then
        measurements[#measurements + 1] = ("%.1fm"):format(e.heightM)
        if e.weightKg then
          measurements[#measurements + 1] = layout.wide
            and ("%.1fkg"):format(e.weightKg)
            or ("%.0fkg"):format(e.weightKg)
        end
      elseif e.heightFt then
        measurements[#measurements + 1] = layout.wide
          and ("%d′%02d″"):format(e.heightFt, e.heightIn or 0)
          or ("%d′%d″"):format(e.heightFt, e.heightIn or 0)
        if e.weight then
          measurements[#measurements + 1] = layout.wide
            and ("%.1flb"):format(e.weight / 10)
            or ("%.0flb"):format(e.weight / 10)
        end
      end
      if #measurements > 0 then
        measurements = table.concat(measurements, "  ")
        drawRight(measurements,
          layout.description.x + layout.description.w - 6,
          layout.description.y + 4, descW, DARK)
      end
    end
    local measureW = type(measurements) == "string"
      and Font.width(measurements) or 0
    local notesLabel = layout.wide and "FIELD NOTES" or "NOTES"
    local sameLine = measureW == 0
      or Font.width(notesLabel) + measureW + 8 <= descW
    local y, maxLines
    if sameLine then
      drawText(notesLabel, descX, layout.description.y + 4,
        math.max(40, descW - measureW - 8), DARK)
      y, maxLines = layout.description.y + 15, 4
    else
      drawText("NOTES", descX, layout.description.y + 14, 48, DARK)
      y, maxLines = layout.description.y + 25, layout.wide and 3 or 3
    end
    local lines = wrappedLines(notes, descW)
    state.modernInfoLines = lines
    state.modernInfoVisible = maxLines
    local maxScroll = math.max(0, #lines - maxLines)
    state.modernInfoScroll = math.max(0,
      math.min(state.modernInfoScroll or 0, maxScroll))
    state.modernInfoCanScroll = maxScroll > 0
    for index = state.modernInfoScroll + 1,
        math.min(#lines, state.modernInfoScroll + maxLines) do
      local line = lines[index]
      drawText(line, descX, y, descW, BLACK)
      y = y + 10
    end
    if state.modernInfoScroll > 0 then
      gray(DARK)
      if love.graphics.polygon then
        love.graphics.polygon("fill", {
          layout.description.x + layout.description.w - 11,
            layout.description.y + 7,
          layout.description.x + layout.description.w - 5,
            layout.description.y + 7,
          layout.description.x + layout.description.w - 8,
            layout.description.y + 4,
        })
      else
        love.graphics.rectangle("fill",
          layout.description.x + layout.description.w - 9,
          layout.description.y + 5, 3, 2)
      end
    end
    if state.modernInfoScroll < maxScroll then
      gray(DARK)
      if love.graphics.polygon then
        love.graphics.polygon("fill", {
          layout.description.x + layout.description.w - 11,
            layout.description.y + layout.description.h - 8,
          layout.description.x + layout.description.w - 5,
            layout.description.y + layout.description.h - 8,
          layout.description.x + layout.description.w - 8,
            layout.description.y + layout.description.h - 5,
        })
      else
        love.graphics.rectangle("fill",
          layout.description.x + layout.description.w - 9,
          layout.description.y + layout.description.h - 7, 3, 2)
      end
    end
  end

  local STAT_ROWS = {
    { "HP", "hp", "GREENMON", "HP" },
    { "ATTACK", "attack", "REDMON", "ATK" },
    { "DEFENSE", "defense", "BROWNMON", "DEF" },
    { "SPEED", "speed", "BLUEMON", "SPE" },
    { "SPECIAL", "special", "PURPLEMON", "SPC" },
  }

  local function growthLabel(id)
    local names = { MEDIUM_FAST = "MED FAST", MEDIUM_SLOW = "MED SLOW" }
    return names[id] or tostring(id or "---"):gsub("_", " ")
  end

  local function drawStatsPage(state, layout, regions)
    local def = state.def
    local metadata = {}
    if def.catchRate ~= nil then
      metadata[#metadata + 1] = Strings("CATCH %d", def.catchRate)
    end
    if def.baseExp ~= nil then
      metadata[#metadata + 1] = Strings("EXP %d", def.baseExp)
    end
    if def.growthRate ~= nil then
      metadata[#metadata + 1] = growthLabel(def.growthRate)
    end
    local stats = def.baseStats or {}
    local availableRows, total = {}, 0
    for _, row in ipairs(STAT_ROWS) do
      if stats[row[2]] ~= nil then
        availableRows[#availableRows + 1] = row
        total = total + stats[row[2]]
      end
    end
    local main = layout.main
    local rowsY, step
    if layout.wide then
      drawProfileCard(state, layout, regions,
        #metadata > 0 and metadata or nil)
      if #availableRows == 0 then return end
      panel(main.x, main.y, main.w, main.h, false)
      local totalText = #availableRows == #STAT_ROWS
        and Strings("TOTAL %d", total) or nil
      local statsTitle = totalText
          and Font.width("BASE STATS") + Font.width(totalText) + 8
            > main.w - 12 and "STATS" or "BASE STATS"
      drawText(statsTitle, main.x + 6, main.y + 5, 88, DARK)
      if #availableRows == #STAT_ROWS then
        drawRight(totalText,
          main.x + main.w - 6, main.y + 5, 88, DARK)
      end
      rowsY = main.y + 20
      step = math.min(16, math.floor(82 / #availableRows))
    else
      local portrait = layout.statsProfile
      panel(portrait.x, portrait.y, portrait.w, portrait.h, true)
      drawSprite(state.game, state.def, {
        x = portrait.x + 4, y = portrait.y + 4,
        w = portrait.w - 8, h = portrait.h - 8,
      }, regions, true, paletteFor(state.def), LIGHT)

      local summary = layout.statsSummary
      panel(summary.x, summary.y, summary.w, summary.h, false)
      local summaryW = summary.w - 12
      local summaryRows = {}
      if #availableRows == #STAT_ROWS then
        summaryRows[#summaryRows + 1] = {
          long = Strings("TOTAL %d", total), shade = DARK,
        }
      end
      if def.catchRate ~= nil then
        summaryRows[#summaryRows + 1] = {
          long = Strings("CATCH RATE %d", def.catchRate),
          short = Strings("CATCH %d", def.catchRate),
        }
      end
      if def.baseExp ~= nil then
        summaryRows[#summaryRows + 1] = {
          long = Strings("BASE EXP %d", def.baseExp),
          short = Strings("EXP %d", def.baseExp),
        }
      end
      if def.growthRate ~= nil then
        local growthShort = ({
          MEDIUM_FAST = "M.F.", MEDIUM_SLOW = "M.S.",
        })[def.growthRate] or growthLabel(def.growthRate):sub(1, 5)
        summaryRows[#summaryRows + 1] = {
          long = Strings("GROWTH %s", growthLabel(def.growthRate)),
          short = Strings("GROW %s", growthShort),
        }
      end
      local summaryY = summary.y + 4
      for index, value in ipairs(summaryRows) do
        if index > 4 then break end
        local shown = value.long
        if Font.width(shown) > summaryW and value.short then
          shown = value.short
        end
        drawText(shown, summary.x + 6, summaryY, summaryW,
          value.shade or BLACK)
        summaryY = summaryY + 11
      end

      main = layout.statsMain
      if #availableRows == 0 then return end
      panel(main.x, main.y, main.w, main.h, false)
      rowsY = main.y + 2
      step = math.max(9, math.floor((main.h - 5) / #availableRows))
    end
    local labelW = layout.wide and 62 or 28
    local valueW = 24
    local barX = main.x + 6 + labelW
    local barW = math.max(10, main.w - labelW - valueW - 16)
    local y = rowsY
    for _, row in ipairs(availableRows) do
      local value = stats[row[2]]
      drawText(layout.wide and row[1] or row[4],
        main.x + 6, y + 1, labelW - 2, BLACK)
      gray(BLACK)
      love.graphics.rectangle("fill", barX, y + 2, barW,
        layout.wide and 7 or 5)
      gray(WHITE)
      love.graphics.rectangle("fill", barX + 2, y + 3,
        math.max(1, math.floor((barW - 4) * math.min(255, value) / 255)),
        layout.wide and 3 or 2)
      drawRight(tostring(value), main.x + main.w - 6,
        y + 1, valueW, BLACK)
      y = y + step
    end
  end

  local function familyFor(game, current)
    local parents = {}
    for _, def in pairs(game.data.pokemon or {}) do
      for _, edge in ipairs(def.evolutions or {}) do
        parents[edge.species] = parents[edge.species] or {}
        parents[edge.species][#parents[edge.species] + 1] = {
          def = def, edge = edge,
        }
      end
    end
    local root, guard = current, {}
    while parents[root.id] and parents[root.id][1] and not guard[root.id] do
      guard[root.id] = true
      root = parents[root.id][1].def
    end
    local family, queued = {}, { root }
    local seen = {}
    while #queued > 0 do
      local def = table.remove(queued, 1)
      if not seen[def.id] then
        seen[def.id] = true
        family[#family + 1] = { def = def,
          parent = parents[def.id] and parents[def.id][1] or nil }
        for _, edge in ipairs(def.evolutions or {}) do
          local child = game.data.pokemon[edge.species]
          if child then queued[#queued + 1] = child end
        end
      end
    end
    table.sort(family, function(a, b)
      return (a.def.dex or 9999) < (b.def.dex or 9999)
    end)
    return family
  end

  local function evolutionLabel(game, parent)
    if not parent then return "BASIC SPECIES" end
    local edge = parent.edge or {}
    if edge.method == "LEVEL" then return Strings("EVOLVES AT LV%d", edge.level or 1) end
    if edge.method == "TRADE" then return "EVOLVES BY TRADE" end
    if edge.method == "ITEM" then
      local item = game.data.items and game.data.items[edge.item]
      return Strings("USE %s", item and item.name
        or tostring(edge.item or "STONE"):gsub("_", " "))
    end
    return tostring(edge.method or "EVOLUTION"):gsub("_", " ")
  end

  local function familyGeometry(layout, count, index)
    local columns = layout.wide and math.min(5, math.max(2, count))
      or math.min(3, math.max(2, count))
    local rows = math.max(1, math.ceil(count / columns))
    local gridY = layout.content.y + 20
    local gridH = layout.content.h - 41
    local zero = index - 1
    local col, row = zero % columns, math.floor(zero / columns)
    local cellW = math.floor((layout.content.w - 10) / columns)
    local cardW = math.min(layout.wide and 72 or 48, cellW - 3)
    local groupW = cellW * columns
    local startX = layout.content.x
      + math.floor((layout.content.w - groupW) / 2)
    local cellH = math.floor(gridH / rows)
    local cardH = math.min(60, cellH - 3)
    return {
      x = startX + col * cellW + math.floor((cellW - cardW) / 2),
      y = gridY + row * cellH + math.floor((cellH - cardH) / 2),
      w = cardW, h = cardH,
    }
  end

  local function familySelection(state)
    local family = state.modernDexFamily
      or familyFor(state.game, state.def)
    state.modernDexFamily = family
    local cursor = math.floor(tonumber(state.modernFamilyCursor) or 0)
    if cursor < 1 or cursor > #family then
      cursor = 1
      for index, member in ipairs(family) do
        if member.def.id == state.def.id then cursor = index break end
      end
    end
    state.modernFamilyCursor = cursor
    return family, cursor, family[cursor]
  end

  local function familyMemberKnown(state, member)
    if not member then return false end
    if state.forceOwned and member.def.id == state.def.id then return true end
    local dex = state.game.save.pokedex or { seen = {}, owned = {} }
    return dex.seen and dex.seen[member.def.id]
      or dex.owned and dex.owned[member.def.id]
      or false
  end

  local function drawFamilyPage(state, layout, regions)
    panel(layout.content.x, layout.content.y,
      layout.content.w, layout.content.h, false)
    local family, cursor = familySelection(state)
    drawText(layout.wide and "EVOLUTION FAMILY" or "FAMILY",
      layout.content.x + 6, layout.content.y + 5,
      layout.wide and 140 or 56, DARK)
    drawRight(Strings("%d SPECIES", #family),
      layout.content.x + layout.content.w - 6, layout.content.y + 5,
      80, DARK)
    local selectedParent, selectedKnown
    for index, member in ipairs(family) do
      local rect = familyGeometry(layout, #family, index)
      local selected = index == cursor
      local known = familyMemberKnown(state, member)
      panel(rect.x, rect.y, rect.w, rect.h, selected)
      if not selected then
        gray(DARK)
        chamfer("line", rect.x + 1, rect.y + 1,
          rect.w - 4, rect.h - 4, 2)
      end
      if known then
        drawSprite(state.game, member.def, {
          x = rect.x + 4, y = rect.y + 3,
          w = rect.w - 8, h = rect.h - 17,
        }, regions, true, paletteFor(member.def),
          selected and LIGHT or WHITE)
        drawCentered(member.def.name, rect.x + 2,
          rect.y + rect.h - 10, rect.w - 4,
          selected and WHITE or BLACK)
      else
        drawCentered("?", rect.x + 2,
          rect.y + math.floor((rect.h - 8) / 2), rect.w - 4, DARK)
      end
      if selected then
        selectedParent, selectedKnown = member.parent, known
      end
    end
    drawCentered(selectedKnown
        and evolutionLabel(state.game, selectedParent) or "UNDISCOVERED",
      layout.content.x + 6, layout.content.y + layout.content.h - 14,
      layout.content.w - 12, DARK)
  end

  local function machineSource(game, moveId)
    for _, item in pairs(game.data.items or {}) do
      local machine = item.machine
      if machine and machine.move == moveId then
        local kind = tostring(machine.kind or "TM"):upper()
        return kind, Strings("%s%02d", kind, machine.number or 0), "machine"
      end
    end
    if compatibility.crystal251 and CRYSTAL_TUTOR_MOVES[moveId] then
      return "TUTOR", "TUTOR", "tutor"
    end
    return "TM/HM", "TM/HM", "compatibility"
  end

  local function moveRows(state)
    local levelRows, machineRows = {}, {}
    local added = {}
    for _, id in ipairs(state.def.level1Moves or {}) do
      if not added["1:" .. id] then
        levelRows[#levelRows + 1] = { source = "1", level = 1, id = id,
          kind = "level",
          move = state.game.data.moves and state.game.data.moves[id] }
        added["1:" .. id] = true
      end
    end
    for _, learned in ipairs(state.def.learnset or {}) do
      local key = tostring(learned.level or 1) .. ":" .. tostring(learned.move)
      if not added[key] then
        levelRows[#levelRows + 1] = { source = learned.level
            and tostring(learned.level) or "",
          level = learned.level, id = learned.move, kind = "level",
          move = state.game.data.moves and state.game.data.moves[learned.move] }
        added[key] = true
      end
    end
    table.sort(levelRows, function(a, b)
      return (a.level or 0) < (b.level or 0)
    end)
    for _, id in ipairs(state.def.tmhm or {}) do
      local short, full, kind = machineSource(state.game, id)
      machineRows[#machineRows + 1] = {
        source = short, sourceDetail = full, id = id, kind = kind,
        move = state.game.data.moves and state.game.data.moves[id],
      }
    end
    for _, row in ipairs(machineRows) do levelRows[#levelRows + 1] = row end
    state.modernMoveMachineStart = #levelRows - #machineRows + 1
    return levelRows
  end

  local function moveListState(state, layout)
    local rows = moveRows(state)
    state.modernMoveRows = rows
    local count = #rows
    state.modernMoveCursor = math.max(1,
      math.min(math.floor(state.modernMoveCursor or 1), math.max(1, count)))
    local maxVisible = layout.wide and 7 or 6
    local maxScroll = math.max(0, count - maxVisible)
    state.modernMoveScroll = math.max(0,
      math.min(state.modernMoveScroll or 0, maxScroll))
    if state.modernMoveCursor <= state.modernMoveScroll then
      state.modernMoveScroll = state.modernMoveCursor - 1
    elseif state.modernMoveCursor > state.modernMoveScroll + maxVisible then
      state.modernMoveScroll = state.modernMoveCursor - maxVisible
    end
    return rows, maxVisible
  end

  local function selectedMoveRow(state, layout)
    local rows = moveListState(state, layout)
    return rows[state.modernMoveCursor], rows
  end

  local EFFECT_DETAILS = {
    TWO_TO_FIVE_ATTACKS = "HITS 2 TO 5 TIMES.",
    ATTACK_TWICE = "HITS TWICE.",
    TWINEEDLE = "HITS TWICE AND MAY POISON.",
    RECOIL = "THE USER TAKES RECOIL DAMAGE.",
    DRAIN_HP = "RESTORES HALF THE DAMAGE DEALT.",
    DREAM_EATER = "DRAINS HP FROM A SLEEPING TARGET.",
    SPECIAL_DAMAGE = "DEALS FIXED DAMAGE.",
    SUPER_FANG = "HALVES THE TARGET'S CURRENT HP.",
    OHKO = "KNOCKS OUT THE TARGET IN ONE HIT.",
    CHARGE = "CHARGES BEFORE ATTACKING.",
    FLY = "FLIES UP BEFORE ATTACKING.",
    TRAPPING = "TRAPS THE TARGET FOR SEVERAL TURNS.",
    THRASH_PETAL_DANCE = "ATTACKS REPEATEDLY, THEN CONFUSES THE USER.",
    JUMP_KICK = "MISSING DAMAGES THE USER.",
    EXPLODE = "THE USER FAINTS AFTER ATTACKING.",
    HYPER_BEAM = "THE USER MUST RECHARGE.",
    PAY_DAY = "SCATTERS COINS AFTER BATTLE.",
    SWIFT = "DOES NOT MISS.",
    RAGE = "POWER RISES WHEN THE USER IS HIT.",
    BIDE = "STORES DAMAGE, THEN RETURNS IT.",
    METRONOME = "USES A RANDOM MOVE.",
    MIRROR_MOVE = "COPIES THE TARGET'S LAST MOVE.",
    MIMIC = "COPIES ONE OF THE TARGET'S MOVES.",
  }

  -- Crystal 251 exports the original effect-family name for every imported
  -- move. Its public move rows contain dispatch ids such as
  -- CRYSTAL_EFFECT_43 rather than prose, but the corresponding family
  -- (DoParalyze in this example) is enough to present accurate, useful copy
  -- without exposing or guessing from an opaque byte id.
  local CRYSTAL_EFFECT_DETAILS = {
    NormalHit = "DEALS DAMAGE WITH NO ADDITIONAL EFFECT.",
    DoSleep = "PUTS THE TARGET TO SLEEP.",
    PoisonHit = "DEALS DAMAGE AND MAY POISON THE TARGET.",
    LeechHit = "DRAINS HALF THE DAMAGE DEALT.",
    BurnHit = "DEALS DAMAGE AND MAY BURN THE TARGET.",
    FreezeHit = "DEALS DAMAGE AND MAY FREEZE THE TARGET.",
    ParalyzeHit = "DEALS DAMAGE AND MAY PARALYZE THE TARGET.",
    Selfdestruct = "DEALS HEAVY DAMAGE, THEN THE USER FAINTS.",
    DreamEater = "DRAINS HP FROM A SLEEPING TARGET.",
    MirrorMove = "COPIES THE TARGET'S LAST MOVE.",
    ResetStats = "RESETS ALL STAT CHANGES.",
    Bide = "STORES DAMAGE, THEN RETURNS IT WITH DOUBLE POWER.",
    Rampage = "ATTACKS FOR SEVERAL TURNS, THEN CONFUSES THE USER.",
    ForceSwitch = "FORCES THE TARGET TO SWITCH OR ENDS A WILD BATTLE.",
    MultiHit = "HITS THE TARGET TWO TO FIVE TIMES.",
    Conversion = "CHANGES THE USER'S TYPE TO MATCH ONE OF ITS MOVES.",
    FlinchHit = "DEALS DAMAGE AND MAY MAKE THE TARGET FLINCH.",
    Heal = "RESTORES THE USER'S HP.",
    Toxic = "BADLY POISONS THE TARGET.",
    PayDay = "SCATTERS COINS THAT ARE COLLECTED AFTER BATTLE.",
    LightScreen = "REDUCES SPECIAL DAMAGE FOR THE USER'S SIDE.",
    TriAttack = "MAY BURN, FREEZE, OR PARALYZE THE TARGET.",
    OHKOHit = "KNOCKS OUT THE TARGET IN ONE HIT IF IT LANDS.",
    RazorWind = "CHARGES FIRST, THEN ATTACKS WITH A HIGH CRITICAL-HIT RATE.",
    SuperFang = "HALVES THE TARGET'S CURRENT HP.",
    StaticDamage = "DEALS A FIXED AMOUNT OF DAMAGE.",
    TrapTarget = "TRAPS AND DAMAGES THE TARGET FOR SEVERAL TURNS.",
    Mist = "PREVENTS THE USER'S STATS FROM BEING LOWERED.",
    FocusEnergy = "RAISES THE USER'S CRITICAL-HIT RATE.",
    RecoilHit = "DEALS DAMAGE, BUT ALSO HURTS THE USER.",
    DoConfuse = "CONFUSES THE TARGET.",
    DoPoison = "POISONS THE TARGET.",
    DoParalyze = "PARALYZES THE TARGET.",
    Reflect = "REDUCES PHYSICAL DAMAGE FOR THE USER'S SIDE.",
    SkyAttack = "CHARGES FIRST, THEN ATTACKS AND MAY CAUSE FLINCHING.",
    ConfuseHit = "DEALS DAMAGE AND MAY CONFUSE THE TARGET.",
    PoisonMultiHit = "HITS TWICE AND MAY POISON THE TARGET.",
    Substitute = "USES HP TO CREATE A DECOY.",
    Transform = "COPIES THE TARGET'S APPEARANCE, STATS, AND MOVES.",
    HyperBeam = "DEALS HEAVY DAMAGE; THE USER MUST RECHARGE.",
    Rage = "THE USER'S ATTACK RISES WHEN IT IS HIT.",
    Mimic = "COPIES ONE OF THE TARGET'S MOVES.",
    Metronome = "USES A RANDOM MOVE.",
    LeechSeed = "PLANTS A SEED THAT DRAINS HP EACH TURN.",
    Splash = "HAS NO EFFECT.",
    Disable = "TEMPORARILY DISABLES ONE OF THE TARGET'S MOVES.",
    Psywave = "DEALS DAMAGE BASED ON THE USER'S LEVEL.",
    Counter = "RETURNS DOUBLE THE PHYSICAL DAMAGE RECEIVED.",
    Encore = "MAKES THE TARGET REPEAT ITS LAST MOVE.",
    PainSplit = "SHARES THE USER'S AND TARGET'S COMBINED HP.",
    Snore = "CAN BE USED WHILE ASLEEP AND MAY CAUSE FLINCHING.",
    Conversion2 = "CHANGES THE USER'S TYPE TO RESIST THE LAST MOVE USED.",
    LockOn = "MAKES THE USER'S NEXT ATTACK HIT.",
    Sketch = "PERMANENTLY COPIES THE TARGET'S LAST MOVE.",
    DefrostOpponent = "DEALS DAMAGE AND THAWS A FROZEN TARGET.",
    SleepTalk = "USES A RANDOM KNOWN MOVE WHILE THE USER IS ASLEEP.",
    DestinyBond = "IF THE USER FAINTS, THE TARGET FAINTS TOO.",
    Reversal = "GROWS STRONGER AS THE USER'S HP FALLS.",
    Spite = "REDUCES THE PP OF THE TARGET'S LAST MOVE.",
    FalseSwipe = "LEAVES THE TARGET WITH AT LEAST 1 HP.",
    HealBell = "CURES STATUS CONDITIONS ACROSS THE USER'S PARTY.",
    TripleKick = "KICKS THREE TIMES, GROWING STRONGER EACH HIT.",
    Thief = "STEALS THE TARGET'S HELD ITEM.",
    MeanLook = "PREVENTS THE TARGET FROM ESCAPING OR SWITCHING.",
    Nightmare = "HURTS A SLEEPING TARGET EACH TURN.",
    FlameWheel = "MAY BURN THE TARGET AND CAN THAW THE USER.",
    Curse = "HAS A DIFFERENT EFFECT FOR GHOST-TYPE USERS.",
    Protect = "BLOCKS ATTACKS, BUT MAY FAIL IF USED REPEATEDLY.",
    Spikes = "SCATTERS HAZARDS THAT DAMAGE SWITCHING TARGETS.",
    Foresight = "NEGATES THE TARGET'S EVASION AND REVEALS GHOST TYPES.",
    PerishSong = "MAKES ALL ACTIVE POKéMON FAINT AFTER THREE TURNS.",
    Sandstorm = "SUMMONS A SANDSTORM FOR FIVE TURNS.",
    Endure = "LEAVES THE USER WITH AT LEAST 1 HP.",
    Rollout = "ATTACKS REPEATEDLY AND GROWS STRONGER EACH TURN.",
    Swagger = "SHARPLY RAISES THE TARGET'S ATTACK, THEN CONFUSES IT.",
    FuryCutter = "GROWS STRONGER WITH EACH CONSECUTIVE HIT.",
    Attract = "MAY INFATUATE A TARGET OF THE OPPOSITE GENDER.",
    Return = "GROWS STRONGER THE MORE THE USER LIKES ITS TRAINER.",
    Present = "MAY DAMAGE THE TARGET OR RESTORE ITS HP.",
    Frustration = "GROWS STRONGER THE LESS THE USER LIKES ITS TRAINER.",
    Safeguard = "PROTECTS THE USER'S SIDE FROM STATUS CONDITIONS.",
    SacredFire = "DEALS DAMAGE AND MAY BURN THE TARGET.",
    Magnitude = "DEALS DAMAGE WITH RANDOM POWER.",
    BatonPass = "SWITCHES OUT AND PASSES STAT CHANGES TO A TEAMMATE.",
    Pursuit = "DEALS EXTRA DAMAGE TO A TARGET THAT IS SWITCHING.",
    RapidSpin = "REMOVES BINDING EFFECTS AND ENTRY HAZARDS.",
    MorningSun = "RESTORES HP; THE AMOUNT DEPENDS ON THE WEATHER.",
    Synthesis = "RESTORES HP; THE AMOUNT DEPENDS ON THE WEATHER.",
    Moonlight = "RESTORES HP; THE AMOUNT DEPENDS ON THE WEATHER.",
    HiddenPower = "ITS TYPE AND POWER DEPEND ON THE USER'S DVS.",
    RainDance = "SUMMONS RAIN FOR FIVE TURNS.",
    SunnyDay = "INTENSIFIES SUNLIGHT FOR FIVE TURNS.",
    AllUpHit = "DEALS DAMAGE AND MAY RAISE ALL OF THE USER'S STATS.",
    FakeOut = "STRIKES FIRST AND CAUSES FLINCHING ON THE OPENING TURN.",
    BellyDrum = "USES HALF THE USER'S HP TO MAXIMIZE ATTACK.",
    PsychUp = "COPIES THE TARGET'S STAT CHANGES.",
    MirrorCoat = "RETURNS DOUBLE THE SPECIAL DAMAGE RECEIVED.",
    SkullBash = "RAISES DEFENSE WHILE CHARGING, THEN ATTACKS.",
    Twister = "MAY CAUSE FLINCHING AND CAN HIT A FLYING TARGET.",
    Earthquake = "HITS A TARGET UNDERGROUND WITH DOUBLE POWER.",
    FutureSight = "ATTACKS THE TARGET TWO TURNS LATER.",
    Gust = "HITS A FLYING TARGET WITH DOUBLE POWER.",
    Stomp = "MAY CAUSE FLINCHING; STRONGER AGAINST MINIMIZED TARGETS.",
    Solarbeam = "CHARGES FIRST, THEN ATTACKS; SUNLIGHT SKIPS THE CHARGE.",
    Thunder = "MAY PARALYZE; MORE ACCURATE IN RAIN.",
    Teleport = "ESCAPES A WILD BATTLE.",
    BeatUp = "THE PARTY JOINS IN TO ATTACK THE TARGET.",
    Fly = "FLIES UP FIRST, THEN ATTACKS ON THE NEXT TURN.",
    DefenseCurl = "RAISES DEFENSE AND STRENGTHENS ROLLOUT.",
  }

  local CRYSTAL_STAT_NAMES = {
    Attack = "ATTACK", Defense = "DEFENSE", Speed = "SPEED",
    SpecialAttack = "SPECIAL ATTACK", SpecialDefense = "SPECIAL DEFENSE",
    Accuracy = "ACCURACY", Evasion = "EVASION",
  }

  local function crystalEffectDetail(move)
    local scripts = compatibility.crystalMoveScripts
    local script = type(scripts) == "table" and scripts[move.id] or nil
    local name = type(script) == "table" and script.effectName or nil
    if not name then return nil end
    if CRYSTAL_EFFECT_DETAILS[name] then
      return CRYSTAL_EFFECT_DETAILS[name]
    end
    local stat, direction, suffix = name:match("^(.-)(Up)(.*)$")
    if not stat then
      stat, direction, suffix = name:match("^(.-)(Down)(.*)$")
    end
    local label = stat and CRYSTAL_STAT_NAMES[stat]
    if label and (suffix == "" or suffix == "2" or suffix == "Hit") then
      local verb = direction == "Up" and "RAISE" or "LOWER"
      local owner = direction == "Up" and "USER'S" or "TARGET'S"
      local amount = suffix == "2" and "SHARPLY " or ""
      if suffix == "Hit" then
        return "DEALS DAMAGE AND MAY " .. verb .. " THE " .. owner
          .. " " .. label .. "."
      end
      return amount .. verb .. "S THE " .. owner .. " " .. label .. "."
    end
    return nil
  end

  local function moveEffectDetail(game, move)
    local supplied = move.description or move.desc or move.text
    if supplied ~= nil and tostring(supplied) ~= "" then
      local resolved = type(supplied) == "string" and game.data.text
          and game.data.text[supplied] or supplied
      return Strings(tostring(resolved))
    end
    local crystalDetail = crystalEffectDetail(move)
    if crystalDetail then return crystalDetail end
    local effect = tostring(move.effect or "")
    if effect == "" then return nil end
    if effect == "NO_ADDITIONAL_EFFECT" then
      if tonumber(move.power or 0) > 0 then
        return "DEALS DAMAGE WITH NO ADDITIONAL EFFECT."
      end
      return "HAS NO ADDITIONAL EFFECT."
    end
    local clean = effect:gsub("_EFFECT%d*$", ""):gsub("_SIDE$", "")
    if EFFECT_DETAILS[clean] then return EFFECT_DETAILS[clean] end
    local statuses = {
      BURN = "MAY BURN THE TARGET.",
      FREEZE = "MAY FREEZE THE TARGET.",
      PARALYZE = "MAY PARALYZE THE TARGET.",
      POISON = "MAY POISON THE TARGET.",
      CONFUSION = "MAY CONFUSE THE TARGET.",
      FLINCH = "MAY MAKE THE TARGET FLINCH.",
      SLEEP = "MAY PUT THE TARGET TO SLEEP.",
    }
    if statuses[clean] then return statuses[clean] end
    local stat, direction = clean:match(
      "^(ATTACK|DEFENSE|SPEED|SPECIAL|ACCURACY|EVASION)_(UP|DOWN)")
    if stat then
      return direction == "UP" and ("RAISES THE USER'S " .. stat .. ".")
        or ("MAY LOWER THE TARGET'S " .. stat .. ".")
    end
    if type(compatibility.moveEffectText) == "function"
        and not effect:match("^CRYSTAL_EFFECT_%x%x$") then
      local ok, detail = pcall(compatibility.moveEffectText, effect)
      if ok and type(detail) == "string" and detail ~= "" then
        return Strings(detail):upper() .. "."
      end
    end
    -- Effect ids are battle-dispatch keys, not player-facing descriptions.
    -- Compatibility mods such as Crystal 251 intentionally expose opaque
    -- values like CRYSTAL_EFFECT_43; humanising those identifiers fabricates
    -- prose the data never supplied. Unknown ids therefore create no panel.
    return nil
  end

  local function moveCategory(move)
    local category = move.category
    if category == nil and move.power ~= nil then
      category = tonumber(move.power) == 0 and "status"
        or TypeChart.category(move.type)
    end
    category = category and tostring(category):upper() or nil
    if category == "PHYSICAL" then return "PHYS" end
    if category == "SPECIAL" then return "SPEC" end
    return category
  end

  local function drawMovesPage(state, layout)
    panel(layout.content.x, layout.content.y,
      layout.content.w, layout.content.h, false)
    local rows, maxVisible = moveListState(state, layout)
    local hasTutor = false
    for _, row in ipairs(rows) do
      if row.kind == "tutor" then hasTutor = true break end
    end
    local heading = hasTutor
      and (layout.wide and "LEVEL/TM-HM/TUTOR" or "LV/TM/HM/TUT")
      or (layout.wide and "LEVEL UP/TM-HM" or "LV/TM-HM")
    drawText(heading,
      layout.content.x + 6, layout.content.y + 5,
      layout.content.w - 42, DARK)
    drawRight("PP",
      layout.content.x + layout.content.w - 6, layout.content.y + 5,
      24, DARK)
    local y = layout.content.y + 18
    for visible = 1, maxVisible do
      local index = state.modernMoveScroll + visible
      local row = rows[index]
      if not row then break end
      local move = row.move or { name = row.id }
      local selected = index == state.modernMoveCursor
      gray(selected and DARK or LIGHT)
      chamfer("fill", layout.content.x + 5, y,
        layout.content.w - 10, 12, 2)
      if selected then
        gray(WHITE)
        love.graphics.rectangle("fill", layout.content.x + 7, y + 4, 3, 3)
      end
      local source = row.kind == "level"
        and row.source or (row.sourceDetail or row.source)
      local sourceWidth = row.kind == "level" and 17
        or math.min(42, Font.width(Strings(tostring(source or ""))) + 2)
      drawText(source, layout.content.x + 12, y + 2, sourceWidth,
        selected and WHITE or DARK)
      drawText(move.name or row.id,
        layout.content.x + 14 + sourceWidth, y + 2,
        layout.content.w - sourceWidth - 45,
        selected and WHITE or BLACK)
      if move.pp ~= nil then
        drawRight(tostring(move.pp),
          layout.content.x + layout.content.w - 9, y + 2, 24,
          selected and WHITE or DARK)
      end
      y = y + 14
    end
  end

  local function drawMoveDetail(state, layout)
    panel(layout.content.x, layout.content.y,
      layout.content.w, layout.content.h, false)
    local row = selectedMoveRow(state, layout)
    if not row then return end
    local move = row.move or { name = row.id }
    local x, y, w = layout.content.x + 5,
      layout.content.y + 5, layout.content.w - 10
    gray(LIGHT)
    chamfer("fill", x, y, w, 28, 3)
    drawText(move.name or row.id, x + 6, y + 4,
      w - (layout.wide and 86 or 54), BLACK)
    local source = row.kind == "level"
      and Strings("LEVEL %s", tostring(row.source or "?"))
      or tostring(row.sourceDetail or row.source or "COMPATIBLE")
    drawText(source, x + 6, y + 15, w - 70, DARK)
    if move.type then
      drawTypeChip(translatedTypeName(move.type),
        x + w - (layout.wide and 70 or 48),
        y + 8, layout.wide and 64 or 42)
    end

    local facts = {}
    if move.power ~= nil then
      facts[#facts + 1] = { "PWR", tostring(move.power) }
    end
    if move.accuracy ~= nil then
      facts[#facts + 1] = { "ACC", tostring(move.accuracy) .. "%" }
    end
    if move.pp ~= nil then facts[#facts + 1] = { "PP", tostring(move.pp) } end
    local category = moveCategory(move)
    if category then facts[#facts + 1] = { "CLASS", category } end
    if move.priority ~= nil then
      facts[#facts + 1] = { "PRIORITY", tostring(move.priority) }
    end

    -- A fifth wide column is preferable to a second tall fact row: it keeps
    -- enough vertical room for the move description on priority moves.
    local columns = math.min(layout.wide and 5 or 4,
      math.max(1, #facts))
    local factRows = math.max(0, math.ceil(#facts / columns))
    local factY = y + 33
    local cellH = layout.wide and 27 or 21
    for index, fact in ipairs(facts) do
      local zero = index - 1
      local column, factRow = zero % columns, math.floor(zero / columns)
      local x1 = x + math.floor(column * w / columns)
      local x2 = x + math.floor((column + 1) * w / columns)
      local cellY = factY + factRow * cellH
      gray(WHITE)
      chamfer("fill", x1 + 1, cellY, x2 - x1 - 3, cellH - 3, 2)
      local shortLabels = (not layout.wide or columns >= 5) and {
        CLASS = "CAT", PRIORITY = "PRI",
      } or nil
      local factLabel = shortLabels and shortLabels[fact[1]] or fact[1]
      drawCentered(factLabel, x1 + 3, cellY + 2, x2 - x1 - 7, DARK)
      drawCentered(fact[2], x1 + 3, cellY + 11, x2 - x1 - 7, BLACK)
    end

    local detail = moveEffectDetail(state.game, move)
    local detailY = factY + factRows * cellH + 1
    local detailH = layout.content.y + layout.content.h - detailY - 4
    if detail and detailH >= 16 then
      gray(WHITE)
      chamfer("fill", x + 1, detailY, w - 2, detailH, 2)
      drawText("EFFECT", x + 6, detailY + 3, 48, DARK)
      local lines = wrappedLines(detail, w - 12,
        math.max(1, math.floor((detailH - 12) / 9)))
      local lineY = detailY + 12
      for _, line in ipairs(lines) do
        drawText(line, x + 6, lineY, w - 12, BLACK)
        lineY = lineY + 9
      end
    end
  end

  local function hasStatsData(def)
    for _, row in ipairs(STAT_ROWS) do
      if def.baseStats and def.baseStats[row[2]] ~= nil then return true end
    end
    return def.catchRate ~= nil or def.baseExp ~= nil
      or def.growthRate ~= nil
  end

  local function pageContext(state, layout, regions)
    return {
      game = state.game, state = state, def = state.def,
      owned = entryOwned(state), layout = layout, regions = regions,
      colors = { white = WHITE, light = LIGHT, dark = DARK, black = BLACK },
      draw = {
        panel = panel, text = drawText, right = drawRight,
        centered = drawCentered, sprite = drawSprite, icon = drawIcon,
      },
    }
  end

  local function resolveExtraRows(page, state)
    if type(page._modernResolvedRows) == "table" then
      return page._modernResolvedRows
    end
    local rows = page.rows
    if type(rows) == "function" then
      local ok, value = pcall(rows, pageContext(state))
      rows = ok and value or nil
      if not ok then
        Logger.warn("Modern Pokedex page %s rows failed: %s",
          tostring(page.id or page.label or "?"), tostring(value))
      end
    end
    local available = {}
    for _, row in ipairs(type(rows) == "table" and rows or {}) do
      if type(row) == "table" then
        local value = row.value
        if type(value) == "function" then
          local ok, resolved = pcall(value, pageContext(state))
          value = ok and resolved or nil
        end
        if value ~= nil and tostring(value) ~= "" then
          available[#available + 1] = {
            label = row.label, value = value,
            palette = row.palette,
          }
        end
      end
    end
    page._modernResolvedRows = available
    return available
  end

  local function buildEntryPages(state)
    local family = state.modernDexFamily or familyFor(state.game, state.def)
    state.modernDexFamily = family
    local moves = moveRows(state)
    local pages = { { id = "info", label = "INFO", shortLabel = "INFO" } }
    if hasStatsData(state.def) then
      pages[#pages + 1] = {
        id = "stats", label = "STATS", shortLabel = "STAT",
      }
    end
    if #family > 1 then
      pages[#pages + 1] = {
        id = "family", label = "FAMILY", shortLabel = "EVO",
      }
    end
    if #moves > 0 then
      pages[#pages + 1] = {
        id = "moves", label = "MOVES", shortLabel = "MOVE",
      }
    end

    local hooked = Runtime.call("ui.pokedex.pages",
      function(_, current) return current end,
      state.game, pages, pageContext(state))
    if type(hooked) ~= "table" then hooked = pages end

    local usable, ids = {}, {}
    for _, page in ipairs(hooked) do
      if type(page) == "table" then
        local id = tostring(page.id or ""):lower()
        local available = id ~= ""
        if type(page.available) == "function" then
          local ok, value = pcall(page.available, pageContext(state))
          available = available and ok and value == true
        elseif page.available ~= nil then
          available = available and page.available == true
        end
        local builtIn = id == "info" or id == "stats"
          or id == "family" or id == "moves"
        if not builtIn and type(page.draw) ~= "function" then
          available = available and #resolveExtraRows(page, state) > 0
        end
        if available and not ids[id] then
          page.id = id
          page.label = tostring(page.label or id):upper()
          usable[#usable + 1], ids[id] = page, true
        end
      end
    end
    if #usable == 0 then usable[1] = { id = "info", label = "INFO" } end
    return usable
  end

  local function drawExtraPage(state, page, layout, regions)
    if type(page.draw) == "function" then
      local ok, err = pcall(page.draw, pageContext(state, layout, regions))
      if not ok then
        Logger.warn("Modern Pokedex page %s draw failed: %s",
          tostring(page.id), tostring(err))
      end
      return
    end
    local rows = resolveExtraRows(page, state)
    if #rows == 0 then return end
    panel(layout.content.x, layout.content.y,
      layout.content.w, layout.content.h, false)
    drawText(page.title or page.label, layout.content.x + 6,
      layout.content.y + 5, layout.content.w - 12, DARK)
    local maxRows = layout.wide and 8 or 7
    local y = layout.content.y + 20
    for index = 1, math.min(maxRows, #rows) do
      local row = rows[index]
      if index % 2 == 0 then
        gray(LIGHT)
        chamfer("fill", layout.content.x + 5, y - 2,
          layout.content.w - 10, 13, 2)
      end
      if row.label and tostring(row.label) ~= "" then
        drawText(row.label, layout.content.x + 9, y,
          math.floor(layout.content.w * 0.42), DARK)
      end
      drawRight(tostring(row.value),
        layout.content.x + layout.content.w - 9, y,
        math.floor(layout.content.w * 0.54), BLACK)
      y = y + 13
    end
  end

  local function drawEntry(state, forcedWidth)
    clearInheritedUiTrueColor()
    local width = forcedWidth or select(1, state:uiSize())
    local renderer = not forcedWidth and state.game and state.game.renderer
    if renderer and renderer.uiSize then
      width = select(1, renderer:uiSize()) or width
    end
    local layout = entryLayout(width)
    local regions = {}
    backdrop({ width = layout.width, height = SCREEN_H, footerY = 134 })
    drawEntryHeader(state, layout)
    local page = entryPage(state)
    if page.id == "stats" then
      drawStatsPage(state, layout, regions)
    elseif page.id == "family" then
      drawFamilyPage(state, layout, regions)
    elseif page.id == "moves" then
      if state.modernMoveDetail then
        drawMoveDetail(state, layout)
      else
        drawMovesPage(state, layout)
      end
    elseif page.id == "info" then
      drawInfoPage(state, layout, regions)
    else
      drawExtraPage(state, page, layout, regions)
    end

    gray(DARK)
    love.graphics.rectangle("fill", 0, layout.footerY,
      layout.width, SCREEN_H - layout.footerY)
    if state.modernDexTabbed then
      local tight = not layout.wide and layout.width < 176
      local right
      if state.modernMoveDetail then
        right = "B LIST"
      elseif page.id == "family" then
        right = layout.wide and "A VIEW B BACK" or "A VIEW B"
      elseif page.id == "moves" then
        right = layout.wide and "A VIEW B BACK" or "A VIEW B"
      elseif page.footer then
        right = type(page.footer) == "function"
          and page.footer(pageContext(state, layout, regions)) or page.footer
      elseif page.onAction then
        right = tight and "A ACT B BACK" or "A ACTION  B BACK"
      else
        right = layout.wide and "A CRY  B BACK" or "A CRY B BACK"
      end
      local left
      local roomy = layout.width >= 300
      if state.modernMoveDetail then
        left = layout.wide and "MOVE DETAILS" or "MOVE DATA"
      elseif page.id == "family" then
        left = roomy and "L/R  U/D SELECT"
          or tight and "LR UD" or "L/R U/D"
      elseif page.id == "moves" then
        left = roomy and "L/R  U/D MOVE"
          or tight and "LR UD" or "L/R U/D"
      elseif page.id == "info" and state.modernInfoCanScroll then
        left = layout.wide and "L/R  U/D NOTES"
          or tight and "LR UD" or "L/R U/D"
      else
        left = layout.wide and "LEFT/RIGHT TAB"
          or tight and "LR TAB" or "L/R TAB"
      end
      local leftWidth = 0
      if #entryPages(state) > 1 then
        leftWidth = drawText(left, 5, layout.footerY + 2,
          Font.width(left), WHITE)
      end
      local gap = leftWidth > 0 and 6 or 0
      local rightWidth = math.max(0,
        layout.width - 10 - leftWidth - gap)
      drawRight(right, layout.width - 5, layout.footerY + 2,
        rightWidth, LIGHT)
    else
      local lines = state.modernInfoLines or {}
      local visible = state.modernInfoVisible or #lines
      local hasMore = (state.modernInfoScroll or 0)
        < math.max(0, #lines - visible)
      drawText(hasMore and "A MORE  B CLOSE" or "A/B CLOSE",
        5, layout.footerY + 2, hasMore and 112 or 80, WHITE)
      if layout.wide and not hasMore then
        drawRight("MODERN RESEARCH FILE", layout.width - 5,
          layout.footerY + 2, 152, LIGHT)
      elseif not hasMore then
        drawRight("RESEARCH", layout.width - 5,
          layout.footerY + 2, 64, LIGHT)
      end
    end
    for _, rect in ipairs(regions) do
      PaletteFX.markTrueColor(rect.x, rect.y, rect.w, rect.h)
    end
    gray(WHITE)
  end

  local function entryZones(state, game)
    local width = select(1, state:uiSize())
    local renderer = game and game.renderer
    if renderer and renderer.uiSize then width = select(1, renderer:uiSize()) end
    local layout = entryLayout(width)
    local base = basePalette(game)
    local primary = paletteFor(state.def)
    local page = entryPage(state)
    local zones = { { colors = base, x = 0, y = 0,
      w = layout.width, h = SCREEN_H },
      { colors = PaletteFX.pal(game.data, "REDMON") or base,
        x = 0, y = 0, w = layout.width, h = HEADER_H },
      { colors = PaletteFX.pal(game.data, "CYANMON") or base,
        x = 0, y = layout.footerY, w = layout.width,
        h = SCREEN_H - layout.footerY },
    }
    if page.id == "info" then
      local profile = layout.infoProfile or layout.profile
      zones[#zones + 1] = { colors = primary,
        x = profile.x, y = profile.y,
        w = profile.w, h = profile.h }
      zones[#zones + 1] = { colors = primary,
        x = layout.info.x, y = layout.info.y,
        w = layout.info.w, h = layout.info.h }
      local types = state.def.types or {}
      local available = layout.info.w - 12
      local two = types[2] and types[2] ~= types[1]
      local chipW = two and math.floor((available - 3) / 2) or available
      local chipY = layout.info.y + layout.info.h - 16
      if types[1] then
        zones[#zones + 1] = { colors = paletteFor({ types = { types[1] } }),
          x = layout.info.x + 6, y = chipY, w = chipW, h = 11 }
      end
      if types[1] and two then
        zones[#zones + 1] = { colors = paletteFor({ types = { types[2] } }),
          x = layout.info.x + 9 + chipW, y = chipY, w = chipW, h = 11 }
      end
    elseif page.id == "stats" then
      local profile = layout.statsProfile or layout.profile
      zones[#zones + 1] = { colors = primary,
        x = profile.x, y = profile.y,
        w = profile.w, h = profile.h }
      local main = layout.wide and layout.main or layout.statsMain
      local y = layout.wide and (main.y + 20) or (main.y + 2)
      local availableRows = {}
      for _, row in ipairs(STAT_ROWS) do
        if state.def.baseStats and state.def.baseStats[row[2]] ~= nil then
          availableRows[#availableRows + 1] = row
        end
      end
      local step = #availableRows > 0 and (layout.wide
          and math.min(16, math.floor(82 / #availableRows))
          or math.max(9, math.floor((main.h - 5) / #availableRows))) or 16
      for _, row in ipairs(availableRows) do
        zones[#zones + 1] = { colors = PaletteFX.pal(game.data, row[3])
            or primary, x = main.x, y = y,
          w = main.w, h = layout.wide and 12 or math.min(9, step) }
        y = y + step
      end
    elseif page.id == "family" then
      local family = state.modernDexFamily or familyFor(game, state.def)
      state.modernDexFamily = family
      for index, member in ipairs(family) do
        local rect = familyGeometry(layout, #family, index)
        zones[#zones + 1] = { colors = paletteFor(member.def),
          x = rect.x, y = rect.y, w = rect.w, h = rect.h }
      end
    elseif page.id == "moves" then
      if state.modernMoveDetail then
        local row = selectedMoveRow(state, layout)
        local move = row and row.move or nil
        if move and move.type then
          zones[#zones + 1] = {
            colors = paletteFor({ types = { move.type } }),
            x = layout.content.x + 5, y = layout.content.y + 5,
            w = layout.content.w - 10, h = 28,
          }
        end
      else
        local rows = state.modernMoveRows or moveRows(state)
        local maxVisible = layout.wide and 7 or 6
        local y = layout.content.y + 18
        for visible = 1, maxVisible do
          local row = rows[(state.modernMoveScroll or 0) + visible]
          if not row then break end
          local move = row.move or {}
          zones[#zones + 1] = {
            colors = paletteFor({ types = { move.type } }),
            x = layout.content.x + 5, y = y,
            w = layout.content.w - 10, h = 12,
          }
          y = y + 14
        end
      end
    else
      local extra = page.zones
      if type(extra) == "function" then
        local ok, value = pcall(extra, pageContext(state, layout))
        extra = ok and value or nil
      end
      if type(extra) == "table" then
        for _, zone in ipairs(extra) do
          if type(zone) == "table" then zones[#zones + 1] = zone end
        end
      elseif type(page.palette) == "table" then
        zones[#zones + 1] = { colors = page.palette,
          x = layout.content.x, y = layout.content.y,
          w = layout.content.w, h = layout.content.h }
      end
    end
    return zones
  end

  local function moveFamilySelection(state, delta)
    local family, cursor = familySelection(state)
    if #family < 2 then return end
    state.modernFamilyCursor = (cursor - 1 + delta) % #family + 1
  end

  local function currentEntryLayout(state)
    local width = select(1, state:uiSize())
    local renderer = state.game and state.game.renderer
    if renderer and renderer.uiSize then
      width = select(1, renderer:uiSize()) or width
    end
    return entryLayout(width)
  end

  local function resetMoveSelection(state)
    state.modernMoveCursor = 1
    state.modernMoveScroll = 0
    state.modernMoveRows = nil
    state.modernMoveDetail = false
  end

  local function moveMoveSelection(state, delta)
    local layout = currentEntryLayout(state)
    local rows = moveListState(state, layout)
    if #rows == 0 then return end
    state.modernMoveCursor = math.max(1,
      math.min(#rows, state.modernMoveCursor + delta))
    moveListState(state, layout)
  end

  local function moveInfoScroll(state, delta)
    local lines = state.modernInfoLines or {}
    local visible = state.modernInfoVisible or #lines
    local maxScroll = math.max(0, #lines - visible)
    state.modernInfoScroll = math.max(0,
      math.min(maxScroll, (state.modernInfoScroll or 0) + delta))
  end

  local function syncDexListSelection(state, species)
    local list = state.modernDexSource
    if not (list and type(list.modernDexEntries) == "table") then return end
    local function selectSpecies()
      for index, row in ipairs(list.modernDexEntries) do
        if row.def and row.def.id == species then
          list.index = index
          local rows = math.max(1, list.rows or activeLayout(list).rows)
          if index <= list.scroll then
            list.scroll = index - 1
          elseif index > list.scroll + rows then
            list.scroll = index - rows
          end
          return true
        end
      end
      return false
    end
    if selectSpecies() then return end
    -- A viewed evolution can sit outside the active letter/type filter. Clear
    -- it so returning to the index can still focus the species just opened.
    if list.modernDexLetter or list.modernDexType then
      applyDexFilter(list, false, false)
      selectSpecies()
    end
  end

  local function viewFamilySelection(state)
    local _, _, member = familySelection(state)
    if not familyMemberKnown(state, member) then return false end
    state.def = member.def
    state.forceOwned = false
    state.modernDexFamily = nil
    state.modernFamilyCursor = nil
    resetMoveSelection(state)
    state.modernInfoScroll = 0
    state.modernDexPages = buildEntryPages(state)
    state.modernDexPage = 1
    syncDexListSelection(state, state.def.id)
    require("src.core.Sound").playCry(state.game.data, state.def.id)
    return true
  end

  local function makeEntry(game, speciesOrOpts, onDone)
    local source = game.stack and game.stack:top()
    local state = BuiltinDexEntry.new(game, speciesOrOpts, onDone)
    local nativeUpdate = state.update
    state.modernPokedexEntry = true
    state.modernDexTabbed = source and source.modernPokedexUI == true or false
    state.modernDexSource = state.modernDexTabbed and source or nil
    state.modernDexPage = 1
    state.modernFamilyCursor = nil
    state.modernMoveCursor = 1
    state.modernMoveScroll = 0
    state.modernMoveDetail = false
    state.modernInfoScroll = 0
    state.modernDexClock = 0
    state.uiSize = uiSize
    state.isWideBattleLayout = function()
      return setting("responsive", true)
    end
    state.modernDexPages = buildEntryPages(state)
    state.update = function(self, dt)
      self.modernDexClock = (self.modernDexClock + 1) % 32000
      if not self.modernDexTabbed then
        local input = self.game.input
        local lines = self.modernInfoLines or {}
        local visible = self.modernInfoVisible or #lines
        local maxScroll = math.max(0, #lines - visible)
        if input:wasPressed("a")
            and (self.modernInfoScroll or 0) < maxScroll then
          require("src.core.Sound").play(self.game.data, "Press_AB")
          moveInfoScroll(self, math.max(1, visible))
          return
        end
        nativeUpdate(self, dt)
        return
      end
      local input = self.game.input
      if self.modernMoveDetail then
        if input:wasPressed("b") then
          require("src.core.Sound").play(self.game.data, "Press_AB")
          self.modernMoveDetail = false
        end
        return
      elseif input:wasPressed("b") then
        require("src.core.Sound").play(self.game.data, "Press_AB")
        self.game.stack:pop()
        if self.onDone then self.onDone() end
      elseif input:wasPressed("left") then
        local count = #entryPages(self)
        self.modernDexPage = (self.modernDexPage - 2) % count + 1
        resetMoveSelection(self)
        self.modernInfoScroll = 0
      elseif input:wasPressed("right") then
        local count = #entryPages(self)
        self.modernDexPage = self.modernDexPage % count + 1
        resetMoveSelection(self)
        self.modernInfoScroll = 0
      elseif input:wasPressed("a") then
        local page = entryPage(self)
        if page.id == "family" then
          viewFamilySelection(self)
        elseif page.id == "moves" then
          local row = selectedMoveRow(self, currentEntryLayout(self))
          if row then
            require("src.core.Sound").play(self.game.data, "Press_AB")
            self.modernMoveDetail = true
          end
        elseif type(page.onAction) == "function" then
          local ok, err = pcall(page.onAction, pageContext(self))
          if not ok then
            Logger.warn("Modern Pokedex page %s action failed: %s",
              tostring(page.id), tostring(err))
          end
        else
          require("src.core.Sound").playCry(self.game.data, self.def.id)
        end
      elseif entryPage(self).id == "family" and input:wasPressed("up") then
        moveFamilySelection(self, -1)
      elseif entryPage(self).id == "family" and input:wasPressed("down") then
        moveFamilySelection(self, 1)
      elseif entryPage(self).id == "moves" and input:wasPressed("up") then
        moveMoveSelection(self, -1)
      elseif entryPage(self).id == "moves" and input:wasPressed("down") then
        moveMoveSelection(self, 1)
      elseif entryPage(self).id == "info" and input:wasPressed("up") then
        moveInfoScroll(self, -1)
      elseif entryPage(self).id == "info" and input:wasPressed("down") then
        moveInfoScroll(self, 1)
      else
        local page = entryPage(self)
        if type(page.update) == "function" then
          local ctx = pageContext(self)
          ctx.input, ctx.dt = input, dt
          local ok, err = pcall(page.update, ctx)
          if not ok then
            Logger.warn("Modern Pokedex page %s update failed: %s",
              tostring(page.id), tostring(err))
          end
        end
      end
    end
    state.draw = drawEntry
    state.sgbPalettes = entryZones
    return state
  end

  return {
    pokedex = { new = makePokedex },
    entry = {
      new = makeEntry,
      -- The Yellow printer deliberately keeps the native compact print
      -- renderer. Printed PNGs are an archival Gen I feature, while every
      -- interactive Pokédex surface uses the modern presentation above.
      render = BuiltinDexEntry.render,
    },
  }
end
