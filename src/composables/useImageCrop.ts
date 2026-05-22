/**
 * Lightweight canvas-based image cropper.
 *
 * Pure-JS — no canvas DOM management. The caller controls the source image
 * (loaded as HTMLImageElement) and the visible crop frame size. This module
 * provides:
 *   - The math for fitting the image inside the crop frame
 *   - Drag offset tracking
 *   - A `renderCrop()` function that produces a Blob of the cropped region
 */

export interface AspectRatio {
  id: string;
  label: string;
  /** ratio = width / height. `null` means free / no constraint. */
  ratio: number | null;
}

export const ASPECT_RATIOS: AspectRatio[] = [
  { id: 'free', label: 'Free', ratio: null },
  { id: '1:1', label: '1:1', ratio: 1 },
  { id: '4:5', label: '4:5', ratio: 4 / 5 },
  { id: '9:16', label: '9:16', ratio: 9 / 16 },
  { id: '16:9', label: '16:9', ratio: 16 / 9 },
];

export const ZOOM_MIN = 1;
export const ZOOM_MAX = 3;

export interface FitResult {
  /** Display size of the image on screen (CSS pixels) */
  displayWidth: number;
  displayHeight: number;
  /** Min translation (most negative) the image can be moved to before exposing edge */
  minTx: number;
  minTy: number;
  maxTx: number;
  maxTy: number;
}

/**
 * Cover-fit the source image to the crop frame so it always fills the frame
 * regardless of orientation. Returns the display dimensions and clamping bounds
 * for translation (drag).
 */
export function computeCoverFit(
  imgW: number,
  imgH: number,
  frameW: number,
  frameH: number
): FitResult {
  const scale = Math.max(frameW / imgW, frameH / imgH);
  const displayWidth = imgW * scale;
  const displayHeight = imgH * scale;

  const overflowX = displayWidth - frameW;
  const overflowY = displayHeight - frameH;

  return {
    displayWidth,
    displayHeight,
    minTx: -overflowX,
    minTy: -overflowY,
    maxTx: 0,
    maxTy: 0,
  };
}

export function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

export interface CropRenderOptions {
  /** Source image (already loaded) */
  image: HTMLImageElement;
  /** Crop frame dimensions in display (CSS) pixels */
  frameWidth: number;
  frameHeight: number;
  /** Display dimensions of the image (after cover-fit) */
  displayWidth: number;
  displayHeight: number;
  /** Current translation of the image inside the frame (CSS pixels) */
  translateX: number;
  translateY: number;
  /** Output dimensions in image pixels — pick a sensible cap for upload */
  outputMaxWidth?: number;
  outputType?: 'image/webp' | 'image/jpeg';
  outputQuality?: number;
}

/**
 * Render the visible crop region to a Blob.
 * Computes the source rectangle in original image coordinates, then drawImage
 * to an offscreen canvas at the desired output resolution.
 */
export async function renderCrop(opts: CropRenderOptions): Promise<Blob> {
  const {
    image,
    frameWidth,
    frameHeight,
    displayWidth,
    displayHeight,
    translateX,
    translateY,
    outputMaxWidth = 1080,
    outputType = 'image/webp',
    outputQuality = 0.9,
  } = opts;

  const imgW = image.naturalWidth;
  const imgH = image.naturalHeight;

  // Pixel ratio between source image and on-screen display.
  const pxPerCssX = imgW / displayWidth;
  const pxPerCssY = imgH / displayHeight;

  // Source rect (in image pixels)
  const sourceX = -translateX * pxPerCssX;
  const sourceY = -translateY * pxPerCssY;
  const sourceWidth = frameWidth * pxPerCssX;
  const sourceHeight = frameHeight * pxPerCssY;

  // Output size — keep aspect, cap longer side at outputMaxWidth.
  const aspect = frameWidth / frameHeight;
  let outW: number;
  let outH: number;
  if (aspect >= 1) {
    outW = Math.min(outputMaxWidth, sourceWidth);
    outH = Math.round(outW / aspect);
  } else {
    outH = Math.min(outputMaxWidth, sourceHeight);
    outW = Math.round(outH * aspect);
  }

  const canvas = document.createElement('canvas');
  canvas.width = outW;
  canvas.height = outH;
  const ctx = canvas.getContext('2d');
  if (!ctx) throw new Error('Canvas 2D context unavailable');

  ctx.drawImage(
    image,
    sourceX,
    sourceY,
    sourceWidth,
    sourceHeight,
    0,
    0,
    outW,
    outH
  );

  return await new Promise<Blob>((resolve, reject) => {
    canvas.toBlob(
      (blob) => {
        if (blob) resolve(blob);
        else reject(new Error('Failed to encode image'));
      },
      outputType,
      outputQuality
    );
  });
}

export function blobToDataUrl(blob: Blob): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result as string);
    reader.onerror = () => reject(reader.error ?? new Error('FileReader failed'));
    reader.readAsDataURL(blob);
  });
}

export function fileToImage(file: File): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const img = new Image();
    img.onload = () => {
      // Caller owns the lifetime of img.src — do NOT revoke here, or any
      // later use of img.src (CSS background-image, another <img> binding,
      // re-decode) fails with ERR_FILE_NOT_FOUND.
      resolve(img);
    };
    img.onerror = (err) => {
      // Load failed: caller never sees the URL, so revoke here to avoid leak.
      URL.revokeObjectURL(url);
      reject(err instanceof Error ? err : new Error('Image load failed'));
    };
    img.src = url;
  });
}
