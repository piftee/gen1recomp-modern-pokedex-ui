-- Run with the unmodified Crystal Animated Sprites 2.0.2 release in a
-- fresh, muted background QA profile. Tests standalone mods or the suite.
return function(game)
  local U = dofile(assert(os.getenv("PC_REPO")) .. "/tests/drivers/util.lua")
  local Screens = require("src.ui.Screens")
  local Mon = require("src.battle.gen2.Mon")
  local Save = require("src.core.gen2.Save")
  local Boxes = require("src.core.gen2.Boxes")
  local Palette = require("src.render.GbcPalette")
  local api = assert(game.mods.exports.crystal_animated_sprites_with_shiny_visuals)
  local Assets = require("src.render.Assets")
  local staticImages = {}
  for _, species in ipairs({ "ABRA", "KADABRA", "ALAKAZAM", "AMPHAROS", "GOLDEEN" }) do
    local def = game.data.pokemon[species]
    assert(def.spriteFront:find("crystal_animated_sprites_with_shiny_visuals", 1, true))
    staticImages[Assets.image(def.spriteFront)] = true
    print("[CRYSTAL SPRITES] source", species, def.trueColor, def.spriteFront)
  end
  local baseline = os.getenv("EXPECT_BASELINE") == "1"
  local checks, samples, tinted, frames = 0, 0, 0, {}
  local G, draw = love.graphics, love.graphics.draw
  local function check(ok, message)
    assert(ok, "CRYSTAL SPRITES: " .. message)
    checks = checks + 1
  end
  local function observedDraw(image, ...)
    if staticImages[image] or api.isCrystalImage(image) then
      samples = samples + 1
      frames[image] = true
      if G.getShader() then tinted = tinted + 1 end
    end
    return draw(image, ...)
  end
  G.draw = observedDraw
  local function clear()
    while game.stack:top() do game.stack:pop() end
  end
  local function capture(name, expectArt)
    samples, tinted, frames = 0, 0, {}
    U.wait(16)
    check(U.shot(game, os.getenv("SHOT_DIR") .. "/" .. name .. ".png"), name)
    check(not love.window.hasFocus() and love.audio.getVolume() == 0,
      name .. " remained silent and in background")
    if expectArt ~= false then
      print("[CRYSTAL SPRITES] draw", name, samples, tinted, G.draw == observedDraw)
      check(samples > 0, name .. " draws actual Crystal images")
      check(baseline and tinted > 0 or not baseline and tinted == 0,
        name .. (baseline and " reproduces palette corruption" or " preserves source RGB"))
    end
    local count = 0
    for _ in pairs(frames) do count = count + 1 end
    return count
  end
  game.save = Save.newGame({ playerName = "SPRITE QA", trainerId = 4321 })
  game.save.options = game.options or game.save.options
  game.save.options.musicVol, game.save.options.sfxVol, game.save.options.pikaVol = 0, 0, 0
  local normal = Mon.new(game.data, "AMPHAROS", 35)
  local shiny = Mon.new(game.data, "AMPHAROS", 35, {
    dvs = { attack = 2, defense = 10, speed = 10, special = 10 },
  })
  check(shiny.shiny == true, "fixture uses genuine Gen 2 shiny DVs")
  game.save.party = { normal, shiny }
  for _, species in ipairs({ "ABRA", "KADABRA", "ALAKAZAM", "AMPHAROS", "GOLDEEN" }) do
    game.save.pokedex.seen[species], game.save.pokedex.caught[species] = true, true
  end
  love.window.setMode(1440, 1024, { resizable = true })
  clear()
  local dex = Screens.push(game, "Gen2PokedexMenu", { save = game.save })
  check(dex.modernPokedexGeneration == 2, "modern Gen 2 Pokedex loaded")
  local function select(species)
    for i, row in ipairs(dex.rows) do
      if row.species == species then dex.index = i; dex:ensureVisible(); return end
    end
    error("missing species " .. species)
  end
  for _, species in ipairs({ "ABRA", "ALAKAZAM", "AMPHAROS" }) do
    select(species)
    dex.view = "list"
    capture(species:lower() .. "-list")
    dex.view = "entry"
    local count = capture(species:lower() .. "-entry")
    check(count > 1, species .. " entry retains animated frames")
  end
  select("ABRA"); dex.view = "family"
  capture("abra-family", false)
  dex.view = "list"
  dex:current().seen = false
  capture("unseen-question-mark", false)
  check(samples == 0, "unseen entry never renders replacement art")
  dex:current().seen = true
  for _, size in ipairs({ {"wide",1280,720}, {"portrait",480,900} }) do
    love.window.setMode(size[2], size[3], { resizable = true })
    clear()
    local summary = Screens.push(game, "Gen2SummaryMenu", { save = game.save, mon = shiny })
    check(summary.modernPartyGeneration == 2, "modern summary loaded")
    local count = capture("shiny-summary-" .. size[1])
    if not baseline then check(count > 1, "shiny summary keeps animating") end
    clear()
    game.save.currentBox = 1
    local box = Boxes.box(game.save, 1)
    box[1], box[2] = normal, shiny
    local pc = Screens.push(game, "Gen2PcMenu", { save = game.save, bills = true })
    pc.boxIndex = 2
    check(pc.modernPCGeneration == 2, "modern PC loaded")
    count = capture("shiny-pc-" .. size[1])
    if not baseline then check(count > 1, "shiny PC portrait keeps animating") end
  end
  if not baseline then
    clear()
    love.window.setMode(800, 720, { resizable = true })
    local summary = Screens.push(game, "Gen2SummaryMenu", { save = game.save, mon = normal })
    local first = summary:picFor(normal)
    local second = summary:picFor(shiny)
    check(first ~= second and api.isCrystalImage(first) and api.isCrystalImage(second),
      "normal and shiny variants remain distinct")
    for _, mode in ipairs({ "dmg", "classic", "gbc" }) do
      Palette.setMode(mode)
      capture("summary-mode-" .. mode)
    end
  end
  G.draw = draw
  print("[CRYSTAL SPRITES] PASS " .. checks .. " checks"
    .. (baseline and " (original bug reproduced)" or ""))
  love.event.quit(0)
end
