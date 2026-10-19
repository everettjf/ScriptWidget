//
// ScriptWidget
// https://xnu.app/scriptwidget
//
// Activity Rings: three goal rings and a week of move calories.
// Replace the sample values with your own (or $health data).
//

const size = $getenv("widget-size");
const goals = [
  { name: "Move", value: 420, goal: 500, unit: "CAL", color: "#FA114F", track: "#3A0B18" },
  { name: "Exercise", value: 24, goal: 30, unit: "MIN", color: "#92E82A", track: "#20330A" },
  { name: "Stand", value: 9, goal: 12, unit: "HRS", color: "#1EEAEF", track: "#0A3334" },
];
const week = [["M", 510], ["T", 380], ["W", 620], ["T", 450], ["F", 290], ["S", 540], ["S", 420]];

const Rings = ({ side, thickness }) => (
  <zstack frame={`${side},${side}`}>
    {goals.map((goal, index) => {
      const inset = index * (thickness + 2);
      return <ring value={Math.min(1, goal.value / goal.goal)} thickness={thickness} color={goal.color} trackColor={goal.track} frame={`${side - inset * 2},${side - inset * 2}`} />;
    })}
  </zstack>
);
const Stat = ({ goal, font }) => (
  <vstack alignment="leading" spacing="0">
    <text font="caption2" fontWeight="semibold" color="white">{goal.name}</text>
    <hstack alignment="bottom" spacing="3"><text font={font} fontWeight="semibold" color={goal.color}>{goal.value}/{goal.goal}</text><text font="caption" fontWeight="semibold" color={goal.color}>{goal.unit}</text></hstack>
  </vstack>
);
const Week = () => (
  <vstack alignment="leading" spacing="8" frame="max,leading">
    <text font="caption" fontWeight="semibold" color="#8E8E93">MOVE THIS WEEK</text>
    <hstack alignment="bottom" frame="max,70">
      {week.map(([, calories]) => <capsule frame={`14,${Math.round(70 * calories / 620)}`} color={calories >= goals[0].goal ? "#FA114F" : "#5C1527"} />).flatMap((bar, index) => (index ? [<spacer />, bar] : [bar]))}
    </hstack>
    <hstack>
      {week.map(([day]) => <text font="caption2" color="#8E8E93" frame="14">{day}</text>).flatMap((label, index) => (index ? [<spacer />, label] : [label]))}
    </hstack>
  </vstack>
);

if (size === "accessoryCircular") {
  $render(<zstack><ring value={goals[0].value / goals[0].goal} thickness="5" frame="max" /><text font="caption" fontWeight="bold">{Math.round(100 * goals[0].value / goals[0].goal)}%</text></zstack>);
} else if (size === "accessoryRectangular") {
  $render(
    <hstack spacing="8" frame="max,leading">
      <Rings side={44} thickness={5} />
      <vstack alignment="leading" spacing="0">
        {goals.map((goal) => <text font="caption">{goal.value}/{goal.goal} {goal.unit}</text>)}
      </vstack>
    </hstack>
  );
} else if (size === "accessoryInline") {
  $render(<text>Move {goals[0].value}/{goals[0].goal} · Exercise {goals[1].value} min</text>);
} else if (size === "small") {
  $render(
    <vstack spacing="10" padding="14" background="black">
      <Rings side={84} thickness={11} />
      <hstack>
        {goals.map((goal) => <text font="caption" fontWeight="bold" color={goal.color} frame="max">{goal.value}</text>)}
      </hstack>
    </vstack>
  );
} else if (size === "medium") {
  $render(
    <hstack spacing="18" padding="16" background="black">
      <Rings side={112} thickness={14} />
      <vstack alignment="leading" spacing="6" frame="max,leading">
        {goals.map((goal) => <Stat goal={goal} font="title3" />)}
      </vstack>
    </hstack>
  );
} else if (size === "extraLarge") {
  $render(
    <hstack spacing="32" padding="24" background="black">
      <Rings side={180} thickness={20} />
      <vstack alignment="leading" spacing="10" frame="160,leading">
        {goals.map((goal) => <Stat goal={goal} font="title2" />)}
      </vstack>
      <Week />
    </hstack>
  );
} else {
  $render(
    <vstack spacing="18" padding="16" background="black">
      <hstack spacing="20">
        <Rings side={128} thickness={16} />
        <vstack alignment="leading" spacing="8" frame="max,leading">
          {goals.map((goal) => <Stat goal={goal} font="title2" />)}
        </vstack>
      </hstack>
      <spacer />
      <Week />
    </vstack>
  );
}
