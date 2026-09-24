(function(){
"use strict";
const TERMS=["June 2026","December 2025","June 2025","December 2024","June 2024"];
const path=location.pathname.split("/").pop();
const byPath=window.CMA_FINAL_PYQ||{};
const entry=Object.values(byPath).find(x=>x.path===path);
if(!entry||!entry.rows||entry.rows.length<75)return;
const paper=(entry.rows[0].id||"").split("-")[0];
const group=paper==="P13"||paper==="P14"||paper==="P15"||paper==="P16"?"Group 3":"Group 4";
const accent=group==="Group 3"?"#0b6e69":"#7a5c16";
const storageKey="cma_final_pyq_"+paper+"_v1";
let state={source:"bank",term:"all",count:75,marks:2,instant:false,timer:false,seconds:60,random:true,mode:"all"};
let pool=[],index=0,score=0,answers=[],timer=null,wrongSet=new Set(),bookSet=new Set();
try{Object.assign(state,JSON.parse(localStorage.getItem(storageKey)||"{}"));}catch(e){}
try{const x=JSON.parse(localStorage.getItem(storageKey+"_flags")||"{}");wrongSet=new Set(x.wrong||[]);bookSet=new Set(x.book||[]);}catch(e){}
function save(){try{localStorage.setItem(storageKey,JSON.stringify(state));localStorage.setItem(storageKey+"_flags",JSON.stringify({wrong:[...wrongSet],book:[...bookSet]}));}catch(e){}}
function esc(s){return String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));}
function rowsFor(term){let r=entry.rows.slice();if(term&&term!=="all")r=r.filter(q=>q.pyqTerm===term);if(state.mode==="wrong")r=r.filter(q=>wrongSet.has(q.id));if(state.mode==="book")r=r.filter(q=>bookSet.has(q.id));return r;}
function root(){return document.querySelector(".app,.wrap")||document.body;}
function inject(){
 const r=root(), hero=r.querySelector(".hero,.masthead");
 const source=document.createElement("section");source.id="finalPyqSource";source.className="final-pyq-source";
 source.innerHTML='<div class="fpyq-source-head"><div><div class="fpyq-kicker">'+group+' · '+paper+'</div><h2>Question Source</h2><p>Switch between the existing MCQ Bank and Previous Year Paper practice.</p></div><select id="fpyqSource"><option value="bank">MCQ Bank</option><option value="pyq">Previous Year Paper</option></select></div>';
 const panel=document.createElement("section");panel.id="finalPyqPanel";panel.className="final-pyq-panel";
 panel.innerHTML='<div class="fpyq-hero"><div><span class="fpyq-badge">'+group+' · '+paper+'</span><h2>Previous Year Paper</h2><p>75 PYQ-based practice questions across 5 attempts.</p></div><div class="fpyq-total">75</div></div>'+
 '<div class="fpyq-card"><label>Attempt / Year</label><select id="fpyqTerm"><option value="all">All Attempts — 75 Questions</option>'+TERMS.map(t=>'<option value="'+t+'">'+t+' — 15 Questions</option>').join("")+'</select></div>'+
 '<div class="fpyq-quick"><button id="fpyqWrong">↻ Reattempt Wrong <span></span></button><button id="fpyqBook">★ Bookmarked <span></span></button></div>'+
 '<div class="fpyq-card"><div class="fpyq-row"><div><b>Number of questions</b><small>Choose how many questions to attempt.</small></div><div class="fpyq-step"><button id="fpyqDown">−</button><strong id="fpyqCount">75</strong><button id="fpyqUp">+</button></div></div><div class="fpyq-row"><div><b>Marks per question</b><small>Previous-year style: 2 marks.</small></div><strong>2</strong></div><div class="fpyq-row"><div><b>Answer mode</b><small>Choose when the correct answer is revealed.</small></div><select id="fpyqInstant"><option value="0">After submission / Next</option><option value="1">Immediately</option></select></div><div class="fpyq-row"><div><b>Question timer</b><small>Optional countdown for each question.</small></div><label class="fpyq-switch"><input id="fpyqTimer" type="checkbox"><span></span></label></div><div class="fpyq-row" id="fpyqSecondsRow" style="display:none"><div><b>Seconds per question</b></div><input id="fpyqSeconds" type="number" min="10" max="300" value="60"></div></div>'+
 '<button class="fpyq-start" id="fpyqStart">Start Previous Year Paper</button>'+
 '<div class="fpyq-note">Note: These are PYQ-based/paraphrased practice items mapped to the five recent exam terms, not verbatim reproduction of official question papers.</div>'+
 '<div id="fpyqQuiz" style="display:none"></div>';
 if(hero)hero.insertAdjacentElement("afterend",source);else r.insertBefore(source,r.firstChild);
 source.insertAdjacentElement("afterend",panel);
 const style=document.createElement("style");style.textContent=
 '#finalPyqSource,#finalPyqPanel{--fpya:'+accent+';font-family:Inter,system-ui,-apple-system,Segoe UI,Roboto,Arial,sans-serif}'+
 '#finalPyqSource{background:var(--card,#fff);border:1px solid var(--line,#dfe5ea);border-radius:16px;padding:16px;margin:14px 0;box-shadow:0 5px 18px rgba(0,0,0,.04)}'+
 '.fpyq-source-head{display:flex;justify-content:space-between;align-items:center;gap:14px}.fpyq-kicker{font-size:11px;font-weight:800;letter-spacing:.08em;text-transform:uppercase;color:var(--fpya)}.fpyq-source-head h2{margin:4px 0;font-size:18px}.fpyq-source-head p{margin:0;color:#6c7378;font-size:12px}.fpyq-source-head select,#finalPyqPanel select,#finalPyqPanel input[type=number]{padding:10px;border:1px solid #d9dee2;border-radius:10px;background:#fff;font:inherit;min-width:190px}'+
 '#finalPyqPanel{display:none;background:var(--card,#fff);border:1px solid var(--line,#dfe5ea);border-radius:16px;padding:16px;margin:14px 0;box-shadow:0 8px 24px rgba(0,0,0,.05)}'+
 'body.final-pyq-active #finalPyqPanel{display:block}body.final-pyq-active #finalPyqSource{border-color:var(--fpya)}body.final-pyq-active .app>*:not(.hero):not(.nav):not(.top):not(#finalPyqSource):not(#finalPyqPanel),body.final-pyq-active .wrap>*:not(.masthead):not(.hero):not(#finalPyqSource):not(#finalPyqPanel){display:none!important}'+
 'body.final-pyq-active .final-pyq-hide{display:none!important}'+
 '.fpyq-hero{display:flex;justify-content:space-between;gap:12px;align-items:center;background:linear-gradient(135deg,var(--fpya),#123b3d);color:#fff;border-radius:14px;padding:16px}.fpyq-hero h2{margin:5px 0;font-size:20px}.fpyq-hero p{margin:0;opacity:.84;font-size:12px}.fpyq-badge{font-size:10px;font-weight:800;letter-spacing:.08em;text-transform:uppercase}.fpyq-total{font-size:30px;font-weight:900}.fpyq-card{background:#f8fafb;border:1px solid #e1e6e9;border-radius:13px;padding:14px;margin-top:12px}.fpyq-card>label{display:block;font-size:12px;font-weight:800;color:#59636a;margin-bottom:6px}.fpyq-card select{width:100%;min-width:0}.fpyq-quick{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin:12px 0}.fpyq-quick button{padding:11px;border:1px solid #d9dee2;background:#fff;border-radius:10px;font-weight:800;color:#334047}.fpyq-row{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:11px 0;border-bottom:1px solid #e5e9eb}.fpyq-row:last-child{border-bottom:0}.fpyq-row small{display:block;color:#7a8389;margin-top:3px}.fpyq-step{display:flex;align-items:center;gap:10px}.fpyq-step button{width:36px;height:36px;border-radius:10px;border:1px solid #d4dade;background:#fff;font-size:20px}.fpyq-step strong{min-width:30px;text-align:center}.fpyq-switch input{display:none}.fpyq-switch span{display:block;width:44px;height:24px;border-radius:99px;background:#cbd2d6;position:relative}.fpyq-switch span:after{content:"";position:absolute;width:18px;height:18px;top:3px;left:3px;background:#fff;border-radius:50%;transition:.15s}.fpyq-switch input:checked+span{background:var(--fpya)}.fpyq-switch input:checked+span:after{left:23px}.fpyq-start{width:100%;margin-top:14px;padding:13px;border:0;border-radius:11px;background:var(--fpya);color:#fff;font-weight:900;font-size:15px}.fpyq-note{margin-top:10px;font-size:11px;color:#7a8389;line-height:1.5}.fpyq-qbar{display:flex;justify-content:space-between;gap:8px;align-items:center;font-size:12px;color:#667078}.fpyq-q{font-size:18px;line-height:1.5;margin:15px 0}.fpyq-opt{width:100%;text-align:left;padding:12px;margin:7px 0;border:1px solid #dce2e5;border-radius:11px;background:#fff}.fpyq-opt.correct{border-color:#3d8a5d;background:#eaf6ee}.fpyq-opt.wrong{border-color:#b94c43;background:#fff0ee}.fpyq-explain{padding:12px;border-radius:11px;background:#eef5f4;margin-top:12px;font-size:13px;line-height:1.5}.fpyq-nav{display:flex;gap:9px;margin-top:13px}.fpyq-nav button{flex:1;padding:11px;border-radius:10px;border:1px solid #d5dce0;background:#fff;font-weight:800}.fpyq-nav .primary{background:var(--fpya);color:#fff;border-color:var(--fpya)}.fpyq-bookmark{float:right;border:0;background:transparent;font-size:20px}.fpyq-result{text-align:center;padding:20px}.fpyq-result h3{font-size:26px;margin:4px}.fpyq-result p{color:#69747a}'+
 '@media(max-width:560px){.fpyq-source-head{align-items:stretch;flex-direction:column}.fpyq-source-head select{min-width:0;width:100%}.fpyq-quick{grid-template-columns:1fr}.fpyq-row{align-items:flex-start}.fpyq-hero{padding:14px}}';
 document.head.appendChild(style);
 return source,panel;
}
function accessCheck(){
 return new Promise(async resolve=>{
   try{
     const auth=window.firebase&&firebase.auth?firebase.auth():null,db=window.firebase&&firebase.firestore?firebase.firestore():null;
     const u=auth&&auth.currentUser;
     if(!u){resolve({ok:false,msg:"Please login first to open Previous Year Paper practice."});return;}
     const email=(u.email||"").trim().toLowerCase();
     if(email==="rohit.fcg123@gmail.com"){resolve({ok:true});return;}
     const snap=await db.collection("access").doc(email).get(),d=snap.exists?snap.data()||{}:{};
     const set=await db.collection("settings").doc("access").get(),s=set.exists?set.data()||{}:{};
     const today=new Date().toISOString().slice(0,10),exp=String(d.expiryDate||"");
     if(exp&&exp<today){resolve({ok:false,msg:"Your access has expired. Please renew to use Previous Year Paper practice."});return;}
     const universal=d.universalFull===true||d.universalFree===true||d.fullAccess===true||d.freeFullAccess===true||String(d.accessType||"").toLowerCase()==="all";
     const groups=Array.isArray(d.groups)?d.groups:[];
     const paid=groups.includes("final-group-3")||groups.includes("final-group-4")||groups.includes("final");
     const feature=d.overrides&&d.overrides.pyq!==undefined?!!d.overrides.pyq:(s.features&&s.features.pyq!==undefined?!!s.features.pyq:false);
     resolve({ok:!!(universal||paid||feature||s.siteWideFree),msg:"Previous Year Paper practice requires premium/full access."});
   }catch(e){console.warn("PYQ access check failed",e);resolve({ok:false,msg:"Could not verify access right now. Please try again."});}
 });
}
function refreshCounts(){
 const term=document.getElementById("fpyqTerm").value;
 const avail=rowsFor(term);const max=avail.length||1;
 state.count=Math.min(Math.max(5,Number(state.count)||75),max);
 document.getElementById("fpyqCount").textContent=state.count;
 document.querySelector("#fpyqWrong span").textContent="("+wrongSet.size+")";
 document.querySelector("#fpyqBook span").textContent="("+bookSet.size+")";
}
function renderSetup(){
 document.getElementById("fpyqQuiz").style.display="none";
 const controls=[...document.querySelectorAll("#finalPyqPanel>.fpyq-card,#finalPyqPanel>.fpyq-quick,#finalPyqPanel>.fpyq-start,#finalPyqPanel>.fpyq-note")];
 controls.forEach(x=>x.style.display="");
 document.querySelector("#finalPyqPanel .fpyq-hero").style.display="";
 refreshCounts();
}
function start(mode){
 accessCheck().then(res=>{
   if(!res.ok){if(typeof cmaShowAccessPopup==="function")cmaShowAccessPopup(res.msg);else alert(res.msg);return;}
   state.mode=mode||"all";const term=document.getElementById("fpyqTerm").value;
   let avail=rowsFor(term);
   if(!avail.length){alert(state.mode==="wrong"?"No wrong PYQ questions saved yet.":"No questions available for this selection.");return;}
   const n=Math.min(Number(state.count)||75,avail.length);
   if(state.random)avail=avail.sort(()=>Math.random()-.5);
   pool=avail.slice(0,n);index=0;score=0;answers=[];renderQ();save();
 });
}
function renderQ(){
 const q=pool[index],quiz=document.getElementById("fpyqQuiz");quiz.style.display="block";
 [...document.querySelectorAll("#finalPyqPanel>.fpyq-card,#finalPyqPanel>.fpyq-quick,#finalPyqPanel>.fpyq-start,#finalPyqPanel>.fpyq-note,#finalPyqPanel .fpyq-hero")].forEach(x=>x.style.display="none");
 const marked=bookSet.has(q.id);
 quiz.innerHTML='<div class="fpyq-qbar"><span>Question '+(index+1)+' / '+pool.length+' · '+esc(q.pyqTerm)+'</span><span>'+esc(q.chapter)+'</span></div>'+
 '<button class="fpyq-bookmark" id="fpyqBookmark">'+(marked?"★":"☆")+'</button><div class="fpyq-q">'+esc(q.q)+'</div>'+
 '<div>'+q.options.map((o,i)=>'<button class="fpyq-opt" data-i="'+i+'"><b>'+String.fromCharCode(65+i)+'.</b> '+esc(o)+'</button>').join("")+'</div>'+
 '<div id="fpyqExplain"></div><div class="fpyq-nav"><button id="fpyqExit">Exit</button><button class="primary" id="fpyqNext" disabled>'+(index===pool.length-1?"Submit":"Next")+'</button></div>';
 let selected=null,locked=false;
 const opts=[...quiz.querySelectorAll(".fpyq-opt")];
 function choose(i){
   if(locked)return;selected=i;answers[index]=i;
   opts.forEach((b,j)=>{b.disabled=true;if(j===q.answer)b.classList.add("correct");if(j===i&&i!==q.answer)b.classList.add("wrong");});
   if(i!==q.answer)wrongSet.add(q.id);else wrongSet.delete(q.id);
   locked=true;score+=i===q.answer?2:0;
   if(state.instant||index===pool.length-1) document.getElementById("fpyqExplain").innerHTML='<div class="fpyq-explain"><b>Explanation:</b> '+esc(q.explanation)+'</div>';
   document.getElementById("fpyqNext").disabled=false;save();
 }
 opts.forEach(b=>b.onclick=()=>choose(Number(b.dataset.i)));
 document.getElementById("fpyqBookmark").onclick=()=>{if(bookSet.has(q.id))bookSet.delete(q.id);else bookSet.add(q.id);document.getElementById("fpyqBookmark").textContent=bookSet.has(q.id)?"★":"☆";save();};
 document.getElementById("fpyqNext").onclick=()=>{if(index<pool.length-1){index++;renderQ();}else finish();};
 document.getElementById("fpyqExit").onclick=()=>{clearInterval(timer);renderSetup();};
 if(state.timer){let left=Number(state.seconds)||60;const bar=document.createElement("div");bar.className="fpyq-explain";bar.id="fpyqTimerBox";bar.textContent="⏱ "+left+" sec";quiz.prepend(bar);clearInterval(timer);timer=setInterval(()=>{left--;const el=document.getElementById("fpyqTimerBox");if(el)el.textContent="⏱ "+left+" sec";if(left<=0){clearInterval(timer);if(!locked){answers[index]=null;wrongSet.add(q.id);locked=true;opts.forEach(b=>b.disabled=true);document.getElementById("fpyqExplain").innerHTML='<div class="fpyq-explain"><b>Time up.</b> '+esc(q.explanation)+'</div>';document.getElementById("fpyqNext").disabled=false;}}},1000);}
}
function finish(){
 clearInterval(timer);const correct=answers.filter((a,i)=>a===pool[i].answer).length;const attempted=answers.filter(a=>a!==undefined&&a!==null).length;
 document.getElementById("fpyqQuiz").innerHTML='<div class="fpyq-result"><div class="fpyq-kicker">Round Complete</div><h3>'+correct+' / '+pool.length+'</h3><p>Marks: '+(correct*2)+' / '+(pool.length*2)+' · Attempted: '+attempted+'</p><div class="fpyq-nav"><button id="fpyqBack">Back to PYQ setup</button><button class="primary" id="fpyqAgain">New round</button></div></div>';
 document.getElementById("fpyqBack").onclick=()=>renderSetup();document.getElementById("fpyqAgain").onclick=()=>start("all");
 save();
}
function init(){
 const source=root(),refs=inject();const sel=document.getElementById("fpyqSource");
 sel.value=state.source==="pyq"?"pyq":"bank";
 const setMode=()=>{state.source=sel.value;document.body.classList.toggle("final-pyq-active",sel.value==="pyq");save();if(sel.value==="pyq")renderSetup();};
 sel.onchange=setMode;
 document.getElementById("fpyqTerm").value=state.term||"all";
 document.getElementById("fpyqTerm").onchange=e=>{state.term=e.target.value;state.mode="all";refreshCounts();save();};
 document.getElementById("fpyqDown").onclick=()=>{state.count=Math.max(5,(Number(state.count)||75)-5);refreshCounts();save();};
 document.getElementById("fpyqUp").onclick=()=>{state.count=Math.min(75,(Number(state.count)||75)+5);refreshCounts();save();};
 document.getElementById("fpyqInstant").onchange=e=>{state.instant=e.target.value==="1";save();};
 document.getElementById("fpyqTimer").onchange=e=>{state.timer=e.target.checked;document.getElementById("fpyqSecondsRow").style.display=state.timer?"flex":"none";save();};
 document.getElementById("fpyqSeconds").onchange=e=>{state.seconds=Math.max(10,Math.min(300,Number(e.target.value)||60));save();};
 document.getElementById("fpyqStart").onclick=()=>start("all");
 document.getElementById("fpyqWrong").onclick=()=>start("wrong");
 document.getElementById("fpyqBook").onclick=()=>start("book");
 refreshCounts();
 if(state.source==="pyq")setMode();
}
if(document.readyState==="loading")document.addEventListener("DOMContentLoaded",init);else init();
})();