### STL models

Renders an interactive 3D WebGL viewer. ASCII STL only for fenced blocks; binary `.stl` files also render when browsed on GitHub. Useful for hardware/electronics projects.

````markdown
```stl
solid cube
  facet normal 0 0 -1
    outer loop
      vertex 0 0 0
      vertex 1 0 0
      vertex 1 1 0
    endloop
  endfacet
endsolid cube
```
````

### SVG `<foreignObject>` — CSS animations

GitHub strips `<style>` tags from markdown but renders `<img src="file.svg">`. SVGs can contain `<foreignObject>` wrapping XHTML+CSS, enabling `@keyframes` animations, `prefers-color-scheme` media queries, and custom fonts. Embed images inside the SVG as base64 data URIs (external loads are blocked by CSP).

```xml
<!-- animation.svg -->
<svg xmlns="http://www.w3.org/2000/svg" width="400" height="80">
  <foreignObject width="400" height="80">
    <body xmlns="http://www.w3.org/1999/xhtml">
      <style>
        @keyframes fade { 0%,100% { opacity:1 } 50% { opacity:0.3 } }
        .t { font-family: monospace; animation: fade 2s infinite; }
      </style>
      <div class="t">animated text</div>
    </body>
  </foreignObject>
</svg>
```

Combine with `<picture>` for dark/light mode variants:

```html
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="header-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="header-light.svg">
  <img src="header-light.svg" alt="project header">
</picture>
```

### Color model swatches

Wrapping a color value in backticks renders a small color swatch preview next to it when GitHub detects the format. Supported in issues and PRs (rendering may vary in READMEs).

Supported formats: `` `#ffffff` `` `` `rgb(255, 255, 255)` `` `` `hsl(0, 0%, 100%)` ``

### Alerts

Callout blocks for notes, warnings, and tips. Use sparingly — one or two per README max.

```markdown
> [!NOTE]
> Useful information the reader should know.

> [!TIP]
> Helpful advice for doing things better.

> [!IMPORTANT]
> Key information users need to succeed.

> [!WARNING]
> Urgent info that needs immediate attention.

> [!CAUTION]
> Advises about risks or negative outcomes.
```
