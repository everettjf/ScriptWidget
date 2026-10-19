import { useEffect, useState } from "react";
import { Download, LayoutGrid, Plus, Smartphone, Upload } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

interface TopBarProps {
  projectName: string;
  projectID: string | null;
  onRename(name: string): void;
  onNew(): void;
  onTemplates(): void;
  onImport(): void;
  onExport(): void;
  onInstall(): void;
}

export function TopBar({ projectName, projectID, onRename, onNew, onTemplates, onImport, onExport, onInstall }: TopBarProps) {
  const [name, setName] = useState(projectName);
  // Show the stored name again when another project opens.
  useEffect(() => setName(projectName), [projectID, projectName]);
  const commit = () => { if (name.trim() !== projectName) onRename(name); };
  return (
    <header className="flex flex-wrap items-center gap-x-3 gap-y-2 border-b bg-card px-4 py-2">
      <div className="flex items-center gap-2 font-semibold whitespace-nowrap">
        <span aria-hidden="true" className="size-[22px] rounded-md bg-gradient-to-br from-[#0a84ff] to-[#5e5ce6]" />
        <span>ScriptWidget Studio</span>
      </div>
      <label className="min-w-32 flex-[1_1_10rem]">
        <span className="sr-only">Project name</span>
        <Input
          id="project-name" value={name} autoComplete="off" spellCheck={false}
          className="h-8 border-transparent bg-transparent font-semibold shadow-none hover:border-input focus-visible:border-ring dark:bg-transparent"
          onChange={(event) => setName(event.target.value)}
          onBlur={commit}
          onKeyDown={(event) => { if (event.key === "Enter") event.currentTarget.blur(); }}
        />
      </label>
      <nav className="flex flex-wrap gap-1.5" aria-label="Project actions">
        <Button id="new-project" variant="outline" size="sm" onClick={onNew}><Plus />New</Button>
        <Button id="open-templates" variant="outline" size="sm" onClick={onTemplates}><LayoutGrid />Gallery</Button>
        <Button id="import-package" variant="outline" size="sm" onClick={onImport}><Upload />Import</Button>
        <Button id="export-package" variant="outline" size="sm" onClick={onExport}><Download />Export .swt</Button>
        <Button id="install-package" size="sm" onClick={onInstall}><Smartphone />Install on iPhone</Button>
      </nav>
    </header>
  );
}
