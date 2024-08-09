import { CompletionContext } from "@codemirror/autocomplete"

function myCompletions(context) {
  let word = context.matchBefore(/</);
  if (word == null || word.text == null || word.from == null) {
    return null;
  }

  console.log(word);

  if (word.text === '<') {
    console.log("match <")
    return {
      from: word.from,
      options: [
        { label: "match", type: "keyword" },
        { label: "hello", type: "variable", info: "(World)" },
        { label: "hello", type: "variable", info: "(World)" },
        { label: "hello", type: "variable", info: "(World)" },
        { label: "hello", type: "variable", info: "(World)" },
        { label: "hello", type: "variable", info: "(World)" },
        { label: "magic", type: "text", apply: "⠁⭒*.✩.*⭒⠁", detail: "macro" }
      ]
    }
  }

  if (word.text === '$') {
    console.log("match $")
    return {
      from: word.from,
      options: [
        { label: "match", type: "keyword" },
        { label: "match", type: "keyword" },
        { label: "match", type: "keyword" },
        { label: "match", type: "keyword" },
        { label: "hello", type: "variable", info: "(World)" },
        { label: "magic", type: "text", apply: "⠁⭒*.✩.*⭒⠁", detail: "macro" }
      ]
    }
  }

  return null;
}

export { myCompletions };
