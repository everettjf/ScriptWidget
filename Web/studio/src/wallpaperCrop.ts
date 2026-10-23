/** Pixel geometry shared by the wallpaper import dialog and its export path.
 * Coordinates refer to the orientation-normalized working image, never CSS pixels.
 */
export type WallpaperFamily = "small" | "medium" | "large" | "extraLarge" | "extraLargePortrait";
export interface PixelSize { width: number; height: number }
export interface WallpaperCrop extends PixelSize { x: number; y: number }

export const wallpaperLimits = Object.freeze({
  sourceBytes: 25 * 1024 * 1024,
  sourceEdge: 20_000,
  sourcePixels: 100_000_000,
  workingEdge: 3072,
  cropEdge: 1024,
});

function positiveInteger(value: number): boolean {
  return Number.isSafeInteger(value) && value > 0;
}

export function validateWallpaperSize(size: PixelSize): void {
  if (!positiveInteger(size.width) || !positiveInteger(size.height)
    || Math.max(size.width, size.height) > wallpaperLimits.sourceEdge
    || size.width * size.height > wallpaperLimits.sourcePixels) {
    throw new Error("Image must fit within 20,000 pixels per edge and 100 megapixels.");
  }
}

export function fitWallpaperSize(size: PixelSize, maximumEdge: number): PixelSize {
  validateWallpaperSize(size);
  if (!positiveInteger(maximumEdge) || maximumEdge > wallpaperLimits.workingEdge) {
    throw new Error("Invalid wallpaper output size.");
  }
  const scale = Math.min(1, maximumEdge / Math.max(size.width, size.height));
  return { width: Math.max(1, Math.round(size.width * scale)), height: Math.max(1, Math.round(size.height * scale)) };
}

export function validateWallpaperCrop(crop: WallpaperCrop, image: PixelSize): void {
  validateWallpaperSize(image);
  if (![crop.x, crop.y].every((value) => Number.isSafeInteger(value) && value >= 0)
    || !positiveInteger(crop.width) || !positiveInteger(crop.height)
    || crop.width > image.width || crop.height > image.height
    || crop.x > image.width - crop.width || crop.y > image.height - crop.height) {
    throw new Error("The crop must stay inside the image using whole pixel coordinates.");
  }
}

/** These are starting shapes, matching the native wizard, not device placement guarantees. */
export function initialWallpaperCrop(family: WallpaperFamily, image: PixelSize): WallpaperCrop {
  validateWallpaperSize(image);
  const ratio = family === "small" ? 1 : family === "large" ? 0.95 : family === "extraLargePortrait" ? 0.7 : 2.14;
  let width = Math.max(1, Math.floor(image.width * (family === "small" ? 0.42 : 0.86)));
  let height = Math.max(1, Math.floor(width / ratio));
  if (height > image.height) {
    height = image.height;
    width = Math.max(1, Math.min(image.width, Math.floor(height * ratio)));
  }
  return { x: Math.floor((image.width - width) / 2), y: Math.floor((image.height - height) / 2), width, height };
}

/** Inspect encoded dimensions before browser decoding allocates an image surface.
 * PNG and JPEG only; other formats must not reach a decoder through this path.
 * This is allocation preflight, not a substitute for successful image decoding.
 */
