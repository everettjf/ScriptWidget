// Home Screen widget sizes in points from Apple's Human Interface Guidelines.
// "iphone-393" matches BrowserPreviewSnapshotProfile in the native tests.
export const deviceProfiles = Object.freeze({
  "iphone-430": { label: "iPhone Pro Max (430 pt)", small: [170, 170], medium: [364, 170], large: [364, 382] },
  "iphone-393": { label: "iPhone / iPhone Pro (393 pt)", small: [158, 158], medium: [338, 158], large: [338, 354] },
  "iphone-375": { label: "iPhone SE (375 pt)", small: [148, 148], medium: [321, 148], large: [321, 324] },
});

export const widgetFamilies = Object.freeze(["small", "medium", "large"]);

export function widgetSize(profile, family) {
  const sizes = deviceProfiles[profile] ?? deviceProfiles["iphone-393"];
  const [width, height] = sizes[family] ?? sizes.medium;
  return { width, height };
}
