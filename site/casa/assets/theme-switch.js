// Comutarea temei. Tema aleasa se tine intr-un cookie, ca PHP-ul sa poata pune atributul de tema
// pe <html> direct la randare - asa nu apare nicio licarire la incarcarea paginii. Schimbarea nu
// reincarca pagina: doar schimba atributul de pe <html>.
//
// Acelasi fisier serveste doua sisteme de teme, fiecare cu cookie-ul si atributul lui; selectorul
// isi aduce configuratia in data-*:
//   restul site-ului: <select class="theme-select">                                (implicit)
//   /casa:            <select class="theme-select" data-cookie="casa_theme"
//                             data-attr="data-casa-theme" data-path="/casa">
(function () {
  function config(select) {
    return {
      cookie: select.getAttribute('data-cookie') || 'site_theme',
      attr: select.getAttribute('data-attr') || 'data-theme',
      path: select.getAttribute('data-path') || '/'
    };
  }

  function applyTheme(select, theme) {
    // Temele valide sunt exact optiunile randate de PHP - fara o lista dublata aici.
    if (!theme || !select.querySelector('option[value="' + theme + '"]')) return;

    var cfg = config(select);
    var tenYears = 10 * 365 * 24 * 60 * 60;
    document.documentElement.setAttribute(cfg.attr, theme);
    document.cookie = cfg.cookie + '=' + theme + '; path=' + cfg.path + '; max-age=' + tenYears + '; samesite=Lax';

    // Daca aceeasi pagina are mai multe selectoare pe acelasi cookie, le tinem sincronizate.
    document.querySelectorAll('.theme-select').forEach(function (other) {
      if (config(other).cookie === cfg.cookie) other.value = theme;
    });
  }

  document.addEventListener('change', function (e) {
    if (!e.target.classList || !e.target.classList.contains('theme-select')) return;
    applyTheme(e.target, e.target.value);
  });
})();
