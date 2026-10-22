# ScriptWidget Runtime API

> Generated from Studio's static API metadata (schema v1, runtime 1.4). The native runtime switch is authoritative. Do not edit by hand.

## Components

### `<VStack>`

Arrange children vertically.

| Property | Type | Required | Notes |
| --- | --- | --- | --- |
| `background` | `color` | No | Background color, hex value, or named color. |
| `color` | `color` | No | Foreground color, hex value, or named color. |
| `font` | `enum` | No | Semantic text style. Values: `largeTitle`, `title`, `title2`, `title3`, `headline`, `subheadline`, `body`, `callout`, `footnote`, `caption`, `caption2` |
| `fontWeight` | `enum` | No | Font weight. Values: `ultraLight`, `thin`, `light`, `regular`, `medium`, `semibold`, `bold`, `heavy`, `black` |
| `fontDesign` | `enum` | No | Font design. Values: `default`, `rounded`, `serif`, `monospaced` |
| `frame` | `number|string` | No | Square size (64 or "64"), width,height ("64,48"), or flexible frame ("max", "max,48"). |
| `padding` | `number|string` | No | Padding amount or edge description. |
| `corner` | `number` | No | Corner radius. |
| `opacity` | `number` | No | Opacity from 0 through 1. |
| `alignment` | `enum` | No | Layout alignment. Values: `center`, `leading`, `trailing`, `top`, `bottom`, `topLeading`, `topTrailing`, `bottomLeading`, `bottomTrailing`, `firstTextBaseline`, `lastTextBaseline` |
| `clip` | `enum` | No | Clip the view to a shape. Values: `circle`, `rect`, `capsule`, `ellipse` |
| `rotation` | `number` | No | Rotation in degrees. |
| `rotation3d` | `string` | No | 3D rotation description. |
| `shadow` | `string` | No | Shadow color, radius, and offset description. |
| `animation` | `string` | No | Timeline-driven animation description. |
| `widgetAccentable` | `boolean` | No | Group this view into the accent layer in tinted and vibrant widget appearances. |
| `linkurl` | `url` | No | Widget deep link URL. |
| `spacing` | `number` | No |  |

### `<HStack>`

Arrange children horizontally.

| Property | Type | Required | Notes |
| --- | --- | --- | --- |
| `background` | `color` | No | Background color, hex value, or named color. |
| `color` | `color` | No | Foreground color, hex value, or named color. |
| `font` | `enum` | No | Semantic text style. Values: `largeTitle`, `title`, `title2`, `title3`, `headline`, `subheadline`, `body`, `callout`, `footnote`, `caption`, `caption2` |
| `fontWeight` | `enum` | No | Font weight. Values: `ultraLight`, `thin`, `light`, `regular`, `medium`, `semibold`, `bold`, `heavy`, `black` |
| `fontDesign` | `enum` | No | Font design. Values: `default`, `rounded`, `serif`, `monospaced` |
| `frame` | `number|string` | No | Square size (64 or "64"), width,height ("64,48"), or flexible frame ("max", "max,48"). |
| `padding` | `number|string` | No | Padding amount or edge description. |
| `corner` | `number` | No | Corner radius. |
| `opacity` | `number` | No | Opacity from 0 through 1. |
| `alignment` | `enum` | No | Layout alignment. Values: `center`, `leading`, `trailing`, `top`, `bottom`, `topLeading`, `topTrailing`, `bottomLeading`, `bottomTrailing`, `firstTextBaseline`, `lastTextBaseline` |
| `clip` | `enum` | No | Clip the view to a shape. Values: `circle`, `rect`, `capsule`, `ellipse` |
| `rotation` | `number` | No | Rotation in degrees. |
| `rotation3d` | `string` | No | 3D rotation description. |
| `shadow` | `string` | No | Shadow color, radius, and offset description. |
| `animation` | `string` | No | Timeline-driven animation description. |
| `widgetAccentable` | `boolean` | No | Group this view into the accent layer in tinted and vibrant widget appearances. |
| `linkurl` | `url` | No | Widget deep link URL. |
| `spacing` | `number` | No |  |

### `<ZStack>`

Overlay children.

| Property | Type | Required | Notes |
| --- | --- | --- | --- |
| `background` | `color` | No | Background color, hex value, or named color. |
| `color` | `color` | No | Foreground color, hex value, or named color. |
| `font` | `enum` | No | Semantic text style. Values: `largeTitle`, `title`, `title2`, `title3`, `headline`, `subheadline`, `body`, `callout`, `footnote`, `caption`, `caption2` |
| `fontWeight` | `enum` | No | Font weight. Values: `ultraLight`, `thin`, `light`, `regular`, `medium`, `semibold`, `bold`, `heavy`, `black` |
| `fontDesign` | `enum` | No | Font design. Values: `default`, `rounded`, `serif`, `monospaced` |
| `frame` | `number|string` | No | Square size (64 or "64"), width,height ("64,48"), or flexible frame ("max", "max,48"). |
| `padding` | `number|string` | No | Padding amount or edge description. |
| `corner` | `number` | No | Corner radius. |
| `opacity` | `number` | No | Opacity from 0 through 1. |
| `alignment` | `enum` | No | Layout alignment. Values: `center`, `leading`, `trailing`, `top`, `bottom`, `topLeading`, `topTrailing`, `bottomLeading`, `bottomTrailing`, `firstTextBaseline`, `lastTextBaseline` |
| `clip` | `enum` | No | Clip the view to a shape. Values: `circle`, `rect`, `capsule`, `ellipse` |
| `rotation` | `number` | No | Rotation in degrees. |
| `rotation3d` | `string` | No | 3D rotation description. |
| `shadow` | `string` | No | Shadow color, radius, and offset description. |
| `animation` | `string` | No | Timeline-driven animation description. |
| `widgetAccentable` | `boolean` | No | Group this view into the accent layer in tinted and vibrant widget appearances. |
| `linkurl` | `url` | No | Widget deep link URL. |

### `<VGrid>`

Vertical lazy grid.

| Property | Type | Required | Notes |
| --- | --- | --- | --- |
| `background` | `color` | No | Background color, hex value, or named color. |
| `color` | `color` | No | Foreground color, hex value, or named color. |
| `font` | `enum` | No | Semantic text style. Values: `largeTitle`, `title`, `title2`, `title3`, `headline`, `subheadline`, `body`, `callout`, `footnote`, `caption`, `caption2` |
| `fontWeight` | `enum` | No | Font weight. Values: `ultraLight`, `thin`, `light`, `regular`, `medium`, `semibold`, `bold`, `heavy`, `black` |
| `fontDesign` | `enum` | No | Font design. Values: `default`, `rounded`, `serif`, `monospaced` |
| `frame` | `number|string` | No | Square size (64 or "64"), width,height ("64,48"), or flexible frame ("max", "max,48"). |
| `padding` | `number|string` | No | Padding amount or edge description. |
| `corner` | `number` | No | Corner radius. |
| `opacity` | `number` | No | Opacity from 0 through 1. |
| `alignment` | `enum` | No | Values: `leading`, `center`, `trailing` |
| `clip` | `enum` | No | Clip the view to a shape. Values: `circle`, `rect`, `capsule`, `ellipse` |
| `rotation` | `number` | No | Rotation in degrees. |
| `rotation3d` | `string` | No | 3D rotation description. |
| `shadow` | `string` | No | Shadow color, radius, and offset description. |
| `animation` | `string` | No | Timeline-driven animation description. |
| `widgetAccentable` | `boolean` | No | Group this view into the accent layer in tinted and vibrant widget appearances. |
| `linkurl` | `url` | No | Widget deep link URL. |
| `columns` | `string` | Yes |  |
| `spacing` | `number` | No |  |

### `<HGrid>`

Horizontal lazy grid.

| Property | Type | Required | Notes |
| --- | --- | --- | --- |
| `background` | `color` | No | Background color, hex value, or named color. |
| `color` | `color` | No | Foreground color, hex value, or named color. |
| `font` | `enum` | No | Semantic text style. Values: `largeTitle`, `title`, `title2`, `title3`, `headline`, `subheadline`, `body`, `callout`, `footnote`, `caption`, `caption2` |
| `fontWeight` | `enum` | No | Font weight. Values: `ultraLight`, `thin`, `light`, `regular`, `medium`, `semibold`, `bold`, `heavy`, `black` |
| `fontDesign` | `enum` | No | Font design. Values: `default`, `rounded`, `serif`, `monospaced` |
| `frame` | `number|string` | No | Square size (64 or "64"), width,height ("64,48"), or flexible frame ("max", "max,48"). |
| `padding` | `number|string` | No | Padding amount or edge description. |
| `corner` | `number` | No | Corner radius. |
| `opacity` | `number` | No | Opacity from 0 through 1. |
| `alignment` | `enum` | No | Values: `top`, `center`, `bottom`, `firstTextBaseline`, `lastTextBaseline` |
| `clip` | `enum` | No | Clip the view to a shape. Values: `circle`, `rect`, `capsule`, `ellipse` |
| `rotation` | `number` | No | Rotation in degrees. |
| `rotation3d` | `string` | No | 3D rotation description. |
| `shadow` | `string` | No | Shadow color, radius, and offset description. |
| `animation` | `string` | No | Timeline-driven animation description. |
| `widgetAccentable` | `boolean` | No | Group this view into the accent layer in tinted and vibrant widget appearances. |
| `linkurl` | `url` | No | Widget deep link URL. |
| `columns` | `string` | Yes |  |
| `spacing` | `number` | No |  |

