export interface VisualLayoutPropertyDefinition { type: string; values?: string[]; required?: boolean }
export interface VisualLayoutProperty { name: string; value: string | number | boolean | null; from: number; to: number; editable: boolean; definition: VisualLayoutPropertyDefinition | null }
export interface VisualLayoutNode {
  id: string; parentID: string | null; tag: string; component: string | null; from: number; to: number;
  openingEnd: number; insertAt: number; contentFrom: number; contentTo: number; children: string[];
  properties: VisualLayoutProperty[]; locked: boolean; structure: boolean; text: string | null; textEditable: boolean; depth: number; reason: string;
}
export interface VisualLayoutModel { formatVersion: 1; source: string; nodes: VisualLayoutNode[]; roots: string[]; issue: string }
export type VisualLayoutOperation =
  | {type: "property"; id: string; name: string; value?: string | number | boolean; remove?: boolean}
  | {type: "text"; id: string; value: string}
  | {type: "move"; id: string; parentID: string; index: number}
  | {type: "remove"; id: string}
  | {type: "add"; id: string; kind: "text" | "spacer" | "stack" | "icon"};
export function parseVisualLayout(source: string): VisualLayoutModel;
export function visualPropertyDefinitions(node: VisualLayoutNode): Record<string, VisualLayoutPropertyDefinition>;
export function editVisualLayout(model: VisualLayoutModel, source: string, operation: VisualLayoutOperation): {changes: {from: number; to: number; insert: string}[]; selectedFrom: number};
