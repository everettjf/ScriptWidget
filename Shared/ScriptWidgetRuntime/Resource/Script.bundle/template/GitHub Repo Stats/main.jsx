//
// ScriptWidget
// https://xnu.app/scriptwidget
//
// GitHub Repo Stats
// widget-param: "owner/repo"
//

const repo = ($getenv("widget-param") || "everettjf/ScriptWidget").trim();
const url = `https://api.github.com/repos/${repo}`;
const result = await fetch(url);
const data = JSON.parse(result);

$render(
  <vstack frame="max" padding="12" background="#0f172a">
    <text font="caption" color="#94a3b8">GitHub</text>
    <text font="title3" color="#e2e8f0">{repo}</text>
    <hstack spacing="12">
      <stat title="Stars" value={(data.stargazers_count || 0).toString()} subtitle="" color="#f59e0b" />
      <stat title="Forks" value={(data.forks_count || 0).toString()} subtitle="" color="#38bdf8" />
      <stat title="Issues" value={(data.open_issues_count || 0).toString()} subtitle="" color="#ef4444" />
    </hstack>
  </vstack>
);
