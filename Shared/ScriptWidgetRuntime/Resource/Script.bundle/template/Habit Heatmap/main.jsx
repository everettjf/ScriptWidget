//
// ScriptWidget
// https://xnu.app/scriptwidget
//
// Habit Heatmap: one square per day, darker when you did more.
// `log` holds 0-4 per day, oldest first; the sample is generated so the
// widget looks lived-in. Store your own log with $storage.
//

const size = $getenv("widget-size");
const habits = [
  { name: "Read", color: ["#1B2A1E", "#0E4429", "#006D32", "#26A641", "#39D353"] },
  { name: "Run", color: ["#1E1B2A", "#2E2266", "#4434A5", "#6B5BE0", "#9D8CFF"] },
  { name: "Meditate", color: ["#2A1E1B", "#5C2A10", "#9A4A12", "#D9741C", "#FFA94D"] },
];
// Deterministic sample activity: a simple linear congruential generator.
const sample = (seed, days) => {
  let state = seed;
  return Array.from({ length: days }, (_, index) => {
    state = (state * 1103515245 + 12345) % 2147483648;
    const recent = index > days - 10;
    return recent ? 1 + (state % 4) : state % 5 === 0 ? 0 : (state >> 8) % 5;
  });
};
const logs = habits.map((habit, index) => sample(17 + index * 31, 26 * 7));
const streak = (log) => { let count = 0; for (let i = log.length - 1; i >= 0 && log[i] > 0; i--) count++; return count; };

const Grid = ({ log, colors, weeks, cell, gap }) => {
  const days = log.slice(-weeks * 7);
  // Columns are weeks, rows are weekdays, as in a contribution graph.
  return (
    <hstack spacing={gap}>
      {Array.from({ length: weeks }, (_, week) => (
        <vstack spacing={gap}>
          {days.slice(week * 7, week * 7 + 7).map((level) => <rect frame={`${cell},${cell}`} corner={cell * 0.25} color={colors[level]} />)}
        </vstack>
      ))}
    </hstack>
  );
};
const Header = ({ habit, log, font }) => (
  <hstack>
    <text font={font} fontWeight="semibold" color="white">{habit.name}</text>
    <spacer />
    <icon systemName="flame.fill" size="12" color={habit.color[4]} />
    <text font="caption" fontWeight="semibold" color={habit.color[4]}>{streak(log)} days</text>
  </hstack>
);

if (size === "accessoryCircular") {
  $render(<vstack spacing="0"><icon systemName="flame.fill" size="16" /><text font="title3" fontWeight="bold">{streak(logs[0])}</text></vstack>);
} else if (size === "accessoryRectangular") {
  $render(
    <vstack alignment="leading" spacing="3" frame="max,leading">
      <text font="caption" fontWeight="semibold">{habits[0].name} · {streak(logs[0])}-day streak</text>
      <Grid log={logs[0].map((level) => (level > 0 ? 4 : 1))} colors={["#444444", "#666666", "#888888", "#AAAAAA", "#FFFFFF"]} weeks={20} cell={5} gap={1.5} />
    </vstack>
  );
} else if (size === "accessoryInline") {
  $render(<text>{habits[0].name} · {streak(logs[0])}-day streak</text>);
} else if (size === "small") {
  $render(
    <vstack alignment="leading" spacing="10" padding="14" background="#0D1117">
      <Header habit={habits[0]} log={logs[0]} font="headline" />
      <Grid log={logs[0]} colors={habits[0].color} weeks={8} cell={12} gap={3} />
    </vstack>
  );
} else if (size === "medium") {
  $render(
    <vstack alignment="leading" spacing="10" padding="14" background="#0D1117">
      <Header habit={habits[0]} log={logs[0]} font="headline" />
      <Grid log={logs[0]} colors={habits[0].color} weeks={18} cell={12} gap={3} />
    </vstack>
  );
} else if (size === "extraLarge") {
  $render(
    <hstack alignment="top" spacing="28" padding="24" background="#0D1117">
      {habits.map((habit, index) => (
        <vstack alignment="leading" spacing="10" frame="max">
          <Header habit={habit} log={logs[index]} font="headline" />
          <Grid log={logs[index]} colors={habit.color} weeks={11} cell={14} gap={4} />
        </vstack>
      ))}
    </hstack>
  );
} else {
  $render(
    <vstack alignment="leading" spacing="12" padding="16" background="#0D1117">
      {habits.map((habit, index) => (
        <vstack alignment="leading" spacing="5">
          <Header habit={habit} log={logs[index]} font="subheadline" />
          <Grid log={logs[index]} colors={habit.color} weeks={26} cell={9} gap={2} />
        </vstack>
      ))}
    </vstack>
  );
}
