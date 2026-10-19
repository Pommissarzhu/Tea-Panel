# Tea Panel 应用图标

使用内置 `image_gen`（imagegen 技能）生成。原图为 [`Resources/AppIcon.png`](../../Resources/AppIcon.png)；根目录的 [`build.sh`](../../build.sh) 负责缩放和打包 `.icns`，无需重新调用生成工具。

设计：浅鼠尾草绿底、深绿茶杯剪影和单片茶叶。使用扁平几何形状，无立体边框、材质或投影。

备选方案见[图标 v3 提案](proposals/AppIcon-v3.md)。该提案单独保留，尚未替换当前应用图标。

## 生成提示词

```text
Use case: logo-brand
Asset type: minimalist flat two-color app icon for a desktop tea timer called Tea Panel.
Create ONE extraordinarily simple, clean vector-style icon. A single solid very pale sage #E2EBDD rounded-square tile contains a centered dark forest-green #1F4538 tea cup silhouette with one small tea leaf floating above it.
The cup is a flat geometric front-view shape, with a straight horizontal top edge, rounded bottom, and a right-side rounded open handle cutout showing the same pale sage tile color. The leaf is a simple smooth diagonal pointed oval, no veins, drawn in the same forest green. Only two solid flat colors within the tile, no gradients or textures anywhere.
The rounded square is a SOLID FILLED PALE TILE, fully opaque throughout its entire interior including all negative space around the cup and leaf. Transparency is allowed ONLY OUTSIDE the outer rounded square. Every interior tile pixel must be solid pale sage except the solid green pictogram. No see-through holes within the tile.
Style: modern minimal flat brand icon, crisp vector-like paths, bold shapes, balanced spacing and quiet warm utility-app character. The cup including handle fills about 58 percent of tile width. Generous negative space. Straight-on view, exact centered square composition. Tile covers 84 percent of canvas width and height, clean transparent padding outside.
Absolutely NO three-dimensional rendering, NO clay, NO gloss, NO drop shadow, NO border, NO inset, NO bevel, NO lighting or glow, NO glass, NO grain, NO texture, NO decorative detail, NO saucer, NO steam, NO clock, NO text, NO letters, NO watermark. The result must look like a simple SVG made of three or four flat paths, not an illustration.
```
