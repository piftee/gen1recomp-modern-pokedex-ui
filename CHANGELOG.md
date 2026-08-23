# Changelog

## [0.1.6] - 2026-08-23

### Added

- Move details now consume Crystal 251's exported move-script families and
  present concise functional descriptions instead of hiding opaque
  `CRYSTAL_EFFECT_xx` dispatch ids.
- Ordinary damaging moves with no secondary effect now say so explicitly,
  keeping their detail page visually useful when Crystal 251 is disabled.
- Useful Move Info's curated vanilla effect descriptions are used when that
  optional mod is available and no built-in description matched first.

## [0.1.5] - 2026-08-23

### Fixed

- Replaced full rectangular Unique Menu Icon colour masks with per-row
  visible-pixel masks. Transparent icon pixels now reveal the Pokédex card
  beneath them instead of restoring a white square.

## [0.1.4] - 2026-08-23

### Fixed

- Selected Pokédex cards no longer pass their darker face tint into Unique
  Menu Icons; authored icon colours now remain identical in focused and
  unfocused rows.
- Opaque move-dispatch identifiers such as Crystal 251's
  `CRYSTAL_EFFECT_43` are no longer fabricated into visible descriptions.
  EFFECT appears only for supplied prose or an effect this mod can translate
  meaningfully.

## [0.1.3] - 2026-08-23

### Changed

- MOVES is now a selectable reference list: Up/Down moves and scrolls a real
  cursor, A opens the selected move, and Select switches level/TM sources when
  both exist.
- Every move row receives its move-type colour instead of alternating between
  coloured and uncoloured bands.
- Simplified move-list rows to source level (or TM), name, and PP; all other
  move facts now live in the A-button detail view.
- The move-detail view conditionally presents only supplied power, accuracy,
  PP, category, priority, and effect information.
- Compact INFO now uses a shorter portrait/identity composition, gives field
  notes a third visible line, and lets Up/Down reveal any remaining lines.
- Compact STATS now separates its portrait, research summary, and full-width
  stat bars so total, catch rate, base EXP, and growth remain readable.

### Fixed

- Stopped compact INFO's portrait palette zone before the notes panel, so a
  species card can no longer recolour the beginning of its flavour text.
- Removed title/total collisions and shortened overflowing metadata on the
  240–256px STATS layout.
- Prevented FAMILY and MOVES footer hints from overlapping at intermediate
  widescreen widths.
- Selected Pokédex rows keep menu icons on a neutral backing and never request
  the shared icon renderer's darkened selected state.
- Added rendering and palette-bound regressions for 160, 192, 224, 240, and
  256-pixel logical widths across every built-in research page and the list.

## [0.1.2] - 2026-08-23

### Fixed

- Battle-context Pokémon portraits now use each species' own game palette
  instead of inheriting the surrounding type-coloured card palette.
- Full-colour battle sprite replacements remain untouched, while grayscale
  sprites are palette-baked with transparent outer matte and protected from
  the later screen palette pass.
- FAMILY cards now use scaled battle-front artwork rather than menu icons;
  undiscovered relatives remain concealed.

## [0.1.1] - 2026-08-23

### Changed

- Removed the redundant type abbreviation beneath species names in the wide
  Pokédex list, giving names a clean single-line card presentation.
- Selected list cards now keep their Pokémon icon on its normal resting frame
  and palette; selection is communicated by the card treatment alone.
- Typing remains available in the selected-species preview and INFO page.
- Simplified the widescreen header to `POKéDEX` and one uncluttered
  `CAUGHT x/xx` progress label.
- FAMILY cards can be selected with Up/Down; A opens a known relative's INFO
  page in place and keeps the backing Pokédex selection synchronized.
- Restyled the DATA/CRY/AREA/QUIT overlay as a fitted neutral-white card.

### Fixed

- Cleared inherited full-colour UI claims before opaque Pokédex screens draw,
  preventing Unique Icons and HGSS icon regions from appearing as grey boxes.
- Prevented the Pokédex action decorator and its yellow palette from attaching
  to the Start menu when the Pokédex closes.
- Included the research-card heading in its height calculation so the final
  QUIT row no longer overflows its frame.

## [0.1.0] - 2026-08-23

### Added

- Responsive modern-retro Pokédex list with icon cards, discovery progress,
  typing, scrolling, and a battle-art preview.
- Conditional INFO, STATS, FAMILY, and MOVES research pages built only from
  data present on the selected species.
- Base-stat bars and total, capture/training facts, evolution-family icons and
  methods, plus scrollable level-up and TM/HM move data.
- `ui.pokedex.pages` extension hook for conditional data supplied by other
  mods, including safe generic label/value pages.
- Shared Unique Menu Icons rendering and alpha-fitted HGSS icon support.
- Battle-context front artwork shared with combat, Modern Party UI summaries,
  and Modern PC UI details.
- Compact and widescreen layouts, palette-zone support, headless tests, and a
  visual preview driver.

### Preserved

- Native seen/owned state, DATA/CRY/AREA/QUIT actions, Yellow PRNT behavior,
  scripted dex-entry close flow, cries, area maps, and save format.
