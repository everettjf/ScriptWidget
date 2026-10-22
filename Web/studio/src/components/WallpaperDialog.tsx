import { useEffect, useRef, useState } from "react";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { downloadBytes } from "@/lib/download.ts";
import type { Project } from "@/project.ts";
import { defaultWallpaperConfiguration, readWallpaperConfiguration, serializeWallpaperConfiguration, wallpaperConfigurationPath, wallpaperFamilies, wallpaperImagePattern, type WallpaperConfiguration } from "@/wallpaperConfiguration.ts";
import { exportWallpaperCrop, fitWallpaperSize, initialWallpaperCrop, prepareWallpaper, validateWallpaperCrop, type PreparedWallpaper, type WallpaperCrop, type WallpaperFamily } from "@/wallpaperCrop.ts";

type Changes = Record<string, string | Uint8Array | null>;
const titles = { small: "Small", medium: "Medium", large: "Large", extraLarge: "Extra large", extraLargePortrait: "Extra large portrait" };
const selectClass = "h-9 w-full rounded-md border bg-background px-2 text-sm";

function initialConfiguration(project: Project) {
  try { return { values: readWallpaperConfiguration(project.files), error: null }; }
  catch (error) { return { values: defaultWallpaperConfiguration(), error: (error as Error).message }; }
}

