//
// ScriptWidget
// https://scriptwidget.app
//
// Usage for api file
//

// read as string
console.log($file.read("data.json"));

// read as json
let json = $file.readJSON("data.json");
console.log(json);
console.log(json.name);
