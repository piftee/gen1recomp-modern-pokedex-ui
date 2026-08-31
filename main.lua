-- Modern Pokedex UI keeps the native discovery data and action behavior, then
-- replaces the dex list, its action overlay, and the species data page.
return function(mod)
  local activeGame
  local reconcileElapsed = 0
  local OWNERSHIP_PROOF_FLAGS = {
    EVENT_CHOSE_CHARMANDER = "CHARMANDER",
    EVENT_CHOSE_SQUIRTLE = "SQUIRTLE",
    EVENT_CHOSE_BULBASAUR = "BULBASAUR",
    EVENT_GOT_BULBASAUR_IN_CERULEAN = "BULBASAUR",
    EVENT_GOT_SQUIRTLE_FROM_OFFICER_JENNY = "SQUIRTLE",
    EVENT_GOT_EEVEE = "EEVEE",
  }

  -- A Pokémon in the player's live save is stronger evidence of ownership
  -- than the route that placed it there. Vanilla catches, gifts, trades and
  -- evolutions update the Pokédex themselves, but some third-party acquisition
  -- paths only append the Pokémon to the party or PC. Reconcile those sources
  -- silently so existing saves self-heal without every companion mod needing
  -- a bespoke compatibility patch.
  local function registerOwnedSpecies(game, species)
    if type(game) ~= "table" or type(game.save) ~= "table"
        or species == nil then return false end
    local pokemon = game.data and game.data.pokemon
    local def = type(pokemon) == "table" and pokemon[species] or nil
    -- Species without a Pokédex number cannot be represented by either the
    -- native controller or this presentation. Do not inflate global counts
    -- with temporary forms or stale ids from an unloaded content mod.
    if type(def) ~= "table" or def.dex == nil then return false end

    local dex = game.save.pokedex
    if type(dex) ~= "table" then
      dex = {}
      game.save.pokedex = dex
    end
    if type(dex.seen) ~= "table" then dex.seen = {} end
    if type(dex.owned) ~= "table" then dex.owned = {} end
    local added = dex.owned[species] ~= true
    dex.seen[species] = true
    dex.owned[species] = true
    return added
  end

  local function reconcileOwnedPokemon(game)
    if type(game) ~= "table" or type(game.save) ~= "table" then return 0 end
    local save, added, visited = game.save, 0, {}

    local function recordSpecies(species)
      if species == nil or visited[species] then return end
      visited[species] = true
      if registerOwnedSpecies(game, species) then added = added + 1 end
    end

    local function record(mon)
      if type(mon) ~= "table" or mon.isEgg == true then return end
      recordSpecies(mon.species)
    end

    local function scan(list)
      if type(list) ~= "table" then return end
      for _, mon in pairs(list) do record(mon) end
    end

    scan(save.party)
    for _, box in pairs(type(save.boxes) == "table" and save.boxes or {}) do
      -- Normal saves contain a list of box lists. Accept a flat third-party
      -- box as well; malformed metadata is ignored by record().
      if type(box) == "table" and box.species ~= nil then
        record(box)
      else
        scan(box)
      end
    end
    scan(save.box) -- pre-12-box saves and older companion mods

    local daycare = save.daycare
    if type(daycare) == "table" then
      record(daycare.mon)
      scan(daycare.mons)
    end

    -- Hall of Fame records are historical proof that a species belonged to
    -- the player, so they can restore ownership lost from an older broken
    -- acquisition path even when that Pokémon is no longer in storage.
    for _, roster in pairs(type(save.hallOfFame) == "table"
        and save.hallOfFame or {}) do
      scan(roster)
    end

    -- These story flags are only written after a successful gift and are
    -- therefore safe historical evidence when an already-evolved or traded-
    -- away gift is no longer present in a standard container. Yellow reuses
    -- the otherwise opaque EVENT_54F for Damian's Charmander, so gate that
    -- one (and its special starter) on the save version.
    local flags = type(save.flags) == "table" and save.flags or {}
    for flag, species in pairs(OWNERSHIP_PROOF_FLAGS) do
      if flags[flag] then recordSpecies(species) end
    end
    if tostring(save.version or ""):lower() == "yellow" then
      if flags.EVENT_GOT_STARTER then recordSpecies("PIKACHU") end
      if flags.EVENT_54F then recordSpecies("CHARMANDER") end
    end
    return added
  end

  mod.exports.registerOwnedSpecies = registerOwnedSpecies
  mod.exports.reconcileOwnedPokemon = reconcileOwnedPokemon

  -- Repair loaded saves immediately, then keep common third-party paths
  -- covered with a deliberately low-frequency observer. This preserves the
  -- species that was actually obtained before a later evolution can replace
  -- it in the party. The screen factory also performs the same idempotent
  -- check directly before constructing the native list.
  mod.events:on("game.ready", function(event)
    activeGame = type(event) == "table" and event.game or activeGame
    reconcileOwnedPokemon(activeGame)
  end, 1000)
  mod.events:on("save.loaded", function()
    reconcileOwnedPokemon(activeGame)
  end, -1000)
  mod.events:on("save.created", function()
    reconcileOwnedPokemon(activeGame)
  end, -1000)
  mod.events:on("screen.pushed", function(event)
    local state = type(event) == "table" and event.state or nil
    local game = type(state) == "table" and state.game or activeGame
    if type(game) == "table" then activeGame = game end
    reconcileOwnedPokemon(game)
  end, -1000)
  mod.events:on("pokemon.caught", function(event)
    local game = type(event) == "table" and event.game or activeGame
    if type(event) == "table" then
      registerOwnedSpecies(game, event.species)
    end
    reconcileOwnedPokemon(game)
  end, -1000)
  mod.hooks:wrap("save.write", function(next, game)
    reconcileOwnedPokemon(game or activeGame)
    return next(game)
  end, 1000)
  mod.hooks:wrap("input.step", function(next, game, dt)
    if type(game) == "table" then activeGame = game end
    reconcileElapsed = reconcileElapsed + math.max(0, tonumber(dt) or 0)
    if reconcileElapsed >= 0.5 then
      reconcileElapsed = reconcileElapsed % 0.5
      reconcileOwnedPokemon(game or activeGame)
    end
    return next(game, dt)
  end, -1000)

  local optionSchema = {
    { key = "responsive", label = "POKEDEX WIDESCREEN", type = "toggle",
      default = true },
    { key = "pattern", label = "POKEDEX BACKDROP", type = "choice",
      default = "grid", choices = {
        { "GRID", "grid" }, { "PLAIN", "plain" },
      } },
    { key = "theme", label = "POKEDEX COLOURS", type = "choice",
      default = "light", choices = {
        { "LIGHT", "light" }, { "DARK", "dark" },
      } },
  }
  mod.options:define(optionSchema)

  local nestedLabels = {
    responsive = "WIDESCREEN",
    pattern = "BACKDROP",
    theme = "COLOURS",
  }

  local function setOption(game, key, value)
    local options = game and game.save and game.save.options
    if options then
      options.modOptions = options.modOptions or {}
      options.modOptions[mod.id] = options.modOptions[mod.id] or {}
      options.modOptions[mod.id][key] = value
    end
    local loader = game and game.mods
    if loader then
      loader.modOptions = loader.modOptions or {}
      loader.modOptions[mod.id] = loader.modOptions[mod.id] or {}
      loader.modOptions[mod.id][key] = value
      if loader.events then
        loader.events:emit("mod.options_changed",
          { mod = mod.id, key = key, value = value })
      end
    end
  end

  local function optionRows()
    local out = {}
    for _, sourceRow in ipairs(optionSchema) do
      local row = sourceRow
      local rendered = {
        id = "modern_pokedex_ui_" .. row.key,
        label = nestedLabels[row.key] or row.label or row.key,
      }
      if row.type == "toggle" then
        rendered.value = function()
          return mod.options:get(row.key) and "ON" or "OFF"
        end
        rendered.step = function(game)
          setOption(game, row.key, not mod.options:get(row.key))
          return true
        end
      elseif row.type == "choice" then
        rendered.value = function()
          local current = mod.options:get(row.key)
          for _, choice in ipairs(row.choices or {}) do
            if choice[2] == current then return choice[1] end
          end
          return "----"
        end
        rendered.step = function(game, direction)
          local choices = row.choices or {}
          if #choices == 0 then return false end
          local current = mod.options:get(row.key)
          local index = 1
          for i, choice in ipairs(choices) do
            if choice[2] == current then index = i break end
          end
          index = (index - 1 + (direction or 1)) % #choices + 1
          setOption(game, row.key, choices[index][2])
          return true
        end
      end
      out[#out + 1] = rendered
    end
    return out
  end

  -- Match the other Modern UI mods: the ordinary Options menu gains one
  -- concise entry, while the individual settings live on their own nested
  -- Options-style page. The mod manager and this page share the same saved
  -- values and live loader state.
  mod.hooks:wrap("ui.options.rows", function(next, game, rows)
    local out = next(game, rows)
    if type(out) ~= "table" then return out end
    out[#out + 1] = {
      id = "modern_pokedex_ui",
      -- Keep the main-row label inside the 128px option-box text area. The
      -- opened page is exclusively this mod's settings, so the trailing UI
      -- adds no useful distinction there.
      label = "MODERN POKEDEX",
      value = function() return "OPEN" end,
      activate = function(activeGame)
        local OptionsMenu = require("src.ui.OptionsMenu")
        local page = OptionsMenu.new(activeGame)
        local rows = optionRows()
        page.rows, page.view = rows, rows
        page.index, page.scroll, page.sub = 1, 0, true
        activeGame.stack:push(page)
      end,
    }
    return out
  end)

  local GameVersion = require("src.core.GameVersion")
  if type(GameVersion.generation) == "function"
      and GameVersion.generation() == 2 then
    return require("mods.modern_pokedex_ui.gen2")(mod)
  end

  local crystal251 = mod.find("CRYSTAL_251")
  local usefulMoveInfo = mod.find("useful_move_info")
  local wildsOfKanto = mod.find("overworld_wild_spawns")
  local compatibility = {
    gen1ModernUi = mod.find("gen1_modern_ui") ~= nil,
    crystal251 = crystal251 ~= nil,
    hgssSprites = mod.find("HGSS_SPRITES") ~= nil,
    uniqueMenuIcons = mod.find("unique_menu_icons") ~= nil,
    wildsOfKanto = wildsOfKanto ~= nil,
    wildsOfKantoExports = wildsOfKanto and wildsOfKanto.exports or nil,
    crystalMoveScripts = crystal251 and crystal251.exports
      and crystal251.exports.crystalMoveScripts,
    moveEffectText = usefulMoveInfo and usefulMoveInfo.exports
      and usefulMoveInfo.exports.effectText,
    reconcileOwnedPokemon = reconcileOwnedPokemon,
  }

  local source, readErr = mod:read("screen.lua")
  if not source then
    mod.log:error("screen.lua is missing (%s); reinstall the mod",
      tostring(readErr or "unknown read error"))
    return
  end
  local chunk, compileErr = load(source, "@" .. mod.path .. "/screen.lua")
  if not chunk then
    mod.log:error("screen.lua did not compile: %s", tostring(compileErr))
    return
  end
  local okFactory, factory = pcall(chunk)
  if not okFactory or type(factory) ~= "function" then
    mod.log:error("screen.lua must return a factory function: %s",
      tostring(factory))
    return
  end
  local okScreens, screens = pcall(factory, mod, compatibility)
  if not okScreens or type(screens) ~= "table"
      or type(screens.pokedex) ~= "table"
      or type(screens.pokedex.new) ~= "function"
      or type(screens.entry) ~= "table"
      or type(screens.entry.new) ~= "function" then
    mod.log:error("Pokedex screen factory failed: %s", tostring(screens))
    return
  end

  local function install(id, record)
    if mod.content.screens:get(id) then
      mod.content.screens:override(id, record)
    else
      mod.content.screens:register(id, record)
    end
  end
  install("PokedexMenu", screens.pokedex)
  install("DexEntryMenu", screens.entry)

  -- Gen1 Modern UI leaves screens with this contract source-owned. The small
  -- models remain useful to inspection tools without suppressing our canvas.
  mod.exports.gen1ModernUi = {
    apiVersion = 1,
    screens = {
      ModernPokedexList = {
        match = function(state)
          return type(state) == "table" and state.modernPokedexUI == true
        end,
        model = function(game, state)
          local row = state.modernDexEntries
            and state.modernDexEntries[state.index]
          return {
            title = "POKéDEX",
            rows = row and { { label = row.def and row.def.name or "-----",
              value = row.owned and "CAUGHT" or row.seen and "SEEN" or "---" } }
              or {},
            index = 1,
            footer = { "Modern Pokedex UI" },
          }
        end,
        layer = "screen",
        canSuppressNative = false,
      },
      ModernPokedexEntry = {
        match = function(state)
          return type(state) == "table" and state.modernPokedexEntry == true
        end,
        model = function(game, state)
          return {
            title = state.def and state.def.name or "POKéDEX DATA",
            rows = {}, index = 1, footer = { "Modern Pokedex UI" },
          }
        end,
        layer = "screen",
        canSuppressNative = false,
      },
    },
  }
  local modern = mod.find("gen1_modern_ui")
  local exports = modern and modern.exports
  if exports and type(exports.registerAdapter) == "function" then
    local ok, registered, reason = pcall(exports.registerAdapter, {
      owner = mod.id,
      contract = mod.exports.gen1ModernUi,
    })
    if not ok or registered == false then
      mod.log:warn("Gen1 Modern UI adapter registration failed: %s",
        tostring(reason or registered))
    end
  end

  local icons = {}
  if compatibility.hgssSprites then icons[#icons + 1] = "HGSS" end
  if compatibility.uniqueMenuIcons then icons[#icons + 1] = "Unique Icons" end
  if compatibility.wildsOfKanto then icons[#icons + 1] = "Wilds of Kanto" end
  mod.log:info("modern Pokedex enabled%s",
    #icons > 0 and (" with " .. table.concat(icons, " + ")) or "")
end
