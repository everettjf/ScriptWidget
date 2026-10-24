export const runtimeContract: Readonly<{
  nativeAPIVersion: string; nativeCompilerFingerprint: string;
  apiVersion: string; compilerFingerprint: string;
  maximumSourceBytes: number; maximumTranspiledBytes: number;
  executionTimeoutMilliseconds: number; maximumElementNodes: number;
  maximumMaterialBackgrounds: number; maximumElementDepth: number;
  maximumPropsPerElement: number; maximumDataQueries: number;
  globalAPIs: readonly string[];
}>;
export const engineVersion: string;
export const errorCategories: Readonly<Record<string, Readonly<{category: string; recovery: string}>>>;
export function makeError(kind: string, message: string): {kind: string; message: string; category: string; recovery: string; diagnostic: string};
export function wrappedSource(source: string, callFunction?: string): string;
export function utf8ByteLength(value: string): number;
export function validateByteCount(value: string, maximum: number, label: string): ReturnType<typeof makeError> | null;
export function inferredLibraries(source: string): string[];
