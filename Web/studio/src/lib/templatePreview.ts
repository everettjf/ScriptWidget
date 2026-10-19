// Renders a template's widget for the gallery: the same sandbox and
// renderer as the editor preview, at a chosen size. Runs are queued so a
// grid of cards does not start dozens of executions at once.
import { renderWidget } from "../../../preview-engine/src/render/renderer.js";
import type { Appearance, WidgetSize } from "../../../preview-engine/src/types.js";
import { packageReport, projectFromTemplate, resourceURLs, textFiles, type Template } from "@/project.ts";
import { sandbox } from "@/runtime.ts";

export type TemplatePreview =
  | { kind: "widget"; element: HTMLElement; width: number; height: number }
  | { kind: "error"; message: string };

const concurrency = 2;
let running = 0;
const waiting: Array<() => void> = [];

async function slot<T>(work: () => Promise<T>): Promise<T> {
  if (running >= concurrency) await new Promise<void>((resolve) => waiting.push(resolve));
  running += 1;
  try { return await work(); } finally {
    running -= 1;
    waiting.shift()?.();
  }
}

/// Files as Studio opens them: legacy templates get a generated widget.json.
const packages = new Map<string, ReturnType<typeof projectFromTemplate>["files"]>();
export function templateFiles(template: Template) {
  let files = packages.get(template.id);
  if (!files) {
    files = projectFromTemplate(template).files;
    packages.set(template.id, files);
  }
  return files;
}

export function renderTemplate(template: Template, family: WidgetSize, options: { profile?: string; appearance?: Appearance } = {}): Promise<TemplatePreview> {
  const { profile = "iphone-393", appearance = "light" } = options;
  return slot(async () => {
    await sandbox.ready;
    const files = templateFiles(template);
    const report = packageReport({ files });
    const result = await sandbox.execute({
      files: textFiles(files),
      entry: report.manifest?.entry ?? "main.jsx",
      manifest: report.manifest,
      environments: { "widget-size": family, "widget-param": "", "widget-rendering-mode": "fullColor" },
      preview: { appearance },
      fixtures: {},
    });
    if (result.error || result.tree === null) return { kind: "error", message: result.error?.message ?? "The widget did not render." };
    const rendered = await renderWidget(result.tree, { family, profile, appearance, renderingMode: "fullColor", resources: resourceURLs(files) });
    return { kind: "widget", element: rendered.element, width: rendered.size.width, height: rendered.size.height };
  });
}
