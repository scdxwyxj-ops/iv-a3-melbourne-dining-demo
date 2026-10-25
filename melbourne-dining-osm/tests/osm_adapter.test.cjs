// Offline contracts for the active OSM adapter. Synthetic fixtures, no network.
const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const source = fs.readFileSync('www/osm-explorer.js','utf8');
let checks = 0;
function check(value,label) { assert.ok(value,label); checks++; console.log('PASS',label); }
function harness() {
  const elements = {}, handlers = {}, messages = [], scripts = [], created = [], markers = [], maps = [], jq = {};
  const timers = new Map(); let timerId = 0;
  function element(tag='div') {
    const x = {tag, children:[], events:{}, disabled:false, hidden:false, textContent:'', className:'',
      append(...nodes){this.children.push(...nodes);}, appendChild(node){this.append(node);},
      replaceChildren(...nodes){this.children=nodes;}, querySelector(){return element();},
      addEventListener(name,fn){this.events[name]=fn;}};
    created.push(x); return x;
  }
  const document = {readyState:'complete',head:{appendChild:s=>scripts.push(s)},
    getElementById:id=>elements[id] ||= element(),createElement:element,addEventListener(){}};
  const map = {layers:new Set(),fits:[],pans:[],setView(){return this;},fitBounds(b){this.fits.push(b);},
    panTo(p){this.pans.push(p);},hasLayer(x){return this.layers.has(x);},removeLayer(x){this.layers.delete(x);}};
  const L = {map:()=>{maps.push(map);return map;},divIcon:x=>x,
    latLngBounds:()=>({extend(){},isValid:()=>true}),latLng:()=>({distanceTo:()=>100}),
    tileLayer:()=>({addTo(){return this;},on(){return this;}}),
    layerGroup:()=>({addTo(){return this;},clearLayers(){}}),
    circle:()=>({radius:600,addTo(m){m.layers.add(this);return this;},setLatLng(){return this;},
      setRadius(r){this.radius=r;return this;},getBounds(){return {radius:this.radius};}}),
    marker:(point,options)=>{const m={point,options,events:{},addTo(){return this;},
      on(name,fn){this.events[name]=fn;return this;},setIcon(icon){this.options.icon=icon;},setZIndexOffset(){},getLatLng(){return this.point;}};
      markers.push(m); return m;}};
  const Shiny = {setInputValue:(name,value)=>messages.push({name,value}),addCustomMessageHandler:(name,fn)=>handlers[name]=fn};
  const window = {L,Shiny,google:{maps:{importLibrary:async()=>({PlaceSearchElement:true,PlaceDetailsElement:true})}},
    jQuery:()=>({on:(name,...args)=>jq[name]=args.at(-1)})};
  vm.runInNewContext(source,{window,document,Shiny,L,URLSearchParams,Map,Date,Intl,
    setTimeout:(fn,ms)=>{timers.set(++timerId,{fn,ms});return timerId;},clearTimeout:id=>timers.delete(id),setInterval(){}});
  return {elements,handlers,messages,scripts,created,markers,maps,window,timers,jq};
}
const landmark={landmark_id:'TEST',landmark_name:'Test landmark',latitude:-37.8,longitude:145};
const config={browserKey:'TEST_BROWSER',requestLimit:3,landmarks:[landmark]};
const scene={key:'TEST|600|',landmark,radius:600,cuisine:''};
const place={id:'TEST_PLACE',location:{lat:()=>-37.801,lng:()=>145}};
const lastWidget=h=>h.created.filter(x=>x.tag==='gmp-place-search').at(-1);
async function ready(h) { h.handlers['osm-init'](config); await h.window.explorerPlacesReady(); h.handlers['osm-scene'](scene); }
(async()=>{
  check(!source.includes('fetchFields(') && !source.includes('fetch('), 'No REST or fetchFields fallback');
  const missing=harness(); missing.handlers['osm-init']({...config,browserKey:''});
  check(missing.maps.length===1 && missing.scripts.length===0,'OSM works without Google key');
  const failed=harness(); failed.handlers['osm-init'](config); failed.window.gm_authFailure(); await failed.window.explorerPlacesReady();
  check(failed.elements.search.disabled && failed.maps.length===1,'Google auth failure preserves OSM and cannot be overwritten');
  const h=harness(); await ready(h); h.handlers['osm-init'](config);
  check(h.scripts.length===1,'Repeated init does not reload Google');
  check(!lastWidget(h),'Initialization and landmark selection issue no restaurant query');
  h.handlers['osm-search']({...scene,key:'STALE'});
  check(!lastWidget(h),'Search for obsolete scene ignored');
  h.handlers['osm-search'](scene); const first=lastWidget(h);
  check(first.children[1].rankPreference==='DISTANCE' && first.children[1].maxResultCount===10,'Nearby widget requests ten distance-ranked results');
  first.places=[place]; first.events['gmp-load']();
  check(h.elements['result-count'].textContent==='1 results','Search result count rendered');
  const marker=h.markers.at(-1); marker.events.click();
  const details=h.created.filter(x=>x.tag==='gmp-place-details').at(-1);
  check(details.children[0].place===place && h.maps[0].pans.length===1,'Marker selects same place and pans map');
  details.events['gmp-load']();
  check(h.elements['selected-distance'].textContent.startsWith('100 m'),'Straight-line distance displayed');
  const detailCount=h.created.filter(x=>x.tag==='gmp-place-details').length;
  first.events['gmp-select']({place});
  check(h.created.filter(x=>x.tag==='gmp-place-details').length===detailCount,'Repeated selection does not re-request details');
  const place2={id:'SECOND',location:place.location};
  first.places=[place,place2]; first.events['gmp-load'](); first.events['gmp-select']({place:place2});
  check(h.created.filter(x=>x.tag==='gmp-place-details').at(-1).children[0].place===place2,'Card selection event uses same map/detail path');
  h.handlers['osm-scene']({...scene,key:'TEST|300|',radius:300});
  check(h.elements['places-results'].children.length===0 && h.elements['places-details'].children.length===0,'Radius change clears results and details');
  first.events['gmp-load']();
  check(h.elements['result-count'].textContent==='Awaiting search','Late prior results cannot revive cleared scene');
  const next={...scene,key:'TEST|300|',radius:300};
  h.handlers['osm-search'](next); const second=lastWidget(h); second.events['gmp-error']();
  check(h.elements['live-status'].textContent.includes('No automatic retry') && !h.elements.search.disabled,'Search failure permits explicit retry');
  h.handlers['osm-search'](next); const third=lastWidget(h); third.places=[]; third.events['gmp-load']();
  check(h.elements['live-status'].textContent.startsWith('No restaurants'),'Empty result is not a fabricated restaurant');
  check(h.elements.search.disabled,'Client search cap enforced');
  const count=h.created.length; h.handlers['osm-search'](next);
  check(h.created.length===count,'Search cap prevents further widgets');
  h.jq['shiny:disconnected']();
  check(h.elements['places-results'].children.length===0 && h.elements.search.disabled,'R disconnect clears stale results and disables search');
  const sorting=harness(); await ready(sorting);
  sorting.handlers['osm-search']({...scene,rankPreference:'POPULARITY'});
  const fixedWidget=lastWidget(sorting);
  check(fixedWidget.children[1].rankPreference==='DISTANCE','Obsolete popularity payload cannot override distance ranking');
  fixedWidget.places=[place]; fixedWidget.events['gmp-load']();
  check(sorting.elements['live-status'].textContent.includes('nearest distance first') && sorting.elements['results-order'].textContent.includes('nearest distance'),
    'Result status and heading consistently show fixed distance order');
  console.log(`\n${checks} OSM adapter checks passed.`);
})().catch(e=>{console.error(e);process.exitCode=1;});