### `<Text>`

Display text content.

| Property | Type | Required | Notes |
| --- | --- | --- | --- |
| `background` | `color` | No | Background color, hex value, or named color. |
| `color` | `color` | No | Foreground color, hex value, or named color. |
| `font` | `enum` | No | Semantic text style. Values: `largeTitle`, `title`, `title2`, `title3`, `headline`, `subheadline`, `body`, `callout`, `footnote`, `caption`, `caption2` |
| `fontWeight` | `enum` | No | Font weight. Values: `ultraLight`, `thin`, `light`, `regular`, `medium`, `semibold`, `bold`, `heavy`, `black` |
| `fontDesign` | `enum` | No | Font design. Values: `default`, `rounded`, `serif`, `monospaced` |
| `frame` | `number|string` | No | Square size (64 or "64"), width,height ("64,48"), or flexible frame ("max", "max,48"). |
| `padding` | `number|string` | No | Padding amount or edge description. |
| `corner` | `number` | No | Corner radius. |
| `opacity` | `number` | No | Opacity from 0 through 1. |
| `alignment` | `enum` | No | Layout alignment. Values: `center`, `leading`, `trailing`, `top`, `bottom`, `topLeading`, `topTrailing`, `bottomLeading`, `bottomTrailing`, `firstTextBaseline`, `lastTextBaseline` |
| `clip` | `enum` | No | Clip the view to a shape. Values: `circle`, `rect`, `capsule`, `ellipse` |
| `rotation` | `number` | No | Rotation in degrees. |
| `rotation3d` | `string` | No | 3D rotation description. |
| `shadow` | `string` | No | Shadow color, radius, and offset description. |
| `animation` | `string` | No | Timeline-driven animation description. |
| `widgetAccentable` | `boolean` | No | Group this view into the accent layer in tinted and vibrant widget appearances. |
| `linkurl` | `url` | No | Widget deep link URL. |
| `text` | `string` | No |  |

### `<Date>`

Display a formatted date.

| Property | Type | Required | Notes |
| --- | --- | --- | --- |
| `background` | `color` | No | Background color, hex value, or named color. |
| `color` | `color` | No | Foreground color, hex value, or named color. |
| `font` | `enum` | No | Semantic text style. Values: `largeTitle`, `title`, `title2`, `title3`, `headline`, `subheadline`, `body`, `callout`, `footnote`, `caption`, `caption2` |
| `fontWeight` | `enum` | No | Font weight. Values: `ultraLight`, `thin`, `light`, `regular`, `medium`, `semibold`, `bold`, `heavy`, `black` |
| `fontDesign` | `enum` | No | Font design. Values: `default`, `rounded`, `serif`, `monospaced` |
| `frame` | `number|string` | No | Square size (64 or "64"), width,height ("64,48"), or flexible frame ("max", "max,48"). |
| `padding` | `number|string` | No | Padding amount or edge description. |
| `corner` | `number` | No | Corner radius. |
| `opacity` | `number` | No | Opacity from 0 through 1. |
| `alignment` | `enum` | No | Layout alignment. Values: `center`, `leading`, `trailing`, `top`, `bottom`, `topLeading`, `topTrailing`, `bottomLeading`, `bottomTrailing`, `firstTextBaseline`, `lastTextBaseline` |
| `clip` | `enum` | No | Clip the view to a shape. Values: `circle`, `rect`, `capsule`, `ellipse` |
| `rotation` | `number` | No | Rotation in degrees. |
| `rotation3d` | `string` | No | 3D rotation description. |
| `shadow` | `string` | No | Shadow color, radius, and offset description. |
| `animation` | `string` | No | Timeline-driven animation description. |
| `widgetAccentable` | `boolean` | No | Group this view into the accent layer in tinted and vibrant widget appearances. |
| `linkurl` | `url` | No | Widget deep link URL. |
| `date` | `date|number` | Yes |  |
| `style` | `enum` | No | Values: `time`, `date`, `relative`, `offset`, `timer` |

### `<Image>`

Display a bundled, remote, or SF Symbol image.

| Property | Type | Required | Notes |
| --- | --- | --- | --- |
| `background` | `color` | No | Background color, hex value, or named color. |
| `color` | `color` | No | Foreground color, hex value, or named color. |
| `font` | `enum` | No | Semantic text style. Values: `largeTitle`, `title`, `title2`, `title3`, `headline`, `subheadline`, `body`, `callout`, `footnote`, `caption`, `caption2` |
| `fontWeight` | `enum` | No | Font weight. Values: `ultraLight`, `thin`, `light`, `regular`, `medium`, `semibold`, `bold`, `heavy`, `black` |
| `fontDesign` | `enum` | No | Font design. Values: `default`, `rounded`, `serif`, `monospaced` |
| `frame` | `number|string` | No | Square size (64 or "64"), width,height ("64,48"), or flexible frame ("max", "max,48"). |
| `padding` | `number|string` | No | Padding amount or edge description. |
| `corner` | `number` | No | Corner radius. |
| `opacity` | `number` | No | Opacity from 0 through 1. |
| `alignment` | `enum` | No | Layout alignment. Values: `center`, `leading`, `trailing`, `top`, `bottom`, `topLeading`, `topTrailing`, `bottomLeading`, `bottomTrailing`, `firstTextBaseline`, `lastTextBaseline` |
| `clip` | `enum` | No | Clip the view to a shape. Values: `circle`, `rect`, `capsule`, `ellipse` |
| `rotation` | `number` | No | Rotation in degrees. |
| `rotation3d` | `string` | No | 3D rotation description. |
| `shadow` | `string` | No | Shadow color, radius, and offset description. |
| `animation` | `string` | No | Timeline-driven animation description. |
| `widgetAccentable` | `boolean` | No | Group this view into the accent layer in tinted and vibrant widget appearances. |
| `linkurl` | `url` | No | Widget deep link URL. |
| `systemName` | `string` | No |  |
| `name` | `string` | No |  |
| `id` | `string` | No | Deprecated: Use name. |
| `url` | `url` | No |  |
| `src` | `url` | No | Deprecated: Use url. |
| `ratio` | `number` | No |  |
| `mode` | `enum` | No | Values: `fit`, `fill` |
| `accentedRenderingMode` | `enum` | No | Control how the image is rendered in tinted and clear widget appearances. Values: `accented`, `desaturated`, `accentedDesaturated`, `fullColor` |

### `<Gif>`

Display a GIF from the package.

| Property | Type | Required | Notes |
| --- | --- | --- | --- |
| `background` | `color` | No | Background color, hex value, or named color. |
| `color` | `color` | No | Foreground color, hex value, or named color. |
| `font` | `enum` | No | Semantic text style. Values: `largeTitle`, `title`, `title2`, `title3`, `headline`, `subheadline`, `body`, `callout`, `footnote`, `caption`, `caption2` |
| `fontWeight` | `enum` | No | Font weight. Values: `ultraLight`, `thin`, `light`, `regular`, `medium`, `semibold`, `bold`, `heavy`, `black` |
| `fontDesign` | `enum` | No | Font design. Values: `default`, `rounded`, `serif`, `monospaced` |
| `frame` | `number|string` | No | Square size (64 or "64"), width,height ("64,48"), or flexible frame ("max", "max,48"). |
| `padding` | `number|string` | No | Padding amount or edge description. |
| `corner` | `number` | No | Corner radius. |
| `opacity` | `number` | No | Opacity from 0 through 1. |
| `alignment` | `enum` | No | Layout alignment. Values: `center`, `leading`, `trailing`, `top`, `bottom`, `topLeading`, `topTrailing`, `bottomLeading`, `bottomTrailing`, `firstTextBaseline`, `lastTextBaseline` |
| `clip` | `enum` | No | Clip the view to a shape. Values: `circle`, `rect`, `capsule`, `ellipse` |
| `rotation` | `number` | No | Rotation in degrees. |
| `rotation3d` | `string` | No | 3D rotation description. |
| `shadow` | `string` | No | Shadow color, radius, and offset description. |
| `animation` | `string` | No | Timeline-driven animation description. |
| `widgetAccentable` | `boolean` | No | Group this view into the accent layer in tinted and vibrant widget appearances. |
| `linkurl` | `url` | No | Widget deep link URL. |
| `file` | `string` | Yes |  |

