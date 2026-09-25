/* CMA Portal Central Access Controller */
(function(){'use strict';
const ADMIN_EMAIL='rohit.fcg123@gmail.com';
const DEFAULTS={freeAccessMode:'fixedPool',freeQuestionLimit:20,freeAttemptLimit:5,freeTestMinutes:60,freeQuestionSeconds:0,siteWideFree:false,features:{mcqBank:true,pyq:false,reattemptWrong:false,bookmark:true,chapterTopic:true,answerReveal:true,overallTimer:true,questionTimer:false}};
const norm=v=>String(v||'').trim().toLowerCase();
function getAuth(){return window.CMA_AUTH||window.auth||(window.firebase&&firebase.auth?firebase.auth():null)}
function getDb(){return window.CMA_DB||window.db||(window.firebase&&firebase.firestore?firebase.firestore():null)}
async function getSettings(){const db=getDb();if(!db)return DEFAULTS;try{const s=await db.collection('settings').doc('access').get();const d=s.exists?s.data():{};return Object.assign({},DEFAULTS,d,{features:Object.assign({},DEFAULTS.features,d.features||d.freeFeatures||{})})}catch(e){return DEFAULTS}}
async function getUserAccess(user){if(!user||!user.email)return{allowed:false,reason:'Please sign in to continue.'};const email=norm(user.email),settings=await getSettings();if(email===ADMIN_EMAIL)return{allowed:true,admin:true,paid:true,settings,overrides:{},accessType:'all'};const db=getDb();let data={};if(db){try{const s=await db.collection('access').doc(email).get();if(s.exists)data=s.data()||{}}catch(e){}}if(String(data.status||'active').toLowerCase()==='inactive')return{allowed:false,reason:'Your account is currently inactive.',data,settings,overrides:data.overrides||{}};const expiry=String(data.expiryDate||''),expired=!!expiry&&expiry<new Date().toISOString().slice(0,10),groups=Array.isArray(data.groups)?data.groups:[];if((data.universalFull===true||data.universalFree===true||String(data.accessType||'').toLowerCase()==='all')&&!expired)return{allowed:true,paid:true,expired:false,data,settings,overrides:data.overrides||{},groups,accessType:'all'};return{allowed:true,paid:groups.length>0&&!expired,expired,data,settings,overrides:data.overrides||{},groups,accessType:data.accessType||'partial'}}
function featureAllowed(a,f,freeDefault){if(!a)return freeDefault!==false;if(a.admin||a.paid)return true;const o=a.overrides||{},g=a.settings?.features||{};if(Object.prototype.hasOwnProperty.call(o,f))return o[f]!==false;if(Object.prototype.hasOwnProperty.call(g,f))return g[f]!==false;return freeDefault!==false}
function value(a,key,def){if(!a||a.admin||a.paid)return Infinity;return Number((a.overrides||{})[key]??a.settings?.[key]??def)}
function questionLimit(a){return value(a,'freeQuestionLimit',DEFAULTS.freeQuestionLimit)}
function attemptLimit(a){return value(a,'freeAttemptLimit',DEFAULTS.freeAttemptLimit)}

function closeAccessPopup(){const p=document.getElementById('cmaAccessPopup');if(p)p.remove()}
function continueWithFreeVersion(limit){closeAccessPopup();const selects=[...document.querySelectorAll('select,input[type="number"],input[type="range"]')];const target=selects.find(el=>{const t=textOf(el);return t.includes('question')||t.includes('count')||t.includes('mcq')||t.includes('number')});if(target){if(target.tagName==='SELECT'){const opts=[...target.options];const match=opts.find(o=>Number(o.value)===Number(limit))||opts.find(o=>Number(o.textContent.replace(/[^0-9]/g,''))===Number(limit));if(match)target.value=match.value;else target.value=String(limit)}else target.value=String(limit);target.dispatchEvent(new Event('input',{bubbles:true}));target.dispatchEvent(new Event('change',{bubbles:true}))}}
function showPopup(message,options){
  if(typeof window.cmaShowAccessPopup==='function')return window.cmaShowAccessPopup(message,options);
  if(typeof window.openPremium==='function')return window.openPremium(message,options);
  const old=document.getElementById('cmaAccessPopup');if(old)old.remove();
  const isLimit=options&&options.questionLimit;
  const limit=isLimit?Number(options.questionLimit):null;
  const selected=isLimit?Number(options.selectedQuestions):null;
  const overlay=document.createElement('div');overlay.id='cmaAccessPopup';overlay.style.cssText='position:fixed;inset:0;z-index:10000;background:rgba(8,38,39,.62);backdrop-filter:blur(4px);display:flex;align-items:center;justify-content:center;padding:18px';
  overlay.innerHTML='<div style="width:min(430px,100%);background:#fffdf8;border:1px solid #e3dbc9;border-radius:19px;padding:25px;box-shadow:0 25px 70px rgba(0,0,0,.25);font-family:Inter,Segoe UI,Arial,sans-serif;color:#22302f"><div style="width:46px;height:46px;border-radius:13px;background:#0d3b3e;color:#ead39b;display:grid;place-items:center;font-size:21px;font-weight:900;margin-bottom:13px">C</div><h2 style="margin:0 0 8px;color:#082627;font-size:21px">Buy subscription to avail this</h2><p style="margin:0 0 8px;color:#65716f;font-size:13px;line-height:1.55">'+(isLimit?'You selected <b>'+selected+' questions</b>, but the current free version is limited to <b>'+limit+' questions</b>. The '+limit+'-question free-access rule is why this option is unavailable.':'This option is available with a subscription.')+'</p>'+(isLimit?'<p style="margin:0 0 18px;color:#7b6a38;font-size:12px;font-weight:800">Question-limit rule: maximum '+limit+' questions in the free version.</p>':'')+'<div style="display:flex;gap:9px;flex-wrap:wrap"><a href="payment.html" style="flex:1;min-width:170px;text-align:center;text-decoration:none;background:#c8a24a;color:#082627;border:1px solid #c8a24a;border-radius:10px;padding:11px 13px;font-weight:850">Buy Subscription</a>'+(isLimit?'<button type="button" id="cmaContinueFree" style="flex:1;min-width:170px;background:#fff;border:1px solid #e3dbc9;color:#0d3b3e;border-radius:10px;padding:11px 13px;font-weight:850">Continue with free version</button>':'')+'</div><button type="button" id="cmaCloseAccessPopup" style="display:block;margin:13px auto 0;border:0;background:transparent;color:#65716f;font-size:12px">Cancel</button></div>';
  document.body.appendChild(overlay);
  document.getElementById('cmaCloseAccessPopup').onclick=closeAccessPopup;
  if(isLimit)document.getElementById('cmaContinueFree').onclick=()=>continueWithFreeVersion(limit);
  overlay.addEventListener('click',e=>{if(e.target===overlay)closeAccessPopup()});
}
async function canUse(feature,freeDefault){const a=await getUserAccess(getAuth()?.currentUser);if(!a.allowed){showPopup(a.reason);return false}if(!featureAllowed(a,feature,freeDefault)){showPopup('This feature is not included in your current access. Please buy a subscription to continue.');return false}return true}
window.CMAAccessController={getSettings,getUserAccess,featureAllowed,questionLimit,attemptLimit,showPopup,canUse};
window.cmaAccessState=null;
async function initState(){try{const auth=getAuth();if(!auth)return;const u=auth.currentUser;if(u)window.cmaAccessState=await getUserAccess(u);auth.onAuthStateChanged(async user=>{window.cmaAccessState=await getUserAccess(user);});}catch(e){}}
function textOf(el){return ((el?.textContent||'')+' '+(el?.id||'')+' '+(el?.name||'')+' '+(el?.value||'')).toLowerCase()}
function selectedQuestionCount(){let vals=[];document.querySelectorAll('select,input[type="number"],input[type="range"]').forEach(el=>{const t=textOf(el);const n=Number(el.value);if(Number.isFinite(n)&&n>0&&(t.includes('question')||t.includes('count')||t.includes('mcq')||t.includes('number')))vals.push(n)});return vals.length?Math.max(...vals):null}
function featureFromClick(btn){const t=textOf(btn);if(t.includes('pyq'))return'pyq';if(t.includes('mcq bank')||t.includes('mcqbank'))return'mcqBank';if(t.includes('reattempt wrong')||t.includes('wrong answers'))return'reattemptWrong';if(t.includes('bookmark'))return'bookmark';if(t.includes('chapter')||t.includes('topic'))return'chapterTopic';if(t.includes('reveal answer')||t.includes('show answer')||t.includes('instant answer'))return'answerReveal';if(t.includes('question-wise timer')||t.includes('question timer'))return'questionTimer';if(t.includes('overall timer')||t.includes('test timer'))return'overallTimer';return null}
function looksLikeStart(btn){const t=textOf(btn);return t.includes('start practice')||t==='start'||t.includes('start test')||t.includes('begin test')||t.includes('start quiz')}
document.addEventListener('click',function(e){const btn=e.target.closest('button,a');if(!btn)return;const a=window.cmaAccessState;if(!a||a.admin||a.paid)return;const f=featureFromClick(btn);if(f&&!featureAllowed(a,f,DEFAULTS.features[f])){e.preventDefault();e.stopImmediatePropagation();showPopup(f+' is not included in your current access. Please buy a subscription to continue.');return}if(looksLikeStart(btn)){const lim=questionLimit(a),count=selectedQuestionCount();if(Number.isFinite(lim)&&count&&count>lim){e.preventDefault();e.stopImmediatePropagation();showPopup('',{questionLimit:lim,selectedQuestions:count});return}if(Number.isFinite(attemptLimit(a))&&attemptLimit(a)<=0){e.preventDefault();e.stopImmediatePropagation();showPopup('Your free attempts are exhausted. Please buy a subscription to continue.');return}}},true);
initState();window.dispatchEvent(new CustomEvent('cma-access-controller-ready'));
})();
/* UPDATE 6 — unified subject screen routing
   Keep setup, quiz and result as separate full screens even on legacy subject templates.
   Some older pages reveal quiz/result with inline display without removing the setup screen. */
