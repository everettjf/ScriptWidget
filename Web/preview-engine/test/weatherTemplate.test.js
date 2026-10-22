import assert from "node:assert/strict";
import test from "node:test";
import fs from "node:fs";
import {executePackageInNode} from "../src/node.js";
const root=new URL("../../../Shared/ScriptWidgetRuntime/Resource/Script.bundle/template/",import.meta.url);
const names=["Local Weather (Location)","Weather Now (MET Norway)"];
const filesFor=(name=names[0])=>Object.fromEntries(["main.jsx","widget.json","lib/weather.js"].map(path=>[path,fs.readFileSync(new URL(`${name}/${path}`,root),"utf8")]));
const now=Date.parse("2026-01-01T12:15:00Z"),hour=3600000,key="weather.met.v1";
const config={city:"London",latitude:51.5,longitude:-0.12,useLocation:false,unit:"c"};
const url=(latitude=51.5,longitude=-0.12)=>`https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=${latitude.toFixed(2)}&lon=${longitude.toFixed(2)}`;
const body=()=>({properties:{meta:{updated_at:"2026-01-01T12:00:00Z",units:{air_temperature:"celsius",relative_humidity:"%",wind_speed:"m/s"}},timeseries:Array.from({length:30},(_,index)=>({time:new Date(Date.parse("2026-01-01T12:00:00Z")+index*hour).toISOString(),data:{instant:{details:{air_temperature:18+index/2,relative_humidity:64,wind_speed:1}},next_1_hours:{summary:{symbol_code:"partlycloudy_day"}}}}))}});
const response=(options={})=>({url:url(),status:200,body:JSON.stringify(body()),headers:{Expires:"Thu, 01 Jan 2026 13:00:00 GMT","Last-Modified":"Thu, 01 Jan 2026 12:00:00 GMT"},...options});
const api=(mode="denied")=>({"$location.isAvailable":{value:true},"$location.authorizationStatus":{value:mode==="granted"?"authorizedWhenInUse":"denied"},"$location.isAuthorizedForWidgetUpdates":{value:mode==="granted"},"$location.current":{value:{latitude:37.3349,longitude:-122.009}}});
async function run({settings=config,storage={},time=now,responses=[response()],location="denied",prefix="",inspect=true,size="medium",name=names[0],projection=false,atomic=true}={}){
 const files=filesFor(name);
 const trace=`const calls=[];let locationCalls=0;const realGet=$http.getResponse,realLocation=$location.current;
 $http.getResponse=(url,options)=>{calls.push({url,headers:options.headers});return realGet(url,options);};
 $location.current=(options)=>{locationCalls++;return realLocation(options);};`;
 const clock=`const NativeDate=Date;Date=class extends NativeDate{constructor(...args){super(...(args.length?args:[${time}]));}static now(){return ${time};}};Math.random=()=>0;`;
 if(inspect)files["main.jsx"]='const $testRender=$render;$render=()=>{};\n'+trace+prefix+files["main.jsx"]+'\n$testRender(<text>{JSON.stringify({weather,calls,locationCalls,raw:$storage.getString("weather.met.v1"),stored:$storage.getString("recordTemplate.config.v1")})}</text>);';
 const fixtures={api:api(location),fetch:responses,storage,storageAtomicAvailable:atomic};
 const result=await executePackageInNode({files,prelude:clock,environments:{"widget-size":size,"widget-param":settings===null?"":JSON.stringify(settings),"timeline-is-projection":String(projection)},fixtures});
 if(!inspect)return result;
 assert.equal(result.error,null,result.error?.message);return JSON.parse(JSON.parse(result.tree).children.join(""));
}

