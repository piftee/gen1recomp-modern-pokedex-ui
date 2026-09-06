-- Headless regression for static and animated provider image ownership.
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local function image() return { getWidth = function() return 56 end } end
local source, animated, foreign, question = image(), image(), image(), image()
local selected, provider = source, nil
local shader, drawnShader, drawnImage, paletteCalls = nil, nil, nil, 0
local speciesPalette, questionPalette = {}, {}
local paletteShader, inheritedShader = {}, {}
local def = { name = "ABRA", spriteFront = "abra.png", types = { "PSYCHIC" } }
local row = { species = "ABRA", dex = 63, seen = true, caught = true }
local menu = { rows = { row }, index = 1, scroll = 0, view = "list",
  pokemon = { ABRA = def }, palettes = {}, gfx = { questionMarkPalette = questionPalette } }
function menu:picFor() return selected end
function menu:questionMark() return question end
function menu:current() return row end
function menu:totals() return 1, 1 end
function menu:monName() return "ABRA" end
package.loaded["src.ui.gen2.PokedexMenu"] = { new = function() return menu end }
package.loaded["src.ui.gen2.Chrome"] = { paletteGlyphs = function() return nil end }
package.loaded["src.render.Font"] = { width = function(s) return #s * 8 end, draw = function() end }
package.loaded["src.render.Assets"] = { image = function(path)
  assert(path == "abra.png"); return source
end }
package.loaded["src.world.gen2.Palettes"] = { monColors = function() return speciesPalette end }
local usedPalette
package.loaded["src.render.GbcPalette"] = {
  available = function() return true end,
  with = function(colors, body)
    usedPalette, paletteCalls = colors, paletteCalls + 1
    local old = shader; shader = paletteShader; body(); shader = old
  end,
}
love.graphics = {
  setColor = function() end, rectangle = function() end, line = function() end,
  polygon = function() end,
  getShader = function() return shader end,
  setShader = function(value) shader = value end,
  draw = function(value) drawnImage, drawnShader = value, shader end,
}
local registered
local mod = {
  path = "mods/modern_pokedex_ui", exports = {}, log = { info = function() end },
  find = function() return provider end,
  read = function(self, name)
    local f = assert(io.open(self.path .. "/" .. name, "rb"))
    local text = f:read("*a"); f:close(); return text
  end,
  content = { screens = {
    get = function() end,
    register = function(_, _, value) registered = value end,
  } },
}
assert(loadfile(mod.path .. "/gen2.lua"))()(mod)
registered.new({})
local function checkDraw(label, expected, raw)
  shader, paletteCalls = inheritedShader, 0
  menu:drawPanel()
  T.eq(drawnImage, expected, label .. " retains selected artwork")
  T.check((raw and drawnShader == nil) or (not raw and drawnShader == paletteShader),
    label .. " applies the correct colour treatment")
  T.eq(paletteCalls, raw and 0 or 1, label .. " palette passes")
  T.eq(shader, inheritedShader, label .. " restores caller shader")
end
checkDraw("native without companion", source, false)
provider = { exports = { isCrystalImage = function(value) return value == animated end } }
checkDraw("native with companion", source, false)
selected = animated
checkDraw("animated frame without filename", animated, true)
selected, def.trueColor = source, true
checkDraw("registered full-colour static frame", source, true)
selected = foreign
checkDraw("foreign frame with same species flag", foreign, false)
row.seen = false
checkDraw("unseen question mark", question, false)
T.eq(usedPalette, questionPalette, "unseen keeps question-mark palette")
row.seen, selected, provider = true, source, { exports = {} }
checkDraw("static colour provider without predicate", source, true)
def.trueColor, mod.find = false, nil
checkDraw("native with no mod lookup API", source, false)
T.eq(usedPalette, speciesPalette, "native keeps species palette")
T.finish("modern_pokedex_ui Gen 2 sprite colours")
