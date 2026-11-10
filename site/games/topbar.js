// Bara fixă de sus cu linkuri către toate jocurile (no-santos.com/games/).
// Se include imediat după <body> cu <script src="/games/topbar.js"></script>.
// Lista jocurilor e aici o singură dată; pagina /games/ o citește din window.NS_GAMES.
// Seteaza variabila CSS --gb (înălțimea barei) pe <html>, ca jocurile să-și mute HUD-ul sub ea:
//   #hud { top: calc(12px + var(--gb, 0px)); }
(function () {
  var GAMES = [
    { href: '/flappy-cat/', icon: '🐱', name: 'Flappy Cat', short: 'Pisici', desc: 'Lansează pisici cu praștia și dărâmă turnurile șobolanilor. 32 de niveluri, 3D.', color: '#4aa8ff' },
    { href: '/santa-claus/', icon: '🎅', name: 'Santa Claus', short: 'Moș', desc: 'Moș Crăciun prinde cadourile și împodobește bradul. Ferește-te de cărbuni.', color: '#e0463c' },
    { href: '/padurar/', icon: '🪓', name: 'Pădurarul', short: 'Pădurar', desc: 'Taie copaci bolnavi, vinde lemnul la gater și fugi de urși și de reporteri.', color: '#4f9a4a' },
    { href: '/drift/', icon: '🏎️', name: 'Drift', short: 'Drift', desc: 'Drift 3D cu BMW, Audi, Porsche, Passat, Dacia de poliție, TIR, kart și moto.', color: '#f0a020' }
  ];
  window.NS_GAMES = GAMES;

  var H = 34;
  var path = location.pathname.replace(/index\.html$/, '');
  if (path.slice(-1) !== '/') path += '/';

  var css = document.createElement('style');
  css.textContent =
    ':root{--gb:' + H + 'px}' +
    '#ns-gbar{position:fixed;left:0;right:0;top:0;height:' + H + 'px;z-index:2147483000;display:flex;align-items:center;gap:2px;' +
    'padding:0 6px;box-sizing:border-box;background:rgba(14,16,22,.82);-webkit-backdrop-filter:blur(8px);backdrop-filter:blur(8px);' +
    'border-bottom:1px solid rgba(255,255,255,.12);font:600 13px/1 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;' +
    'overflow-x:auto;overflow-y:hidden;scrollbar-width:none;white-space:nowrap;touch-action:pan-x;user-select:none;-webkit-user-select:none}' +
    '#ns-gbar::-webkit-scrollbar{display:none}' +
    '#ns-gbar a{display:inline-flex;align-items:center;gap:5px;height:26px;padding:0 10px;border-radius:7px;color:#d8dde6;text-decoration:none;flex:none}' +
    '#ns-gbar a:hover{background:rgba(255,255,255,.1);color:#fff}' +
    '#ns-gbar a.on{background:rgba(255,255,255,.16);color:#fff}' +
    '#ns-gbar a.hub{font-weight:800;color:#fff}' +
    '#ns-gbar .sep{width:1px;height:18px;background:rgba(255,255,255,.18);margin:0 4px;flex:none}' +
    '#ns-gbar .s{display:none}' +
    '@media (max-width:560px){#ns-gbar .l{display:none}#ns-gbar .s{display:inline}#ns-gbar a{padding:0 8px}}';
  (document.head || document.documentElement).appendChild(css);

  var bar = document.createElement('nav');
  bar.id = 'ns-gbar';
  bar.setAttribute('aria-label', 'Jocuri');
  var html = '<a class="hub' + (path === '/games/' || path === '/' ? ' on' : '') + '" href="/games/">🎮 <span class="l">Jocuri</span></a><span class="sep"></span>';
  GAMES.forEach(function (g) {
    var on = path.indexOf(g.href) === 0;
    html += '<a href="' + g.href + '"' + (on ? ' class="on" aria-current="page"' : '') + '>' + g.icon +
      ' <span class="l">' + g.name + '</span><span class="s">' + g.short + '</span></a>';
  });
  bar.innerHTML = html;
  // jocurile ascultă tastatura/pointerul pe window; nu le lăsăm să vadă click-urile din bară
  ['pointerdown', 'mousedown', 'touchstart', 'wheel'].forEach(function (t) {
    bar.addEventListener(t, function (e) { e.stopPropagation(); }, { passive: true });
  });
  bar.addEventListener('click', function (e) { var a = e.target.closest && e.target.closest('a'); if (a) a.blur(); });

  function mount() { document.body.insertBefore(bar, document.body.firstChild); }
  if (document.body) mount(); else document.addEventListener('DOMContentLoaded', mount);
})();
