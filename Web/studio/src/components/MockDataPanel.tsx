import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { addSampleMocks, isObject, mockAPIs, parseMocks, permissionScenario, responseFor, setResponse, type MockObject, type MockValue } from "@/mockData.ts";

const groups = ["health", "location", "device", "system", "network", "storage", "dataSource", "json"];
const labels: Record<string, string> = { health: "Health", location: "Location", device: "Device", system: "System", network: "Network responses", storage: "Storage", dataSource: "Data Source Plugins", json: "Full JSON" };

// Primitive leaves use normal form fields. Arrays and uncommon payloads can
// always be edited in the return JSON without losing unknown properties.
function ValueFields({ value, onChange, path = "result" }: { value: MockValue; onChange(value: MockValue): void; path?: string }) {
  if (isObject(value)) return <div className="grid gap-2">{Object.entries(value).map(([key, item]) => <ValueFields key={key} path={`${path}.${key}`} value={item} onChange={(next) => onChange({ ...value, [key]: next })} />)}</div>;
  if (Array.isArray(value) || value === null) return null;
  return <div className="grid grid-cols-[minmax(0,1fr)_minmax(0,1fr)] items-center gap-2">
    <Label htmlFor={`mock-${path}`} className="break-all text-xs font-normal">{path.replace(/^result\.?/, "") || "Return value"}</Label>
    {typeof value === "boolean" ? <select id={`mock-${path}`} aria-label={path} className="h-8 min-w-0 rounded-md border bg-background px-2 text-xs" value={String(value)} onChange={(event) => onChange(event.target.value === "true")}><option value="true">true</option><option value="false">false</option></select>
      : <Input id={`mock-${path}`} aria-label={path} type={typeof value === "number" ? "number" : "text"} step="any" className="h-8 text-xs" value={value} onChange={(event) => {
        if (typeof value === "number") { if (event.target.value !== "" && Number.isFinite(event.target.valueAsNumber)) onChange(event.target.valueAsNumber); }
        else onChange(event.target.value);
      }} />}
  </div>;
}

