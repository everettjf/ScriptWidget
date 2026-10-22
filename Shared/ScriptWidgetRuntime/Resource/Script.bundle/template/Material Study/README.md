# Material Study

Original geometric shapes sit behind a public SwiftUI frosted material card. A small fixed 3D tilt adds depth to the backdrop while keeping the text sharp; this is a static composition, not device-motion parallax. Change the literal `backgroundMaterial` property in Layout to compare ultraThin/thin/regular/thick/ultraThick or none. `background` supplies the color fallback. Runtime API 1.4 is required; no permissions or network are needed.

Reduce Transparency composites the fallback over an opaque base. Reduce Motion removes the 3D tilt. In accented/vibrant rendering the decorative shapes are hidden and local material is omitted, leaving system rendering in charge. Compact accessory families use text only. Web Studio offers matching accessibility preview controls, with a clearly marked CSS approximation of material.

Material blurs content inside the widget. It does not read or blur Home Screen wallpaper. Clear/Tinted system Liquid Glass is a system/user appearance choice. This template uses no private clock-hand/swing effect, continuous animation, wallpaper-setting API or background sensor subscription. Original geometry and source follow the repository MIT license.