(function(){
  'use strict';
  function visible(el){
    if(!el) return false;
    const s=getComputedStyle(el);
    const r=el.getBoundingClientRect();
    return s.display!=='none' && s.visibility!=='hidden' && (r.width>0 || r.height>0);
  }
  function hideScreen(el){
    if(!el)return;
    el.classList.remove('active');
    el.style.setProperty('display','none','important');
  }
  function showScreen(el){
    if(!el)return;
    el.classList.add('active');
    el.style.removeProperty('display');
  }
  function routeSubjectScreens(){
    if(new URLSearchParams(location.search).get('cmaQuiz')==='1') return;
    const setup=document.getElementById('setup')||document.getElementById('setupScreen');
    const quiz=document.getElementById('quiz')||document.getElementById('quizScreen');
    const result=document.getElementById('results')||document.getElementById('resultScreen');
    if(!setup&&!quiz&&!result)return;
    if(result && (result.classList.contains('active') || visible(result) && !!(result.querySelector('.score,.score-num,#score,#finalScore,.results')))){
      hideScreen(setup); hideScreen(quiz); showScreen(result); return;
    }
    if(quiz && (quiz.classList.contains('active') || visible(quiz) && !!(quiz.querySelector('.options,#options,#qOptions,.q-text,#qText')))){
      hideScreen(setup); hideScreen(result); showScreen(quiz); return;
    }
    if(setup) showScreen(setup);
    if(quiz && !quiz.classList.contains('active')) hideScreen(quiz);
    if(result && !result.classList.contains('active')) hideScreen(result);
  }
  window.CMA_routeSubjectScreens=routeSubjectScreens;
  document.addEventListener('click',function(){
    setTimeout(routeSubjectScreens,50);
    setTimeout(routeSubjectScreens,250);
  },true);
  document.addEventListener('DOMContentLoaded',routeSubjectScreens);
  window.addEventListener('load',routeSubjectScreens);
  const observer=new MutationObserver(function(){
    if(new URLSearchParams(location.search).get('cmaQuiz')==='1') return;
    routeSubjectScreens();
  });
  if(document.documentElement) observer.observe(document.documentElement,{childList:true,subtree:true,attributes:true,attributeFilter:['class','style']});
})();

