// Home Screen widget sizes in points from Apple's Human Interface Guidelines.
// "iphone-393" matches BrowserPreviewSnapshotProfile in the native tests.
// Lock Screen accessory sizes follow AIWidgetSize.previewSize in the app.
const accessories = { accessoryCircular: [72, 72], accessoryRectangular: [170, 72], accessoryInline: [250, 30] };
export const deviceProfiles = Object.freeze({
  "iphone-430": { label: "iPhone Pro Max (430 pt)", small: [170, 170], medium: [364, 170], large: [364, 382], ...accessories },
  "iphone-393": { label: "iPhone / iPhone Pro (393 pt)", small: [158, 158], medium: [338, 158], large: [338, 354], ...accessories },
  "iphone-375": { label: "iPhone SE (375 pt)", small: [148, 148], medium: [321, 148], large: [321, 324], ...accessories },
  "ipad-1024": { label: "iPad Pro 12.9-inch", small: [170, 170], medium: [379, 170], large: [379, 379], extraLarge: [800, 379], extraLargePortrait: [379, 800] },
});

/// `$getenv("widget-size")` values, as set by ScriptWidgetDataObject.
export const widgetFamilies = Object.freeze(["small", "medium", "large", "extraLarge", "extraLargePortrait", "accessoryCircular", "accessoryRectangular", "accessoryInline"]);
export const familiesFor = (profile) => widgetFamilies.filter((family) => deviceProfiles[profile]?.[family]);

export function widgetSize(profile, family) {
  const sizes = deviceProfiles[profile] ?? deviceProfiles["iphone-393"];
  const [width, height] = sizes[family] ?? sizes.medium;
  return { width, height };
}