### `<Spacer>`

Flexible layout space.

| Property | Type | Required | Notes |
| --- | --- | --- | --- |
| `background` | `color` | No | Background color, hex value, or named color. |
| `color` | `color` | No | Foreground color, hex value, or named color. |
| `font` | `enum` | No | Semantic text style. Values: `largeTitle`, `title`, `title2`, `title3`, `headline`, `subheadline`, `body`, `callout`, `footnote`, `caption`, `caption2` |
| `fontWeight` | `enum` | No | Font weight. Values: `ultraLight`, `thin`, `light`, `regular`, `medium`, `semibold`, `bold`, `heavy`, `black` |
| `fontDesign` | `enum` | No | Font design. Values: `default`, `rounded`, `serif`, `monospaced` |
| `frame` | `number|string` | No | Square size (64 or "64"), width,height ("64,48"), or flexible frame ("max", "max,48"). |
| `padding` | `number|string` | No | Padding amount or edge description. |
| `corner` | `number` | No | Corner radius. |
| `opacity` | `number` | No | Opacity from 0 through 1. |
| `alignment` | `enum` | No | Layout alignment. Values: `center`, `leading`, `trailing`, `top`, `bottom`, `topLeading`, `topTrailing`, `bottomLeading`, `bottomTrailing`, `firstTextBaseline`, `lastTextBaseline` |
| `clip` | `enum` | No | Clip the view to a shape. Values: `circle`, `rect`, `capsule`, `ellipse` |
| `rotation` | `number` | No | Rotation in degrees. |
| `rotation3d` | `string` | No | 3D rotation description. |
| `shadow` | `string` | No | Shadow color, radius, and offset description. |
| `animation` | `string` | No | Timeline-driven animation description. |
| `widgetAccentable` | `boolean` | No | Group this view into the accent layer in tinted and vibrant widget appearances. |
| `linkurl` | `url` | No | Widget deep link URL. |
| `minLength` | `number` | No |  |

### `<Rect>`

Rectangle shape.

| Property | Type | Required | Notes |
| --- | --- | --- | --- |
| `background` | `color` | No | Background color, hex value, or named color. |
| `color` | `color` | No | Foreground color, hex value, or named color. |
| `font` | `enum` | No | Semantic text style. Values: `largeTitle`, `title`, `title2`, `title3`, `headline`, `subheadline`, `body`, `callout`, `footnote`, `caption`, `caption2` |
| `fontWeight` | `enum` | No | Font weight. Values: `ultraLight`, `thin`, `light`, `regular`, `medium`, `semibold`, `bold`, `heavy`, `black` |
| `fontDesign` | `enum` | No | Font design. Values: `default`, `rounded`, `serif`, `monospaced` |
| `frame` | `number|string` | No | Square size (64 or "64"), width,height ("64,48"), or flexible frame ("max", "max,48"). |
| `padding` | `number|string` | No | Padding amount or edge description. |
| `corner` | `number` | No | Corner radius. |
| `opacity` | `number` | No | Opacity from 0 through 1. |
| `alignment` | `enum` | No | Layout alignment. Values: `center`, `leading`, `trailing`, `top`, `bottom`, `topLeading`, `topTrailing`, `bottomLeading`, `bottomTrailing`, `firstTextBaseline`, `lastTextBaseline` |
| `clip` | `enum` | No | Clip the view to a shape. Values: `circle`, `rect`, `capsule`, `ellipse` |
| `rotation` | `number` | No | Rotation in degrees. |
| `rotation3d` | `string` | No | 3D rotation description. |
| `shadow` | `string` | No | Shadow color, radius, and offset description. |
| `animation` | `string` | No | Timeline-driven animation description. |
| `widgetAccentable` | `boolean` | No | Group this view into the accent layer in tinted and vibrant widget appearances. |
| `linkurl` | `url` | No | Widget deep link URL. |
| `trim` | `number|string` | No |  |
| `stroke` | `string` | No |  |

### `<RoundedRect>`

Filled rounded rectangle.

| Property | Type | Required | Notes |
| --- | --- | --- | --- |
| `background` | `color` | No | Background color, hex value, or named color. |
| `color` | `color` | No | Foreground color, hex value, or named color. |
| `font` | `enum` | No | Semantic text style. Values: `largeTitle`, `title`, `title2`, `title3`, `headline`, `subheadline`, `body`, `callout`, `footnote`, `caption`, `caption2` |
| `fontWeight` | `enum` | No | Font weight. Values: `ultraLight`, `thin`, `light`, `regular`, `medium`, `semibold`, `bold`, `heavy`, `black` |
| `fontDesign` | `enum` | No | Font design. Values: `default`, `rounded`, `serif`, `monospaced` |
| `frame` | `number|string` | No | Square size (64 or "64"), width,height ("64,48"), or flexible frame ("max", "max,48"). |
| `padding` | `number|string` | No | Padding amount or edge description. |
| `corner` | `number` | No | Corner radius. |
| `opacity` | `number` | No | Opacity from 0 through 1. |
| `alignment` | `enum` | No | Layout alignment. Values: `center`, `leading`, `trailing`, `top`, `bottom`, `topLeading`, `topTrailing`, `bottomLeading`, `bottomTrailing`, `firstTextBaseline`, `lastTextBaseline` |
| `clip` | `enum` | No | Clip the view to a shape. Values: `circle`, `rect`, `capsule`, `ellipse` |
| `rotation` | `number` | No | Rotation in degrees. |
| `rotation3d` | `string` | No | 3D rotation description. |
| `shadow` | `string` | No | Shadow color, radius, and offset description. |
| `animation` | `string` | No | Timeline-driven animation description. |
| `widgetAccentable` | `boolean` | No | Group this view into the accent layer in tinted and vibrant widget appearances. |
| `linkurl` | `url` | No | Widget deep link URL. |
| `radius` | `number` | No |  |

### `<Capsule>`

Capsule shape.

| Property | Type | Required | Notes |
| --- | --- | --- | --- |
| `background` | `color` | No | Background color, hex value, or named color. |
| `color` | `color` | No | Foreground color, hex value, or named color. |
| `font` | `enum` | No | Semantic text style. Values: `largeTitle`, `title`, `title2`, `title3`, `headline`, `subheadline`, `body`, `callout`, `footnote`, `caption`, `caption2` |
| `fontWeight` | `enum` | No | Font weight. Values: `ultraLight`, `thin`, `light`, `regular`, `medium`, `semibold`, `bold`, `heavy`, `black` |
| `fontDesign` | `enum` | No | Font design. Values: `default`, `rounded`, `serif`, `monospaced` |
| `frame` | `number|string` | No | Square size (64 or "64"), width,height ("64,48"), or flexible frame ("max", "max,48"). |
| `padding` | `number|string` | No | Padding amount or edge description. |
| `corner` | `number` | No | Corner radius. |
| `opacity` | `number` | No | Opacity from 0 through 1. |
| `alignment` | `enum` | No | Layout alignment. Values: `center`, `leading`, `trailing`, `top`, `bottom`, `topLeading`, `topTrailing`, `bottomLeading`, `bottomTrailing`, `firstTextBaseline`, `lastTextBaseline` |
| `clip` | `enum` | No | Clip the view to a shape. Values: `circle`, `rect`, `capsule`, `ellipse` |
| `rotation` | `number` | No | Rotation in degrees. |
| `rotation3d` | `string` | No | 3D rotation description. |
| `shadow` | `string` | No | Shadow color, radius, and offset description. |
| `animation` | `string` | No | Timeline-driven animation description. |
| `widgetAccentable` | `boolean` | No | Group this view into the accent layer in tinted and vibrant widget appearances. |
| `linkurl` | `url` | No | Widget deep link URL. |
| `trim` | `number|string` | No |  |
| `stroke` | `string` | No |  |

### `<Ellipse>`

Ellipse shape.

| Property | Type | Required | Notes |
| --- | --- | --- | --- |
| `background` | `color` | No | Background color, hex value, or named color. |
| `color` | `color` | No | Foreground color, hex value, or named color. |
| `font` | `enum` | No | Semantic text style. Values: `largeTitle`, `title`, `title2`, `title3`, `headline`, `subheadline`, `body`, `callout`, `footnote`, `caption`, `caption2` |
| `fontWeight` | `enum` | No | Font weight. Values: `ultraLight`, `thin`, `light`, `regular`, `medium`, `semibold`, `bold`, `heavy`, `black` |
| `fontDesign` | `enum` | No | Font design. Values: `default`, `rounded`, `serif`, `monospaced` |
| `frame` | `number|string` | No | Square size (64 or "64"), width,height ("64,48"), or flexible frame ("max", "max,48"). |
| `padding` | `number|string` | No | Padding amount or edge description. |
| `corner` | `number` | No | Corner radius. |
| `opacity` | `number` | No | Opacity from 0 through 1. |
| `alignment` | `enum` | No | Layout alignment. Values: `center`, `leading`, `trailing`, `top`, `bottom`, `topLeading`, `topTrailing`, `bottomLeading`, `bottomTrailing`, `firstTextBaseline`, `lastTextBaseline` |
| `clip` | `enum` | No | Clip the view to a shape. Values: `circle`, `rect`, `capsule`, `ellipse` |
| `rotation` | `number` | No | Rotation in degrees. |
| `rotation3d` | `string` | No | 3D rotation description. |
| `shadow` | `string` | No | Shadow color, radius, and offset description. |
| `animation` | `string` | No | Timeline-driven animation description. |
| `widgetAccentable` | `boolean` | No | Group this view into the accent layer in tinted and vibrant widget appearances. |
| `linkurl` | `url` | No | Widget deep link URL. |
| `trim` | `number|string` | No |  |
| `stroke` | `string` | No |  |