export function MockDataPanel({ fixtures, onChange }: { fixtures: string; onChange(text: string): void }) {
  const [group, setGroup] = useState("health");
  const [selected, setSelected] = useState("$health.stepCountToday");
  const [draft, setDraft] = useState("");
  const [mode, setMode] = useState("value");
  const [error, setError] = useState("");
  let data: MockObject = {}, parseError = "";
  try { data = parseMocks(fixtures); } catch (reason) { parseError = (reason as Error).message; }
  const methods = mockAPIs.filter((api) => api.group === group);
  const api = mockAPIs.find((item) => item.id === selected)!;
  const response = responseFor(data, api);
  const special = group === "network" ? "fetch" : group;
  const structured = ["network", "storage", "dataSource"].includes(group);
  const encoded = structured ? JSON.stringify(data[special] ?? (group === "storage" ? {} : []), null, 2)
    : JSON.stringify("error" in response ? response.error : response.value, null, 2);
  useEffect(() => { setDraft(encoded ?? "null"); setMode("error" in response ? "error" : "value"); setError(""); }, [encoded, selected, group, fixtures]); // eslint-disable-line react-hooks/exhaustive-deps
  const commit = (work: () => string) => { try { onChange(work()); setError(""); } catch (reason) { setError((reason as Error).message); } };
  const chooseGroup = (next: string) => { setGroup(next); const first = mockAPIs.find((item) => item.group === next); if (first) setSelected(first.id); };
  const apply = () => commit(() => {
    const value: MockValue = JSON.parse(draft);
    if (structured) {
      const next = { ...parseMocks(fixtures), [special]: value };
      const text = JSON.stringify(next, null, 2); parseMocks(text); return text;
    }
    if (mode === "error" && typeof value !== "string") throw new Error("An error response must be a JSON string.");
    return setResponse(fixtures, selected, { [mode]: value });
  });
  return <div className="flex flex-col gap-3" id="mock-data-panel">
    <p className="text-xs text-muted-foreground">Sample data for this preview. Changes stay in this browser project and are never exported. Scripts do not call real system services or the network here.</p>
    <div className="flex flex-wrap items-end gap-2">
      <div className="min-w-0 flex-1"><Label htmlFor="mock-group" className="text-xs">Data source</Label><select id="mock-group" className="mt-1 h-8 w-full rounded-md border bg-background px-2 text-xs" value={group} onChange={(event) => chooseGroup(event.target.value)}>{groups.map((item) => <option key={item} value={item}>{labels[item]}</option>)}</select></div>
      <Button variant="outline" size="sm" disabled={!!parseError} onClick={() => commit(() => addSampleMocks(fixtures))}>Add missing samples</Button>
    </div>
    {parseError && <p role="alert" className="text-xs text-destructive">{parseError} Fix the Full JSON below; your text has been preserved.</p>}
    {group === "json" || parseError ? <><Label htmlFor="fixtures" className="text-xs">Full mock JSON</Label><Textarea id="fixtures" spellCheck={false} aria-label="Preview fixtures JSON" className="min-h-64 font-mono text-xs" value={fixtures} onChange={(event) => onChange(event.target.value)} /></> : <>
      {!structured && <>
        <div><Label htmlFor="mock-api" className="text-xs">API</Label><select id="mock-api" className="mt-1 h-8 w-full rounded-md border bg-background px-2 font-mono text-xs" value={selected} onChange={(event) => setSelected(event.target.value)}>{methods.map((item) => <option key={item.id} value={item.id}>{item.id}()</option>)}</select></div>
        {(group === "health" || group === "location") && <div className="flex flex-wrap gap-1">{(["granted", "denied", "unavailable"] as const).map((item) => <Button key={item} variant="outline" size="xs" onClick={() => commit(() => permissionScenario(fixtures, group, item))}>{item === "granted" ? "Sample success" : item === "denied" ? "Permission denied" : "Unavailable"}</Button>)}</div>}
        <div className="flex items-center gap-2"><Label htmlFor="mock-mode" className="text-xs">Response</Label><select id="mock-mode" className="h-8 rounded-md border bg-background px-2 text-xs" value={mode} onChange={(event) => { setMode(event.target.value); setDraft(JSON.stringify(event.target.value === "error" ? "Simulated failure" : api.value, null, 2)); }}><option value="value">Return value</option><option value="error">Throw / reject error</option></select><Button size="xs" variant="ghost" className="ml-auto" onClick={() => commit(() => setResponse(fixtures, selected, { value: api.value }))}>Reset this API</Button></div>
        {mode === "value" && "value" in response && <ValueFields value={response.value!} onChange={(value) => commit(() => setResponse(fixtures, selected, { value }))} />}
      </>}
      {group === "network" && <p className="text-xs text-muted-foreground">Match an exact URL and method. body is response text (JSON as a string); error simulates failure. Unmatched requests show a warning. Package network permissions still apply.</p>}
      {group === "storage" && <p className="text-xs text-muted-foreground">Initial key/value pairs for each run. Reads and writes work within that run; the next preview starts from these values. Edit package files in the file tree to mock $file data.</p>}
      {group === "dataSource" && <p className="text-xs text-muted-foreground">Match pluginID and operationID. Each rule needs an HTTPS url and value or error. Declare the plugin, network permission and domain in widget.json. Parameters are not matched.</p>}
      {group === "dataSource" && <Button variant="outline" size="xs" className="self-start" onClick={() => setDraft(JSON.stringify([{ pluginID: "example.weather", operationID: "current", url: "https://api.example.com/weather", value: { temperature: 22 } }], null, 2))}>Show example rule</Button>}
      <Label htmlFor="mock-response-json" className="text-xs">{structured ? "Mock data JSON" : "Response JSON"}</Label>
      <Textarea id="mock-response-json" spellCheck={false} aria-label="Mock response JSON" className="min-h-32 font-mono text-xs" value={draft} onChange={(event) => setDraft(event.target.value)} />
      <Button size="sm" className="self-start" onClick={apply}>Apply mock data</Button>
    </>}
    {error && <p role="alert" className="text-xs text-destructive">{error}</p>}
    <p className="text-xs text-muted-foreground">Files, JSX rendering and XML parsing run normally. Widget size, appearance and parameters use the preview controls. $runtime reports the real preview contract.</p>
  </div>;
}
