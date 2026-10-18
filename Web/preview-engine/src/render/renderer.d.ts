import type { Appearance, Issue, RenderingMode, WidgetSize } from "../types.js";

export interface RenderedWidget {
  element: HTMLElement;
  size: { width: number; height: number };
  diagnostics: Issue[];
}

export function renderWidget(treeJSON: string, options?: {
  family?: WidgetSize;
  profile?: string;
  appearance?: Appearance;
  renderingMode?: RenderingMode;
  lockScreen?: boolean;
  resources?: Record<string, string>;
  document?: Document;
}): Promise<RenderedWidget>;

export function lineHeight(size: number): number;