### `<Circle>`

Circle shape.

| Property | Type | Required | Notes |
| --- | --- | --- | --- |
| `background` | `color` | No | Background color, hex value, or named color. |
| `color` | `color` | No | Foreground color, hex value, or named color. |
| `font` | `enum` | No | Semantic text style. Values: `largeTitle`, `title`, `title2`, `title3`, `headline`, `subheadline`, `body`, `callout`, `footnote`, `caption`, `caption2` |
| `fontWeight` | `enum` | No | Font weight. Values: `ultraLight`, `thin`, `light`, `regular`, `medium`, `semibold`, `bold`, `heavy`, `black` |
| `fontDesign` | `enum` | No | Font design. Values: `default`, `rounded`, `serif`, `monospaced` |
| `frame` | `number|string` | No | Square size (64 or "64"), width,height ("64,48"), or flexible frame ("max", "max,48"). |
| `padding` | `number|string` | No | Padding amount or edge description. |
| `corner` | `number` | No | Corner radius. |
| `opacity` | `number` | No | Opacity from 0 through 1. |
| `alignment` | `enum` | No | Layout alignment. Values: `center`, `leading`, `trailing`, `top`, `bottom`, `topLeading`, `topTrailing`, `bottomLeading`, `bottomTrailing`, `firstTextBaseline`, `lastTextBaseline` |
| `clip` | `enum` | No | Clip the view to a shape. Values: `circle`, `rect`, `capsule`, `ellipse` |
| `rotation` | `number` | No | Rotation in degrees. |
| `rotation3d` | `string` | No | 3D rotation description. |
| `shadow` | `string` | No | Shadow color, radius, and offset description. |
| `animation` | `string` | No | Timeline-driven animation description. |
| `widgetAccentable` | `boolean` | No | Group this view into the accent layer in tinted and vibrant widget appearances. |
| `linkurl` | `url` | No | Widget deep link URL. |
| `trim` | `number|string` | No |  |
| `stroke` | `string` | No |  |

### `<Gauge>`

Display a gauge or instrument.

| Property | Type | Required | Notes |
| --- | --- | --- | --- |
| `background` | `color` | No | Background color, hex value, or named color. |
| `color` | `color` | No | Foreground color, hex value, or named color. |
| `font` | `enum` | No | Semantic text style. Values: `largeTitle`, `title`, `title2`, `title3`, `headline`, `subheadline`, `body`, `callout`, `footnote`, `caption`, `caption2` |
| `fontWeight` | `enum` | No | Font weight. Values: `ultraLight`, `thin`, `light`, `regular`, `medium`, `semibold`, `bold`, `heavy`, `black` |
| `fontDesign` | `enum` | No | Font design. Values: `default`, `rounded`, `serif`, `monospaced` |
| `frame` | `number|string` | No | Square size (64 or "64"), width,height ("64,48"), or flexible frame ("max", "max,48"). |
| `padding` | `number|string` | No | Padding amount or edge description. |
| `corner` | `number` | No | Corner radius. |
| `opacity` | `number` | No | Opacity from 0 through 1. |
| `alignment` | `enum` | No | Layout alignment. Values: `center`, `leading`, `trailing`, `top`, `bottom`, `topLeading`, `topTrailing`, `bottomLeading`, `bottomTrailing`, `firstTextBaseline`, `lastTextBaseline` |
| `clip` | `enum` | No | Clip the view to a shape. Values: `circle`, `rect`, `capsule`, `ellipse` |
| `rotation` | `number` | No | Rotation in degrees. |
| `rotation3d` | `string` | No | 3D rotation description. |
| `shadow` | `string` | No | Shadow color, radius, and offset description. |
| `animation` | `string` | No | Timeline-driven animation description. |
| `widgetAccentable` | `boolean` | No | Group this view into the accent layer in tinted and vibrant widget appearances. |
| `linkurl` | `url` | No | Widget deep link URL. |
| `type` | `string` | No |  |
| `value` | `number` | No |  |
| `style` | `enum` | No | Values: `circular`, `linear` |
| `text` | `string` | No |  |
| `current` | `string` | No |  |
| `min` | `string` | No |  |
| `max` | `string` | No |  |
| `angle` | `number` | No |  |
| `thickness` | `number` | No |  |
| `needleColor` | `color` | No |  |
| `label` | `string` | No |  |
| `title` | `string` | No |  |
| `sections` | `string` | No |  |

### `<Chart>`

Render chart data.

| Property | Type | Required | Notes |
| --- | --- | --- | --- |
| `background` | `color` | No | Background color, hex value, or named color. |
| `color` | `color` | No | Foreground color, hex value, or named color. |
| `font` | `enum` | No | Semantic text style. Values: `largeTitle`, `title`, `title2`, `title3`, `headline`, `subheadline`, `body`, `callout`, `footnote`, `caption`, `caption2` |
| `fontWeight` | `enum` | No | Font weight. Values: `ultraLight`, `thin`, `light`, `regular`, `medium`, `semibold`, `bold`, `heavy`, `black` |
| `fontDesign` | `enum` | No | Font design. Values: `default`, `rounded`, `serif`, `monospaced` |
| `frame` | `number|string` | No | Square size (64 or "64"), width,height ("64,48"), or flexible frame ("max", "max,48"). |
| `padding` | `number|string` | No | Padding amount or edge description. |
| `corner` | `number` | No | Corner radius. |
| `opacity` | `number` | No | Opacity from 0 through 1. |
| `alignment` | `enum` | No | Layout alignment. Values: `center`, `leading`, `trailing`, `top`, `bottom`, `topLeading`, `topTrailing`, `bottomLeading`, `bottomTrailing`, `firstTextBaseline`, `lastTextBaseline` |
| `clip` | `enum` | No | Clip the view to a shape. Values: `circle`, `rect`, `capsule`, `ellipse` |
| `rotation` | `number` | No | Rotation in degrees. |
| `rotation3d` | `string` | No | 3D rotation description. |
| `shadow` | `string` | No | Shadow color, radius, and offset description. |
| `animation` | `string` | No | Timeline-driven animation description. |
| `widgetAccentable` | `boolean` | No | Group this view into the accent layer in tinted and vibrant widget appearances. |
| `linkurl` | `url` | No | Widget deep link URL. |
| `type` | `enum` | No | Values: `bar`, `bar-x`, `bar-y`, `bar-gantt`, `line`, `point`, `line-point`, `area`, `rect`, `rule-x` |
| `data` | `json` | Yes |  |
| `category` | `boolean` | No |  |
| `hideLegend` | `boolean` | No |  |
| `hideXAxis` | `boolean` | No |  |
| `hideYAxis` | `boolean` | No |  |

### `<Link>`

Open a URL when selected.

| Property | Type | Required | Notes |
| --- | --- | --- | --- |
| `background` | `color` | No | Background color, hex value, or named color. |
| `color` | `color` | No | Foreground color, hex value, or named color. |
| `font` | `enum` | No | Semantic text style. Values: `largeTitle`, `title`, `title2`, `title3`, `headline`, `subheadline`, `body`, `callout`, `footnote`, `caption`, `caption2` |
| `fontWeight` | `enum` | No | Font weight. Values: `ultraLight`, `thin`, `light`, `regular`, `medium`, `semibold`, `bold`, `heavy`, `black` |
| `fontDesign` | `enum` | No | Font design. Values: `default`, `rounded`, `serif`, `monospaced` |
| `frame` | `number|string` | No | Square size (64 or "64"), width,height ("64,48"), or flexible frame ("max", "max,48"). |
| `padding` | `number|string` | No | Padding amount or edge description. |
| `corner` | `number` | No | Corner radius. |
| `opacity` | `number` | No | Opacity from 0 through 1. |
| `alignment` | `enum` | No | Layout alignment. Values: `center`, `leading`, `trailing`, `top`, `bottom`, `topLeading`, `topTrailing`, `bottomLeading`, `bottomTrailing`, `firstTextBaseline`, `lastTextBaseline` |
| `clip` | `enum` | No | Clip the view to a shape. Values: `circle`, `rect`, `capsule`, `ellipse` |
| `rotation` | `number` | No | Rotation in degrees. |
| `rotation3d` | `string` | No | 3D rotation description. |
| `shadow` | `string` | No | Shadow color, radius, and offset description. |
| `animation` | `string` | No | Timeline-driven animation description. |
| `widgetAccentable` | `boolean` | No | Group this view into the accent layer in tinted and vibrant widget appearances. |
| `linkurl` | `url` | No | Widget deep link URL. |
| `url` | `url` | Yes |  |

