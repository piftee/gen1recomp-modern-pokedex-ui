-- Standalone on a Gen 2-capable engine checkout:
--   luajit mods/modern_pokedex_ui/tests/gen2_native_evolution_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local okNative, NativePokedex = pcall(require, "src.ui.gen2.PokedexMenu")
if not okNative then
  T.check(true, "this engine checkout has no native Gen 2 Pokedex controller")
  T.finish("modern_pokedex_ui native Gen 2 evolution info (skipped)")
  return
end

local Font = require("src.render.Font")
Font.load(T.fixtures.fresh())

local pokemon = {
  PICHU = {
    id = "PICHU", dex = 172, name = "PICHU", types = { "ELECTRIC" },
    levelMoves = { { level = 1, move = "THUNDERSHOCK" } },
    evolutions = { { method = "EVOLVE_HAPPINESS", time = "ANYTIME",
      into = "PIKACHU" } },
  },
  PIKACHU = {
    id = "PIKACHU", dex = 25, name = "PIKACHU", types = { "ELECTRIC" },
    levelMoves = { { level = 1, move = "THUNDERSHOCK" } },
    tmhm = { "THUNDER", "FLASH" },
    tutorMoves = { "THUNDERBOLT" },
    evolutions = { { method = "EVOLVE_ITEM", item = "THUNDERSTONE",
      into = "RAICHU" } },
  },
  RAICHU = {
    id = "RAICHU", dex = 26, name = "RAICHU", types = { "ELECTRIC" },
    evolutions = {},
  },
}
local order = { "PICHU", "PIKACHU", "RAICHU" }
local entries = {}
for species, def in pairs(pokemon) do
  entries[species] = {
    dex = def.dex, name = def.name, kind = "MOUSE",
    height = 4, weight = 44, text = "TEST ENTRY", text2 = "SECOND PAGE",
  }
end

local input = { pressed = {} }
function input:wasPressed(key) return self.pressed[key] == true end
local game = {
  input = input,
  data = {
    pokemon = pokemon, items = {
      THUNDERSTONE = { name = "THUNDERSTONE" },
      TM_THUNDER = { name = "TM25", tmLabel = "TM25", teaches = "THUNDER" },
      HM_FLASH = { name = "HM05", tmLabel = "HM05", teaches = "FLASH" },
    },
    moves = {
      THUNDERSHOCK = { id = "THUNDERSHOCK", name = "THUNDERSHOCK",
        type = "ELECTRIC", power = 40, accuracy = 100, pp = 30,
        description = "An attack that may cause paralysis." },
      THUNDER = { id = "THUNDER", name = "THUNDER", type = "ELECTRIC",
        power = 120, accuracy = 70, pp = 10,
        description = "A wicked thunderbolt is dropped." },
      FLASH = { id = "FLASH", name = "FLASH", type = "NORMAL",
        power = 0, accuracy = 70, pp = 20,
        description = "Blinds the foe to reduce accuracy." },
      THUNDERBOLT = { id = "THUNDERBOLT", name = "THUNDERBOLT",
        type = "ELECTRIC", power = 95, accuracy = 100, pp = 15,
        description = "An electric blast that may paralyze." },
    },
    type_chart = { types = {
      ELECTRIC = { name = "ELECTRIC", category = "special" },
      NORMAL = { name = "NORMAL", category = "physical" },
    } },
  },
  save = { pokedex = {
    seen = { PICHU = true, PIKACHU = true, RAICHU = true },
    caught = { PICHU = true, PIKACHU = true, RAICHU = true },
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
  path = "mods/modern_pokedex_ui",
  read = function(self, name)
    local file = assert(io.open(self.path .. "/" .. name, "rb"))
    local source = file:read("*a"); file:close(); return source
  end,
  exports = {}, content = { screens = screens },
  log = { info = function() end },
}
assert(loadfile("mods/modern_pokedex_ui/gen2.lua"))()(mod)
local menu = registered.new(game, {
  save = game.save, pokemon = pokemon,
  pokedex = { entries = entries, newOrder = order,
    alphabeticalOrder = order },
  palettes = {}, menuGfx = {},
})

T.check(getmetatable(menu) == NativePokedex,
  "the mod decorates the real native Gen 2 controller")
T.eq(#menu.rows, 3, "the native controller built all fixture rows")
local family = menu:modernGen2EvolutionFamily("RAICHU")
T.same({ family[1].species, family[2].species, family[3].species }, order,
  "the live controller resolves the complete Pichu family")
local moves = menu:modernGen2MoveRowsFor("PIKACHU")
T.same({ moves[2].sourceDetail, moves[3].sourceDetail,
    moves[4].sourceDetail }, { "TM25", "HM05", "TUTOR" },
  "the real controller exposes numbered machines and Crystal tutors")

local function press(key)
  input.pressed[key] = true
  menu:update(0)
  input.pressed[key] = nil
end

menu.view, menu.index, menu.entryAction = "entry", 1, 1
press("right")
press("right")
press("a")
T.eq(menu.view, "family", "the real controller opens the EVO view")
T.eq(menu.modernGen2FamilyCursor, 1,
  "the real controller selects the current family member")
local drawOK, drawErr = pcall(menu.drawPanel, menu)
T.check(drawOK,
  "the native Gen 2 family view renders headlessly: " .. tostring(drawErr))
press("down")
press("a")
T.eq(menu.view, "entry", "a known relative returns to native entry mode")
T.eq(menu:current().species, "PIKACHU",
  "the native list follows the selected relative")

press("right")
press("right")
press("right")
press("a")
T.eq(menu.view, "moves", "the real controller opens the MOVE view")
local movesDrawOK, movesDrawErr = pcall(menu.drawPanel, menu)
T.check(movesDrawOK,
  "the native Gen 2 move list renders headlessly: " .. tostring(movesDrawErr))
press("a")
T.check(menu.modernGen2MoveDetail == true,
  "the real controller opens move details")
local detailDrawOK, detailDrawErr = pcall(menu.drawPanel, menu)
T.check(detailDrawOK,
  "the native Gen 2 move details render headlessly: "
    .. tostring(detailDrawErr))

T.finish("modern_pokedex_ui native Gen 2 evolution info")
