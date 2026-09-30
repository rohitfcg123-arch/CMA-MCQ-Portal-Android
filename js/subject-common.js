/* CMA Zone — common subject setup behaviour
 * Keep subject-specific question data and chapters inside each subject page.
 * This file owns only shared UI behaviour so a common fix applies everywhere.
 */
(function () {
  function initSourceSwitcher() {
    const source = document.getElementById('sourceSelect');
    const bank = document.getElementById('bankCard');
    const pyq = document.getElementById('pyqCard');
    if (!source || !bank || !pyq) return;

    function sync() {
      const isPyq = source.value === 'pyq';
      bank.style.display = isPyq ? 'none' : 'block';
      pyq.style.display = isPyq ? 'block' : 'none';

      if (typeof window.updateRoundDesc === 'function') window.updateRoundDesc();
      if (typeof window.updateCounts === 'function') window.updateCounts();
    }

    source.onchange = sync;
    sync();
    window.addEventListener('pageshow', sync);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initSourceSwitcher);
  } else {
    initSourceSwitcher();
  }
})();
