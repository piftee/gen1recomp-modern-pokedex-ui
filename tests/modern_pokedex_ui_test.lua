-- Standalone: luajit mods/modern_pokedex_ui/tests/modern_pokedex_ui_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Assets = require("src.render.Assets")
local Font = require("src.render.Font")
local PaletteFX = require("src.render.PaletteFX")
local PartyMenu = require("src.ui.PartyMenu")
local Sprites = require("src.pokemon.Sprites")
local Strings = require("src.core.Strings")

local data = T.fixtures.fresh()
data.icons = { icons = {}, byDex = {}, bySpecies = {} }
data.icons.bySpecies.FIXMON_A = {
  image = "tests/fixture_data/assets/fake_unique_icon.png", frames = 2,
}
data.palettes = {
  palettes = {
    BLUEMON = { { 255, 255, 255 }, { 150, 180, 235 },
      { 55, 95, 175 }, { 0, 0, 0 } },
    REDMON = { { 255, 255, 255 }, { 240, 160, 145 },
      { 175, 45, 35 }, { 0, 0, 0 } },
    BROWNMON = { { 255, 255, 255 }, { 220, 185, 145 },
      { 145, 90, 45 }, { 0, 0, 0 } },
    CYANMON = { { 255, 255, 255 }, { 165, 220, 230 },
      { 45, 135, 160 }, { 0, 0, 0 } },
    GREENMON = { { 255, 255, 255 }, { 150, 220, 150 },
      { 30, 130, 45 }, { 0, 0, 0 } },
    PURPLEMON = { { 255, 255, 255 }, { 215, 170, 230 },
      { 130, 70, 160 }, { 0, 0, 0 } },
  },
  pokemon = {},
}
data.pokemon.FIXMON_A.extraAbilities = { "OVERGROW" }
data.pokemon.FIXMON_A.name = "ALPHAMON"
data.pokemon.FIXMON_B.name = "BLAZEMON"
data.pokemon.FIXMON_C.name = "ÉCORAL"
for index = 1, 8 do
  local id = "FIX_EXTRA_" .. index
  data.moves[id] = {
    id = id, index = 10 + index, name = "EXTRA " .. index,
    type = index % 2 == 0 and "FIRE" or "GRASS",
    power = 35 + index, accuracy = 90, pp = 20,
    priority = index == 6 and 1 or nil,
    effect = index == 6 and "BURN_SIDE_EFFECT1"
      or "NO_ADDITIONAL_EFFECT",
  }
  data.pokemon.FIXMON_A.learnset[#data.pokemon.FIXMON_A.learnset + 1] = {
    level = 10 + index, move = id,
  }
end
Font.load(data)
local previousMode = PaletteFX.mode
PaletteFX.setMode("gbc")

local run = T.sdk.loadMods({
  "mods/modern_party_ui/tests/fixtures/gen1_modern_ui",
  "mods/modern_pokedex_ui/tests/fixtures/dex_extras",
  "mods/modern_pokedex_ui/tests/fixtures/crystal_251_moves",
  "mods/modern_pokedex_ui",
}, { data = data, dev = true })
T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")
Strings.load(run.data)

local dexRecord = run.data.screens and run.data.screens.PokedexMenu
local entryRecord = run.data.screens and run.data.screens.DexEntryMenu
T.check(type(dexRecord) == "table" and type(dexRecord.new) == "function",
  "the modern Pokedex list is registered")
T.check(type(entryRecord) == "table" and type(entryRecord.new) == "function",
  "the modern data entry is registered")

run.data.strings = run.data.strings or {}
run.data.strings.BUG = "INSETO"
run.data.strings.POISON = "VENENO"
run.data.strings.FLYING = "VOADOR"
run.data.strings.DRAGON = "DRAGÃO"
-- These deliberately collide with English abbreviations. They must never be
-- consulted now that abbreviations are derived from translated full names.
run.data.strings.PSN = "VENENOSO STATUS"
run.data.strings.FLY = "VOAR"
Strings.load(run.data)

