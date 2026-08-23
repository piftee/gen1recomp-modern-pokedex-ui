-- Modern Pokedex UI keeps the native discovery data and action behavior, then
-- replaces the dex list, its action overlay, and the species data page.
return function(mod)
  mod.options:define({
    { key = "responsive", label = "POKEDEX WIDESCREEN", type = "toggle",
      default = true },
    { key = "pattern", label = "POKEDEX BACKDROP", type = "choice",
      default = "grid", choices = {
        { "GRID", "grid" }, { "PLAIN", "plain" },
      } },
  })

  local crystal251 = mod.find("CRYSTAL_251")
  local usefulMoveInfo = mod.find("useful_move_info")
  local compatibility = {
    hgssSprites = mod.find("HGSS_SPRITES") ~= nil,
    uniqueMenuIcons = mod.find("unique_menu_icons") ~= nil,
    crystalMoveScripts = crystal251 and crystal251.exports
      and crystal251.exports.crystalMoveScripts,
    moveEffectText = usefulMoveInfo and usefulMoveInfo.exports
      and usefulMoveInfo.exports.effectText,
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
  mod.log:info("modern Pokedex enabled%s",
    #icons > 0 and (" with " .. table.concat(icons, " + ")) or "")
end
