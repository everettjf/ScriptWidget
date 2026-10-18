import type { Completion, CompletionContext, CompletionResult } from "@codemirror/autocomplete";

export const scriptWidgetAPI: { components: Record<string, unknown>; [key: string]: unknown };
export const scriptWidgetCompletionOptions: Completion[];
export function scriptWidgetCompletions(context: CompletionContext): CompletionResult | null;
