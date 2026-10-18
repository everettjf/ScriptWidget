import { useEffect, useMemo, useState } from "react";
import { Search } from "lucide-react";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import type { Template } from "@/project.ts";

let catalog: Promise<Template[]> | null = null;
const loadTemplates = () => {
  catalog ??= fetch(new URL("./templates.json", document.baseURI)).then((response) => response.json()).then((json: { templates: Template[] }) => json.templates);
  return catalog;
};

export function TemplatesDialog({ open, onOpenChange, onChoose }: { open: boolean; onOpenChange(open: boolean): void; onChoose(template: Template): void }) {
  const [templates, setTemplates] = useState<Template[] | null>(null);
  const [query, setQuery] = useState("");
  useEffect(() => {
    if (open && !templates) loadTemplates().then(setTemplates, () => { catalog = null; setTemplates([]); });
  }, [open, templates]);
  const visible = useMemo(() => {
    const needle = query.trim().toLowerCase();
    return (templates ?? []).filter((template) => !needle || `${template.name} ${template.description} ${template.category}`.toLowerCase().includes(needle));
  }, [templates, query]);
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="flex max-h-[calc(100vh-4rem)] flex-col sm:max-w-3xl">
        <DialogHeader>
          <DialogTitle>Start from a template</DialogTitle>
          <DialogDescription>Bundled templates and Gallery widgets open as new projects.</DialogDescription>
        </DialogHeader>
        <div className="relative">
          <Search className="pointer-events-none absolute top-1/2 left-2.5 size-4 -translate-y-1/2 text-muted-foreground" />
          <Input id="template-search" type="search" placeholder="Search templates" aria-label="Search templates" className="pl-8"
            value={query} onChange={(event) => setQuery(event.target.value)} />
        </div>
        <ul id="template-list" className="-mx-1 grid min-h-0 grid-cols-[repeat(auto-fill,minmax(190px,1fr))] gap-2.5 overflow-auto px-1 pb-1">
          {templates === null && <li className="text-sm text-muted-foreground">Loading templates…</li>}
          {visible.map((template) => (
            <li key={template.id}>
              <button type="button" onClick={() => onChoose(template)}
                className="template-card flex h-full w-full flex-col gap-1 rounded-lg border bg-sidebar p-2.5 text-left outline-none hover:border-primary/50 hover:bg-accent focus-visible:ring-[3px] focus-visible:ring-ring/50">
                <span className="font-semibold">{template.name}</span>
                <span className="text-[11px] text-primary capitalize">{template.source === "gallery" ? "Gallery" : template.category}</span>
                <span className="text-xs text-muted-foreground">{template.description}</span>
              </button>
            </li>
          ))}
        </ul>
      </DialogContent>
    </Dialog>
  );
}