/* UPDATE 7 — real document navigation for question attempt
   Start must load the question view as a new document, not render it underneath setup.
   Selection state is preserved in sessionStorage and the original Start action is replayed
   after the new document loads. */
(function(){
  'use strict';
  const NAV_KEY='cma_question_page_start_v1';
  function isStartButton(btn){
    if(!btn)return false;
    const t=((btn.textContent||'')+' '+(btn.id||'')).trim().toLowerCase();
    return /^(start|start test|start quiz|start practice|begin test|begin round|start round|start new round)$/.test(t)
      || /start(test|quiz|practice|round|newround)/i.test(btn.getAttribute('onclick')||'')
      || /start/.test(btn.id||'');
  }
  function saveSelections(){
    const values={};
    document.querySelectorAll('input,select,textarea').forEach((el,i)=>{
      const key=el.id||el.name||('__i'+i);
      if(el.type==='checkbox'||el.type==='radio') values[key]={type:el.type,checked:el.checked,value:el.value};
      else values[key]={type:el.type||el.tagName.toLowerCase(),value:el.value};
    });
    sessionStorage.setItem(NAV_KEY,JSON.stringify({
      path:location.pathname,
      values,
      buttonId:(window.__cmaLastStartButton&&window.__cmaLastStartButton.id)||'',
      buttonText:(window.__cmaLastStartButton&&window.__cmaLastStartButton.textContent||'').trim(),
      at:Date.now()
    }));
  }
  function restoreSelections(){
    let data=null;
    try{data=JSON.parse(sessionStorage.getItem(NAV_KEY)||'null')}catch(e){}
    if(!data||data.path!==location.pathname)return null;
    Object.keys(data.values||{}).forEach(key=>{
      const el=document.getElementById(key)||document.querySelector('[name="'+CSS.escape(key)+'"]');
      const v=data.values[key];
      if(!el)return;
      if(v.type==='checkbox'||v.type==='radio')el.checked=!!v.checked;
      else el.value=v.value;
      el.dispatchEvent(new Event('input',{bubbles:true}));
      el.dispatchEvent(new Event('change',{bubbles:true}));
    });
    return data;
  }
  function findStart(data){
    if(data?.buttonId){
      const b=document.getElementById(data.buttonId);
      if(b)return b;
    }
    const all=[...document.querySelectorAll('button,a')];
    return all.find(b=>isStartButton(b) && (!data?.buttonText || b.textContent.trim()===data.buttonText)) ||
           all.find(isStartButton);
  }
  /* Use WINDOW capture so this runs before subject-level access gates
     that stop document capture propagation. This prevents the first tap from
     being consumed by the old same-page start handler. */
  window.addEventListener('click',function(e){
    if(new URLSearchParams(location.search).get('cmaQuiz')==='1')return;
    /* UPDATE 12: modern subject pages (Foundation/modern templates) already
       switch setup -> quiz in the same document. Do NOT force a URL reload on
       those pages; the reload was causing users to get stuck at a loading state.
       Legacy templates without native startQuiz() keep the separate-document flow. */
    if(typeof window.startQuiz==='function' && document.getElementById('setup') && document.getElementById('quiz')) return;
    if(sessionStorage.getItem('cma_real_start')==='1'){
      sessionStorage.removeItem('cma_real_start');
      return;
    }
    const btn=e.target.closest('button,a');
    if(!isStartButton(btn))return;
    window.__cmaLastStartButton=btn;
    saveSelections();
    e.preventDefault();
    e.stopImmediatePropagation();
    const u=new URL(location.href);
    u.searchParams.set('cmaQuiz','1');
    location.href=u.href;
  },true);
  function prepareQuizDocument(){
    if(new URLSearchParams(location.search).get('cmaQuiz')!=='1')return;
    /* Keep the new document renderable while the native Start action is replayed. */
    document.documentElement.classList.add('cma-quiz-loading');
    if(!document.getElementById('cma-quiz-loading-style')){
      const s=document.createElement('style');
      s.id='cma-quiz-loading-style';
      s.textContent='html.cma-quiz-loading body{visibility:hidden!important}';
      (document.head||document.documentElement).appendChild(s);
    }
  }
  function revealQuestionViewport(){
    const quiz=document.getElementById('quiz')||document.getElementById('quizScreen')||document.querySelector('.quiz-screen');
    document.documentElement.classList.remove('cma-quiz-loading');
    requestAnimationFrame(function(){
      requestAnimationFrame(function(){
        if(quiz){
          quiz.scrollIntoView({block:'start',behavior:'instant'});
        }else{
          window.scrollTo(0,0);
        }
      });
    });
  }
  function replayStart(){
    if(new URLSearchParams(location.search).get('cmaQuiz')!=='1')return;
    prepareQuizDocument();
    const data=restoreSelections();
    if(!data){
      document.documentElement.classList.remove('cma-quiz-loading');
      return;
    }
    sessionStorage.setItem('cma_real_start','1');
    const b=findStart(data);
    if(b){
      setTimeout(function(){
        b.click();
        setTimeout(revealQuestionViewport,120);
      },80);
    }else{
      revealQuestionViewport();
    }
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',()=>setTimeout(replayStart,150));
  else setTimeout(replayStart,150);
})();
