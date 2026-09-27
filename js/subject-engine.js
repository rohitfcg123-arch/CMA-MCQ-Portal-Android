
(function(){
"use strict";
const cfg=window.SUBJECT_CONFIG||{};
const questions=(window.SUBJECT_QUESTIONS||[]).map((q,i)=>({
 id:q.id??q.sl??i+1,
 q:q.q??q.question??"",
 options:q.options??q.opts??[],
 ans:Number(q.ans??q.answer??0),
 topic:q.topic||"",
 sourcePage:q.sourcePage||""
}));
let state={pool:[],index:0,selected:{},score:0,minutes:60,seconds:0,timer:null,started:false,paid:false,access:null};
const app=document.getElementById("app");
function ui(){
app.innerHTML=`
<div class="quiz-head"><div><div class="quiz-title">${esc(cfg.title||document.title)}</div><div class="quiz-sub">${esc(cfg.groupLabel||"CMA MCQ Portal")} · MCQ Practice</div></div><div class="quiz-tools"><button class="btn" id="homeBtn">← Home</button><button class="btn" id="signoutBtn">Sign out</button></div></div>
<section id="setupScreen" class="quiz-card">
<p class="muted">Choose your test size and time. The same portal rules apply to every subject.</p>
<div class="setup-card"><h2>Test Settings</h2>
<div class="form-grid"><div class="field"><label>Questions</label><select id="count"></select></div><div class="field"><label>Time (minutes)</label><select id="minutes"><option>15</option><option>30</option><option selected>60</option><option>90</option><option>120</option></select></div></div>
<div class="muted" id="accessHint" style="margin-top:12px"></div></div>
<button class="btn dark" id="startBtn">▶ Start Practice</button>
</section>
<section id="quizScreen" class="quiz-card" style="display:none">
<div class="quiz-meta"><span id="qCounter"></span><span id="timer"></span></div><div class="progress"><span id="bar"></span></div>
<div class="qnum" id="qNum"></div><div class="qtext" id="qText"></div><div class="options" id="options"></div><div id="feedback" class="feedback"></div>
<div class="quiz-actions"><button class="btn" id="prevBtn">← Previous</button><button class="btn" id="bookmarkBtn">☆ Bookmark</button><button class="btn" id="revealBtn">Reveal Answer</button><button class="btn dark" id="nextBtn">Next →</button><button class="btn danger" id="finishBtn">Submit Test</button></div>
</section>
<section id="resultScreen" class="quiz-card" style="display:none"><div class="result-score" id="score"></div><p class="muted" id="resultText" style="text-align:center"></p><div id="review" class="review-item"></div><div class="quiz-actions"><button class="btn dark" id="restartBtn">Practice Again</button><button class="btn" id="resultHomeBtn">Home</button></div></section>
<div id="premiumModal" class="modal-backdrop"><div class="modal"><h2>🔒 Free Practice Limit Reached</h2><p id="premiumMessage">You have reached the free practice limit. Continue with the Premium Plan to access more questions.</p><div class="modal-actions"><button class="btn gold" id="buyBtn">Buy Premium Plan</button><button class="btn" id="continueFreeBtn">Continue with Free Version</button></div></div></div>`;
document.getElementById("homeBtn").onclick=()=>location.href="index.html";
document.getElementById("resultHomeBtn").onclick=()=>location.href="index.html";
document.getElementById("signoutBtn").onclick=()=>CMA_AUTH.signOut().then(()=>location.href="index.html");
document.getElementById("buyBtn").onclick=()=>location.href="payment.html";
document.getElementById("continueFreeBtn").onclick=()=>document.getElementById("premiumModal").style.display="none";
}
function fillSetup(){
const s=document.getElementById("count");s.innerHTML="";
[10,20,30,50,100].forEach(n=>{if(n<=questions.length){const o=document.createElement("option");o.value=n;o.textContent=n+" questions";s.appendChild(o)}});
const all=document.createElement("option");all.value=questions.length;all.textContent="All "+questions.length+" questions";s.appendChild(all);s.value=Math.min(20,questions.length);
}
async function refreshHint(){
const a=await getAccessState(cfg.group);state.access=a;
const h=document.getElementById("accessHint");
if(a.admin||a.paid)h.textContent="Premium access: full question bank available.";
else if(a.attemptLimit)h.textContent=`Free attempts remaining: ${a.freeRemaining}.`;
else h.textContent=`Free question limit: first ${a.poolSize} questions. Premium is required after that.`;
}
async function start(){
const a=await getAccessState(cfg.group);state.access=a;
if(!a.allowed){openPremium(a.reason);return}
state.paid=!!a.paid;
if(a.attemptLimit)await recordAttempt(cfg.group,cfg.title);
const count=Number(document.getElementById("count").value);
state.pool=questions.slice(0,count);state.index=0;state.selected={};state.score=0;state.minutes=Number(document.getElementById("minutes").value);state.seconds=state.minutes*60;state.started=true;
document.getElementById("setupScreen").style.display="none";document.getElementById("quizScreen").style.display="block";renderQuestion();startTimer();
}
function startTimer(){clearInterval(state.timer);state.timer=setInterval(()=>{state.seconds--;if(state.seconds<=0){clearInterval(state.timer);finish(true)}renderTimer()},1000);renderTimer()}
function renderTimer(){const m=Math.floor(state.seconds/60),s=state.seconds%60;document.getElementById("timer").textContent=`Time: ${String(m).padStart(2,"0")}:${String(s).padStart(2,"0")}`}
function renderQuestion(){
const q=state.pool[state.index];if(!q)return;
document.getElementById("qCounter").textContent=`Question ${state.index+1} of ${state.pool.length}`;
document.getElementById("qNum").textContent=`Q${q.id}${q.topic?" · "+q.topic:""}`;
document.getElementById("qText").textContent=q.q;
document.getElementById("bar").style.width=((state.index+1)/state.pool.length*100)+"%";
const box=document.getElementById("options");box.innerHTML="";
q.options.forEach((opt,i)=>{const lab=document.createElement("label");lab.className="option";lab.innerHTML=`<input type="radio" name="answer" value="${i}"><span>${esc(opt)}</span>`;const inp=lab.querySelector("input");if(state.selected[q.id]===i)inp.checked=true;inp.onchange=()=>{state.selected[q.id]=i;showFeedback(false)};box.appendChild(lab)});
document.getElementById("prevBtn").disabled=state.index===0;
document.getElementById("nextBtn").textContent=state.index===state.pool.length-1?"Finish →":"Next →";
document.getElementById("feedback").className="feedback";
}
function showFeedback(reveal){const q=state.pool[state.index],fb=document.getElementById("feedback");if(!reveal){fb.className="feedback";return}const chosen=state.selected[q.id];fb.className="feedback show "+(chosen===q.ans?"good":"bad");fb.textContent=chosen===q.ans?"Correct answer.":`Correct answer: ${q.options[q.ans]}`;document.querySelectorAll(".option").forEach((e,i)=>{e.classList.toggle("correct",i===q.ans);e.classList.toggle("wrong",chosen!==undefined&&i===chosen&&chosen!==q.ans)})}
async function next(){
if(state.index>=state.pool.length-1){finish(false);return}
if(!state.paid&&state.access?.fixedPool&&state.index+1>=state.access.poolSize){openPremium(`Your free version allows ${state.access.poolSize} questions. Buy Premium to continue beyond Q${state.access.poolSize}.`);return}
state.index++;renderQuestion();
}
function prev(){if(state.index>0){state.index--;renderQuestion()}}
function openPremium(msg){document.getElementById("premiumMessage").textContent=msg||"Free practice limit reached. Please buy a Premium Plan.";document.getElementById("premiumModal").style.display="flex"}
function finish(timeout){
clearInterval(state.timer);let score=0;state.pool.forEach(q=>{if(state.selected[q.id]===q.ans)score++});state.score=score;document.getElementById("quizScreen").style.display="none";document.getElementById("resultScreen").style.display="block";document.getElementById("score").textContent=`${score} / ${state.pool.length}`;document.getElementById("resultText").textContent=timeout?"Time ended. Your attempted answers have been submitted.":"Test submitted.";
const r=document.getElementById("review");r.innerHTML=state.pool.map(q=>{const c=state.selected[q.id];return `<div class="review-item"><strong>Q${q.id}.</strong> ${esc(q.q)}<br><span class="muted">Your answer: ${c===undefined?"Not answered":esc(q.options[c])}<br>Correct: ${esc(q.options[q.ans])}</span></div>`}).join("")}
function reveal(){showFeedback(true)}
function bookmark(){const q=state.pool[state.index];const key="cma_bookmarks";let a=JSON.parse(localStorage.getItem(key)||"[]");const exists=a.some(x=>x.subject===cfg.id&&x.id===q.id);if(exists)a=a.filter(x=>!(x.subject===cfg.id&&x.id===q.id));else a.push({subject:cfg.id,id:q.id,title:q.q});localStorage.setItem(key,JSON.stringify(a));document.getElementById("bookmarkBtn").textContent=exists?"☆ Bookmark":"★ Bookmarked"}
function finishNow(){finish(false)}
ui();fillSetup();refreshHint();document.getElementById("startBtn").onclick=start;document.getElementById("nextBtn").onclick=next;document.getElementById("prevBtn").onclick=prev;document.getElementById("revealBtn").onclick=reveal;document.getElementById("bookmarkBtn").onclick=bookmark;document.getElementById("finishBtn").onclick=finishNow;document.getElementById("restartBtn").onclick=()=>{document.getElementById("resultScreen").style.display="none";document.getElementById("setupScreen").style.display="block";refreshHint()};
})();
