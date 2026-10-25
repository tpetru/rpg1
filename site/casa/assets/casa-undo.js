// Shared "undo" toast for delete actions across the casa pages. The delete is applied to the UI
// immediately (optimistic), but the actual server call (opts.commit) only fires after the toast's
// grace period runs out - clicking "Anulează" cancels it and calls opts.undo instead, with nothing
// ever reaching the server. Used instead of confirm() dialogs.
(function(global) {
  var stack;

  function ensureStack() {
    if (stack) return stack;
    stack = document.createElement('div');
    stack.className = 'casa-undo-stack';
    document.body.appendChild(stack);
    return stack;
  }

  global.casaUndoAction = function(opts) {
    var delay = opts.delay || 15000;
    var root = ensureStack();

    var toast = document.createElement('div');
    toast.className = 'casa-undo-toast';

    var msg = document.createElement('span');
    msg.className = 'casa-undo-msg';
    msg.textContent = opts.message || 'Șters.';

    var btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'casa-undo-btn';
    btn.textContent = 'Anulează';

    var bar = document.createElement('div');
    bar.className = 'casa-undo-bar';
    bar.style.animationDuration = delay + 'ms';

    toast.appendChild(msg);
    toast.appendChild(btn);
    toast.appendChild(bar);
    root.appendChild(toast);

    var done = false;
    var timer = setTimeout(function() { finish(true); }, delay);

    function finish(commit) {
      if (done) return;
      done = true;
      clearTimeout(timer);
      toast.remove();
      if (commit) {
        if (opts.commit) opts.commit();
      } else {
        if (opts.undo) opts.undo();
      }
    }

    btn.addEventListener('click', function() { finish(false); });
  };
})(window);
