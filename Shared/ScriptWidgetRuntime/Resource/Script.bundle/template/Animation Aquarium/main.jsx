//
// ScriptWidget
// https://xnu.app/scriptwidget
//
// Animation Aquarium
//
// Description: Animation Aquarium
//

/*
🛟
🪼                   🐟🐠             🫧
           🫧                          🫧   🐡
🪼                 🐬       
     🪼                        🦐     🫧
🍀🪸🌿🪸⚓️🗿🐙🐙🌿🪸
*/

let fishHorizontal = {
  type: "swing",
  duration: 20,
  direction: "horizontal", // "horizontal", "vertical"
  distance: 100,
};

let fishVertical = {
  type: "swing",
  duration: 30,
  direction: "vertical", // "horizontal", "vertical"
  distance: 70,
};

let bubbleVertical = {
  type: "swing",
  duration: 15,
  direction: "vertical", // "horizontal", "vertical"
  distance: 50,
};

let linearGradient = {
  type: "linear",
  colors: ["#013A63", "#1E81B0", "#E0FBFC"],
  startPoint: "top",
  endPoint: "bottom",
};
$render(
  <vstack background={$gradient(linearGradient)} frame="max" alignment="top">
    <hstack alignment="leading">
      <text font="body">  🛟</text>
      <spacer />
    </hstack>
    <hstack alignment="leading">
      <text font="body">  🪼        🐟    🐠         🫧</text>
      <text font="body" animation={$animation(fishVertical)}>🐠</text>
      <text font="body">         🫧</text>
      <spacer />
    </hstack>
    <hstack alignment="leading">
      <text font="body">  🫧</text>
      <text font="body">       </text>
      <text font="body" animation={$animation(bubbleVertical)}>🫧</text>
      <text font="body" animation={$animation(fishHorizontal)}>🐡🐡</text>
      <spacer />
    </hstack>
    <hstack alignment="leading">
      <text font="body">  🪼    🫧    🐬       🐬</text>
    </hstack>
    <hstack alignment="leading">
      <text font="body">  🪼   🫧    🦐          🫧🫧</text>
      <spacer />
    </hstack>
    <hstack alignment="leading">
      <text font="body">  🍀 🪸🌿🪸⚓️🗿🐙🐙  🌿🌿 🌿🪸🪸</text>
      <spacer />
    </hstack>
  </vstack>
);