local stack = { states = {} }
function stack:push(state) self.states[#self.states + 1] = state end
function stack:pop() return table.remove(self.states) end
function stack:top() return self.states[#self.states] end
local input = { pressed = {} }
function input:wasPressed(key) return self.pressed[key] == true end
local game = {
  data = run.data,
  save = { pokedex = {
    seen = { FIXMON_A = true, FIXMON_B = true, FIXMON_C = true },
    owned = { FIXMON_A = true, FIXMON_B = true, FIXMON_C = true },
  } },
  stack = stack, input = input,
}
local function press(state, key)
  input.pressed[key] = true
  state:update(0)
  input.pressed[key] = nil
end

local dex = dexRecord.new(game)
stack:push(dex)
T.check(dex.modernPokedexUI == true, "the responsive Pokedex list is active")
T.eq(#dex.modernDexEntries, 3, "all fixture species remain in dex order")
T.eq(dex.modernDexEntries[1].def.id, "FIXMON_A",
  "the list preserves native dex numbering")

local graphics = love.graphics
local realDimensions = graphics.getPixelDimensions
graphics.getPixelDimensions = function() return 1280, 720 end
T.eq(select(1, dex:uiSize()), 256,
  "the Pokedex uses the shared 256x144 widescreen surface")
local realListIcon = PartyMenu.drawIcon
local realListFont = Font.draw
local realListImageData = Assets.imageData
local realListRectangle = graphics.rectangle
local listSelectionStates, listIconTints, listText = {}, {}, {}
local iconBackings = 0
PartyMenu.drawIcon = function(game_, mon, x, y, selected, ...)
  listSelectionStates[#listSelectionStates + 1] = selected == true
  listIconTints[#listIconTints + 1] = { graphics.getColor() }
  return realListIcon(game_, mon, x, y, selected, ...)
end
Font.draw = function(value, x, y)
  listText[#listText + 1] = tostring(value)
  return realListFont(value, x, y)
end
-- A sparse authored icon makes transparent-pixel protection observable even
-- under the headless image stub.
Assets.imageData = function(path, ...)
  if tostring(path):find("fake_unique_icon.png", 1, true) then
    return {
      getDimensions = function() return 16, 32 end,
      getPixel = function(_, x, y)
        local opaque = y >= 4 and y <= 11 and x >= 5 and x <= 10
        return 1, 1, 1, opaque and 1 or 0
      end,
    }
  end
  return realListImageData(path, ...)
end
graphics.rectangle = function(mode, x, y, w, h, ...)
  if mode == "fill" and w == 18 and h == 18 then
    iconBackings = iconBackings + 1
  end
  return realListRectangle(mode, x, y, w, h, ...)
end
PaletteFX.setPass("ui")
local listOK, listErr = pcall(dex.draw, dex)
PaletteFX.setPass(nil)
PartyMenu.drawIcon = realListIcon
Font.draw = realListFont
Assets.imageData = realListImageData
graphics.rectangle = realListRectangle
T.check(listOK, "the modern dex list draws headlessly: " .. tostring(listErr))
T.eq(iconBackings, 0,
  "authored icons do not paint an opaque rectangular backing")
local exactIconRuns, broadIconClaim = 0, false
for _, rect in ipairs(PaletteFX.trueColorRects("ui")) do
  if rect.x >= 8 and rect.x < 24 and rect.y >= 21 and rect.y < 42 then
    if rect.h == 1 and rect.w < 16 then exactIconRuns = exactIconRuns + 1 end
    if rect.w >= 16 and rect.h >= 16 then broadIconClaim = true end
  end
end
T.check(exactIconRuns > 0 and not broadIconClaim,
  "only visible icon pixels bypass the screen palette")
for _, selected in ipairs(listSelectionStates) do
  T.check(not selected,
    "list focus never asks an icon renderer for a darkened selected state")
end
for _, tint in ipairs(listIconTints) do
  T.check(tint[1] == 1 and tint[2] == 1 and tint[3] == 1
      and (tint[4] == nil or tint[4] == 1),
    "list focus never multiplies an icon's authored colours by the card tint")
end
local sawTypeAbbreviation, sawCaughtProgress, sawCrowdedHeader = false, false, false
for _, value in ipairs(listText) do
  if value == "GRS" or value == "FIR" or value == "WAT" then
    sawTypeAbbreviation = true
  end
  if value:find("CAUGHT 003/003", 1, true) then sawCaughtProgress = true end
  if value:find("KANTO RESEARCH", 1, true)
      or value:find("SEEN ", 1, true) then sawCrowdedHeader = true end
end
T.check(not sawTypeAbbreviation,
  "wide list cards no longer add a type label beneath the species name")
T.check(sawCaughtProgress,
  "the wide header presents a single caught-progress fraction")
T.check(not sawCrowdedHeader,
  "the wide header omits the crowded region and seen labels")

-- SELECT opens a controller-friendly search panel. Letter and type filters
-- can be combined, but their options and matches only use discovered data.
press(dex, "select")
T.check(dex.modernDexSearchOpen and dex.modernDexSearchCursor == 1,
  "SELECT opens Pokedex search on the starting-letter field")
local sawLocalizedInitial = false
for _, letter in ipairs(dex.modernDexSearchLetters or {}) do
  if letter == "É" then sawLocalizedInitial = true break end
end
T.check(sawLocalizedInitial,
  "starting-letter search retains a translated non-ASCII first glyph")
press(dex, "right")
press(dex, "a")
T.eq(#dex.modernDexEntries, 1,
  "applying a starting-letter search filters the native and modern lists")
T.eq(dex.modernDexEntries[1].def.id, "FIXMON_A",
  "starting-letter search returns the matching discovered species")
T.eq(#dex.items, #dex.modernDexEntries,
  "filtered native actions stay aligned with modern Pokedex rows")

press(dex, "select")
press(dex, "left") -- Letter A -> ALL.
press(dex, "down")
press(dex, "right") -- First translated type is FIRE.
press(dex, "a")
T.eq(#dex.modernDexEntries, 1,
  "applying a type search filters to compatible discovered species")
T.eq(dex.modernDexEntries[1].def.id, "FIXMON_B",
  "type search uses the species' actual type identifiers")

press(dex, "select")
press(dex, "down")
press(dex, "left") -- FIRE -> ALL.
press(dex, "a")
T.eq(#dex.modernDexEntries, 3,
  "returning both search fields to ALL restores the complete Pokedex")
dex.index, dex.scroll = 1, 0

-- The DATA/CRY/AREA/QUIT overlay is a neutral white card whose geometry
-- includes both its heading and every row.
input.pressed.a = true
dex:update(0)
input.pressed.a = nil
local action = stack:top()
T.check(action ~= dex and action.modernDexOwner == dex,
  "the Pokédex research action menu receives the modern card treatment")
local actionZones = action:sgbPalettes(game) or {}
local actionZone = actionZones[#actionZones]
T.check(actionZone and actionZone.colors == PaletteFX.GRAYS,
  "the research action card uses a neutral white/grey palette")
T.eq(actionZone and actionZone.h, #action.items * 14 + 20,
  "the research card height budgets its heading and every action")
T.check(actionZone and actionZone.y + actionZone.h <= 132,
  "the final research action stays above the footer")
action.index = 3
input.pressed.a = true
action:update(0)
input.pressed.a = nil
local areaMap = stack:top()
T.check(areaMap and areaMap.modernPokedexAreaMap == true
    and areaMap.nestSpecies == "FIXMON_A" and areaMap.isOpaque == true,
  "AREA remains an opaque visible map when Gen1 Modern UI is enabled")
stack:pop()

-- Closing the list can synchronously push the Start menu through onCancel.
-- The post-update decorator must not treat that replacement as a Dex action.
local closingStack = { states = {} }
function closingStack:push(state) self.states[#self.states + 1] = state end
function closingStack:pop() return table.remove(self.states) end
function closingStack:top() return self.states[#self.states] end
local closingInput = { pressed = {} }
function closingInput:wasPressed(key) return self.pressed[key] == true end
local closingGame = {
  data = run.data, save = game.save, stack = closingStack, input = closingInput,
}
local replacement
local closingDex = dexRecord.new(closingGame, { onCancel = function()
  replacement = { items = { { label = "POKéDEX" } }, update = function() end }
  closingStack:push(replacement)
end })
closingStack:push(closingDex)
closingInput.pressed.b = true
closingDex:update(0)
closingInput.pressed.b = nil
T.eq(closingStack:top(), replacement,
  "closing the Pokédex hands control to the replacement menu")
T.check(replacement.modernDexOwner == nil and replacement.sgbPalettes == nil,
  "the reopened menu does not inherit the yellow Pokédex action palette")

local entry = entryRecord.new(game, "FIXMON_A")
stack:push(entry)
local labels = {}
for _, page in ipairs(entry.modernDexPages) do labels[#labels + 1] = page.label end
T.same(labels, { "INFO", "STATS", "FAMILY", "MOVES", "ABILITY" },
  "only real built-in data plus the supplied extra-data page creates tabs")

local realPath = Sprites.path
local realMonPal = PaletteFX.monPal
local contexts = {}
local portraitPaletteSpecies = {}
Sprites.path = function(data_, species, side, opts)
  contexts[#contexts + 1] = {
    species = species, side = side, kind = opts and opts.kind,
  }
  return realPath(data_, species, side, opts)
end
PaletteFX.monPal = function(data_, species, ...)
  portraitPaletteSpecies[#portraitPaletteSpecies + 1] = species
  return realMonPal(data_, species, ...)
end
local uiRects = PaletteFX.trueColorRects("ui")
uiRects[#uiRects + 1] = {
  colors = false, x = 1234, y = 1234, w = 16, h = 16,
}
PaletteFX.setPass("ui")
local entryOK, entryErr = pcall(entry.draw, entry)
PaletteFX.setPass(nil)
Sprites.path = realPath
PaletteFX.monPal = realMonPal
T.check(entryOK, "the modern entry draws headlessly: " .. tostring(entryErr))
local inheritedClaim = false
for _, rect in ipairs(uiRects) do
  if rect.x == 1234 and rect.y == 1234 then inheritedClaim = true break end
end
T.check(not inheritedClaim,
  "an opaque entry clears inherited list-icon claims before drawing")
local exactPortraitRuns, broadPortraitClaim = 0, false
for _, rect in ipairs(uiRects) do
  if rect.x >= 4 and rect.x < 100 and rect.y >= 21 and rect.y < 90 then
    if rect.h <= 1 then exactPortraitRuns = exactPortraitRuns + 1 end
    if rect.h > 2 then broadPortraitClaim = true end
  end
end
T.check(exactPortraitRuns > 0 and not broadPortraitClaim,
  "battle portraits protect only visible pixels, without a rectangular matte")
local usedSpeciesPalette = false
for _, species in ipairs(portraitPaletteSpecies) do
  if species == "FIXMON_A" then usedSpeciesPalette = true break end
end
T.check(usedSpeciesPalette,
  "the battle portrait is baked through its species palette, not its card type")
local battleArt = false
for _, call in ipairs(contexts) do
  if call.species == "FIXMON_A" and call.side == "front"
      and call.kind == "battle" then battleArt = true break end
end
T.check(battleArt,
  "Pokedex profiles resolve through the exact battle-front sprite context")

press(entry, "right")
T.eq(entry.modernDexPages[entry.modernDexPage].id, "stats",
  "RIGHT visits the next available page")
press(entry, "right")
T.eq(entry.modernDexPages[entry.modernDexPage].id, "family",
  "the evolution page exists for a real two-species family")
press(entry, "down")
T.eq(entry.modernFamilyCursor, 2,
  "DOWN selects the next displayed evolution-family member")
press(entry, "up")
T.eq(entry.modernFamilyCursor, 1,
  "UP selects the previous displayed evolution-family member")
press(entry, "right")
T.eq(entry.modernDexPages[entry.modernDexPage].id, "moves",
  "moves are reachable when level and machine data exist")
entry:draw()
T.eq(#entry.modernMoveRows, 11,
  "the move list combines level-up moves with compatible TM/HM moves")
for _ = 1, 7 do press(entry, "down") end
T.eq(entry.modernMoveCursor, 8,
  "DOWN moves a real cursor through the move list")
T.eq(entry.modernMoveScroll, 1,
  "the move list follows its cursor onto the next row page")
local moveListText = {}
local realMoveListFont = Font.draw
Font.draw = function(value, x, y)
  moveListText[tostring(value)] = true
  return realMoveListFont(value, x, y)
end
entry:draw()
Font.draw = realMoveListFont
T.check(moveListText.PP and not moveListText.GRS and not moveListText.FIR
    and not moveListText.NOR and not moveListText.P41
    and not moveListText.PP20,
  "move rows show only source level, name, and the PP column")
local moveZones = entry:sgbPalettes(game)
local typedRows = 0
for _, zone in ipairs(moveZones) do
  if zone.x == 9 and zone.h == 12 then typedRows = typedRows + 1 end
end
T.eq(typedRows, 7,
  "every visible move row receives its own type-colour treatment")
press(entry, "a")
T.check(entry.modernMoveDetail,
  "A opens details for the selected move")
local moveDetailText = {}
local realMoveFont = Font.draw
Font.draw = function(value, x, y)
  moveDetailText[#moveDetailText + 1] = tostring(value)
  return realMoveFont(value, x, y)
end
local moveDetailOK, moveDetailErr = pcall(entry.draw, entry)
Font.draw = realMoveFont
T.check(moveDetailOK,
  "the move detail view draws headlessly: " .. tostring(moveDetailErr))
local detailFacts = {}
for _, value in ipairs(moveDetailText) do detailFacts[value] = true end
T.check(detailFacts["EXTRA 6"] and detailFacts.PWR and detailFacts.ACC
    and detailFacts.PP and detailFacts.EFFECT,
  "move details expose the available identity, combat facts, and effect")
local moveStackDepth = #stack.states
press(entry, "b")
T.check(not entry.modernMoveDetail and #stack.states == moveStackDepth,
  "B returns from move details to the move list")
local selectedMove = run.data.moves.FIX_EXTRA_6
local savedEffect = selectedMove.effect
selectedMove.effect = "CRYSTAL_EFFECT_43"
press(entry, "a")
local crystalDetailText = {}
Font.draw = function(value, x, y)
  crystalDetailText[tostring(value)] = true
  return realMoveFont(value, x, y)
end
entry:draw()
Font.draw = realMoveFont
T.check(crystalDetailText.EFFECT
    and crystalDetailText["PARALYZES THE TARGET."]
    and not crystalDetailText["CRYSTAL EFFECT 43."],
  "Crystal 251 effect families produce useful prose without exposing ids")
press(entry, "b")
selectedMove.effect = savedEffect
entry.modernMoveCursor = 1
entry.modernMoveScroll = 0
press(entry, "a")
local ordinaryDetailText = {}
Font.draw = function(value, x, y)
  ordinaryDetailText[tostring(value)] = true
  return realMoveFont(value, x, y)
end
entry:draw()
Font.draw = realMoveFont
local sawOrdinaryDetail = false
for value in pairs(ordinaryDetailText) do
  if value:find("ADDITIONAL", 1, true) then
    sawOrdinaryDetail = true
    break
  end
end
T.check(ordinaryDetailText.EFFECT and sawOrdinaryDetail,
  "ordinary moves keep an informative effect panel without Crystal 251")
press(entry, "b")
for _ = 1, 10 do press(entry, "down") end
T.eq(entry.modernMoveCursor, 11,
  "DOWN reaches the compatible TM/HM rows appended after level-up moves")
T.eq(entry.modernMoveRows[11].kind, "machine",
  "the final move row is identified as machine compatibility data")
local machineListText = {}
Font.draw = function(value, x, y)
  machineListText[tostring(value)] = true
  return realMoveFont(value, x, y)
end
entry:draw()
Font.draw = realMoveFont
T.check(machineListText.TM01 and machineListText["FIX CUT"],
  "compatible move rows put the complete TM/HM number before the move name")
press(entry, "a")
local machineDetailText = {}
Font.draw = function(value, x, y)
  machineDetailText[tostring(value)] = true
  return realMoveFont(value, x, y)
end
entry:draw()
Font.draw = realMoveFont
T.check(machineDetailText.TM01 and machineDetailText["FIX CUT"],
  "a compatible machine row opens details with its TM/HM number")
press(entry, "b")

-- Crystal's final three compatibility bits are Move Tutors, not numbered
-- machines. They must not be presented as a clipped or unknown TM number.
run.data.moves.FLAMETHROWER = {
  id = "FLAMETHROWER", name = "FLAMETHROWER", type = "FIRE",
  power = 95, accuracy = 100, pp = 15,
}
local tmhm = run.data.pokemon.FIXMON_A.tmhm
tmhm[#tmhm + 1] = "FLAMETHROWER"
local tutorEntry = entryRecord.new(game, "FIXMON_A")
tutorEntry.modernDexTabbed = true
stack:push(tutorEntry)
for index, page in ipairs(tutorEntry.modernDexPages) do
  if page.id == "moves" then tutorEntry.modernDexPage = index break end
end
tutorEntry:draw()
local tutorRow = tutorEntry.modernMoveRows[#tutorEntry.modernMoveRows]
T.eq(tutorRow.kind, "tutor",
  "Crystal 251 Move Tutor compatibility is distinguished from machines")
tutorEntry.modernMoveCursor = #tutorEntry.modernMoveRows
tutorEntry.modernMoveScroll = math.max(0, #tutorEntry.modernMoveRows - 7)
local tutorListText = {}
Font.draw = function(value, x, y)
  tutorListText[tostring(value)] = true
  return realMoveFont(value, x, y)
end
tutorEntry:draw()
Font.draw = realMoveFont
T.check(tutorListText.TUTOR and tutorListText.FLAMETHROWER,
  "Crystal tutor rows show TUTOR before the move name instead of an unknown TM")
press(tutorEntry, "a")
local tutorDetailText = {}
Font.draw = function(value, x, y)
  tutorDetailText[tostring(value)] = true
  return realMoveFont(value, x, y)
end
tutorEntry:draw()
Font.draw = realMoveFont
T.check(tutorDetailText.TUTOR and tutorDetailText.FLAMETHROWER,
  "Crystal tutor move details retain the correct source label")
stack:pop()
tmhm[#tmhm] = nil
run.data.moves.FLAMETHROWER = nil

press(entry, "right")
T.eq(entry.modernDexPages[entry.modernDexPage].id, "abilities",
  "a companion data mod can append its own conditional research page")

-- A family selection opens that known member in-place and keeps the backing
-- Pokédex list synchronized, rather than stacking nested entry screens.
stack:pop()
local familyEntry = entryRecord.new(game, "FIXMON_A")
stack:push(familyEntry)
press(familyEntry, "right")
press(familyEntry, "right")
T.eq(familyEntry.modernDexPages[familyEntry.modernDexPage].id, "family",
  "the family interaction test reaches the FAMILY page")
press(familyEntry, "down")
local realFamilyIcon = PartyMenu.drawIcon
local realFamilyPath = Sprites.path
local familyIconCalls, familyBattleSpecies = 0, {}
PartyMenu.drawIcon = function(game_, mon, x, y, selected, ...)
  familyIconCalls = familyIconCalls + 1
  return realFamilyIcon(game_, mon, x, y, selected, ...)
end
Sprites.path = function(data_, species, side, opts)
  if side == "front" and opts and opts.kind == "battle" then
    familyBattleSpecies[species] = true
  end
  return realFamilyPath(data_, species, side, opts)
end
local familyDrawOK, familyDrawErr = pcall(familyEntry.draw, familyEntry)
PartyMenu.drawIcon = realFamilyIcon
Sprites.path = realFamilyPath
T.check(familyDrawOK,
  "the focused family card draws headlessly: " .. tostring(familyDrawErr))
T.eq(familyIconCalls, 0,
  "FAMILY cards do not use Unique Icons/HGSS menu-icon artwork")
T.check(familyBattleSpecies.FIXMON_A and familyBattleSpecies.FIXMON_B,
  "known FAMILY cards resolve full battle-front sprites for every member")
local stackDepth = #stack.states
press(familyEntry, "a")
T.eq(#stack.states, stackDepth,
  "viewing a relative reuses the current entry instead of nesting screens")
T.eq(familyEntry.def.id, "FIXMON_B",
  "A opens the selected known family member")
T.eq(familyEntry.modernDexPages[familyEntry.modernDexPage].id, "info",
  "a selected relative opens on its INFO page")
T.eq(dex.index, 2,
  "the backing Pokédex selection follows the viewed family member")

-- Exercise every built-in entry page at the common integer-scaled logical
-- widths. Compact INFO and STATS have purpose-built compositions rather than
-- relying on clipping labels designed for a wide surface.
stack:pop()
local responsiveEntry = entryRecord.new(game, "FIXMON_A")
stack:push(responsiveEntry)
local commonSizes = {
  { 640, 576, 160 }, { 768, 576, 192 }, { 896, 576, 224 },
  { 960, 576, 240 }, { 1280, 720, 256 },
}
press(dex, "select")
for _, size in ipairs(commonSizes) do
  graphics.getPixelDimensions = function() return size[1], size[2] end
  T.eq(select(1, responsiveEntry:uiSize()), size[3],
    "responsive sizing reaches the expected " .. size[3] .. "px surface")
  for pageIndex = 1, #responsiveEntry.modernDexPages do
    responsiveEntry.modernDexPage = pageIndex
    responsiveEntry.modernMoveDetail = false
    local ok, err = pcall(responsiveEntry.draw, responsiveEntry)
    T.check(ok, Strings("page %s draws at %dpx: %s",
      responsiveEntry.modernDexPages[pageIndex].id, size[3], tostring(err)))
    local zones = responsiveEntry:sgbPalettes(game)
    for _, zone in ipairs(zones) do
      T.check(zone.x >= 0 and zone.y >= 0
          and zone.x + zone.w <= size[3] and zone.y + zone.h <= 144,
        Strings("page %s keeps palette regions inside %dpx",
          responsiveEntry.modernDexPages[pageIndex].id, size[3]))
    end
  end
  local listOKAtSize, listErrAtSize = pcall(dex.draw, dex)
  T.check(listOKAtSize,
    Strings("Pokedex list draws at %dpx: %s", size[3],
      tostring(listErrAtSize)))
  for _, zone in ipairs(dex:sgbPalettes(game)) do
    T.check(zone.x >= 0 and zone.y >= 0
        and zone.x + zone.w <= size[3] and zone.y + zone.h <= 144,
      Strings("Pokedex list keeps palette regions inside %dpx", size[3]))
  end
end
press(dex, "b")

graphics.getPixelDimensions = function() return 640, 576 end
local compactListFooter = {}
local compactListRealFont = Font.draw
Font.draw = function(value, x, y)
  compactListFooter[tostring(value)] = true
  return compactListRealFont(value, x, y)
end
dex:draw()
Font.draw = compactListRealFont
T.check(compactListFooter["SEEN 003"]
    and not compactListFooter["S003 C003"],
  "compact Pokedex footer names only the seen count")

local originalDexText = responsiveEntry.def.dexEntry.text
responsiveEntry.def.dexEntry.text = "OBVIOUSLY PREFERS HOT PLACES. WHEN IT "
  .. "RAINS, STEAM SPOUTS FROM THE TIP OF ITS TAIL."
responsiveEntry.modernDexPage = 1
local compactInfoText = {}
local realCompactFont = Font.draw
Font.draw = function(value, x, y)
  compactInfoText[#compactInfoText + 1] = { value = tostring(value), y = y }
  return realCompactFont(value, x, y)
end
responsiveEntry:draw()
Font.draw = realCompactFont
responsiveEntry.def.dexEntry.text = originalDexText
local noteLines = 0
for _, item in ipairs(compactInfoText) do
  if item.y >= 92 and item.y <= 122 then noteLines = noteLines + 1 end
end
T.eq(noteLines, 4,
  "compact INFO reserves four readable lines for flavour text")
local sawTightNav, sawCompleteActions = false, false
for _, item in ipairs(compactInfoText) do
  if item.value == "LR UD" then sawTightNav = true end
  if item.value == "A CRY B BACK" then sawCompleteActions = true end
end
T.check(sawTightNav and sawCompleteActions,
  "compact INFO fits complete navigation and action labels in its footer")
T.check(responsiveEntry.modernInfoCanScroll,
  "compact INFO exposes overflow notes instead of discarding them")
press(responsiveEntry, "down")
T.eq(responsiveEntry.modernInfoScroll, 1,
  "DOWN reveals the next line of compact field notes")
press(responsiveEntry, "up")
T.eq(responsiveEntry.modernInfoScroll, 0,
  "UP returns to the previous compact field-note line")

-- Catch/script entry pages are not tabbed. A advances their overflowing
-- notes before it closes the page, matching the original page-continue flow.
local savedCatchText = responsiveEntry.def.dexEntry.text
responsiveEntry.def.dexEntry.text = "THIS NEWLY CAUGHT POKEMON HAS A VERY LONG "
  .. "DESCRIPTION THAT NEEDS MORE THAN ONE COMPACT PAGE TO SHOW EVERY WORD "
  .. "WITHOUT DISCARDING THE END OF ITS FIELD NOTES."
local catchDone = false
local caughtEntry = entryRecord.new(game,
  { species = "FIXMON_A", forceOwned = true },
  function() catchDone = true end)
stack:push(caughtEntry)
caughtEntry:draw()
local catchDepth = #stack.states
press(caughtEntry, "a")
T.check(caughtEntry.modernInfoScroll > 0 and #stack.states == catchDepth,
  "A advances overflowing notes on a newly-caught entry before closing")
while caughtEntry.modernInfoScroll
    < math.max(0, #(caughtEntry.modernInfoLines or {})
      - (caughtEntry.modernInfoVisible or 0)) do
  press(caughtEntry, "a")
end
press(caughtEntry, "a")
T.check(#stack.states == catchDepth - 1 and catchDone,
  "A closes the newly-caught entry after its final notes page")
responsiveEntry.def.dexEntry.text = savedCatchText

local compactInfoZones = responsiveEntry:sgbPalettes(game)
local shortPortraitZone, tallPortraitZone = false, false
for _, zone in ipairs(compactInfoZones) do
  if zone.x == 4 and zone.y == 21 and zone.w == 52 and zone.h == 52 then
    shortPortraitZone = true
  elseif zone.x == 4 and zone.y == 21 and zone.h == 109 then
    tallPortraitZone = true
  end
end
T.check(shortPortraitZone and not tallPortraitZone,
  "compact INFO matches the STAT portrait size and stops before notes")

local savedTypes = responsiveEntry.def.types
responsiveEntry.def.types = { "BUG", "POISON" }
local translatedCompactTypes = {}
Font.draw = function(value, x, y)
  translatedCompactTypes[tostring(value)] = true
  return realCompactFont(value, x, y)
end
responsiveEntry.modernDexPage = 1
responsiveEntry:draw()
Font.draw = realCompactFont
T.check(translatedCompactTypes.INS and translatedCompactTypes.VEN
    and not translatedCompactTypes["VENENOSO STATUS"],
  "compact type chips abbreviate translated full names without key collisions")

graphics.getPixelDimensions = function() return 1600, 720 end
local translatedPair = {}
dex.index = 1
Font.draw = function(value, x, y)
  translatedPair[tostring(value)] = true
  return realCompactFont(value, x, y)
end
dex:draw()
Font.draw = realCompactFont
local sawTranslatedPair = false
for value in pairs(translatedPair) do
  if value:find("INSETO/VEN", 1, true) == 1 then
    sawTranslatedPair = true
    break
  end
end
T.check(sawTranslatedPair,
  "combined types translate each component before they are joined")
responsiveEntry.def.types = savedTypes
graphics.getPixelDimensions = function() return 640, 576 end

responsiveEntry.modernDexPage = 2
local compactStatsText = {}
Font.draw = function(value, x, y)
  compactStatsText[tostring(value)] = true
  return realCompactFont(value, x, y)
end
responsiveEntry:draw()
Font.draw = realCompactFont
T.check(compactStatsText["TOTAL 253"] and compactStatsText["CATCH 45"]
    and compactStatsText["EXP 64"] and compactStatsText["GROW M.S."],
  "compact STATS preserves total, catch rate, experience, and growth data")
T.check(compactStatsText.ATK and compactStatsText.SPE
    and compactStatsText.SPC,
  "compact STATS uses ATK and distinguishes Speed (SPE) from Special (SPC)")

-- Strip every optional research field from the standalone third species.
-- Its entry should contract to INFO instead of advertising empty sections.
local sparse = run.data.pokemon.FIXMON_C
sparse.baseStats, sparse.catchRate, sparse.baseExp, sparse.growthRate = nil
sparse.level1Moves, sparse.learnset, sparse.tmhm, sparse.evolutions = nil
sparse.dexEntry = {}
sparse.extraAbilities = nil
stack:pop()
local sparseEntry = entryRecord.new(game, "FIXMON_C")
stack:push(sparseEntry)
T.eq(#sparseEntry.modernDexPages, 1,
  "missing stats, family, moves, and extras do not create empty tabs")
T.eq(sparseEntry.modernDexPages[1].id, "info",
  "the basic identity page remains available")

local realFontDraw = Font.draw
local drawnText = {}
Font.draw = function(value, x, y)
  drawnText[#drawnText + 1] = tostring(value)
  return realFontDraw(value, x, y)
end
local sparseOK, sparseErr = pcall(sparseEntry.draw, sparseEntry)
Font.draw = realFontDraw
T.check(sparseOK,
  "the sparse entry draws without placeholder panels: " .. tostring(sparseErr))
local sawUnknownCategory, sawFieldNotes = false, false
for _, value in ipairs(drawnText) do
  if value == "?" then sawUnknownCategory = true end
  if value == "FIELD NOTES" then sawFieldNotes = true end
end
T.check(not sawUnknownCategory,
  "a missing species category is not represented as invented question data")
T.check(not sawFieldNotes,
  "a missing dex description does not leave an empty field-notes card")

graphics.getPixelDimensions = realDimensions
run.release()
PaletteFX.setMode(previousMode)

-- Wilds of Kanto's exported follower selector must survive a later icon mod
-- replacing PartyMenu.drawIcon. The Pokédex consumes the export directly,
-- animates only its focused row, and protects only visible sprite pixels.
do
local wildsData = T.fixtures.fresh()
wildsData.icons = { icons = {}, byDex = {}, bySpecies = {} }
Font.load(wildsData)
local wildsRun = T.sdk.loadMods({
  "mods/modern_party_ui/tests/fixtures/wilds_of_kanto",
  "mods/modern_pokedex_ui",
}, { data = wildsData, dev = true })
T.eq(#wildsRun.errors, 0, "loads beside Wilds of Kanto 2.1.7")

local wildsStack = { states = {} }
function wildsStack:push(state) self.states[#self.states + 1] = state end
function wildsStack:pop() return table.remove(self.states) end
function wildsStack:top() return self.states[#self.states] end
local wildsGame = {
  data = wildsRun.data,
  save = { pokedex = {
    seen = { FIXMON_A = true, FIXMON_B = true, FIXMON_C = true },
    owned = { FIXMON_A = true, FIXMON_B = true, FIXMON_C = true },
  } },
  stack = wildsStack,
  input = { wasPressed = function() return false end },
  renderer = { uiSize = function() return 256, 144 end },
}
local wildsDex = wildsRun.data.screens.PokedexMenu.new(wildsGame)
wildsDex.modernDexClock = 5
wildsStack:push(wildsDex)

local realWildsDraw = graphics.draw
local realWildsImage = Assets.image
local realWildsImageData = Assets.imageData
local realWildsMark = PaletteFX.markTrueColor
local drawIconBeforeWilds = PartyMenu.drawIcon
local wildsDraws, wildsMarks = {}, {}
local fakeWildsData = {}
function fakeWildsData:getDimensions() return 16, 96 end
function fakeWildsData:getPixel(px, py)
  local localY = py % 16
  local opaque = px >= 4 and px <= 11 and localY >= 3 and localY <= 12
  return 1, 1, 1, opaque and 1 or 0
end
Assets.image = function(path)
  if tostring(path):find("overworld_wild_spawns", 1, true) then
    return {
      path = path,
      getDimensions = function() return 16, 96 end,
      getWidth = function() return 16 end,
      getHeight = function() return 96 end,
    }
  end
  return realWildsImage(path)
end
Assets.imageData = function(path)
  if tostring(path):find("overworld_wild_spawns", 1, true) then
    return fakeWildsData
  end
  return realWildsImageData(path)
end
PartyMenu.drawIcon = function() return false end
graphics.draw = function(image, quad, x, y, rotation, sx, sy, ...)
  if type(image) == "table"
      and tostring(image.path):find("overworld_wild_spawns", 1, true) then
    wildsDraws[#wildsDraws + 1] = {
      path = image.path, quad = quad, x = x, y = y,
      sx = sx or 1, sy = sy or sx or 1,
    }
  end
  return realWildsDraw(image, quad, x, y, rotation, sx, sy, ...)
end
PaletteFX.markTrueColor = function(x, y, w, h)
  wildsMarks[#wildsMarks + 1] = { x = x, y = y, w = w, h = h }
end

local wildsOK, wildsErr = pcall(wildsDex.draw, wildsDex)
graphics.draw = realWildsDraw
Assets.image = realWildsImage
Assets.imageData = realWildsImageData
PaletteFX.markTrueColor = realWildsMark
PartyMenu.drawIcon = drawIconBeforeWilds
T.check(wildsOK,
  "Wilds artwork draws without its global icon hook: " .. tostring(wildsErr))
T.eq(#wildsDraws, 3,
  "every visible Pokédex row consumes Wilds' exported sprite sheet")
local wildsCalls = wildsRun.loader.exports.overworld_wild_spawns.calls
T.eq(#wildsCalls, 3,
  "each Pokédex species is resolved once through Wilds' public API")
for index, call in ipairs(wildsCalls) do
  T.eq(call.species, "FIXMON_" .. string.char(64 + index),
    "Wilds resolver receives Pokédex species " .. index)
  T.eq(call.role, "party_menu",
    "Wilds resolver receives the stable menu-art role")
end
T.check(wildsDraws[1] and wildsDraws[1].quad.y == 48,
  "the focused Pokédex row uses Wilds' authored walk frame")
for index = 2, #wildsDraws do
  T.check(wildsDraws[index].quad.y == 0,
    "unfocused Wilds row " .. index .. " uses its idle frame")
end
local exactWildsMarks, broadWildsMark = 0, false
for _, rect in ipairs(wildsMarks) do
  if rect.x < 30 and rect.y >= 20 and rect.y < 84 then
    if rect.w < 16 and rect.h <= 1 then
      exactWildsMarks = exactWildsMarks + 1
    end
    if rect.w >= 16 and rect.h >= 16 then broadWildsMark = true end
  end
end
T.check(exactWildsMarks > 0 and not broadWildsMark,
  "Wilds transparency never restores a square behind a Pokédex icon")
wildsRun.release()
end

T.finish("modern_pokedex_ui")
