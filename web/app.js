'use strict';
const $ = (s) => document.querySelector(s);
const panel = $('#panel'), creator = $('#creator'), placement = $('#placement');
const query = new URLSearchParams(location.search);
const world = query.has('world');
if(world) document.body.classList.add('world');
let advancedOpen=false;
let defaults={screenFade:false,maxFloors:40};
let catalog={}, revision=0, serverRevision=0, draft=null, floorIndex=0, originalId=null, busy=false, selected=null, panelData=null, toastTimer, deleteArmed=false;
const clone = (v) => JSON.parse(JSON.stringify(v));
const esc = (v='') => String(v).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
async function post(route,data={}) {
    try {
        const response=await fetch('https://'+GetParentResourceName()+'/'+route,{method:'POST',headers:{'Content-Type':'application/json; charset=UTF-8'},body:JSON.stringify(data)});
        return await response.json();
    } catch { toast('Could not communicate with the resource.'); return {ok:false}; }
}
function toast(message) {
    $('#toast').textContent=message;$('#toast').hidden=false;
    clearTimeout(toastTimer);toastTimer=setTimeout(()=>$('#toast').hidden=true,4500);
}
const statusLabel = {idle:'SELECT FLOOR',moving:'TRAVELLING'};
function renderPanel() {
    const {elevator:e}=panelData;
    const s=panelData.state||{phase:'idle'};
    const f=e.floors.find(f=>f.id===panelData.floor);
    const ordered=[...e.floors].sort((a,b)=>String(a.label).localeCompare(String(b.label),'en',{numeric:true}));
    const slots=Math.max(12,Math.ceil(ordered.length/3)*3);
    panel.style.setProperty('--slot-rows',String(slots/3));
    panel.innerHTML='<div class="display"><span class="arrows">⌄</span><strong>'+esc(/^\d+$/.test(f?.label??'')?f.label.padStart(2,'0'):(f?.label??'—'))+'</strong><span class="arrows right">⌃</span><small>'+esc(statusLabel[s.phase]??'ELEVATOR')+'</small></div><div class="floor-grid">'+ordered.map((f,i)=>'<button style="grid-row:'+ (Math.floor((slots-1-i)/3)+1)+';grid-column:'+((slots-1-i)%3+1)+'" class="floor '+(f.id===panelData.floor?'current ':'')+(f.id===selected?'pending':'')+'" data-floor="'+esc(f.id)+'" aria-label="Floor '+esc(f.label)+'" '+(f.id===panelData.floor||s.phase==='moving'?'disabled':'')+'>'+esc(f.label)+'</button>').join('')+'</div><div class="panel-foot"><span>'+esc(e.name)+'</span><button id="exit-panel">ESC · EXIT</button></div>';
    panel.querySelectorAll('[data-floor]').forEach(b=>b.onclick=()=>{selected=b.dataset.floor;renderPanel();post('selectFloor',{id:selected});});
    $('#exit-panel').onclick=()=>post('close');
}
function blankFloor(n) { return {id:'floor_'+Date.now()+'_'+n,label:String(n),spawn:null,panel:null,radius:1.4,job:'',grade:0}; }
function newLift() { advancedOpen=false;revision=serverRevision; draft={id:'elevator_'+Date.now(),name:'New elevator',bucket:0,screenFade:defaults.screenFade,floors:[blankFloor(1),blankFloor(2)]};originalId=null;floorIndex=0;deleteArmed=false;renderCreator(); }
function field(label,key,value,type='text',extra='') {
    return '<label>'+label+'<input data-field="'+key+'" type="'+type+'" value="'+esc(value??'')+'" '+extra+'></label>';
}
function posText(p) { return p?[p.x,p.y,p.z].map(v=>Number(v).toFixed(3)).join(', '):'Not configured'; }
const icons = {
    lift:'<path d="M5 3h14v18H5zM9 3v18m6-18v18M2 7l1-2 1 2m16 10 1 2 1-2"/>',
    plus:'<path d="M12 5v14M5 12h14"/>',
    close:'<path d="m6 6 12 12M18 6 6 18"/>',
    pin:'<circle cx="12" cy="12" r="5"/><path d="M12 2v5m0 10v5M2 12h5m10 0h5"/>',
    tablet:'<rect x="6" y="2" width="12" height="20" rx="2"/><path d="M10 18h4"/>',
    check:'<path d="m5 12 4 4L19 6"/>',
    trash:'<path d="M4 6h16M9 6V3h6v3M6 6l1 15h10l1-15M10 10v7m4-7v7"/>',
    chevron:'<path d="m9 5 7 7-7 7"/>',
    save:'<path d="M5 3h12l4 4v14H3V3zm2 0v6h10V3M7 21v-8h10v8"/>'
};
function icon(name) { return '<svg viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">'+icons[name]+'</svg>'; }
const readyFloor = f => Boolean(f.spawn&&f.panel);
function renderCreator(message='Changes are saved when you click Save.') {
    const entries=Object.values(catalog).sort((a,b)=>a.name.localeCompare(b.name));
    creator.innerHTML='<header class="creator-header"><div class="creator-title"><span class="creator-mark">'+icon('lift')+'</span><div><h1>Elevator creator</h1><span>NexusSync</span></div></div><button class="close" id="exit" aria-label="Close creator"><kbd>ESC</kbd>'+icon('close')+'</button></header><div class="workspace"><aside><div class="sidebar-heading"><span>Elevators</span><span class="count">'+entries.length+'</span></div><div class="lift-list">'+entries.map(e=>'<button class="lift-entry '+(e.id===originalId?'active':'')+'" data-lift="'+esc(e.id)+'">'+icon('lift')+'<span><strong>'+esc(e.name)+'</strong><small>'+e.floors.length+' floors</small></span></button>').join('')+'</div><button class="new" id="new">'+icon('plus')+'New elevator</button><p class="sidebar-note">Close with Esc to move between floors. Your draft stays here.</p></aside><section class="editor" id="editor"></section></div><footer class="footer">'+(draft?'<button class="danger" id="delete">'+icon('trash')+(deleteArmed?'Confirm delete':'Delete')+'</button>':'')+'<span class="status" id="status" role="status">'+esc(message)+'</span>'+(draft?'<button class="primary" id="save" '+(busy?'disabled':'')+'>'+icon('save')+(busy?'Saving…':'Save')+'</button>':'')+'</footer>';
    $('#exit').onclick=()=>post('close');$('#new').onclick=newLift;
    creator.querySelectorAll('[data-lift]').forEach(b=>b.onclick=()=>{advancedOpen=false;revision=serverRevision;draft=clone(catalog[b.dataset.lift]);originalId=draft.id;floorIndex=0;deleteArmed=false;renderCreator();});
    const editor=$('#editor');
    if(!draft) { editor.innerHTML='<div class="empty"><span class="empty-icon">'+icon('lift')+'</span><h2>Your next elevator starts here.</h2><p>Create an elevator, add floors<br>and place a screen inside each cabin.</p><button class="primary" id="first">'+icon('plus')+'Create elevator</button></div>';$('#first').onclick=newLift;return; }
    const f=draft.floors[floorIndex],ready=draft.floors.filter(readyFloor).length;
    editor.innerHTML='<div class="general-row">'+field('Elevator name','name',draft.name,'text','maxlength="80"')+'<label class="fade-option"><input id="screen-fade" type="checkbox" '+((draft.screenFade??defaults.screenFade)?'checked':'')+'><span class="switch" aria-hidden="true"></span><span>Black screen<small>During teleport</small></span></label></div><div class="floors-heading"><span>Floors <small>'+ready+' / '+draft.floors.length+' ready</small></span><button class="add-floor" id="add-floor">'+icon('plus')+'Add floor</button></div><div class="floor-tabs" role="tablist" aria-label="Elevator floors">'+draft.floors.map((f,i)=>'<button class="tab '+(i===floorIndex?'active':'')+'" role="tab" aria-selected="'+(i===floorIndex)+'" aria-controls="floor-settings" data-tab="'+i+'"><i class="floor-dot '+(readyFloor(f)?'ready':'')+'" aria-hidden="true"></i><span>'+esc(f.label)+'</span></button>').join('')+'</div><section class="floor-settings" id="floor-settings" role="tabpanel"><div class="floor-heading"><h2>Floor '+esc(f.label)+'</h2><span class="setup-state '+(readyFloor(f)?'ready':'')+'">'+(readyFloor(f)?'Ready':'Needs setup')+'</span><button class="icon-button remove-floor" id="remove-floor" aria-label="Remove this floor" title="Remove this floor">'+icon('trash')+'</button></div><div class="field-row">'+field('Floor label','floor.label',f.label,'text','maxlength="32"')+field('Cabin radius (m)','floor.radius',f.radius,'number','min=".5" max="3" step=".1"')+'</div><div class="capture">'+[['spawn','Arrival position','Stand inside the cabin','pin'],['panel','Preview tablet','Move and rotate in the world','tablet']].map(([k,title,sub,glyph])=>'<button data-capture="'+k+'" class="'+(f[k]?'done':'')+'">'+icon(glyph)+'<span class="capture-label"><strong>'+title+'</strong><small>'+sub+'</small></span><span class="capture-status">'+(f[k]?icon('check'):icon('plus'))+'</span></button>').join('')+'</div><details class="advanced" '+(advancedOpen?'open':'')+'><summary>'+icon('chevron')+'Advanced settings</summary><div class="advanced-body"><div class="field-row">'+field('Job (empty = public)','floor.job',f.job,'text','maxlength="48"')+field('Minimum grade','floor.grade',f.grade,'number','min="0" max="100"')+'</div>'+(f.panel?'<div class="field-row panel-dimensions">'+field('Width (m)','panel.width',f.panel.width,'number','min=".15" max="1" step=".01"')+field('Height (m)','panel.height',f.panel.height,'number','min=".3" max="1.8" step=".01"')+field('Heading (°)','panel.h',f.panel.h,'number','min="0" max="360" step=".1"')+'</div>':'')+'<div class="field-row">'+field('Elevator ID','id',draft.id,'text',originalId?'disabled':'maxlength="48"')+field('Routing bucket','bucket',draft.bucket,'number','min="0" max="65535"')+'</div><div class="coordinates"><span>Arrival <code>'+posText(f.spawn)+'</code></span><span>Screen <code>'+posText(f.panel)+'</code></span></div><p class="advanced-hint">Capture arrival facing the exit. Passengers inside the cabin radius travel together.</p></div></details></section>';
    $('#screen-fade').onchange=event=>{draft.screenFade=event.target.checked;};
    editor.querySelector('.advanced').ontoggle=event=>{advancedOpen=event.target.open;};
    editor.querySelectorAll('[data-field]').forEach(input=>input.oninput=()=>{
        const key=input.dataset.field;
        const val=input.type==='number'?Number(input.value):input.value;
        if(key.startsWith('floor.')) f[key.slice(6)]=val;
        else if(key.startsWith('panel.')) f.panel[key.slice(6)]=val;
        else draft[key]=val;
        if(key==='floor.label') { editor.querySelector('.tab.active span').textContent=val;editor.querySelector('.floor-heading h2').textContent='Floor '+val; }
    });
    editor.querySelectorAll('[data-tab]').forEach(b=>b.onclick=()=>{floorIndex=Number(b.dataset.tab);renderCreator();});
    editor.querySelector('.tab.active').scrollIntoView({block:'nearest',inline:'nearest'});
    $('#add-floor').onclick=()=>{if(draft.floors.length>=defaults.maxFloors)return toast('Maximum of '+defaults.maxFloors+' floors.');draft.floors.push(blankFloor(draft.floors.length+1));floorIndex=draft.floors.length-1;renderCreator();};
    $('#remove-floor').onclick=()=>{if(draft.floors.length<=2)return toast('At least two floors are required.');draft.floors.splice(floorIndex,1);floorIndex=Math.min(floorIndex,draft.floors.length-1);renderCreator();};
    editor.querySelectorAll('[data-capture]').forEach(b=>b.onclick=()=>post('capture',{kind:b.dataset.capture,elevator:draft,floor:f.id}));
    $('#save').onclick=async()=>{
        if(busy)return;
        if(!draft.name.trim()||!draft.id.match(/^[\w-]+$/))return toast('Enter a name and an ID without spaces.');
        const invalid=draft.floors.find(f=>!f.spawn||!f.panel);
        if(invalid)return toast('Configure the arrival position and screen for floor '+invalid.label+'.');
        busy=true;renderCreator();
        const result=await post('save',{elevator:draft,revision});
        if(!result.ok){busy=false;renderCreator('Communication failed. Try again.');}
        setTimeout(()=>{if(busy){busy=false;renderCreator('No response from the server. Check your connection and permissions.');}},8000);
    };
    $('#delete').onclick=()=>{if(!originalId){draft=null;renderCreator();return;}if(!deleteArmed){deleteArmed=true;renderCreator('Click Delete again to confirm.');return;}post('delete',{id:originalId,revision});deleteArmed=false;};
}

