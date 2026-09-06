-- Real Gen 2 move-data proof. Run from a Gen 2-capable engine checkout with
-- an imported Gold/Silver/Crystal cache, for example:
--   POKEPORT_VERSION=crystal POKEPORT_IDENTITY=gen2-mod-proof \
--   POKEPORT_TOUCH=0 SHOT_DIR=/tmp/gen2-pokedex-moves \
--   POKEPORT_DRIVER=mods/modern_pokedex_ui/tests/gen2_move_preview_driver.lua \
--   love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Screens = require("src.ui.Screens")
  local edition = require("src.core.GameVersion").get()
  local dir = os.getenv("SHOT_DIR") or "artifacts/gen2-pokedex-moves"
  U.log("starting Gen 2 move proof for " .. edition)

  love.window.setMode(1280, 720, { resizable = true })
  while game.stack:top() do game.stack:pop() end
  game.save.pokedex = game.save.pokedex or {}
  game.save.pokedex.seen = game.save.pokedex.seen or {}
  game.save.pokedex.caught = game.save.pokedex.caught or {}
  game.save.pokedex.seen.PIKACHU = true
  game.save.pokedex.caught.PIKACHU = true

  local dex = Screens.push(game, "Gen2PokedexMenu", { save = game.save })
  assert(dex.modernPokedexGeneration == 2,
    "Modern Pokedex did not install its Gen 2 controller")
  for index, row in ipairs(dex.rows) do
    if row.species == "PIKACHU" then
      dex.index = index
      dex:ensureVisible()
      break
    end
  end
  assert(dex:current() and dex:current().species == "PIKACHU",
    "Pikachu is absent from the Gen 2 Pokedex")
  U.log("selected Pikachu in the native 251-species controller")

  dex.view, dex.page, dex.entryAction = "entry", 1, 1
  U.wait(2)
  assert(type(dex.modernGen2EntryActions) == "table",
    "modern Gen 2 entry actions were not drawn")
  local moveAction
  for index, action in ipairs(dex.modernGen2EntryActions) do
    if action == "MOVE" then moveAction = index break end
  end
  assert(moveAction, "Pikachu's entry has no MOVE action")
  for _ = 1, #dex.modernGen2EntryActions do
    if dex.entryAction == moveAction then break end
    U.tap(game, "right")
  end
  assert(dex.entryAction == moveAction,
    "could not select MOVE in the modern entry action bar")
  U.tap(game, "a")
  assert(dex.view == "moves", "MOVE did not open the combined learnset")
  U.log("opened the combined learnset through normal menu input")

  local rows = dex:modernGen2MoveRowsFor("PIKACHU")
  local tm25, tutor
  for index, row in ipairs(rows) do
    if row.sourceDetail == "TM25" then tm25 = index end
    if row.kind == "tutor" and row.id == "THUNDERBOLT" then tutor = index end
  end
  assert(tm25, "Pikachu's numbered TM25 compatibility is missing")
  if edition == "crystal" then
    assert(tutor, "Crystal Pikachu's THUNDERBOLT tutor row is missing")
  end
  dex.modernGen2MoveCursor = tm25
  dex.modernGen2MoveScroll = math.max(0, tm25 - 4)
  U.wait(30)
  assert(U.shot(game, ("%s/pikachu-moves-%s.png"):format(dir, edition)))

  U.tap(game, "a")
  assert(dex.modernGen2MoveDetail == true,
    "A did not open the selected move's data")
  local selected = rows[dex.modernGen2MoveCursor]
  assert(selected and selected.move and selected.move.description,
    "the selected Gen 2 move has no ROM description")
  U.wait(30)
  assert(U.shot(game,
    ("%s/pikachu-tm25-data-%s.png"):format(dir, edition)))

  if tutor then
    U.tap(game, "b")
    dex.modernGen2MoveCursor = tutor
    dex.modernGen2MoveScroll = math.max(0, tutor - 4)
    U.wait(30)
    assert(U.shot(game,
      ("%s/pikachu-tutor-%s.png"):format(dir, edition)))
  end

  -- Exercise the 160x144 logical layout used by compact windows and mobile
  -- portrait playfields. The six-action entry bar uses deliberate two-letter
  -- labels here rather than clipping full words into one another.
  love.window.setMode(800, 720, { resizable = true })
  dex.view, dex.entryAction, dex.modernGen2MoveDetail =
    "entry", moveAction, false
  U.wait(30)
  assert(U.shot(game,
    ("%s/pikachu-move-action-compact-%s.png"):format(dir, edition)))
  U.tap(game, "a")
  assert(dex.view == "moves", "compact MOVE action did not open the list")
  dex.modernGen2MoveCursor = tm25
  dex.modernGen2MoveScroll = math.max(0, tm25 - 3)
  U.wait(30)
  assert(U.shot(game,
    ("%s/pikachu-moves-compact-%s.png"):format(dir, edition)))
  U.tap(game, "a")
  U.wait(30)
  assert(U.shot(game,
    ("%s/pikachu-move-data-compact-%s.png"):format(dir, edition)))
  U.log("Gen 2 move screenshots captured under " .. dir)
end
