export type WidgetThemeTokens = Record<string, string | number>;
export interface WidgetThemeModel { source: string; tokens: WidgetThemeTokens | null; ranges: Record<string, {from: number; to: number}>; issue: string; canInitialize: boolean }
export const widgetThemeFields: Readonly<Record<string, {type?: string; maximum?: number; values?: string[]}>>;
export const widgetThemePresets: Readonly<Record<string, WidgetThemeTokens>>;
export function parseWidgetTheme(source: string): WidgetThemeModel;
export function importWidgetTheme(json: string): {formatVersion: 1; name: string; tokens: WidgetThemeTokens};
export function exportWidgetTheme(tokens: WidgetThemeTokens, name?: string): string;
export function editWidgetTheme(model: WidgetThemeModel, source: string, tokens: WidgetThemeTokens): {changes: {from: number; to: number; insert: string}[]};
export function initializeWidgetTheme(source: string, preset?: string): {changes: {from: number; to: number; insert: string}[]};
