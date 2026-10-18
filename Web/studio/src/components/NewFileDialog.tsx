import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { validNewPath } from "@/project.ts";
import type { PackageFiles } from "../../../preview-engine/src/types.js";

export function NewFileDialog({ open, onOpenChange, files, onCreate }: { open: boolean; onOpenChange(open: boolean): void; files: PackageFiles; onCreate(path: string): void }) {
  const [path, setPath] = useState("lib/util.js");
  const [problem, setProblem] = useState<string | null>(null);
  useEffect(() => { if (open) { setPath("lib/util.js"); setProblem(null); } }, [open]);
  const submit = (event: React.FormEvent) => {
    event.preventDefault();
    const name = path.trim();
    const issue = validNewPath(name, files);
    if (issue) { setProblem(issue); return; }
    onCreate(name);
    onOpenChange(false);
  };
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <form onSubmit={submit} className="flex flex-col gap-4">
          <DialogHeader>
            <DialogTitle>New file</DialogTitle>
            <DialogDescription>Add a module or data file to the package. Use / for folders.</DialogDescription>
          </DialogHeader>
          <div className="flex flex-col gap-2">
            <Label htmlFor="new-file-path">Path</Label>
            <Input id="new-file-path" value={path} autoFocus autoComplete="off" spellCheck={false} aria-invalid={problem !== null}
              aria-describedby={problem ? "new-file-problem" : undefined} onChange={(event) => { setPath(event.target.value); setProblem(null); }} />
            {problem && <p id="new-file-problem" className="text-xs text-destructive">{problem}</p>}
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>Cancel</Button>
            <Button type="submit">Create</Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
