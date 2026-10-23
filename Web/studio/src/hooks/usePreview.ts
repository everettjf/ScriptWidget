import { useEffect, useRef, useState } from "react";
import { renderWidget } from "../../../preview-engine/src/render/renderer.js";
import type { Appearance, RenderingMode, Severity, WidgetSize } from "../../../preview-engine/src/types.js";
import { packageReport, resourceURLs, executionFiles, type Project } from "@/project.ts";
import { parseMocks } from "@/mockData.ts";
import { timelinePreview } from "@/timelinePreview.ts";
import { sandbox } from "@/runtime.ts";

export interface PreviewSettings {
  profile: string;
  family: WidgetSize;
  appearance: Appearance;
  renderingMode: RenderingMode;
  parameter: string;
  timelineDate: string;
  reduceTransparency: boolean;
  reduceMotion: boolean;
}

export interface Message {
  severity: Severity;
  text: string;
  detail?: string;
}

export type PreviewOutput =
  | { kind: "starting" }
  | { kind: "unavailable"; message: string }
  | { kind: "widget"; element: HTMLElement; width: number; height: number; milliseconds: number }
  | { kind: "error"; errorKind: string; message: string };

export interface PreviewState {
  output: PreviewOutput;
  problems: Message[];
  logs: Message[];
}

/// Runs the project in the sandbox and renders it whenever files, fixtures,
/// or preview settings change. Results from superseded runs are dropped.
export function usePreview(project: Project | null, settings: PreviewSettings): PreviewState {
  const [state, setState] = useState<PreviewState>({ output: { kind: "starting" }, problems: [], logs: [] });
  const [ready, setReady] = useState(false);
  const generation = useRef(0);

  useEffect(() => {
    sandbox.ready.then(() => setReady(true), (error: Error) => {
      setState((current) => ({ ...current, output: { kind: "unavailable", message: error.message } }));
    });
  }, []);

  const files = project?.files;
  const fixtures = project?.fixtures;
  const { profile, family, appearance, renderingMode, parameter, timelineDate, reduceTransparency, reduceMotion } = settings;

  useEffect(() => {
    if (!ready || !files) return;
    const current = ++generation.current;
    const timer = setTimeout(async () => {
      const started = performance.now();
      const report = packageReport({ files });
      const problems: Message[] = report.issues.map((issue) => ({ severity: issue.severity, text: issue.message }));
      let fixtureData: unknown = {};
      try { fixtureData = parseMocks(fixtures || "{}"); } catch (error) { problems.push({ severity: "warning", text: `Fixtures are not valid JSON: ${(error as Error).message}` }); }
      let timelineEnvironment: Record<string, string> = {};
      try { timelineEnvironment = timelinePreview(report.manifest, timelineDate).environments; }
      catch (error) { problems.push({ severity: "error", text: `Timeline: ${(error as Error).message}` }); }
      const result = await sandbox.execute({
        files: executionFiles(files),
        entry: report.manifest?.entry ?? "main.jsx",
        manifest: report.manifest,
        environments: { "widget-size": family, "widget-param": parameter, "widget-rendering-mode": renderingMode, ...timelineEnvironment },
        preview: { appearance },
        fixtures: fixtureData,
      });
      if (current !== generation.current) return;
      const logs: Message[] = result.logs.map((log) => ({ severity: log.level === "error" ? "error" : "info", text: log.message }));
      for (const item of result.diagnostics) problems.push({ severity: item.severity, text: item.message });
      if (result.error || result.tree === null) {
        const error = result.error ?? { kind: "internalError", message: "The runtime returned no tree." };
        problems.unshift({ severity: "error", text: `The widget failed to run (${error.kind}).`, detail: error.message });
        setState({ output: { kind: "error", errorKind: error.kind, message: error.message }, problems, logs });
        return;
      }
      const rendered = await renderWidget(result.tree, { family, profile, appearance, renderingMode, reduceTransparency, reduceMotion, resources: resourceURLs(files) });
      if (current !== generation.current) return;
      for (const item of rendered.diagnostics) problems.push({ severity: item.severity, text: item.message });
      setState({
        output: { kind: "widget", element: rendered.element, width: rendered.size.width, height: rendered.size.height, milliseconds: Math.round(performance.now() - started) },
        problems, logs,
      });
    }, 200);
    return () => clearTimeout(timer);
  }, [ready, files, fixtures, profile, family, appearance, renderingMode, parameter, timelineDate, reduceTransparency, reduceMotion]);

  return state;
}