### `<Divider>`

Horizontal or vertical separator.

| Property | Type | Required | Notes |
| --- | --- | --- | --- |
| `background` | `color` | No | Background color, hex value, or named color. |
| `color` | `color` | No | Foreground color, hex value, or named color. |
| `font` | `enum` | No | Semantic text style. Values: `largeTitle`, `title`, `title2`, `title3`, `headline`, `subheadline`, `body`, `callout`, `footnote`, `caption`, `caption2` |
| `fontWeight` | `enum` | No | Font weight. Values: `ultraLight`, `thin`, `light`, `regular`, `medium`, `semibold`, `bold`, `heavy`, `black` |
| `fontDesign` | `enum` | No | Font design. Values: `default`, `rounded`, `serif`, `monospaced` |
| `frame` | `number|string` | No | Square size (64 or "64"), width,height ("64,48"), or flexible frame ("max", "max,48"). |
| `padding` | `number|string` | No | Padding amount or edge description. |
| `corner` | `number` | No | Corner radius. |
| `opacity` | `number` | No | Opacity from 0 through 1. |
| `alignment` | `enum` | No | Layout alignment. Values: `center`, `leading`, `trailing`, `top`, `bottom`, `topLeading`, `topTrailing`, `bottomLeading`, `bottomTrailing`, `firstTextBaseline`, `lastTextBaseline` |
| `clip` | `enum` | No | Clip the view to a shape. Values: `circle`, `rect`, `capsule`, `ellipse` |
| `rotation` | `number` | No | Rotation in degrees. |
| `rotation3d` | `string` | No | 3D rotation description. |
| `shadow` | `string` | No | Shadow color, radius, and offset description. |
| `animation` | `string` | No | Timeline-driven animation description. |
| `widgetAccentable` | `boolean` | No | Group this view into the accent layer in tinted and vibrant widget appearances. |
| `linkurl` | `url` | No | Widget deep link URL. |
| `thickness` | `number` | No |  |
| `axis` | `enum` | No | Values: `horizontal`, `vertical` |

### `<Line>`

Fixed-length line.

| Property | Type | Required | Notes |
| --- | --- | --- | --- |
| `background` | `color` | No | Background color, hex value, or named color. |
| `color` | `color` | No | Foreground color, hex value, or named color. |
| `font` | `enum` | No | Semantic text style. Values: `largeTitle`, `title`, `title2`, `title3`, `headline`, `subheadline`, `body`, `callout`, `footnote`, `caption`, `caption2` |
| `fontWeight` | `enum` | No | Font weight. Values: `ultraLight`, `thin`, `light`, `regular`, `medium`, `semibold`, `bold`, `heavy`, `black` |
| `fontDesign` | `enum` | No | Font design. Values: `default`, `rounded`, `serif`, `monospaced` |
| `frame` | `number|string` | No | Square size (64 or "64"), width,height ("64,48"), or flexible frame ("max", "max,48"). |
| `padding` | `number|string` | No | Padding amount or edge description. |
| `corner` | `number` | No | Corner radius. |
| `opacity` | `number` | No | Opacity from 0 through 1. |
| `alignment` | `enum` | No | Layout alignment. Values: `center`, `leading`, `trailing`, `top`, `bottom`, `topLeading`, `topTrailing`, `bottomLeading`, `bottomTrailing`, `firstTextBaseline`, `lastTextBaseline` |
| `clip` | `enum` | No | Clip the view to a shape. Values: `circle`, `rect`, `capsule`, `ellipse` |
| `rotation` | `number` | No | Rotation in degrees. |
| `rotation3d` | `string` | No | 3D rotation description. |
| `shadow` | `string` | No | Shadow color, radius, and offset description. |
| `animation` | `string` | No | Timeline-driven animation description. |
| `widgetAccentable` | `boolean` | No | Group this view into the accent layer in tinted and vibrant widget appearances. |
| `linkurl` | `url` | No | Widget deep link URL. |
| `thickness` | `number` | No |  |
| `length` | `number` | No |  |
| `axis` | `enum` | No | Values: `horizontal`, `vertical` |

### `<Icon>`

SF Symbol icon.

| Property | Type | Required | Notes |
| --- | --- | --- | --- |
| `background` | `color` | No | Background color, hex value, or named color. |
| `color` | `color` | No | Foreground color, hex value, or named color. |
| `font` | `enum` | No | Semantic text style. Values: `largeTitle`, `title`, `title2`, `title3`, `headline`, `subheadline`, `body`, `callout`, `footnote`, `caption`, `caption2` |
| `fontWeight` | `enum` | No | Font weight. Values: `ultraLight`, `thin`, `light`, `regular`, `medium`, `semibold`, `bold`, `heavy`, `black` |
| `fontDesign` | `enum` | No | Font design. Values: `default`, `rounded`, `serif`, `monospaced` |
| `frame` | `number|string` | No | Square size (64 or "64"), width,height ("64,48"), or flexible frame ("max", "max,48"). |
| `padding` | `number|string` | No | Padding amount or edge description. |
| `corner` | `number` | No | Corner radius. |
| `opacity` | `number` | No | Opacity from 0 through 1. |
| `alignment` | `enum` | No | Layout alignment. Values: `center`, `leading`, `trailing`, `top`, `bottom`, `topLeading`, `topTrailing`, `bottomLeading`, `bottomTrailing`, `firstTextBaseline`, `lastTextBaseline` |
| `clip` | `enum` | No | Clip the view to a shape. Values: `circle`, `rect`, `capsule`, `ellipse` |
| `rotation` | `number` | No | Rotation in degrees. |
| `rotation3d` | `string` | No | 3D rotation description. |
| `shadow` | `string` | No | Shadow color, radius, and offset description. |
| `animation` | `string` | No | Timeline-driven animation description. |
| `widgetAccentable` | `boolean` | No | Group this view into the accent layer in tinted and vibrant widget appearances. |
| `linkurl` | `url` | No | Widget deep link URL. |
| `systemName` | `string` | Yes |  |
| `size` | `number` | No |  |

### `<Label>`

Text paired with an SF Symbol.

| Property | Type | Required | Notes |
| --- | --- | --- | --- |
| `background` | `color` | No | Background color, hex value, or named color. |
| `color` | `color` | No | Foreground color, hex value, or named color. |
| `font` | `enum` | No | Semantic text style. Values: `largeTitle`, `title`, `title2`, `title3`, `headline`, `subheadline`, `body`, `callout`, `footnote`, `caption`, `caption2` |
| `fontWeight` | `enum` | No | Font weight. Values: `ultraLight`, `thin`, `light`, `regular`, `medium`, `semibold`, `bold`, `heavy`, `black` |
| `fontDesign` | `enum` | No | Font design. Values: `default`, `rounded`, `serif`, `monospaced` |
| `frame` | `number|string` | No | Square size (64 or "64"), width,height ("64,48"), or flexible frame ("max", "max,48"). |
| `padding` | `number|string` | No | Padding amount or edge description. |
| `corner` | `number` | No | Corner radius. |
| `opacity` | `number` | No | Opacity from 0 through 1. |
| `alignment` | `enum` | No | Layout alignment. Values: `center`, `leading`, `trailing`, `top`, `bottom`, `topLeading`, `topTrailing`, `bottomLeading`, `bottomTrailing`, `firstTextBaseline`, `lastTextBaseline` |
| `clip` | `enum` | No | Clip the view to a shape. Values: `circle`, `rect`, `capsule`, `ellipse` |
| `rotation` | `number` | No | Rotation in degrees. |
| `rotation3d` | `string` | No | 3D rotation description. |
| `shadow` | `string` | No | Shadow color, radius, and offset description. |
| `animation` | `string` | No | Timeline-driven animation description. |
| `widgetAccentable` | `boolean` | No | Group this view into the accent layer in tinted and vibrant widget appearances. |
| `linkurl` | `url` | No | Widget deep link URL. |
| `title` | `string` | No |  |
| `systemName` | `string` | Yes |  |

### `<Progress>`

Linear or circular progress.

