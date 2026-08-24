# Changelog

## [0.2.3] - 2026-08-24

### Changed

- Large SGB portraits that use the pale `REDMON`, `YELLOWMON`, or `BROWNMON`
  ramps now borrow the stronger equivalent midtones from the bundled Advanced
  palette pack. Orange and yellow Pokémon retain readable detail without
  changing cool-coloured species, true-colour replacements, or other display
  modes.

### Fixed

- Portrait colour protection now follows the exact inner face of every
  preview, INFO, STATS, and FAMILY card. Android landscape scaling can no
  longer make sprite guards overlap black frames, erase unselected insets, or
  expose a faint edge around the artwork.

## [0.2.2] - 2026-08-24

### Fixed

- Replaced the Pokédex-only per-row portrait restoration path with the same
  stable card compositing used by Modern Party UI. Android renderers no longer
  stripe, tint, erase, or frame battle sprites when the display is scaled.
- Widescreen browsing now protects the complete chamfered preview face and its
  accent as one region, removing the horizontal seam visible in landscape
  without changing the Pokémon's authored colours.

## [0.2.1] - 2026-08-24

### Added

- The regular Options screen now contains one `MODERN POKEDEX` entry that
  opens a dedicated page for Widescreen, Backdrop, and Colours. Changes made
  there share the same live and saved values as the mod manager.
- `POKEDEX COLOURS` now offers Light and Dark themes. Dark mode uses deep
  neutral surfaces, high-contrast text, and restrained type-colour accents
  without changing or dimming Pokémon artwork.

### Fixed

- INFO reserves a dedicated right-hand gutter for scroll indicators, keeping
  the up arrow clear of weight and the down arrow clear of the final visible
  notes line at compact and portrait resolutions.
- Pokédex descriptions that omit terminal punctuation now receive the final
  full stop supplied by the vanilla entry screen; descriptions and
  translations that already end in punctuation are left unchanged.
- Transparent battle sprites now use their authored alpha as the exact
  background mask. The fallback white-matte flood fill no longer removes
  legitimate white highlights or body pixels, eliminating the broken bands
  seen across some compact FAMILY portraits.
- Fractionally scaled portrait masks are rebuilt on the final integer pixel
  grid. Their colour protection now follows the same nearest-neighbour pixels
  as the sprite at portrait/mobile display scales, without restoring a square
  backing.

## [0.2.0] - 2026-08-23

### Added

- Select opens a modern-retro Pokédex search panel with combinable
  starting-letter and type fields. Only discovered species contribute options
  or results, preventing search from revealing unseen identity data.
- Starting-letter options use the translated name's first rendered glyph, so
  accented and non-Latin font pages are not forced into English A-Z buckets.
- Active filters remain synchronized with the native Pokédex action items and
  can be cleared by returning both fields to ALL.

### Changed

- MOVES is now one continuous list: level-up moves remain first and compatible
  TMs/HMs are appended at the bottom, with each full TM/HM number shown before
  its move name and repeated in move details.
- Crystal 251's three Move Tutor entries are labelled `TUTOR`; they no longer
  appear as a clipped, unknown TM/HM number.
- Removed the separate Select-to-switch machine mode; Up/Down and A now browse
  and inspect the complete learnset without changing sources.

## [0.1.8] - 2026-08-23

### Fixed

- Integrated Wilds of Kanto through its exported follower-sprite resolver,
  preserving configured artwork and idle/walk frames even when another
  late-loading icon mod replaces the shared PartyMenu renderer.
- Wilds icons keep their authored colours on selected Pokédex rows, and only
  their opaque pixels bypass the screen palette so transparent padding cannot
  produce a square backing.
- Compact stats use the conventional `ATK` Attack, `SPE` Speed, and Gen I
  `SPC` Special labels.
- Compact INFO extends its notes card through the available lower gap so the
  fourth flavour-text row is never cut through by the frame.
- Research-page footers allocate their left and right control hints from the
  real available width; tight layouts retain complete labels without dots.
- The compact Pokédex footer now says `SEEN xxx` instead of repeating the
  caught count already presented in the header.

## [0.1.7] - 2026-08-23

### Changed

- Compact INFO now uses the same 52-pixel portrait card height as STATS and
  devotes the recovered space to a fourth visible field-note line.
- Compact type labels are derived from each translated full type name, so
  every language receives consistent three-glyph abbreviations without
  colliding with unrelated translations of English `PSN`, `FLY`, and similar
  tokens.
- Dual-type labels translate their two components before joining them.
- On scripted and newly-caught entries, A advances overflowing field notes a
  page at a time and closes only after the final page; B still closes at once.

### Fixed

- Gen1 Modern UI no longer hides the encounter map opened through AREA.
- Battle portraits now remove edge-connected matte and protect only their
  visible pixel runs, eliminating the rectangular shadow around the artwork.

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
