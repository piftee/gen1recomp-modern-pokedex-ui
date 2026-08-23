-- A small public-hook example: the page exists only for species whose data
-- mod actually supplies abilities. Nil rows are filtered by Modern Pokedex.
return function(mod)
  mod.hooks:wrap("ui.pokedex.pages",
    function(next, game, pages, ctx)
      local out = next(game, pages, ctx)
      out[#out + 1] = {
        id = "abilities",
        label = "ABILITY",
        title = "KNOWN ABILITIES",
        rows = function(page)
          local abilities = page.def.extraAbilities or {}
          return {
            { label = "PRIMARY", value = abilities[1] },
            { label = "SECONDARY", value = abilities[2] },
          }
        end,
      }
      return out
    end)
end