| Property | Type | Required | Notes |
| --- | --- | --- | --- |
| `background` | `color` | No | Background color, hex value, or named color. |
| `color` | `color` | No | Foreground color, hex value, or named color. |
| `font` | `enum` | No | Semantic text style. Values: `largeTitle`, `title`, `title2`, `title3`, `headline`, `subheadline`, `body`, `callout`, `footnote`, `caption`, `caption2` |
| `fontWeight` | `enum` | No | Font weight. Values: `ultraLight`, `thin`, `light`, `regular`, `medium`, `semibold`, `bold`, `heavy`, `black` |
| `fontDesign` | `enum` | No | Font design. Values: `default`, `rounded`, `serif`, `monospaced` |
| `frame` | `number|string` | No | Square size (64 or "64"), width,height ("64,48"), or flexible frame ("max", "max,48"). |
| `padding` | `number|string` | No | Padding amount or edge description. |
| `corner` | `number` | No | Corner radius. |
| `opacity` | `number` | No | Opacity from 0 through 1. |
| `alignment` | `enum` | No | Layout alignment. Values: `center`, `leading`, `trailing`, `top`, `bottom`, `topLeading`, `topTrailing`, `bottomLeading`, `bottomTrailing`, `firstTextBaseline`, `lastTextBaseline` |
| `clip` | `enum` | No | Clip the view to a shape. Values: `circle`, `rect`, `capsule`, `ellipse` |
| `rotation` | `number` | No | Rotation in degrees. |
| `rotation3d` | `string` | No | 3D rotation description. |
| `shadow` | `string` | No | Shadow color, radius, and offset description. |
| `animation` | `string` | No | Timeline-driven animation description. |
| `widgetAccentable` | `boolean` | No | Group this view into the accent layer in tinted and vibrant widget appearances. |
| `linkurl` | `url` | No | Widget deep link URL. |
| `value` | `number` | Yes |  |
| `total` | `number` | No |  |
| `label` | `string` | No |  |
| `style` | `enum` | No | Values: `linear`, `circular` |
| `trackColor` | `color` | No |  |
| `thickness` | `number` | No |  |

### `<Ring>`

Circular progress ring.

| Property | Type | Required | Notes |
| --- | --- | --- | --- |
| `background` | `color` | No | Background color, hex value, or named color. |
| `color` | `color` | No | Foreground color, hex value, or named color. |
| `font` | `enum` | No | Semantic text style. Values: `largeTitle`, `title`, `title2`, `title3`, `headline`, `subheadline`, `body`, `callout`, `footnote`, `caption`, `caption2` |
| `fontWeight` | `enum` | No | Font weight. Values: `ultraLight`, `thin`, `light`, `regular`, `medium`, `semibold`, `bold`, `heavy`, `black` |
| `fontDesign` | `enum` | No | Font design. Values: `default`, `rounded`, `serif`, `monospaced` |
| `frame` | `number|string` | No | Square size (64 or "64"), width,height ("64,48"), or flexible frame ("max", "max,48"). |
| `padding` | `number|string` | No | Padding amount or edge description. |
| `corner` | `number` | No | Corner radius. |
| `opacity` | `number` | No | Opacity from 0 through 1. |
| `alignment` | `enum` | No | Layout alignment. Values: `center`, `leading`, `trailing`, `top`, `bottom`, `topLeading`, `topTrailing`, `bottomLeading`, `bottomTrailing`, `firstTextBaseline`, `lastTextBaseline` |
| `clip` | `enum` | No | Clip the view to a shape. Values: `circle`, `rect`, `capsule`, `ellipse` |
| `rotation` | `number` | No | Rotation in degrees. |
| `rotation3d` | `string` | No | 3D rotation description. |
| `shadow` | `string` | No | Shadow color, radius, and offset description. |
| `animation` | `string` | No | Timeline-driven animation description. |
| `widgetAccentable` | `boolean` | No | Group this view into the accent layer in tinted and vibrant widget appearances. |
| `linkurl` | `url` | No | Widget deep link URL. |
| `value` | `number` | Yes |  |
| `thickness` | `number` | No |  |
| `trackColor` | `color` | No |  |

### `<Badge>`

Compact status badge.

| Property | Type | Required | Notes |
| --- | --- | --- | --- |
| `background` | `color` | No | Background color, hex value, or named color. |
| `color` | `color` | No | Foreground color, hex value, or named color. |
| `font` | `enum` | No | Semantic text style. Values: `largeTitle`, `title`, `title2`, `title3`, `headline`, `subheadline`, `body`, `callout`, `footnote`, `caption`, `caption2` |
| `fontWeight` | `enum` | No | Font weight. Values: `ultraLight`, `thin`, `light`, `regular`, `medium`, `semibold`, `bold`, `heavy`, `black` |
| `fontDesign` | `enum` | No | Font design. Values: `default`, `rounded`, `serif`, `monospaced` |
| `frame` | `number|string` | No | Square size (64 or "64"), width,height ("64,48"), or flexible frame ("max", "max,48"). |
| `padding` | `number|string` | No | Padding amount or edge description. |
| `corner` | `number` | No | Corner radius. |
| `opacity` | `number` | No | Opacity from 0 through 1. |
| `alignment` | `enum` | No | Layout alignment. Values: `center`, `leading`, `trailing`, `top`, `bottom`, `topLeading`, `topTrailing`, `bottomLeading`, `bottomTrailing`, `firstTextBaseline`, `lastTextBaseline` |
| `clip` | `enum` | No | Clip the view to a shape. Values: `circle`, `rect`, `capsule`, `ellipse` |
| `rotation` | `number` | No | Rotation in degrees. |
| `rotation3d` | `string` | No | 3D rotation description. |
| `shadow` | `string` | No | Shadow color, radius, and offset description. |
| `animation` | `string` | No | Timeline-driven animation description. |
| `widgetAccentable` | `boolean` | No | Group this view into the accent layer in tinted and vibrant widget appearances. |
| `linkurl` | `url` | No | Widget deep link URL. |
| `text` | `string` | No |  |
| `radius` | `number` | No |  |

### `<Chip>`

Outlined metadata chip.

| Property | Type | Required | Notes |
| --- | --- | --- | --- |
| `background` | `color` | No | Background color, hex value, or named color. |
| `color` | `color` | No | Foreground color, hex value, or named color. |
| `font` | `enum` | No | Semantic text style. Values: `largeTitle`, `title`, `title2`, `title3`, `headline`, `subheadline`, `body`, `callout`, `footnote`, `caption`, `caption2` |
| `fontWeight` | `enum` | No | Font weight. Values: `ultraLight`, `thin`, `light`, `regular`, `medium`, `semibold`, `bold`, `heavy`, `black` |
| `fontDesign` | `enum` | No | Font design. Values: `default`, `rounded`, `serif`, `monospaced` |
| `frame` | `number|string` | No | Square size (64 or "64"), width,height ("64,48"), or flexible frame ("max", "max,48"). |
| `padding` | `number|string` | No | Padding amount or edge description. |
| `corner` | `number` | No | Corner radius. |
| `opacity` | `number` | No | Opacity from 0 through 1. |
| `alignment` | `enum` | No | Layout alignment. Values: `center`, `leading`, `trailing`, `top`, `bottom`, `topLeading`, `topTrailing`, `bottomLeading`, `bottomTrailing`, `firstTextBaseline`, `lastTextBaseline` |
| `clip` | `enum` | No | Clip the view to a shape. Values: `circle`, `rect`, `capsule`, `ellipse` |
| `rotation` | `number` | No | Rotation in degrees. |
| `rotation3d` | `string` | No | 3D rotation description. |
| `shadow` | `string` | No | Shadow color, radius, and offset description. |
| `animation` | `string` | No | Timeline-driven animation description. |
| `widgetAccentable` | `boolean` | No | Group this view into the accent layer in tinted and vibrant widget appearances. |
| `linkurl` | `url` | No | Widget deep link URL. |
| `text` | `string` | No |  |
| `radius` | `number` | No |  |
| `borderColor` | `color` | No |  |

### `<Stat>`

Title, value, and subtitle statistic.

| Property | Type | Required | Notes |
| --- | --- | --- | --- |
| `background` | `color` | No | Background color, hex value, or named color. |
| `color` | `color` | No | Foreground color, hex value, or named color. |
| `font` | `enum` | No | Semantic text style. Values: `largeTitle`, `title`, `title2`, `title3`, `headline`, `subheadline`, `body`, `callout`, `footnote`, `caption`, `caption2` |
| `fontWeight` | `enum` | No | Font weight. Values: `ultraLight`, `thin`, `light`, `regular`, `medium`, `semibold`, `bold`, `heavy`, `black` |
| `fontDesign` | `enum` | No | Font design. Values: `default`, `rounded`, `serif`, `monospaced` |
| `frame` | `number|string` | No | Square size (64 or "64"), width,height ("64,48"), or flexible frame ("max", "max,48"). |
| `padding` | `number|string` | No | Padding amount or edge description. |
| `corner` | `number` | No | Corner radius. |
| `opacity` | `number` | No | Opacity from 0 through 1. |
| `alignment` | `enum` | No | Layout alignment. Values: `center`, `leading`, `trailing`, `top`, `bottom`, `topLeading`, `topTrailing`, `bottomLeading`, `bottomTrailing`, `firstTextBaseline`, `lastTextBaseline` |
| `clip` | `enum` | No | Clip the view to a shape. Values: `circle`, `rect`, `capsule`, `ellipse` |
| `rotation` | `number` | No | Rotation in degrees. |
| `rotation3d` | `string` | No | 3D rotation description. |
| `shadow` | `string` | No | Shadow color, radius, and offset description. |
| `animation` | `string` | No | Timeline-driven animation description. |
| `widgetAccentable` | `boolean` | No | Group this view into the accent layer in tinted and vibrant widget appearances. |
| `linkurl` | `url` | No | Widget deep link URL. |
| `title` | `string` | No |  |
| `value` | `string` | Yes |  |
| `subtitle` | `string` | No |  |
| `mutedColor` | `color` | No |  |

