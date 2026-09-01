-- Real Gen 2 visual proof. Run from a Gen 2-capable engine checkout with an
-- imported Gold/Silver/Crystal cache, for example:
--   POKEPORT_VERSION=gold POKEPORT_IDENTITY=gen2-mod-proof \
--   POKEPORT_TOUCH=0 SHOT_DIR=/tmp/gen2-evolution \
--   POKEPORT_DRIVER=mods/modern_pokedex_ui/tests/gen2_evolution_preview_driver.lua \
--   love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Screens = require("src.ui.Screens")
  local edition = require("src.core.GameVersion").get()
  local dir = os.getenv("SHOT_DIR") or "artifacts/gen2-evolution-info"

  love.window.setMode(1280, 720, { resizable = true })
  while game.stack:top() do game.stack:pop() end
  game.save.pokedex = game.save.pokedex or {}
  game.save.pokedex.seen = game.save.pokedex.seen or {}
  game.save.pokedex.caught = game.save.pokedex.caught or {}
  for _, species in ipairs({
    "PICHU", "PIKACHU", "RAICHU", "EEVEE", "VAPOREON", "JOLTEON",
    "FLAREON", "ESPEON", "UMBREON",
  }) do
    game.save.pokedex.seen[species] = true
    game.save.pokedex.caught[species] = true
  end

  local dex = Screens.push(game, "Gen2PokedexMenu", { save = game.save })
  assert(dex.modernPokedexGeneration == 2,
    "Modern Pokedex did not install its Gen 2 controller")
  local function select(species)
    dex:rebuild()
    dex.modernDexEntries = dex.rows
    for index, row in ipairs(dex.rows) do
      if row.species == species then
        dex.index = index
        dex:ensureVisible()
        dex.view = "family"
        dex.modernGen2FamilySpecies = nil
        return
      end
    end
    error("species absent from Gen 2 Pokedex: " .. species)
  end

  select("PICHU")
  local pichu = dex:modernGen2EvolutionFamily("PICHU")
  assert(#pichu == 3 and pichu[1].species == "PICHU"
      and pichu[3].species == "RAICHU",
    "Pichu family did not resolve in evolution order")
  dex.modernGen2FamilySpecies = "PICHU"
  dex.modernGen2Family = pichu
  dex.modernGen2FamilyCursor = 2
  U.wait(2)
  assert(U.shot(game, ("%s/pichu-family-%s.png"):format(dir, edition)))

  select("EEVEE")
  local eevee = dex:modernGen2EvolutionFamily("EEVEE")
  assert(#eevee == 6, "Eevee should have six Gen 2 family members")
  assert(eevee[2].species == "VAPOREON" and eevee[3].species == "JOLTEON",
    "Eevee branches should use National Dex order")
  dex.modernGen2FamilySpecies = "EEVEE"
  dex.modernGen2Family = eevee
  dex.modernGen2FamilyCursor = 2
  U.wait(2)
  assert(U.shot(game, ("%s/eevee-family-%s.png"):format(dir, edition)))
  U.log("Gen 2 evolution screenshots captured under " .. dir)
end