test("weather templates stay identical and require honest configuration before fetching",async()=>{
 assert.equal(filesFor(names[0])["lib/weather.js"],filesFor(names[1])["lib/weather.js"]);
 const result=await run({settings:null});assert.equal(result.weather.available,false);assert.equal(result.calls.length,0);assert.match(result.weather.title,/Choose/);
});
test("fresh forecasts cache headers, label data and convert units without a new request",async()=>{
 const first=await run();assert.equal(first.weather.temperature,"18°C");assert.equal(first.weather.wind,"3.6 km/h");assert.equal(first.weather.status,"Forecast");
 assert.equal(first.calls[0].headers["User-Agent"],"ScriptWidget/1.3 (https://github.com/everettjf/scriptwidget)");
 const cache=JSON.parse(first.raw);assert.equal(cache.entries.length,1);assert.equal(cache.entries[0].points.length,24);
 const second=await run({storage:{[key]:first.raw},time:now+60000,settings:{...config,unit:"f"},responses:[response({error:"must not fetch"})]});
 assert.equal(second.calls.length,0);assert.equal(second.weather.temperature,"64°F");assert.equal(second.weather.status,"Saved forecast");
});
test("conditional 304 retains source update time and failed refresh backs off without fake data",async()=>{
 const first=await run();
 const updated=await run({storage:{[key]:first.raw},time:now+hour,responses:[response({status:304,body:"",headers:{Expires:"Thu, 01 Jan 2026 14:00:00 GMT"}})]});
 assert.equal(updated.calls[0].headers["If-Modified-Since"],"Thu, 01 Jan 2026 12:00:00 GMT");
 assert.equal(JSON.parse(updated.raw).entries[0].updatedAt,Date.parse("2026-01-01T12:00:00Z"));assert.equal(updated.weather.available,true);
 const failure=await run({storage:{[key]:first.raw},time:now+hour,responses:[response({status:503,body:"unavailable"})]});
 assert.equal(failure.weather.available,true);assert.match(failure.weather.status,/refresh unavailable/);
 const retry=await run({storage:{[key]:failure.raw},time:now+hour+60000});assert.equal(retry.calls.length,0);
 const empty=await run({responses:[response({status:429,headers:{"Retry-After":"3600"},body:"limited"})]});assert.equal(empty.weather.available,false);
 assert.equal((await run({storage:{[key]:empty.raw},time:now+30*60000})).calls.length,0);
});
test("denied location uses the saved city and never reads location or old GPS cache",async()=>{
 const gps=await run({settings:{...config,useLocation:true},location:"granted",responses:[response({url:url(37.33,-122.01)})]});
 assert.equal(gps.weather.source,"location");assert.equal(gps.calls[0].url,url(37.33,-122.01));
 const fallback=await run({settings:{...config,useLocation:true},storage:{[key]:gps.raw},location:"denied"});
 assert.equal(fallback.locationCalls,0);assert.equal(fallback.weather.name,"London");assert.equal(fallback.weather.source,"manual");
 assert.ok(JSON.parse(fallback.raw).entries.every(entry=>entry.source!=="location"));
});
test("permission changes during success or failure discard GPS data before city fallback",async()=>{
 const seed=await run({settings:{...config,useLocation:true},location:"granted",responses:[response({url:url(37.33,-122.01)})]});
 for(const error of [false,true]){
  const prefix=`const pendingGet=$http.getResponse;$http.getResponse=(url,options)=>{$location.authorizationStatus=()=>"denied";return pendingGet(url,options);};`;
  const result=await run({settings:{...config,useLocation:true},storage:{[key]:seed.raw},location:"granted",time:now+hour,prefix,responses:[response({url:url(37.33,-122.01),...(error?{error:"offline"}:{})}),response()]});
  assert.equal(result.weather.source,"manual");assert.equal(result.weather.name,"London");assert.ok(JSON.parse(result.raw).entries.every(entry=>entry.source!=="location"));
 }
});
test("invalid responses preserve useful cache, and very old forecasts are not shown as current",async()=>{
 const first=await run();const invalid=body();invalid.properties.meta.units.air_temperature="fahrenheit";
 const fallback=await run({storage:{[key]:first.raw},time:now+hour,responses:[response({body:JSON.stringify(invalid)})]});
 assert.equal(fallback.weather.available,true);assert.match(fallback.weather.status,/Saved/);
 for(const value of [invalid,{properties:{}},{properties:{...body().properties,timeseries:[]}}]){
  assert.equal((await run({responses:[response({body:JSON.stringify(value)})]})).weather.available,false);
 }
 const stale=await run({storage:{[key]:first.raw},time:now+25*hour,responses:[response({error:"offline"})]});assert.equal(stale.weather.available,false);
});
test("cache cardinality is bounded, CAS conflicts preserve other places and failures stay visible",async()=>{
 let raw="";
 for(let index=0;index<6;index++)raw=(await run({settings:{...config,latitude:40+index},storage:{[key]:raw},time:now+index*1000,responses:[response({url:url(40+index,-0.12)})]})).raw;
 assert.equal(JSON.parse(raw).entries.length,4);
 const other=JSON.parse(raw).entries[0];
 const prefix=`const realCAS=$storage.compareAndSetString;let conflict=true;$storage.compareAndSetString=(key,before,after)=>{if(conflict){conflict=false;$storage.setString(key,${JSON.stringify(JSON.stringify({version:1,entries:[other]}))});return false;}return realCAS(key,before,after);};`;
 const merged=await run({time:now+10000,prefix});assert.equal(JSON.parse(merged.raw).entries.length,2);
 const noCache=await run({atomic:false});assert.equal(noCache.weather.available,true);assert.equal(noCache.weather.status,"Cache unavailable");assert.equal(noCache.raw,"");
});
test("future projections cannot request data or mutate cache, and all declared sizes render",async()=>{
 const first=await run();const projected=await run({storage:{[key]:first.raw},projection:true});assert.equal(projected.calls.length,0);assert.equal(projected.raw,first.raw);
 for(const size of ["small","medium","large","extraLarge","extraLargePortrait","accessoryCircular","accessoryRectangular","accessoryInline"]){
  for(const name of names){const result=await run({size,name,inspect:false});assert.equal(result.error,null,`${size}/${name}`);assert.ok(result.tree);}
 }
});