### `<Button>`

Interactive widget button. Use actionID to share a declared Package 2.0 action with Siri, Shortcuts, and Control Widgets.

| Property | Type | Required | Notes |
| --- | --- | --- | --- |
| `background` | `color` | No | Background color, hex value, or named color. |
| `color` | `color` | No | Foreground color, hex value, or named color. |
| `font` | `enum` | No | Semantic text style. Values: `largeTitle`, `title`, `title2`, `title3`, `headline`, `subheadline`, `body`, `callout`, `footnote`, `caption`, `caption2` |
| `fontWeight` | `enum` | No | Font weight. Values: `ultraLight`, `thin`, `light`, `regular`, `medium`, `semibold`, `bold`, `heavy`, `black` |
| `fontDesign` | `enum` | No | Font design. Values: `default`, `rounded`, `serif`, `monospaced` |
| `frame` | `number|string` | No | Square size (64 or "64"), width,height ("64,48"), or flexible frame ("max", "max,48"). |
| `padding` | `number|string` | No | Padding amount or edge description. |
| `corner` | `number` | No | Corner radius. |
| `opacity` | `number` | No | Opacity from 0 through 1. |
| `alignment` | `enum` | No | Layout alignment. Values: `center`, `leading`, `trailing`, `top`, `bottom`, `topLeading`, `topTrailing`, `bottomLeading`, `bottomTrailing`, `firstTextBaseline`, `lastTextBaseline` |
| `clip` | `enum` | No | Clip the view to a shape. Values: `circle`, `rect`, `capsule`, `ellipse` |
| `rotation` | `number` | No | Rotation in degrees. |
| `rotation3d` | `string` | No | 3D rotation description. |
| `shadow` | `string` | No | Shadow color, radius, and offset description. |
| `animation` | `string` | No | Timeline-driven animation description. |
| `widgetAccentable` | `boolean` | No | Group this view into the accent layer in tinted and vibrant widget appearances. |
| `linkurl` | `url` | No | Widget deep link URL. |
| `action` | `enum` | No | Values: `reload` |
| `onClick` | `function` | No |  |
| `actionID` | `action-id` | No |  |

### `<Toggle>`

Interactive widget toggle. A declared actionID requires a package-relative storage stateKey.

| Property | Type | Required | Notes |
| --- | --- | --- | --- |
| `background` | `color` | No | Background color, hex value, or named color. |
| `color` | `color` | No | Foreground color, hex value, or named color. |
| `font` | `enum` | No | Semantic text style. Values: `largeTitle`, `title`, `title2`, `title3`, `headline`, `subheadline`, `body`, `callout`, `footnote`, `caption`, `caption2` |
| `fontWeight` | `enum` | No | Font weight. Values: `ultraLight`, `thin`, `light`, `regular`, `medium`, `semibold`, `bold`, `heavy`, `black` |
| `fontDesign` | `enum` | No | Font design. Values: `default`, `rounded`, `serif`, `monospaced` |
| `frame` | `number|string` | No | Square size (64 or "64"), width,height ("64,48"), or flexible frame ("max", "max,48"). |
| `padding` | `number|string` | No | Padding amount or edge description. |
| `corner` | `number` | No | Corner radius. |
| `opacity` | `number` | No | Opacity from 0 through 1. |
| `alignment` | `enum` | No | Layout alignment. Values: `center`, `leading`, `trailing`, `top`, `bottom`, `topLeading`, `topTrailing`, `bottomLeading`, `bottomTrailing`, `firstTextBaseline`, `lastTextBaseline` |
| `clip` | `enum` | No | Clip the view to a shape. Values: `circle`, `rect`, `capsule`, `ellipse` |
| `rotation` | `number` | No | Rotation in degrees. |
| `rotation3d` | `string` | No | 3D rotation description. |
| `shadow` | `string` | No | Shadow color, radius, and offset description. |
| `animation` | `string` | No | Timeline-driven animation description. |
| `widgetAccentable` | `boolean` | No | Group this view into the accent layer in tinted and vibrant widget appearances. |
| `linkurl` | `url` | No | Widget deep link URL. |
| `on` | `boolean` | Yes |  |
| `onClick` | `function` | No |  |
| `actionID` | `action-id` | No |  |
| `stateKey` | `storage-key` | No |  |

## Runtime functions

