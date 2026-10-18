import type { Diagnostic } from "@codemirror/lint";
import type { EditorState } from "@codemirror/state";
import type { EditorView, Tooltip } from "@codemirror/view";

export function scriptWidgetDiagnostics(view: EditorView): Diagnostic[];
export function scriptWidgetHover(view: EditorView, position: number): Tooltip | null;
export function openingTags(state: EditorState): Array<{ name: string; from: number; to: number; [key: string]: unknown }>;