test("stale GPS positions use city fallback while reduced accuracy is labelled honestly",async()=>{
 const stale=await run({settings:{...config,useLocation:true},location:"granted",prefix:'$location.current=()=>Promise.resolve({latitude:37.3349,longitude:-122.009,age:7200,isStale:true});'});
 assert.equal(stale.weather.source,"manual");assert.equal(stale.calls[0].url,url());
 const reduced=await run({settings:{...config,useLocation:true},location:"granted",prefix:'$location.current=()=>Promise.resolve({latitude:37.3349,longitude:-122.009,age:0,isStale:false,accuracyAuthorization:"reduced"});',responses:[response({url:url(37.33,-122.01)})]});
 assert.equal(reduced.weather.name,"Approximate area");
 const other=await run({settings:{...config,useLocation:true},location:"granted",storage:{[key]:reduced.raw},prefix:'$location.current=()=>Promise.resolve({latitude:38,longitude:-123,age:0,isStale:false});',responses:[response({url:url(38,-123)})]});
 assert.equal(JSON.parse(other.raw).entries.filter(entry=>entry.source==="location").length,1);
});

test("forecast states match actual native canonical trees for every family",async()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL("./parity/weather-trees.json",import.meta.url),"utf8"));
 const forecast=fs.readFileSync(new URL("./parity/weather-response.json",import.meta.url),"utf8");
 const seed=await run({responses:[response({body:forecast})]});
 for(const [key,expected]of Object.entries(fixture.trees)){
  const [mode,size]=key.split("/");
  const result=await run({size,inspect:false,storage:mode==="saved"||mode==="stale"?{["weather.met.v1"]:seed.raw}:{},time:mode==="stale"?now+hour:now,
   responses:[response(mode==="stale"||mode==="unavailable"?{error:"isolated network failure"}:{body:forecast})]});
  assert.equal(result.error,null,key);assert.equal(result.tree,expected,key);
 }
});
