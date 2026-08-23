-- Visual smoke test. Enable Modern Pokedex UI, then run from the repository root:
--   SHOT_DIR=/tmp/modern-pokedex-ui \
--   POKEPORT_DRIVER=mods/modern_pokedex_ui/tests/preview_driver.lua \
--   POKEPORT_IDENTITY=modern-pokedex-preview POKEPORT_VERSION=red love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local PaletteFX = require("src.render.PaletteFX")
  local Screens = require("src.ui.Screens")
  local Strings = require("src.core.Strings")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/modern-pokedex-ui"

  love.window.setMode(1280, 720, {
    resizable = true, minwidth = 640, minheight = 576,
  })
  game.save.options = game.save.options or {}
  game.save.options.colors = "redpp"
  PaletteFX.setMode("redpp")
  game.save.pokedex = { seen = {}, owned = {} }
  for id in pairs(game.data.pokemon or {}) do
    game.save.pokedex.seen[id] = true
    game.save.pokedex.owned[id] = true
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
end
