//
// ScriptWidget
// https://xnu.app/scriptwidget
//
// Daily Quote (zenquotes.io)
//

const url = "https://zenquotes.io/api/today";
const result = await fetch(url);
const data = JSON.parse(result);
const quote = data && data.length ? data[0] : { q: "Stay inspired", a: "ScriptWidget" };

$render(
  <vstack frame="max" background="#0f172a">
    <text font="caption" color="#94a3b8">Daily Quote</text>
    <text font="caption" color="#e2e8f0">"{quote.q}"</text>
    <text font="caption2" color="#64748b">- {quote.a}</text>
  </vstack>
);
