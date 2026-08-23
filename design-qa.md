# Design QA

## Direction

The interface follows the project's **Modern retro** rule: newer-game
information hierarchy expressed through Gen I materials. It uses the native
pixel font, nearest-neighbour artwork, 144-pixel logical height, four-shade
palette ramps, hard black outlines, diagonal pixel texture, and chamfered
cards. It does not imitate the reference's high-resolution typography or add
later-generation systems that are absent from the active data model.

## Information rules

- INFO is the stable identity page.
- STATS appears only when at least one base or training fact exists.
- FAMILY appears only for a computed family of two or more species.
- MOVES appears only when at least one level-up or machine move exists.
- An optional mod page appears only after its availability predicate passes,
  or after its generic rows contain a real value.
- Category, measurements, field notes, stat rows, Base Stat Total, type,
  power, and PP are each drawn only when their own source value exists.
- Unknown discovery state may be represented as unknown; absent schema data
  is never represented as a fabricated zero or question mark.

## Artwork rules

- Grid icons use the shared party renderer so Unique Menu Icons remains the
  navigation-art authority.
- HGSS icons are fitted by opaque bounds and protected by opaque runs.
- Large previews resolve `kind = "battle"`, matching combat, Party summary,
  and PC details.
- No new Pokémon artwork or ROM-derived asset is included in the package.

## Layout checks

- 160×144: purpose-built compact INFO and STATS compositions, browsable move
  details, and no off-screen controls.
- 192×144 and 224×144: compact compositions expand without label collisions.
- 240×144 and 256×144: list plus live preview; research profile rail plus main
  data card, with shortened footer hints where the long forms would overlap.
- More than four contributed tabs: header displays a moving tab window while
  Left/Right continues through the complete page list.
- Sparse species: INFO-only layout without empty research panels.
- Long names and values: clipped through the shared pixel-font fitter.

## Behaviour checks

- DATA opens tabbed research only from the modern Pokédex list.
- Script-driven entries retain native A/B close and callback behavior.
- CRY remains repeatable from the action menu and research pages.
- FAMILY uses Up/Down for card focus because Left/Right remains reserved for
  tabs; A opens a known member in-place and synchronizes the backing list.
- INFO uses Up/Down only when wrapped notes exceed its visible lines.
- MOVES uses Up/Down for selection, A for conditional details, Select for an
  available source switch, and B to return to the list.
- AREA still opens the native encounter map.
- Yellow PRNT retains the native printable renderer.
