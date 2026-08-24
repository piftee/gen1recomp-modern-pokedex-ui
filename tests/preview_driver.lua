-- Visual smoke test. Enable Modern Pokedex UI, then run from the repository root:
--   SHOT_DIR=/tmp/modern-pokedex-ui \
--   POKEPORT_DRIVER=mods/modern_pokedex_ui/tests/preview_driver.lua \
--   POKEPORT_IDENTITY=modern-pokedex-preview POKEPORT_VERSION=red love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local OptionsMenu = require("src.ui.OptionsMenu")
  local PaletteFX = require("src.render.PaletteFX")
  local Screens = require("src.ui.Screens")
  local Sprites = require("src.pokemon.Sprites")
  local Strings = require("src.core.Strings")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/modern-pokedex-ui"

  love.window.setMode(1280, 720, {
    resizable = true, minwidth = 640, minheight = 576,
  })
  game.save.options = game.save.options or {}
  game.save.options.colors = "redpp"
  local function setTheme(value)
    game.save.options.modOptions = game.save.options.modOptions or {}
    game.save.options.modOptions.modern_pokedex_ui =
      game.save.options.modOptions.modern_pokedex_ui or {}
    game.save.options.modOptions.modern_pokedex_ui.theme = value
    if game.mods then
      game.mods.modOptions = game.mods.modOptions or {}
      game.mods.modOptions.modern_pokedex_ui =
        game.mods.modOptions.modern_pokedex_ui or {}
      game.mods.modOptions.modern_pokedex_ui.theme = value
    end
  end
  PaletteFX.setMode("redpp")
  game.save.pokedex = { seen = {}, owned = {} }
  for id in pairs(game.data.pokemon or {}) do
    game.save.pokedex.seen[id] = true
    game.save.pokedex.owned[id] = true
  end

  while game.stack:top() do game.stack:pop() end
  local options = OptionsMenu.new(game)
  game.stack:push(options)
  for index, row in ipairs(options.rows or {}) do
    if row.id == "modern_pokedex_ui" then
      options.index = index
      options.scroll = math.max(0, index - 4)
      U.wait(5)
      U.shot(game, DIR .. "/modern_pokedex_options_entry.png")
      row.activate(game)
      U.wait(5)
      U.shot(game, DIR .. "/modern_pokedex_options_page.png")
      break
    end
  end
  while game.stack:top() do game.stack:pop() end
  local dex = Screens.push(game, "PokedexMenu")
  for index, row in ipairs(dex.modernDexEntries or {}) do
    if row.def and row.def.id == "PIDGEY" then
      dex.index = index
      dex.scroll = math.max(0, index - 3)
      break
    end
  end
  U.wait(12)
  U.log(dex.modernPokedexUI and "PASS modern Pokedex is active"
    or "FAIL modern Pokedex was not registered")
  U.shot(game, DIR .. "/modern_pokedex_list.png")
  U.tap(game, "select")
  U.wait(5)
  U.shot(game, DIR .. "/modern_pokedex_search.png")
  U.tap(game, "b")
  U.wait(3)

  dex.onChoose(dex.items[dex.index], dex)
  dex:update(0)
  U.wait(8)
  U.shot(game, DIR .. "/modern_pokedex_actions.png")
  game.stack:pop()

  local species = game.data.pokemon.PARASECT and "PARASECT" or "BULBASAUR"
  local entry = Screens.push(game, "DexEntryMenu", species)
  U.wait(10)
  U.shot(game, DIR .. "/modern_pokedex_info.png")
  for _, wanted in ipairs({ "stats", "family", "moves" }) do
    for index, page in ipairs(entry.modernDexPages or {}) do
      if page.id == wanted then
        entry.modernDexPage = index
        entry.modernMoveScroll = 0
        entry.modernMoveCursor = wanted == "moves" and 3 or 1
        entry.modernMoveDetail = false
        if wanted == "family" and #(entry.modernDexFamily or {}) > 1 then
          entry.modernFamilyCursor = ((entry.modernFamilyCursor or 1)
            % #entry.modernDexFamily) + 1
        end
        U.wait(8)
        U.shot(game, DIR .. "/modern_pokedex_" .. wanted .. ".png")
        if wanted == "moves" then
          local rows = entry.modernMoveRows or {}
          entry.modernMoveCursor = math.max(1, #rows)
          entry.modernMoveScroll = math.max(0, #rows - 7)
          U.wait(5)
          U.shot(game, DIR .. "/modern_pokedex_moves_tmhm.png")
          entry.modernMoveDetail = true
          U.wait(8)
          U.shot(game, DIR .. "/modern_pokedex_move_detail.png")
          entry.modernMoveDetail = false
        end
        break
      end
    end
  end

  local commonSizes = {
    { 640, 576, 160 }, { 768, 576, 192 }, { 896, 576, 224 },
    { 960, 576, 240 }, { 1280, 720, 256 },
  }
  for _, size in ipairs(commonSizes) do
    love.window.setMode(size[1], size[2], {
      resizable = true, minwidth = 640, minheight = 576,
    })
    for _, wanted in ipairs({ "info", "stats", "family", "moves" }) do
      for index, page in ipairs(entry.modernDexPages or {}) do
        if page.id == wanted then
          entry.modernDexPage = index
          entry.modernMoveScroll = 0
          entry.modernMoveCursor = wanted == "moves" and 3 or 1
          entry.modernMoveDetail = false
          U.wait(5)
          U.shot(game, Strings("%s/modern_pokedex_%d_%s.png",
            DIR, size[3], wanted))
          if wanted == "moves" then
            entry.modernMoveDetail = true
            U.wait(5)
            U.shot(game, Strings("%s/modern_pokedex_%d_move_detail.png",
              DIR, size[3]))
          end
          break
        end
      end
    end
  end

  love.window.setMode(640, 576, {
    resizable = true, minwidth = 640, minheight = 576,
  })
  entry.modernDexPage = 1
  entry.modernMoveDetail = false
  U.wait(8)
  U.shot(game, DIR .. "/modern_pokedex_compact_info.png")
  game.stack:pop()
  for _, size in ipairs(commonSizes) do
    love.window.setMode(size[1], size[2], {
      resizable = true, minwidth = 640, minheight = 576,
    })
    U.wait(5)
    U.shot(game, Strings("%s/modern_pokedex_%d_list.png",
      DIR, size[3]))
  end
  love.window.setMode(640, 576, {
    resizable = true, minwidth = 640, minheight = 576,
  })
  U.wait(5)
  U.shot(game, DIR .. "/modern_pokedex_compact_list.png")
  U.tap(game, "select")
  U.wait(5)
  U.shot(game, DIR .. "/modern_pokedex_compact_search.png")
  U.tap(game, "b")

  -- Crystal 251 stores its three Move Tutors after the machine bits. Capture
  -- one of those rows when available so it cannot regress into an unknown TM.
  local tutorSpecies
  for id, def in pairs(game.data.pokemon or {}) do
    for _, move in ipairs(def.tmhm or {}) do
      if move == "FLAMETHROWER" then tutorSpecies = id break end
    end
    if tutorSpecies then break end
  end
  if tutorSpecies then
    love.window.setMode(1280, 720, {
      resizable = true, minwidth = 640, minheight = 576,
    })
    local tutorEntry = Screens.push(game, "DexEntryMenu", tutorSpecies)
    for index, page in ipairs(tutorEntry.modernDexPages or {}) do
      if page.id == "moves" then tutorEntry.modernDexPage = index break end
    end
    U.wait(6)
    for index, row in ipairs(tutorEntry.modernMoveRows or {}) do
      if row.kind == "tutor" then
        tutorEntry.modernMoveCursor = index
        tutorEntry.modernMoveScroll = math.max(0, index - 7)
        break
      end
    end
    U.wait(5)
    U.shot(game, DIR .. "/modern_pokedex_moves_tutor.png")
  end

  if game.data.pokemon.ODDISH then
    love.window.setMode(640, 576, {
      resizable = true, minwidth = 640, minheight = 576,
    })
    -- When a Crystal 251 cache is present, exercise its alpha-backed battle
    -- portraits even if this isolated preview profile has that overhaul off.
    -- These expose white silhouette pixels that an opaque-matte flood fill
    -- must never erase.
    local mountedCrystal = false
    if not love.filesystem.getInfo("crystal_251/generated/front")
        and love.filesystem.mount then
      mountedCrystal = love.filesystem.mount(
        "red/crystal_251", "crystal_251", false) and true or false
    end
    local crystalFront = {}
    for _, id in ipairs({ "ODDISH", "GLOOM", "VILEPLUME" }) do
      local path = "crystal_251/generated/front/" .. id:lower() .. ".png"
      if love.filesystem.getInfo(path) then crystalFront[id] = path end
    end
    local originalSpritePath = Sprites.path
    if next(crystalFront) then
      Sprites.path = function(data, species, side, opts)
        if side == "front" and crystalFront[species] then
          return crystalFront[species], false
        end
        return originalSpritePath(data, species, side, opts)
      end
    end
    local oddishEntry = Screens.push(game, "DexEntryMenu", "ODDISH")
    for index, page in ipairs(oddishEntry.modernDexPages or {}) do
      if page.id == "family" then oddishEntry.modernDexPage = index break end
    end
    U.wait(6)
    U.shot(game, DIR .. "/modern_pokedex_compact_oddish_family.png")
    love.window.setMode(1080, 1920, { resizable = true })
    U.wait(6)
    U.shot(game, DIR .. "/modern_pokedex_portrait_oddish_family.png")
    Sprites.path = originalSpritePath
    if mountedCrystal and love.filesystem.unmount then
      love.filesystem.unmount("red/crystal_251")
    end
  end

  -- Exercise the optional colour setting on both the icon index and the
  -- information-heavy research file. These captures protect dark surface
  -- contrast without making it the default for existing players.
  while game.stack:top() do game.stack:pop() end
  setTheme("dark")
  love.window.setMode(1280, 720, {
    resizable = true, minwidth = 640, minheight = 576,
  })
  Screens.push(game, "PokedexMenu")
  U.wait(8)
  U.shot(game, DIR .. "/modern_pokedex_dark_list.png")
  game.stack:pop()
  local darkEntry = Screens.push(game, "DexEntryMenu", species)
  darkEntry.modernDexPage = 1
  U.wait(8)
  U.shot(game, DIR .. "/modern_pokedex_dark_info.png")
  setTheme("light")
end