- `$storage.getString`: Read a package-scoped string. Missing keys return an empty string.
- `$storage.setString`: Set a package-scoped string, limited to 256 KiB of UTF-8. Check the success result.
- `$storage.getJSON`: Read a package-scoped JSON object. Missing or invalid values return an empty object.
- `$storage.setJSON`: Store a valid JSON object, limited to 256 KiB encoded. Check the success result.
- `$storage.compareAndSetString`: Atomically replace a string only when it still matches expected. A missing key matches an empty string. Conflicts return false; reread and retry a bounded number of times. Requires the shared storage container.
- `$storage.compareAndSetJSON`: Atomically replace a JSON object if its current value equals expected, independent of property order. A missing key matches an empty object. Wrong types and conflicts return false. Requires the shared storage container.
- `$storage.remove`: Remove a key from this package only.
- `$storage.keys`: List keys in this package's namespace.
- `$storage.clear`: Clear this package's storage. Other packages are unaffected.
- `$device.screen`: Device values depend on hardware. Some legacy Mac values are placeholders; inspect the API documentation before using them as measurements.
- `$device.language`: Device values depend on hardware. Some legacy Mac values are placeholders; inspect the API documentation before using them as measurements.
- `$device.model`: Device values depend on hardware. Some legacy Mac values are placeholders; inspect the API documentation before using them as measurements.
- `$device.name`: Device values depend on hardware. Some legacy Mac values are placeholders; inspect the API documentation before using them as measurements.
- `$device.battery`: Device values depend on hardware. Some legacy Mac values are placeholders; inspect the API documentation before using them as measurements.
- `$device.systemVersion`: Device values depend on hardware. Some legacy Mac values are placeholders; inspect the API documentation before using them as measurements.
- `$device.isdarkmode`: Device values depend on hardware. Some legacy Mac values are placeholders; inspect the API documentation before using them as measurements.
- `$device.totalDiskSpace`: Device values depend on hardware. Some legacy Mac values are placeholders; inspect the API documentation before using them as measurements.
- `$device.freeDiskSpace`: Device values depend on hardware. Some legacy Mac values are placeholders; inspect the API documentation before using them as measurements.
- `$system.appInfo`: System metadata, not whole-device CPU, FPS or network traffic monitoring. Hardware-specific values may be unavailable.
- `$system.locale`: System metadata, not whole-device CPU, FPS or network traffic monitoring. Hardware-specific values may be unavailable.
- `$system.preferredLanguages`: System metadata, not whole-device CPU, FPS or network traffic monitoring. Hardware-specific values may be unavailable.
- `$system.timeZone`: System metadata, not whole-device CPU, FPS or network traffic monitoring. Hardware-specific values may be unavailable.
- `$system.is24HourClock`: System metadata, not whole-device CPU, FPS or network traffic monitoring. Hardware-specific values may be unavailable.
- `$system.calendarInfo`: System metadata, not whole-device CPU, FPS or network traffic monitoring. Hardware-specific values may be unavailable.
- `$system.systemUptime`: System metadata, not whole-device CPU, FPS or network traffic monitoring. Hardware-specific values may be unavailable.
- `$system.memory`: System metadata, not whole-device CPU, FPS or network traffic monitoring. Hardware-specific values may be unavailable.
- `$system.thermalState`: System metadata, not whole-device CPU, FPS or network traffic monitoring. Hardware-specific values may be unavailable.
- `$system.lowPowerMode`: System metadata, not whole-device CPU, FPS or network traffic monitoring. Hardware-specific values may be unavailable.
- `$system.brightness`: System metadata, not whole-device CPU, FPS or network traffic monitoring. Hardware-specific values may be unavailable.
- `$system.reduceMotionEnabled`: System metadata, not whole-device CPU, FPS or network traffic monitoring. Hardware-specific values may be unavailable.
- `$system.platform`: System metadata, not whole-device CPU, FPS or network traffic monitoring. Hardware-specific values may be unavailable.
- `$system.hostName`: System metadata, not whole-device CPU, FPS or network traffic monitoring. Hardware-specific values may be unavailable.
- `$system.processName`: System metadata, not whole-device CPU, FPS or network traffic monitoring. Hardware-specific values may be unavailable.
- `$system.osVersionString`: System metadata, not whole-device CPU, FPS or network traffic monitoring. Hardware-specific values may be unavailable.
- `$system.processorCount`: System metadata, not whole-device CPU, FPS or network traffic monitoring. Hardware-specific values may be unavailable.
- `$system.activeProcessorCount`: System metadata, not whole-device CPU, FPS or network traffic monitoring. Hardware-specific values may be unavailable.
- `$calendar.isAvailable`: Requires calendar in widget.json and full system Calendar access. The user's native Settings source selection limits metadata, events and cached snapshots; scripts cannot enlarge it. Use calendars() for permitted IDs and show setup when no sources are selected. Queries are read-only, limited to 31 days and 50 items. Preview calendarSelection simulates this scope without granting package permission.
- `$calendar.authorizationStatus`: Requires calendar in widget.json and full system Calendar access. The user's native Settings source selection limits metadata, events and cached snapshots; scripts cannot enlarge it. Use calendars() for permitted IDs and show setup when no sources are selected. Queries are read-only, limited to 31 days and 50 items. Preview calendarSelection simulates this scope without granting package permission.
- `$calendar.requestAuthorization`: Requires calendar in widget.json and full system Calendar access. The user's native Settings source selection limits metadata, events and cached snapshots; scripts cannot enlarge it. Use calendars() for permitted IDs and show setup when no sources are selected. Queries are read-only, limited to 31 days and 50 items. Preview calendarSelection simulates this scope without granting package permission.
- `$calendar.calendars`: Requires calendar in widget.json and full system Calendar access. The user's native Settings source selection limits metadata, events and cached snapshots; scripts cannot enlarge it. Use calendars() for permitted IDs and show setup when no sources are selected. Queries are read-only, limited to 31 days and 50 items. Preview calendarSelection simulates this scope without granting package permission.
- `$calendar.events`: Requires calendar in widget.json and full system Calendar access. The user's native Settings source selection limits metadata, events and cached snapshots; scripts cannot enlarge it. Use calendars() for permitted IDs and show setup when no sources are selected. Queries are read-only, limited to 31 days and 50 items. Preview calendarSelection simulates this scope without granting package permission.
- `$reminders.isAvailable`: Requires reminders in widget.json and full system Reminders access. Scripts have read-only access to native Settings selected lists; they cannot create, edit or complete reminders. Use lists() for IDs. items() selects pending due dates or completed completion dates in a positive window of at most 31 days, up to 50 items. Undated pending reminders are excluded. remindersSelection mocks the user scope without granting permission.
- `$reminders.authorizationStatus`: Requires reminders in widget.json and full system Reminders access. Scripts have read-only access to native Settings selected lists; they cannot create, edit or complete reminders. Use lists() for IDs. items() selects pending due dates or completed completion dates in a positive window of at most 31 days, up to 50 items. Undated pending reminders are excluded. remindersSelection mocks the user scope without granting permission.
- `$reminders.requestAuthorization`: Requires reminders in widget.json and full system Reminders access. Scripts have read-only access to native Settings selected lists; they cannot create, edit or complete reminders. Use lists() for IDs. items() selects pending due dates or completed completion dates in a positive window of at most 31 days, up to 50 items. Undated pending reminders are excluded. remindersSelection mocks the user scope without granting permission.
- `$reminders.lists`: Requires reminders in widget.json and full system Reminders access. Scripts have read-only access to native Settings selected lists; they cannot create, edit or complete reminders. Use lists() for IDs. items() selects pending due dates or completed completion dates in a positive window of at most 31 days, up to 50 items. Undated pending reminders are excluded. remindersSelection mocks the user scope without granting permission.
- `$reminders.items`: Requires reminders in widget.json and full system Reminders access. Scripts have read-only access to native Settings selected lists; they cannot create, edit or complete reminders. Use lists() for IDs. items() selects pending due dates or completed completion dates in a positive window of at most 31 days, up to 50 items. Undated pending reminders are excluded. remindersSelection mocks the user scope without granting permission.
- `$health.authorizationStatus`: Read-only HealthKit. Request access in the app. Authorization completion does not reveal whether individual read types were granted; empty results must not be labelled permission denied. API 1.3 readings add hasSamples: false means no readable samples, never a read-denial verdict. Existing value/unit/start/end fields remain.
- `$health.isAvailable`: Read-only HealthKit. Request access in the app. Authorization completion does not reveal whether individual read types were granted; empty results must not be labelled permission denied. API 1.3 readings add hasSamples: false means no readable samples, never a read-denial verdict. Existing value/unit/start/end fields remain.
- `$health.requestAuthorization`: Read-only HealthKit. Request access in the app. Authorization completion does not reveal whether individual read types were granted; empty results must not be labelled permission denied. API 1.3 readings add hasSamples: false means no readable samples, never a read-denial verdict. Existing value/unit/start/end fields remain.
- `$health.stepCountToday`: Read-only HealthKit. Request access in the app. Authorization completion does not reveal whether individual read types were granted; empty results must not be labelled permission denied. API 1.3 readings add hasSamples: false means no readable samples, never a read-denial verdict. Existing value/unit/start/end fields remain.
- `$health.activeEnergyToday`: Read-only HealthKit. Request access in the app. Authorization completion does not reveal whether individual read types were granted; empty results must not be labelled permission denied. API 1.3 readings add hasSamples: false means no readable samples, never a read-denial verdict. Existing value/unit/start/end fields remain.
- `$health.heartRateLatest`: Read-only HealthKit. Request access in the app. Authorization completion does not reveal whether individual read types were granted; empty results must not be labelled permission denied. API 1.3 readings add hasSamples: false means no readable samples, never a read-denial verdict. Existing value/unit/start/end fields remain.
- `$location.isAvailable`: Package 2.0 requires location permission. Request system access in the app. Widgets also require isAuthorizedForWidgetUpdates. Cache is rechecked against authorization and precision, discarded after 24 hours or revocation, and reports age/isStale.
- `$location.authorizationStatus`: Package 2.0 requires location permission. Request system access in the app. Widgets also require isAuthorizedForWidgetUpdates. Cache is rechecked against authorization and precision, discarded after 24 hours or revocation, and reports age/isStale.
- `$location.isAuthorizedForWidgetUpdates`: Package 2.0 requires location permission. Request system access in the app. Widgets also require isAuthorizedForWidgetUpdates. Cache is rechecked against authorization and precision, discarded after 24 hours or revocation, and reports age/isStale.
- `$location.requestAuthorization`: Package 2.0 requires location permission. Request system access in the app. Widgets also require isAuthorizedForWidgetUpdates. Cache is rechecked against authorization and precision, discarded after 24 hours or revocation, and reports age/isStale.
- `$location.current`: Package 2.0 requires location permission. Request system access in the app. Widgets also require isAuthorizedForWidgetUpdates. Cache is rechecked against authorization and precision, discarded after 24 hours or revocation, and reports age/isStale.
- `$file.exists`: Return whether a regular file is locally present inside this package, including binary assets. Missing files, directories, unsafe paths and links return false. Does not download iCloud files or read outside the package. Web preview uses workspace file presence.
- `$file.read`: Read package-relative UTF-8 text. Missing or unavailable files return an empty string.
- `$file.readJSON`: Read a package-relative JSON object.
- `fetch`: Perform a network request and return its response text. Existing HTTP methods keep this string result.
- `$http.getResponse`: GET response metadata: {status, body, headers}. Headers are limited to content-type, cache-control, expires, last-modified, date and retry-after (lowercase; each at most 2048 UTF-8 bytes). Network permissions, public-host policy, redirects, body limits and timeline restrictions still apply. HTTP error statuses resolve; transport errors reject.
- `importJS`: Import a package-relative JavaScript file.
- `$dataSource.request`: Call a declared Data Source Plugin operation. Requires Package 2.0 plugins, network permission, and networkDomains declarations.
- `$xml.parse`: Parse up to 256 KiB of XML into {name, attributes, text, children}. DTDs and external entities are rejected; depth and node limits apply.

## Environment values

- `timeline-date`
- `timeline-time-zone`
- `timeline-slot`
- `timeline-is-projection`
- `widget-size`
- `widget-param`
- `widget-rendering-mode`
- `live-activity-state`
- `live-activity-is-stale`
- `live-activity-surface`
- `action-id`
- `action-source`
- `action-value`
- `control-id`
- `control-value`

