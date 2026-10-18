import { closeBrackets, closeBracketsKeymap, autocompletion, completionKeymap } from "@codemirror/autocomplete";
import { defaultKeymap, history, historyKeymap, indentWithTab } from "@codemirror/commands";
import { javascript } from "@codemirror/lang-javascript";
import { bracketMatching, foldGutter, foldKeymap, indentOnInput } from "@codemirror/language";
import { lintGutter, linter } from "@codemirror/lint";
import { highlightSelectionMatches, searchKeymap } from "@codemirror/search";
import { Compartment, EditorState } from "@codemirror/state";
import {
  EditorView, crosshairCursor, drawSelection, dropCursor, highlightActiveLine, highlightActiveLineGutter,
  highlightSpecialChars, hoverTooltip, keymap, lineNumbers, rectangularSelection,
} from "@codemirror/view";
import { scriptWidgetCompletions } from "../../../Editor/editorfe/src/scriptWidgetCompletions.js";
import { scriptWidgetDiagnostics, scriptWidgetHover } from "../../../Editor/editorfe/src/scriptWidgetLanguage.js";
import { studioTheme } from "../../../Editor/editorfe/src/studioTheme.js";

const theme = new Compartment();
const prefersDark = () => globalThis.matchMedia?.("(prefers-color-scheme: dark)").matches === true;

/// One EditorState per file keeps undo history when switching files.
export function createEditor(parent, onChange) {
  const states = new Map();
  let currentPath = null;
  const extensions = (path) => {
    const script = /\.(jsx?|mjs)$/i.test(path);
    return [
      lineNumbers(), highlightActiveLineGutter(), highlightSpecialChars(), history(), foldGutter(), drawSelection(), dropCursor(),
      EditorState.allowMultipleSelections.of(true), indentOnInput(), bracketMatching(), closeBrackets(), rectangularSelection(),
      crosshairCursor(), highlightActiveLine(), highlightSelectionMatches(), EditorView.lineWrapping,
      javascript({ jsx: /\.jsx$/i.test(path) || !/\.json$/i.test(path), typescript: false }),
      ...(script ? [autocompletion({ override: [scriptWidgetCompletions] }), linter(scriptWidgetDiagnostics, { delay: 300 }), lintGutter(), hoverTooltip(scriptWidgetHover)] : []),
      keymap.of([...closeBracketsKeymap, ...defaultKeymap, ...searchKeymap, ...historyKeymap, ...foldKeymap, ...completionKeymap, indentWithTab]),
      theme.of(studioTheme(prefersDark() ? "dark" : "light")),
      EditorView.contentAttributes.of({ "aria-label": `Edit ${path}` }),
      EditorView.updateListener.of((update) => { if (update.docChanged && currentPath === path) onChange(path, update.state.doc.toString()); }),
    ];
  };
  const view = new EditorView({ parent });
  globalThis.matchMedia?.("(prefers-color-scheme: dark)").addEventListener?.("change", () => {
    view.dispatch({ effects: theme.reconfigure(studioTheme(prefersDark() ? "dark" : "light")) });
  });
  return {
    view,
    open(path, text) {
      if (currentPath !== null) states.set(currentPath, view.state);
      let state = states.get(path);
      if (!state || state.doc.toString() !== text) state = EditorState.create({ doc: text, extensions: extensions(path) });
      currentPath = path;
      view.setState(state);
    },
    reset() { states.clear(); currentPath = null; },
    forget(path) { states.delete(path); },
    focus() { view.focus(); },
  };
}
