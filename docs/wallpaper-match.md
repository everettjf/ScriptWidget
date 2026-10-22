# Wallpaper Match

This template and native crop wizard prepare background images for a specific widget size, position and light/dark appearance. They match a region from your own wallpaper or an empty Home Screen screenshot. They do not set the system wallpaper or automatically determine where WidgetKit placed a widget.

## Prepare a crop

1. Install **Wallpaper Match** and open **Records & Configuration**.
2. Choose an image with Photos Picker or import a file. For a Home Screen match, use an empty page with the same wallpaper, orientation, icon layout and appearance as the intended widget position.
3. Choose the widget size and Light or Dark. The starting outline is a shape guide; drag it and adjust Left, Top, Width and Height in working-image pixels until it covers the intended area. Size presets are not device-specific placement measurements.
4. Give the position a label. Inspect the crop preview, then **Add Crop**. Alternatively, **Export Crop PNG** saves just the prepared image to a location you choose.
5. Save Configuration. Install the widget at that same position. If the match is offset, import the reference again and adjust its crop. Moving the widget, rotating the device or changing wallpaper/layout can require a new crop.

Each size has separate Light and Dark selections, for up to ten selections across five Home Screen families. A new crop for the same size/appearance replaces its draft selection. The old image remains until you save the new configuration and explicitly delete the unused crop. This preserves saved references while you review a draft. Keep at most twelve cropped files.

Only matching size/appearance assets are used: a missing dark selection does not silently pretend that the light crop matches. Accessory widgets use text/date content and do not apply a Home Screen screenshot behind their content.

## Content and appearances

Choose background only, title/caption, or calendar date. This is not a live clock. Date content uses bounded midnight timeline entries; WidgetKit controls actual refresh. Small widgets shorten long text to fit. Text color can follow the widget's appearance or use an explicit light/dark choice; inspect contrast against your own image.

Apple controls widget backgrounds and system appearances. Tinted, clear, StandBy or other system contexts can change how the image looks, even with the image's full-color preference. See Apple's [background guidance](https://developer.apple.com/documentation/widgetkit/displaying-the-right-widget-background) and [additional contexts and appearances](https://developer.apple.com/documentation/widgetkit/preparing-widgets-for-additional-contexts-and-appearances). A screenshot match is not a guarantee of true transparency.

## Files and recovery

Input files are bounded to 25 MiB, 20,000 pixels per dimension and 100 million source pixels. Orientation is normalized into a working image with a maximum edge of 3072 pixels. Crops are limited to 1024 pixels on their longest edge, normalized to sRGB and re-encoded as PNG. Original EXIF/GPS data and filenames are not copied. The whole input screenshot is kept only in the import/crop session; the package receives the crop, not the full original. Original Photos/Files items are kept.

Configuration backups preserve titles, content choices and resource references. Export the widget package separately to preserve its PNG files. A missing selected image shows **Restore this crop**, rather than invented image data. `$file.exists` checks presence; damaged image bytes still require replacing the file.

Imports and exports stay user initiated. Package paths are bounded and generated resource names cannot refer outside the current installation. An import draft cannot write into a removed, reinstalled or switched widget library. The wizard uses no network, photo-library-wide query or system wallpaper permission.
