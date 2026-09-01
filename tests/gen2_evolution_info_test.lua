-- Standalone: luajit mods/modern_pokedex_ui/tests/gen2_evolution_info_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Font = require("src.render.Font")
Font.load(T.fixtures.fresh())

local savedModules = {}
local function stub(name, value)
  savedModules[name] = package.loaded[name]
  package.loaded[name] = value
end

local input = { pressed = {} }
function input:wasPressed(key) return self.pressed[key] == true end

local NativePokedex = {}
function NativePokedex.new(game)
  local menu = {
    game = game, save = game.save, data = game.data,
    pokemon = game.data.pokemon, dex = { entries = game.data.dexEntries },
    rows = {}, index = 1, scroll = 0, view = "entry", page = 1,
    entryAction = 1, gfx = {}, nativeUpdates = 0,
  }
  function menu:rebuild()
    self.rows = {}
    local dex = self.save.pokedex or {}
    for _, species in ipairs(self.data.order) do
      local entry = self.data.dexEntries[species]
      self.rows[#self.rows + 1] = {
        species = species, dex = entry.dex,
        seen = dex.seen and dex.seen[species] == true,
        caught = dex.caught and dex.caught[species] == true,
      }
    end
  end
  function menu:current() return self.rows[self.index] end
  function menu:ensureVisible() self.scroll = math.max(0, self.index - 6) end
  function menu:totals()
    local seen, caught = 0, 0
    for _, row in ipairs(self.rows) do
      if row.seen then seen = seen + 1 end
      if row.caught then caught = caught + 1 end
    end
    return seen, caught
  end
  function menu:monName(species) return self.pokemon[species].name end
  function menu:picFor() return nil end
  function menu:questionMark() return nil end
  function menu:playCry(species) self.lastCry = species end
  function menu:printEntry() self.printed = (self.printed or 0) + 1 end
  function menu:optionRows() return {} end
  function menu:searchTypeName() return "-----" end
  function menu:update() self.nativeUpdates = self.nativeUpdates + 1 end
  function menu:drawPanel() self.nativeDraws = (self.nativeDraws or 0) + 1 end
  menu:rebuild()
  return menu
end

stub("src.ui.gen2.PokedexMenu", NativePokedex)
stub("src.ui.gen2.Chrome", {
  paletteGlyphs = function() return nil end,
  wrap = function(text) return { tostring(text or "") } end,
})
stub("src.render.GbcPalette", { available = function() return false end })
stub("src.world.gen2.Palettes", { monColors = function() return nil end })

local pokemon = {
  PICHU = {
    id = "PICHU", dex = 172, name = "PICHU", types = { "ELECTRIC" },
    evolutions = { { method = "EVOLVE_HAPPINESS", time = "ANYTIME",
      into = "PIKACHU" } },
  },
  PIKACHU = {
    id = "PIKACHU", dex = 25, name = "PIKACHU", types = { "ELECTRIC" },
    evolutions = { { method = "EVOLVE_ITEM", item = "THUNDERSTONE",
      into = "RAICHU" } },
  },
  RAICHU = {
    id = "RAICHU", dex = 26, name = "RAICHU", types = { "ELECTRIC" },
    evolutions = {},
  },
  DITTO = {
    id = "DITTO", dex = 132, name = "DITTO", types = { "NORMAL" },
    evolutions = {},
  },
}
local dexEntries = {}
for species, def in pairs(pokemon) do
  dexEntries[species] = { dex = def.dex, name = def.name, kind = "POKéMON",
    text = "TEST ENTRY", text2 = "SECOND PAGE" }
end
local game = {
  input = input,
  data = {
    pokemon = pokemon, dexEntries = dexEntries,
    order = { "PICHU", "PIKACHU", "RAICHU", "DITTO" },
    items = {
      THUNDERSTONE = { name = "THUNDERSTONE" },
      KINGS_ROCK = { name = "KING'S ROCK" },
    },
  },
  save = { pokedex = {
    seen = { PICHU = true, PIKACHU = true, RAICHU = true, DITTO = true },
    caught = { PICHU = true, PIKACHU = true, RAICHU = true, DITTO = true },
  } },
}

local registered
local screens = {
  get = function() return nil end,
  register = function(_, id, record)
    if id == "Gen2PokedexMenu" then registered = record end
  end,
  override = function(_, id, record)
    if id == "Gen2PokedexMenu" then registered = record end
  end,
}
local mod = {
  exports = {}, content = { screens = screens },
  log = { info = function() end },
}
local factory = assert(loadfile("mods/modern_pokedex_ui/gen2.lua"))()
factory(mod)
T.check(type(registered) == "table" and type(registered.new) == "function",
  "the Gen 2 Pokedex provider is installed")

