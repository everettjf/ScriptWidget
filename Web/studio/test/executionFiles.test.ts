import assert from "node:assert/strict";
import test from "node:test";
import {executionFiles,textFiles} from "../src/project.ts";

test("execution files preserve binary names without copying private image bytes into the runtime",()=>{
 const binary=new Uint8Array([0,255,1]),files={"main.jsx":"$render(<text>Hi</text>);","image/picture.png":binary};
 const runtime=executionFiles(files);
 assert.equal(runtime["main.jsx"],files["main.jsx"]);
 assert.ok(runtime["image/picture.png"] instanceof Uint8Array);
 assert.equal((runtime["image/picture.png"] as Uint8Array).byteLength,0);
 assert.equal(files["image/picture.png"],binary);assert.equal(binary.byteLength,3);
 assert.deepEqual(Object.keys(textFiles(files)),["main.jsx"]);
});
