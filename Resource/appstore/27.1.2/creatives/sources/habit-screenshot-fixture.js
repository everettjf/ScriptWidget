// Screenshot fixture only. Never bundled into the user template or persisted.
// Uses the fixed native capture clock and real template date/streak logic.
;(() => {
  const now = new Date();
  const records = [];
  for (let offset = 153; offset >= 0; offset--) {
    // Eleven consecutive completed days, with varied earlier activity.
    const checked = offset <= 10 || (offset > 11 && offset % 13 < 9 && offset % 5 !== 1);
    if (!checked) continue;
    const date = new Date(now.getFullYear(), now.getMonth(), now.getDate() - offset, 12);
    records.push(`${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`);
  }
  $storage = {
    getString: (key) => key === "habitHeatmap.v1.read" ? JSON.stringify(records) : "",
    setString: () => { throw new Error("Screenshot fixtures are read-only"); },
  };
})();