local menu = registered.new(game)
T.eq(menu.modernPokedexGeneration, 2,
  "the decorated controller identifies the Gen 2 path")

-- The three-digit dex number occupies 24px. Keep the following name outside
-- that cell with a visible gutter so scaled widescreen rows never run the two
-- labels together.
local listText = {}
local realFontDraw = Font.draw
Font.draw = function(value, x, y)
  listText[#listText + 1] = { value = tostring(value), x = x, y = y }
  return realFontDraw(value, x, y)
end
menu.view = "list"
menu:drawPanel()
Font.draw = realFontDraw
local numberText, nameText
for _, item in ipairs(listText) do
  if item.value == "172" and not numberText then numberText = item end
  if item.value == "PICHU" and not nameText then nameText = item end
end
T.check(numberText ~= nil and nameText ~= nil,
  "the Gen 2 list draws both the dex number and species name")
T.check(numberText and nameText
    and nameText.x >= numberText.x + Font.width(numberText.value) + 2,
  "the Gen 2 list leaves a clear gutter between number and name")
menu.view = "entry"

local family = menu:modernGen2EvolutionFamily("RAICHU")
T.eq(#family, 3, "an evolved species resolves its complete family")
T.same({ family[1].species, family[2].species, family[3].species },
  { "PICHU", "PIKACHU", "RAICHU" },
  "family order follows evolution depth rather than National Dex number")
T.eq(menu:modernGen2EvolutionLabel(family[1].parent), "BASIC SPECIES",
  "the family root has a useful label")
T.eq(menu:modernGen2EvolutionLabel(family[2].parent), "HIGH HAPPINESS",
  "Gen 2 happiness evolution is described")
T.eq(menu:modernGen2EvolutionLabel(family[3].parent), "USE THUNDERSTONE",
  "Gen 2 stone evolution is described")
T.eq(menu:modernGen2EvolutionLabel({ edge = {
    method = "EVOLVE_TRADE", item = "KINGS_ROCK",
  } }), "TRADE: KING'S ROCK", "held-item trades are described")
T.eq(menu:modernGen2EvolutionLabel({ edge = {
    method = "EVOLVE_HAPPINESS", time = "MORNDAY",
  } }), "HAPPINESS, DAY", "daytime happiness is distinguished")
T.eq(menu:modernGen2EvolutionLabel({ edge = {
    method = "EVOLVE_HAPPINESS", time = "NITE",
  } }), "HAPPINESS, NIGHT", "nighttime happiness is distinguished")
T.eq(menu:modernGen2EvolutionLabel({ edge = {
    method = "EVOLVE_STAT", level = 20, comparison = "ATK_EQ_DEF",
  } }), "LV20: ATK = DEF", "Tyrogue's stat condition is described")

local function press(key)
  input.pressed[key] = true
  menu:update(0)
  input.pressed[key] = nil
end

press("right")
press("right")
T.same(menu.modernGen2EntryActions,
  { "PAGE", "AREA", "EVO", "CRY", "PRNT" },
  "a real family adds EVO without removing native Gen 2 actions")
press("a")
T.eq(menu.view, "family", "EVO opens the evolution-family page")
T.eq(menu.modernGen2FamilyCursor, 1,
  "the family page initially selects the currently viewed species")
local drawOK, drawErr = pcall(menu.drawPanel, menu)
T.check(drawOK, "the Gen 2 family page draws headlessly: " .. tostring(drawErr))

press("down")
T.eq(menu.modernGen2FamilyCursor, 2,
  "DOWN selects the next family member")
press("a")
T.eq(menu.view, "entry", "A opens a known family member's data")
T.eq(menu:current().species, "PIKACHU",
  "opening a relative updates the native Gen 2 list selection")
T.eq(menu.lastCry, "PIKACHU", "opening a relative plays its cry")

-- Standalone species retain the cartridge's original PAGE/AREA/CRY/PRNT bar
-- instead of exposing an empty evolution page.
menu.index, menu.view, menu.entryAction = 4, "entry", 1
press("right")
press("right")
T.same(menu.modernGen2EntryActions, { "PAGE", "AREA", "CRY", "PRNT" },
  "a standalone species keeps the four native actions")
press("a")
T.eq(menu.view, "entry", "the third standalone action remains CRY")
T.eq(menu.lastCry, "DITTO", "CRY was not displaced by an empty EVO action")

-- New-entry catch sequences remain owned by the native two-page controller.
menu.newEntry = true
local nativeBefore = menu.nativeUpdates
press("a")
T.eq(menu.nativeUpdates, nativeBefore + 1,
  "the native Gen 2 new-entry sequence is left intact")

for name, value in pairs(savedModules) do package.loaded[name] = value end
T.finish("modern_pokedex_ui gen2 evolution info")
