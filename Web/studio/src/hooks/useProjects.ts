import { useCallback, useEffect, useRef, useState } from "react";
import { createProject, initialPath, packageReport, type Project } from "@/project.ts";
import { preferences, storage } from "@/store.ts";
import type { PackageFiles } from "../../../preview-engine/src/types.js";

export type SaveState = "idle" | "editing" | "saved" | "unavailable";

export interface ProjectsModel {
  projects: Project[];
  project: Project | null;
  path: string;
  saveState: SaveState;
  openProject(project: Project): void;
  addProject(project: Project): Promise<void>;
  removeProject(id: string): Promise<void>;
  openFile(path: string): void;
  /// Replaces files; null removes a path.
  updateFiles(changes: Record<string, string | Uint8Array | null>): void;
  updateProjectFiles(id: string, expectedFiles: PackageFiles, changes: Record<string, string | Uint8Array | null>): boolean;
  rename(name: string): void;
  setFixtures(text: string): void;
}

const byRecent = (a: Project, b: Project) => b.updatedAt - a.updatedAt;

/// Projects stored in this browser and the one being edited. Edits are saved
/// 400 ms after the last change and when the page is hidden.
export function useProjects(): ProjectsModel {
  const [projects, setProjects] = useState<Project[]>([]);
  const [project, setProject] = useState<Project | null>(null);
  const [path, setPath] = useState("main.jsx");
  const [saveState, setSaveState] = useState<SaveState>("idle");
  const dirty = useRef(false);
  const latest = useRef<Project | null>(null);
  latest.current = project;

  const openProject = useCallback((next: Project) => {
    dirty.current = false;
    latest.current = next;
    preferences.write("project", next.id);
    setProject(next);
    setPath(initialPath(next));
  }, []);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      let list = (await storage.list()).sort(byRecent);
      if (list.length === 0) {
        const starter = createProject("My First Widget");
        await storage.save(starter);
        list = [starter];
      }
      if (cancelled) return;
      setProjects(list);
      const lastID = preferences.read<string | null>("project", null);
      openProject(list.find((item) => item.id === lastID) ?? list[0]!);
      if (!storage.persistent) setSaveState("unavailable");
    })();
    return () => { cancelled = true; };
  }, [openProject]);

  // Debounced save of the edited project.
  useEffect(() => {
    if (!project || !dirty.current) return;
    setSaveState("editing");
    const timer = setTimeout(async () => {
      const saved = await storage.save(project);
      dirty.current = false;
      setProjects((list) => list.map((item) => (item.id === saved.id ? saved : item)));
      setSaveState(storage.persistent ? "saved" : "unavailable");
    }, 400);
    return () => clearTimeout(timer);
  }, [project]);

  useEffect(() => {
    const flush = () => { if (dirty.current && latest.current) void storage.save(latest.current); };
    const onVisibility = () => { if (document.visibilityState === "hidden") flush(); };
    window.addEventListener("beforeunload", flush);
    document.addEventListener("visibilitychange", onVisibility);
    return () => { window.removeEventListener("beforeunload", flush); document.removeEventListener("visibilitychange", onVisibility); };
  }, []);

  const edit = useCallback((change: (current: Project) => Project) => {
    const current = latest.current;
    if (!current) return;
    dirty.current = true;
    const next = change(current);
    latest.current = next;
    setProject(next);
  }, []);

  const addProject = useCallback(async (next: Project) => {
    await storage.save(next);
    setProjects((list) => [next, ...list.filter((item) => item.id !== next.id)]);
    openProject(next);
  }, [openProject]);

  const removeProject = useCallback(async (id: string) => {
    await storage.remove(id);
    let remaining = projects.filter((item) => item.id !== id);
    if (remaining.length === 0) {
      const fresh = createProject();
      await storage.save(fresh);
      remaining = [fresh];
    }
    setProjects(remaining);
    if (latest.current?.id === id) openProject(remaining[0]!);
  }, [projects, openProject]);

  const updateFiles = useCallback((changes: Record<string, string | Uint8Array | null>) => {
    edit((current) => {
      const files: PackageFiles = { ...current.files };
      for (const [name, value] of Object.entries(changes)) {
        if (value === null) delete files[name]; else files[name] = value;
      }
      return { ...current, files };
    });
  }, [edit]);

  // Async authoring dialogs must commit to the same project and file snapshot
  // they reviewed, never to whichever project happens to be open later.
  const updateProjectFiles = useCallback((id: string, expectedFiles: PackageFiles, changes: Record<string, string | Uint8Array | null>) => {
    const current = latest.current;
    if (!current || current.id !== id || current.files !== expectedFiles) return false;
    updateFiles(changes);
    return true;
  }, [updateFiles]);

  const rename = useCallback((input: string) => {
    const name = input.trim() || "My Widget";
    edit((current) => {
      const report = packageReport(current);
      if (!report.manifest) return { ...current, name };
      const manifest = { ...report.manifest, name: name.slice(0, 80) };
      return { ...current, name, files: { ...current.files, "widget.json": `${JSON.stringify(manifest, null, 2)}\n` } };
    });
  }, [edit]);

  const setFixtures = useCallback((fixtures: string) => edit((current) => ({ ...current, fixtures })), [edit]);

  return { projects, project, path, saveState, openProject, addProject, removeProject, openFile: setPath, updateFiles, updateProjectFiles, rename, setFixtures };
}