/** Mounted afresh for each project/session; imported screenshots stay in memory. */
export function WallpaperDialog({ project: currentProject, onClose, onSave }: {
  project: Project; onClose(): void; onSave(changes: Changes, expected: Project): boolean;
}) {
  const [project] = useState(currentProject);
  const [initial] = useState(() => initialConfiguration(project));
  const [values, setValues] = useState(initial.values);
  const [loadError, setLoadError] = useState(initial.error);
  const [changes, setChanges] = useState<Changes>({});
  const [image, setImage] = useState<PreparedWallpaper | null>(null);
  const [crop, setCrop] = useState<WallpaperCrop | null>(null);
  const [family, setFamily] = useState<WallpaperFamily>("medium");
  const [appearance, setAppearance] = useState<"light" | "dark">("light");
  const [label, setLabel] = useState("Top left");
  const [busy, setBusy] = useState(false);
  const [problem, setProblem] = useState<string | null>(null);
  const generation = useRef(0);
  const alive = useRef(false);
  const input = useRef<HTMLInputElement>(null);
  const surface = useRef<HTMLCanvasElement>(null);
  const preview = useRef<HTMLCanvasElement>(null);
  const bounds = useRef<HTMLDivElement>(null);
  const drag = useRef<{ pointer: number; x: number; y: number; crop: WallpaperCrop } | null>(null);
  useEffect(() => { alive.current = true; return () => { alive.current = false; generation.current++; }; }, []);

  const files = { ...project.files };
  for (const [path, content] of Object.entries(changes)) { if (content === null) delete files[path]; else files[path] = content; }
  const resources = Object.keys(files).filter((path) => wallpaperImagePattern.test(path)).sort();
  const protectedImages = new Set([...initial.values.backgrounds, ...values.backgrounds].map((item) => `image/${item.image}.png`));
  const portableSource = typeof files["main.jsx"] === "string" && files["main.jsx"].includes("wallpaperConfiguration.load()");
  let validCrop = false;
  try { if (image && crop) { validateWallpaperCrop(crop, image); validCrop = true; } } catch { /* Numeric fields can temporarily be incomplete. */ }

  useEffect(() => {
    if (!image || !surface.current) return;
    const canvas = surface.current; canvas.width = image.width; canvas.height = image.height;
    canvas.getContext("2d")?.drawImage(image.canvas, 0, 0);
  }, [image]);
  useEffect(() => {
    if (!image || !crop || !preview.current || !validCrop) return;
    const size = fitWallpaperSize(crop, 300), canvas = preview.current;
    canvas.width = size.width; canvas.height = size.height;
    canvas.getContext("2d")?.drawImage(image.canvas, crop.x, crop.y, crop.width, crop.height, 0, 0, size.width, size.height);
  }, [image, crop, validCrop]);

  const importImage = async (file: File) => {
    const token = ++generation.current;
    setBusy(true); setProblem(null);
    try {
      const prepared = await prepareWallpaper(file);
      if (!alive.current || generation.current !== token) return;
      setImage(prepared); setCrop(initialWallpaperCrop(family, prepared));
    } catch (error) { if (alive.current && generation.current === token) setProblem((error as Error).message); }
    finally { if (alive.current && generation.current === token) setBusy(false); }
  };
  const processCrop = async (add: boolean) => {
    if (!image || !crop || busy || !validCrop) return;
    const token = ++generation.current;
    setBusy(true); setProblem(null);
    try {
      if (add && resources.length >= 12) throw new Error("Keep at most 12 crop files. Save your selections, reopen this tool and delete unused crops.");
      // Validate the complete next selection before allocating or encoding a crop.
      const name = `background-${crypto.randomUUID().toLowerCase()}`;
      const next: WallpaperConfiguration = { ...values, backgrounds: [...values.backgrounds.filter((item) => item.family !== family || item.appearance !== appearance), { family, appearance, label, image: name }] };
      if (add) serializeWallpaperConfiguration(next);
      const bytes = new Uint8Array(await (await exportWallpaperCrop(image, crop)).arrayBuffer());
      if (!alive.current || generation.current !== token) return;
      if (add) {
        if (Object.keys(files).some((path) => path.toLowerCase() === `image/${name}.png`)) throw new Error("A crop filename collided. Try again.");
        setChanges((current) => ({ ...current, [`image/${name}.png`]: bytes })); setValues(next);
      } else downloadBytes(bytes, "wallpaper-crop.png", "image/png");
    } catch (error) { if (alive.current && generation.current === token) setProblem((error as Error).message); }
    finally { if (alive.current && generation.current === token) setBusy(false); }
  };
  const save = () => {
    try {
      const raw = serializeWallpaperConfiguration(values);
      if (!onSave({ ...changes, [wallpaperConfigurationPath]: raw }, project)) throw new Error("This project changed while the tool was open. Close and reopen it before saving.");
      onClose();
    } catch (error) { setProblem((error as Error).message); }
  };
  const field = (key: "title" | "caption", limit: number) => <div className="grid gap-1"><Label htmlFor={`wallpaper-${key}`}>{key === "title" ? "Title" : "Caption"}</Label><Input id={`wallpaper-${key}`} disabled={busy} value={values[key]} maxLength={limit} onChange={(event) => setValues({ ...values, [key]: event.target.value })} /></div>;
  return <Dialog open onOpenChange={(open) => { if (!open) { generation.current++; onClose(); } }}>
    <DialogContent id="wallpaper-dialog" className="max-h-[90dvh] overflow-y-auto sm:max-w-3xl" onDragOver={(event) => event.stopPropagation()} onDrop={(event) => { event.preventDefault(); event.stopPropagation(); }}>
      <DialogHeader><DialogTitle>Match your wallpaper</DialogTitle><DialogDescription>Choose your own wallpaper or empty Home Screen screenshot. Calibrate each size and appearance; placement is manual.</DialogDescription></DialogHeader>
      {!portableSource && <p role="alert" className="text-sm text-destructive">This copy predates portable wallpaper settings. Create a fresh Wallpaper Match template to save settings from Web Studio. You can still export a crop PNG.</p>}
      {loadError && <div role="alert" className="grid gap-2 text-sm text-destructive"><p>{loadError} Existing settings are preserved until you explicitly replace them.</p><Button variant="outline" onClick={() => { setValues(defaultWallpaperConfiguration()); setLoadError(null); }}>Replace invalid settings with a new draft</Button></div>}
      <div className="grid gap-4 sm:grid-cols-2">
        <div className="grid content-start gap-3">
          <Button id="wallpaper-import" variant="outline" disabled={busy} onClick={() => input.current?.click()}>Choose PNG or JPEG…</Button>
          <input id="wallpaper-image-input" ref={input} hidden type="file" accept="image/png,image/jpeg" onChange={(event) => { const file = event.target.files?.[0]; event.target.value = ""; if (file) void importImage(file); }} />
          <p className="text-xs text-muted-foreground">Up to 25 MiB. The original stays in this session; only cropped PNGs enter the package.</p>
          <div className="grid grid-cols-2 gap-2">
            <div className="grid gap-1"><Label htmlFor="wallpaper-family">Widget size</Label><select id="wallpaper-family" className={selectClass} disabled={busy} value={family} onChange={(event) => { const next = event.target.value as WallpaperFamily; setFamily(next); if (image) setCrop(initialWallpaperCrop(next, image)); }}>{wallpaperFamilies.map((item) => <option key={item} value={item}>{titles[item]}</option>)}</select></div>
            <div className="grid gap-1"><Label htmlFor="wallpaper-appearance">Appearance</Label><select id="wallpaper-appearance" className={selectClass} disabled={busy} value={appearance} onChange={(event) => setAppearance(event.target.value as "light" | "dark")}><option value="light">Light</option><option value="dark">Dark</option></select></div>
          </div>
          {image && crop && <>
            <div ref={bounds} className="relative w-fit max-w-full self-center overflow-hidden rounded-md bg-muted">
              <canvas ref={surface} className="block h-auto max-h-72 max-w-full" aria-label="Imported reference image" />
              {validCrop && <div id="wallpaper-selection" role="img" aria-label="Crop selection; drag to reposition, or use exact pixel fields" className="absolute touch-none cursor-move border-2 border-white bg-white/10 outline outline-1 outline-black" style={{ left: `${100 * crop.x / image.width}%`, top: `${100 * crop.y / image.height}%`, width: `${100 * crop.width / image.width}%`, height: `${100 * crop.height / image.height}%` }}
                onPointerDown={(event) => { event.currentTarget.setPointerCapture(event.pointerId); drag.current = { pointer: event.pointerId, x: event.clientX, y: event.clientY, crop }; }}
                onPointerMove={(event) => {
                  const start = drag.current, rect = bounds.current?.getBoundingClientRect();
                  if (!start || start.pointer !== event.pointerId || !rect?.width || !rect.height || busy) return;
                  setCrop({ ...start.crop, x: Math.max(0, Math.min(image.width - start.crop.width, Math.round(start.crop.x + (event.clientX - start.x) * image.width / rect.width))), y: Math.max(0, Math.min(image.height - start.crop.height, Math.round(start.crop.y + (event.clientY - start.y) * image.height / rect.height))) });
                }} onPointerUp={() => { drag.current = null; }} onPointerCancel={() => { drag.current = null; }} />}
            </div>
            <p className="text-xs text-muted-foreground">Drag the outline. Presets are starting shapes, not device position measurements. Working image: {image.width} × {image.height}.</p>
            <div className="grid grid-cols-2 gap-2">{([['x', 'Left'], ['y', 'Top'], ['width', 'Width'], ['height', 'Height']] as const).map(([key, title]) => <div key={key} className="grid gap-1"><Label htmlFor={`wallpaper-${key}`}>{title} (px)</Label><Input id={`wallpaper-${key}`} type="number" step="1" min={key === "x" || key === "y" ? 0 : 1} disabled={busy} value={Number.isFinite(crop[key]) ? crop[key] : ""} onChange={(event) => setCrop({ ...crop, [key]: event.target.valueAsNumber })} /></div>)}</div>
            {!validCrop && <p className="text-xs text-destructive">Keep the whole crop within the working image.</p>}
          </>}
        </div>
        <div className="grid content-start gap-3">
          {field("title", 40)}{field("caption", 80)}
          <div className="grid grid-cols-2 gap-2">
            <div className="grid gap-1"><Label htmlFor="wallpaper-content">Content</Label><select id="wallpaper-content" disabled={busy} className={selectClass} value={values.content} onChange={(event) => setValues({ ...values, content: event.target.value as WallpaperConfiguration["content"] })}><option value="none">Background only</option><option value="text">Title and caption</option><option value="date">Date and text</option></select></div>
            <div className="grid gap-1"><Label htmlFor="wallpaper-ink">Text color</Label><select id="wallpaper-ink" disabled={busy} className={selectClass} value={values.ink} onChange={(event) => setValues({ ...values, ink: event.target.value as WallpaperConfiguration["ink"] })}><option value="adaptive">Adaptive</option><option value="light">Light</option><option value="dark">Dark</option></select></div>
          </div>
          <div className="grid gap-1"><Label htmlFor="wallpaper-label">Position label</Label><Input id="wallpaper-label" value={label} maxLength={30} disabled={busy} onChange={(event) => setLabel(event.target.value)} /></div>
          {image && crop && validCrop && <canvas ref={preview} id="wallpaper-crop-preview" aria-label="Selected crop preview" className="max-h-36 max-w-full rounded-md border" />}
          <div className="flex flex-wrap gap-2"><Button id="wallpaper-add-crop" disabled={busy || !validCrop || resources.length >= 12 || !!loadError} onClick={() => void processCrop(true)}>Add crop</Button><Button id="wallpaper-export-crop" variant="outline" disabled={busy || !validCrop} onClick={() => void processCrop(false)}>Export crop PNG</Button></div>
          <p className="text-xs text-muted-foreground">{resources.length}/12 crop files. Replacing a selection keeps the old image until settings are saved and the unused crop is explicitly deleted.</p>
        </div>
      </div>
      <section className="grid gap-2" aria-label="Saved crop selections"><h3 className="text-sm font-medium">Draft selections ({values.backgrounds.length}/10)</h3>
        {values.backgrounds.length === 0 && <p className="text-xs text-muted-foreground">Add a separate crop for each size and Light/Dark appearance you use.</p>}
        {values.backgrounds.map((item) => <div key={`${item.family}.${item.appearance}`} className="flex items-center justify-between gap-2 rounded-md border px-3 py-2 text-sm"><span>{titles[item.family]} · {item.appearance} · {item.label}{!files[`image/${item.image}.png`] && " — missing image"}</span><Button variant="ghost" size="sm" disabled={busy} onClick={() => setValues({ ...values, backgrounds: values.backgrounds.filter((other) => other !== item) })}>Remove selection</Button></div>)}
        {resources.filter((path) => !protectedImages.has(path)).map((path) => <div key={path} className="flex min-w-0 items-center justify-between gap-2 text-xs"><span className="truncate">Unused: {path}</span><Button variant="ghost" size="sm" disabled={busy} onClick={() => setChanges((current) => ({ ...current, [path]: null }))}>Delete unused crop</Button></div>)}
      </section>
      <p className="text-xs text-muted-foreground">Settings and crops travel with the exported widget package. Native saved settings and preview storage mocks take precedence. This tool does not change the system wallpaper.</p>
      {busy && <p role="status" className="text-sm">Processing image…</p>}
      {problem && <p id="wallpaper-problem" role="alert" className="text-sm text-destructive">{problem}</p>}
      <DialogFooter><Button variant="outline" onClick={() => { generation.current++; onClose(); }}>Cancel</Button><Button id="wallpaper-save" disabled={busy || !!loadError || !portableSource} onClick={save}>Save configuration</Button></DialogFooter>
    </DialogContent>
  </Dialog>;
}
