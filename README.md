# Modern Pokedex UI

Modern Pokedex UI turns Gen I's Pokédex into a useful modern-retro research
tool without pretending the game contains later-generation systems. It keeps
the original discovery flags, cries, Area map, dex text, sprites, and controls,
then presents the data that is genuinely available for each species.

The visual direction combines the clearer hierarchy and tabbed research pages
of newer Pokémon games with Pokémon Red's pixel font, native-scale artwork,
four-shade palette ramps, hard outlines, and chamfered cards.

## What changes

- a responsive Pokédex index with icon cards, caught/seen progress, typing,
  scrolling, starting-letter and type filters, and a live battle-art preview
  on wide displays; search values are limited to discovered species so the
  feature never leaks an unseen Pokémon's name or typing
- a compact 160×144 layout that preserves the same browsing flow
- an INFO page with dex number, caught state, available category, type,
  measurements, and field notes; long notes scroll instead of being discarded
- a STATS page with available base stats, Base Stat Total when the complete
  Gen I set exists, catch rate, base EXP, and growth rate
- a FAMILY page when the species belongs to a real multi-species evolution
  line, including full battle-front artwork for known members, concealed
  unknown members, selectable relatives, and the selected member's evolution
  method
- a MOVES page when level-up or TM/HM compatibility data exists, with a
  selectable, fully type-coloured continuous list limited to level/source,
  name, and PP. Level-up moves appear first and every compatible TM/HM is
  appended beneath them, with its full `TMxx` or `HMxx` number immediately
  before the move name. Its details view repeats the machine number and shows
  type, power, accuracy, category, priority, and effect only when those fields
  are supplied and an effect has meaningful display text (internal
  compatibility identifiers are never shown as descriptions). Crystal 251
  effect families and Useful Move Info's curated vanilla copy are consumed
  when those mods are present. Crystal 251's Flamethrower, Thunderbolt, and Ice
  Beam Move Tutors are correctly labelled `TUTOR` rather than being given a
  false TM number
- the native DATA, CRY, AREA, QUIT, and Pokémon Yellow PRNT actions remain
  authoritative

Pages are species-specific. Missing stats do not create a STATS tab, a
standalone species does not get a FAMILY tab, and an empty learnset does not
get a MOVES tab. Individual labels and facts also disappear when their value
is absent; the UI never invents `0`, `?`, or later-generation mechanics to
fill a reference layout.

## Sprite compatibility

Pokédex icons always go through the same shared menu-icon renderer used by the
party:

- **Wilds of Kanto** is read through its exported follower-sprite selector,
  preserving its configured artwork and authored idle/walk frames even when a
  later-loading icon mod replaces the shared renderer. Selection animation
  never darkens or recolours the sprite.
- **Unique Menu Icons** retains its authored full-colour icon sets and its
  palette-aware Original mode. Full-colour protection follows only visible
  pixels, so transparent icon space never becomes a white backing square.
- **HGSS Visual Overhaul** uses visible-pixel fitting for its padded 32×32,
  two-frame icons, keeping them centred inside the Pokédex cards without grey
  restored rectangles.

The large Pokédex preview and every species profile deliberately resolve the
`battle` front-sprite context. This matches Modern Party UI 0.3.18 and Modern
PC UI 0.2.2, so a sprite selector cannot show one design in battle and a
different design in the Pokédex, stats screen, or PC details rail.
Grayscale battle artwork is coloured with that species' own game palette;
the type palette belongs only to the surrounding card. Already-full-colour
battle replacements bypass both recolouring steps. Portrait colour protection
follows the artwork's visible pixels and removes edge-connected matte, so a
sprite never carries a rectangular backing or shadow into its card.

Type names are translated individually before dual types are joined. Compact
chips take their three-glyph abbreviation from those translated full names;
the mod never asks a translation catalog to translate ambiguous English
abbreviations such as `PSN` or `FLY`.

## Appearance options

Open `MODERN POKEDEX` in the game's regular Options screen to reach its
dedicated Widescreen, Backdrop, and Colours settings. These are synchronized
with the same settings in the mod manager. `COLOURS` switches between the
default Light presentation and a Dark presentation with black research
surfaces, bright text, and type-coloured card accents. Both modes retain the
same modern-retro framing and preserve the authored colours of full-colour
Pokémon icons and battle sprites.

## Controls

### Pokédex index

| Action | Control |
| --- | --- |
| Browse | Up/Down |
| Jump a page | Left/Right |
| Open actions | A |
| Open search | Select |
| Return | B |

In SEARCH, Up/Down chooses the letter or type field, Left/Right changes its
value, A applies both fields, and B cancels. Set both fields to ALL to restore
the complete index. Letter and type filters may be combined.

### Species research file

| Action | Control |
| --- | --- |
| Previous/next available page | Left/Right |
| Select a family member | Up/Down on FAMILY |
| View a known family member | A on FAMILY |
| Scroll field notes | Up/Down on INFO, when notes overflow |
| Select/scroll moves | Up/Down on MOVES |
| Open selected move details | A on MOVES |
| Return to move list | B from move details |
| Play cry | A on other built-in pages |
| Return | B |

On scripted one-off and newly-caught entries, A advances a page of overflowing
field notes before closing after the final page; B closes immediately. The
Yellow printer keeps the original compact printable entry renderer.

## Optional data pages for other mods

Companion data mods can extend the current species file through the
`ui.pokedex.pages` hook. The hook receives `(game, pages, context)` after the
built-in availability checks. Append a page with an `id`, short `label`, and
either non-empty `rows` or a custom `draw(context)` function.

```lua
mod.hooks:wrap("ui.pokedex.pages",
  function(next, game, pages, context)
    local out = next(game, pages, context)
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
```

Nil and empty row values are removed automatically, and a generic page with no
remaining rows is not added. Custom pages may also provide `available(context)`,
`onAction(context)`, `update(context)`, `footer`, `palette`, or `zones(context)`.
The context exposes the current `game`, `state`, species `def`, owned state,
layout, colour regions, and small `draw` helpers. This makes abilities,
breeding, habitats, held items, forms, or other systems possible when a mod
actually supplies them, while keeping an ordinary Gen I installation honest.

## Development

From the Gen1Recomp repository root:

```sh
python3 tools/modkit.py validate mods/modern_pokedex_ui --base fixture
luajit mods/modern_pokedex_ui/tests/modern_pokedex_ui_test.lua
```

The package contains no ROM-derived assets. Pokémon names and imagery are
trademarks of their respective owners; this is an unofficial fan-made mod.