export function inspectWallpaperImage(bytes: Uint8Array): PixelSize {
  if (bytes.length === 0 || bytes.length > wallpaperLimits.sourceBytes) throw new Error("Choose a PNG or JPEG no larger than 25 MiB.");
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  let size: PixelSize | undefined;
  if (bytes.length >= 33 && view.getUint32(0) === 0x89504e47 && view.getUint32(4) === 0x0d0a1a0a
    && view.getUint32(8) === 13 && view.getUint32(12) === 0x49484452) {
    size = { width: view.getUint32(16), height: view.getUint32(20) };
  } else if (bytes.length >= 4 && bytes[0] === 0xff && bytes[1] === 0xd8) {
    let offset = 2;
    while (offset < bytes.length) {
      if (bytes[offset++] !== 0xff) break;
      while (offset < bytes.length && bytes[offset] === 0xff) offset++;
      const marker = bytes[offset++];
      if (marker === undefined || marker === 0xda || marker === 0xd9) break;
      if (marker === 0x01 || (marker >= 0xd0 && marker <= 0xd7)) continue;
      if (offset + 2 > bytes.length) break;
      const length = view.getUint16(offset);
      if (length < 2 || offset + length > bytes.length) break;
      if ([0xc0, 0xc1, 0xc2, 0xc3, 0xc5, 0xc6, 0xc7, 0xc9, 0xca, 0xcb, 0xcd, 0xce, 0xcf].includes(marker)) {
        if (length < 8) break;
        size = { width: view.getUint16(offset + 5), height: view.getUint16(offset + 3) };
        break;
      }
      offset += length;
    }
  }
  if (!size) throw new Error("Cannot read PNG or JPEG image dimensions.");
  validateWallpaperSize(size);
  return size;
}

export interface PreparedWallpaper extends PixelSize {
  /** In-memory, oriented and downsampled surface. Never add this source to a package. */
  canvas: HTMLCanvasElement;
}

function canvasSurface(size: PixelSize): { canvas: HTMLCanvasElement; context: CanvasRenderingContext2D } {
  const canvas = document.createElement("canvas");
  canvas.width = size.width;
  canvas.height = size.height;
  const context = canvas.getContext("2d", { colorSpace: "srgb" });
  if (!context) throw new Error("Image processing is unavailable in this browser.");
  return { canvas, context };
}

/** The caller must discard a late result when its project/session has changed. */
export async function prepareWallpaper(file: Blob): Promise<PreparedWallpaper> {
  if (file.size === 0 || file.size > wallpaperLimits.sourceBytes) throw new Error("Choose a PNG or JPEG no larger than 25 MiB.");
  const bytes = new Uint8Array(await file.arrayBuffer());
  const encodedSize = inspectWallpaperImage(bytes);
  // Ignore the supplied filename and MIME type. Decode only the inspected bytes.
  const type = bytes[0] === 0x89 ? "image/png" : "image/jpeg";
  const bitmap = await createImageBitmap(new Blob([bytes], { type }), { imageOrientation: "from-image" });
  try {
    validateWallpaperSize(bitmap);
    // EXIF orientation may exchange the axes; every other dimensional change is invalid.
    if (!((bitmap.width === encodedSize.width && bitmap.height === encodedSize.height)
      || (bitmap.width === encodedSize.height && bitmap.height === encodedSize.width))) {
      throw new Error("Decoded image dimensions do not match the file header.");
    }
    const size = fitWallpaperSize(bitmap, wallpaperLimits.workingEdge);
    const { canvas, context } = canvasSurface(size);
    context.imageSmoothingEnabled = true;
    context.imageSmoothingQuality = "high";
    context.drawImage(bitmap, 0, 0, size.width, size.height);
    return { ...size, canvas };
  } finally {
    bitmap.close();
  }
}

/** Canvas encoding creates a fresh sRGB PNG without source EXIF or filename metadata. */
export async function exportWallpaperCrop(image: PreparedWallpaper, crop: WallpaperCrop): Promise<Blob> {
  if (image.canvas.width !== image.width || image.canvas.height !== image.height
    || Math.max(image.width, image.height) > wallpaperLimits.workingEdge) {
    throw new Error("The prepared image has changed. Import it again.");
  }
  validateWallpaperCrop(crop, image);
  const size = fitWallpaperSize(crop, wallpaperLimits.cropEdge);
  const { canvas, context } = canvasSurface(size);
  context.imageSmoothingEnabled = true;
  context.imageSmoothingQuality = "high";
  context.drawImage(image.canvas, crop.x, crop.y, crop.width, crop.height, 0, 0, size.width, size.height);
  return new Promise((resolve, reject) => {
    canvas.toBlob((blob) => blob ? resolve(blob) : reject(new Error("Could not export the cropped PNG.")), "image/png");
  });
}