function receive(data) {
    switch(data.action) {
        case 'panel':
            if(!data.elevator||!data.elevator.floors)return;
            data.elevator.floors=Array.isArray(data.elevator.floors)?data.elevator.floors:Object.values(data.elevator.floors);
            panelData=data;selected=null;renderPanel();panel.hidden=false;creator.hidden=true;break;
        case 'state':if(panelData){panelData.state=data.state;renderPanel();}break;
        case 'creator':defaults={...defaults,...data.defaults};catalog=data.elevators||{};serverRevision=data.revision;if(!draft)revision=data.revision;busy=false;creator.hidden=false;panel.hidden=true;renderCreator(draft?'Draft resumed. You can close the menu to move to the next floor.':'Changes only take effect after saving.');break;
        case 'close':panel.hidden=true;creator.hidden=true;break;
        case 'toast':toast(data.message);break;
        case 'placing':creator.hidden=true;placement.hidden=false;break;
        case 'placementUpdate':$('#placement-position').textContent=posText(data.position)+' · '+Number(data.position.h).toFixed(1)+'°'+(data.fine?' · FINE ADJUSTMENT':'');break;
        case 'placementEnd':placement.hidden=true;break;
        case 'captured':
            creator.hidden=false;
            if(draft&&data.value&&['spawn','panel'].includes(data.kind)){draft.floors[floorIndex][data.kind]=data.value;}
            renderCreator();break;
        case 'saveResult':
            busy=false;
            if(data.ok){catalog=data.elevators||catalog;revision=data.revision;serverRevision=data.revision;if(draft&&catalog[draft.id])originalId=draft.id;else {draft=null;originalId=null;}}
            renderCreator(data.message);break;
    }
}
window.addEventListener('message',e=>{
    let data=e.data;
    if(typeof data==='string'){try{data=JSON.parse(data);}catch{return;}}
    if(data&&typeof data.action==='string')receive(data);
});
// Bootstrap the in-world screen before the first DUI message arrives.
if(world&&query.has('payload')){try{receive(JSON.parse(query.get('payload')));}catch(error){console.error('Panel bootstrap:',error);}}
document.addEventListener('keydown',e=>{if(e.key==='Escape'&&!world&&placement.hidden)post('close');});
