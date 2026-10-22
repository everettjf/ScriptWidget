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
  /// A fixed clock for absolute <date> styles and clock animation poses, in milliseconds since 1970.
  now?: number | null;
  /// "live" animates with CSS; "firstFrame" draws what ImageRenderer captures.
  animations?: "live" | "firstFrame";
  /// Display-only fixed elapsed seconds for deterministic swing poses.
  animationElapsed?: number | null;
  reduceTransparency?: boolean;
  reduceMotion?: boolean;
}): Promise<RenderedWidget>;

export function lineHeight(size: number): number;
