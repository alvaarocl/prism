# Product photo cutouts

PNG assets used directly over Prism's window, without a photo card or background.

- `hyperx-origins-core.png`: HyperX Alloy Origins Core reference, US layout.
- `glorious-model-d.png`: Glorious Model D wired reference, black finish.
- `razer-blackshark-v2-hyperspeed.png`: Razer BlackShark V2 HyperSpeed reference, black finish.

Original manufacturer photographs and source pages are recorded in
`../product-photos.json`. Product finishes, sizes and keyboard regional layouts
cannot all be inferred from a USB identifier; these are catalogue references.
Original photographs remain the property of HyperX/HP, Glorious and Razer.
They and these photo-derived assets are not relicensed under the code's GPL.
No affiliation or endorsement is implied.

## Editing provenance

Edited on 2026-11-14 using the built-in image generation/editing tool, one edit
per original photograph, with `transparent_background: true`. Originals were
inspected before editing. PNG alpha and the three installed device views were
checked after editing. No procedural device drawings are used.

Final prompt set (same prompt for each of the three corresponding edit targets):

> Use case: background-extraction. Edit target: the supplied original manufacturer product photograph. Remove ONLY the white/gray background and all background floor/shadow to produce a clean cutout with actual alpha transparency. Preserve the exact photographed product, original viewpoint, proportions, silhouette, every keycap/letter/mark/logo, RGB colours, texture, grille holes, cables and microphone. Do not redraw, reinterpret, enhance, stylize, change lighting, invent any part or substitute another model. Preserve natural product edge antialiasing, no white fringe. Keep complete visible product and cables. Crop excess transparent margins while leaving a small safe margin. Output a real transparent PNG, not a checkerboard baked into the pixels. This cutout is for a native macOS peripheral manager and must remain a real photograph.

The source dimensions and edited dimensions differ; these are edited reference
images, not pixel-identical originals or live representations of device settings.
