export const archivePolicy: Readonly<{
  maximumArchiveBytes: number;
  maximumExpandedBytes: number;
  maximumFileBytes: number;
  maximumFileCount: number;
  maximumPathDepth: number;
}>;
export function preflightArchive(bytes: Uint8Array): { error: string } | { entries: Array<{ name: string; compressed: number; uncompressed: number }>; error?: undefined };
export function readArchive(bytes: Uint8Array, options?: { inflate?: (bytes: Uint8Array) => Promise<Uint8Array> }): Promise<{ error: string } | { files: Record<string, Uint8Array>; rootName: string | null; error?: undefined }>;
export function crc32(bytes: Uint8Array): number;
export function packageDirectoryName(name: string): string;
export function writeArchive(rootName: string, files: Record<string, string | Uint8Array>, options?: { date?: Date }): Uint8Array;
