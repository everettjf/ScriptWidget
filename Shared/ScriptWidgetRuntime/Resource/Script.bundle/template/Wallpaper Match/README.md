# Wallpaper Match

Install the complete package and open **Records & Configuration → Choose Screenshot or Wallpaper**. Select a size and appearance, drag the crop outline and calibrate its pixel rectangle. Add the crop, then Save Configuration. Place the widget at the position matching your reference.

Select background only, text or calendar date. Crop files are local PNG resources; no network or system wallpaper-setting capability is used. Light and Dark crops are independent. The original screenshot is not retained in the package.

Record backups preserve settings only. Export the widget package to keep its image files, or use Export Crop PNG in the wizard. System tinting and glass appearances can change the match. See [the background guide](../../../../../../../docs/wallpaper-match.md) for setup, calibration, limits and recovery.

In Web Studio, create a fresh copy of this template and choose **Wallpaper crops…** in the file sidebar. Choose a PNG/JPEG, adjust the rectangle, add a crop for each size/appearance, then Save Configuration. Export the .swt to carry `wallpaper.json` and its cropped images to the native app. Runtime 1.4 or later is required. Existing native saved configuration and preview storage mocks take precedence; imported package defaults never write records automatically. Save Configuration in the native app before exporting a record backup of these defaults.
