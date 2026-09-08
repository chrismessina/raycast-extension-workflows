# Shelf

Baubles parked for later. Gut-check at drop time; nothing here is adopted.

## svg-showcase-for-raycast (luarmr) — 2026-09-07

- **What:** Raúl's catalogue of what SVG actually survives Raycast's markdown renderer —
  animation, live graphs, gradients — shipped as a paired extension + browser page so you can
  diff "works on the web" against "works in Raycast."
  https://github.com/luarmr/svg-showcase-for-raycast ·
  https://luarmr.github.io/svg-showcase-for-raycast/
- **Verdict:** Park, with one real candidate. The technique is just
  `![](data:image/svg+xml;base64,…)` in a `Detail` — no dependency, no build step, which is why
  it clears the bar. The headline is that Raycast 2 stopped being picky: SVG that used to render
  as a broken image now mostly just works, so the old "don't bother" reflex is stale.
- **Where it'd plug in:** `raycast-tesla-energy` is the honest one — battery/solar/grid over
  time is a chart we currently don't draw, and a hand-rolled SVG sparkline in the `Detail` is a
  smaller diff than any charting library. Everything else in the fleet is list-and-text and
  doesn't want pictures.
- **The caveat that matters:** the browser page is the reference, not the extension. If they
  disagree, Raycast is the limited one. Anything animated is eyes-only — it cannot be tested
  from a terminal, and a screenshot of frame one proves nothing.
