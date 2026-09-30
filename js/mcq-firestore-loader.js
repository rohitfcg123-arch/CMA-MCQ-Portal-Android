/* CMA Zone universal MCQ Firestore loader.
 * Subject pages keep their UI/quiz logic; this file only supplies QUESTIONS
 * from the universal mcqQuestions collection created by Question Uploader.
 */
(function(){
  const $=id=>document.getElementById(id);
  const path=location.pathname.split("/").pop().toLowerCase();
  const MAP={
    "inter-group-1-business-law-and-ethics.html":["inter1","Business Laws and Ethics"],
    "inter-group-1-cost-accounting.html":["inter1","Cost Accounting"],
    "inter-group-1-direct-and-indirect-taxation.html":["inter1","Direct and Indirect Taxation"],
    "inter-group-1-financial-accounting.html":["inter1","Financial Accounting"],
    "inter-group-2-corporate-accounting-auditing.html":["inter2","Corporate Accounting and Auditing"],
    "inter-group-2-financial-management-business-data-analytics.html":["inter2","Financial Management and Business Data Analytics"],
    "inter-group-2-operation-management-strategic-management.html":["inter2","Operations Management and Strategic Management"],
    "inter-group-2-management-accounting.html":["inter2","Management Accounting"],
    "final-group-3-corporate-economic-laws.html":["final3","Corporate and Economic Laws"],
    "final-group-3-direct-tax-international-laws.html":["final3","Direct Tax Laws and International Taxation"],
    "final-group-3-strategic-financial-management.html":["final3","Strategic Financial Management"],
    "final-group-3-strategic-cost-management.html":["final3","Strategic Cost Management"],
    "final-group-4-cost-management-audit.html":["final4","Cost and Management Audit"],
    "final-group-4-corporate-financial-reporting.html":["final4","Corporate Financial Reporting"],
    "final-group-4-indirect-tax-law-practice.html":["final4","Indirect Tax Laws and Practice"],
    "final-group-4-risk-management-banking-insurance.html":["final4","Risk Management in Banking and Insurance"],
    "final-group-4-strategic-performance-business-valuation.html":["final4","Strategic Performance Management and Business Valuation"],
    "final-group-4-entrepreneurship-startup.html":["final4","Entrepreneurship and Start-Up"],
    "foundation-fundamentals-business-economics-management.html":["foundation","Fundamentals of Business Economics and Management"],
    "foundation-fundamentals-business-mathematics-statistics.html":["foundation","Fundamentals of Business Mathematics and Statistics"],
    "foundation-fundamentals-financial-cost-accounting.html":["foundation","Fundamentals of Financial and Cost Accounting"],
    "foundation-fundamentals-law-business-communication.html":["foundation","Fundamentals of Business Laws and Business Communication"]
  };
  function norm(v){return String(v||"").trim().toLowerCase().replace(/[^a-z0-9]+/g,"");}
  window.cmaLoadMCQs=async function(){
    const meta=MAP[path]; if(!meta||typeof db==="undefined")return;
    const [group,subject]=meta, key=norm(subject);
    try{
      const snap=await db.collection("mcqQuestions").where("subjectKey","==",key).get();
      const rows=snap.docs.map(d=>({id:d.id,...d.data()})).filter(x=>norm(x.subject)===key && norm(x.group)===norm(group));
      const target=window.__CMA_QUESTIONS__;
      if(!Array.isArray(target))return;
      target.length=0;
      const pyqTarget=window.__CMA_PYQ_QUESTIONS__;
      if(Array.isArray(pyqTarget))pyqTarget.length=0;
      rows.forEach(x=>{
        ...x,
        source:x.source==="pyq"?"pyq":"bank",
        options:Array.isArray(x.options)?x.options:[],
        answer:Number.isInteger(x.answer)?x.answer:null,
        html:String(x.html||"")
      }));
      rows.forEach(x=>{ if(Array.isArray(pyqTarget) && x.source==="pyq") pyqTarget.push({...x}); });
      if(typeof window.updateSourceUI==="function")window.updateSourceUI();
      if(typeof window.updateChapterCount==="function")window.updateChapterCount();
      if(typeof window.updateCounts==="function")window.updateCounts();
      if(typeof window.updateChapter==="function")window.updateChapter();
      const summary=$("sourceSummary");
      if(summary && rows.length)summary.textContent=rows.filter(x=>x.source!=="pyq").length.toLocaleString("en-IN")+" MCQ Bank questions loaded.";
    }catch(e){
      const summary=$("sourceSummary");
      if(summary)summary.textContent="Could not load uploaded MCQs. Please refresh.";
      console.error("CMA Zone MCQ loader:",e);
    }
  };
})();
