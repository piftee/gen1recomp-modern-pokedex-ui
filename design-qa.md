# Design QA

## Direction

The interface follows the project's **Modern retro** rule: newer-game
information hierarchy expressed through Gen I materials. It uses the native
pixel font, nearest-neighbour artwork, 144-pixel logical height, four-shade
palette ramps, hard black outlines, diagonal pixel texture, and chamfered
cards. It does not imitate the reference's high-resolution typography or add
later-generation systems that are absent from the active data model.

Light remains the default. The optional Dark colour setting replaces white
research surfaces with deep neutral cards, promotes body and secondary copy
to high-contrast light shades, and retains type colour as a border, selected
state, or chip accent. Pokémon artwork remains colour-authoritative in both
themes.

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
- Search letters, types, and results are derived only from discovered rows;
  filtering cannot reveal an unseen species' identity data.

## Artwork rules

- Grid icons use the shared party renderer so Unique Menu Icons remains the
  navigation-art authority.
- Wilds of Kanto icons use its exported follower selector directly, retaining
  authored idle/walk frames across icon-mod load orders without changing the
  battle-art path used by large portraits.
- HGSS icons are fitted by opaque bounds and protected by opaque runs.
- Large previews resolve `kind = "battle"`, matching combat, Party summary,
  and PC details.
- Large portraits remove only edge-connected matte and publish pixel-tight
  true-colour regions, never a rectangular backing.
- Alpha-backed battle art treats opaque white as authored artwork rather than
  globally erasing it. The reported 56x56 Yellow/SGB-derived Rattata pose is
  the one narrow exception: a complete geometry signature clears its three
  enclosed tail/body background pixels in palette and true-colour paths.
  Crystal frames, other Rattata poses, and genuine white markings are not
  altered; future exceptions must be equally species- and asset-specific.
- No new Pokémon artwork or ROM-derived asset is included in the package.

## Layout checks

- 160×144: purpose-built compact INFO and STATS compositions, browsable move
  details, fitted search controls, dedicated note-scroll gutters, and no
  off-screen controls.
- 192×144 and 224×144: compact compositions expand without label collisions.
- 240×144 and 256×144: list plus live preview; research profile rail plus main
  data card, with shortened footer hints where the long forms would overlap.
- More than four contributed tabs: header displays a moving tab window while
  Left/Right continues through the complete page list.
- Sparse species: INFO-only layout without empty research panels.
- Long names and values: clipped through the shared pixel-font fitter.
- Light and Dark: list, search, actions, every built-in research page, move
  detail, and compact/wide layouts retain readable surface separation and
  text contrast.

## Behaviour checks

- The regular Options screen exposes one `MODERN POKEDEX` row; activating
  it opens a three-row nested page whose values stay synchronized with the
  mod manager rather than adding loose settings to the main menu.
- DATA opens tabbed research only from the modern Pokédex list.
- Select opens letter/type search; both fields combine, ALL clears them, and
  the filtered native action items remain aligned with the visible cards.
- Script-driven and newly-caught entries use A to advance unread notes before
  closing and retain immediate B-close and callback behavior.
- CRY remains repeatable from the action menu and research pages.
- FAMILY uses Up/Down for card focus because Left/Right remains reserved for
  tabs; A opens a known member in-place and synchronizes the backing list.
- INFO uses Up/Down only when wrapped notes exceed its visible lines.
- MOVES uses one continuous Up/Down list: level-up rows first, compatible
  TM/HM rows at the bottom, A for conditional details, and B to return.
- AREA still opens the native encounter map, including alongside Gen1 Modern
  UI where the source-owned Pokédex remains underneath it.
- Yellow PRNT retains the native printable renderer.
