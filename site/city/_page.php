<?php
// Pagina comuna a jocului. index.php o include cu $cityMode = 'view' (oricine: vede harta si
// locuitorii), admin/index.php cu $cityMode = 'admin' (dupa parola: poate schimba harta).
$cityMode = ($cityMode ?? 'view') === 'admin' ? 'admin' : 'view';
?>
<!DOCTYPE html>
<html lang="ro">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<title><?= $cityMode === 'admin' ? 'Admin · ' : '' ?>No-Santos City</title>
<link href="https://fonts.googleapis.com/css2?family=Fredoka:wght@400;500;600&family=Nunito:wght@500;600;700;800&display=swap" rel="stylesheet">
<style>
  :root {
    --panel: rgba(255, 250, 240, 0.94);
    --panel-solid: #fffaf0;
    --ink: #4a3f32;
    --ink-2: #857766;
    --line: rgba(120, 100, 70, 0.18);
    --accent: #e0894a;
    --accent-2: #7aa95c;
    --shadow: 0 6px 24px rgba(60, 45, 25, 0.18);
  }
  * { box-sizing: border-box; }
  html, body { margin: 0; height: 100%; overflow: hidden; background: #5f8a52; }
  body { font-family: 'Nunito', system-ui, sans-serif; color: var(--ink); -webkit-user-select: none; user-select: none; }
  canvas { position: fixed; inset: 0; width: 100%; height: 100%; touch-action: none; display: block; }
  [hidden] { display: none !important; }
  button { font: inherit; color: inherit; }
  input { -webkit-user-select: text; user-select: text; }

  .panel {
    position: fixed;
    background: var(--panel);
    border: 1px solid var(--line);
    border-radius: 16px;
    box-shadow: var(--shadow);
    backdrop-filter: blur(6px);
  }

  /* ---------- Top-left: town + stats ---------- */
  #statsPanel { top: 12px; left: 12px; padding: 10px 14px 12px; min-width: 210px; }
  #townName {
    width: 100%;
    border: none; background: transparent;
    font: inherit; font-weight: 800; font-size: 1.05rem; color: var(--ink);
    padding: 2px 0; border-bottom: 1px dashed transparent;
  }
  #townName:hover, #townName:focus { outline: none; border-bottom-color: var(--line); }
  .stats { display: grid; grid-template-columns: 1fr 1fr; gap: 2px 14px; margin-top: 6px; font-size: 0.86rem; font-weight: 700; }
  .stats span { white-space: nowrap; }
  .stats small { color: var(--ink-2); font-weight: 600; }
  .demand { margin-top: 8px; display: grid; gap: 4px; font-size: 0.72rem; color: var(--ink-2); font-weight: 700; }
  .demand-row { display: grid; grid-template-columns: 62px 1fr; align-items: center; gap: 8px; }
  .bar { height: 7px; border-radius: 99px; background: rgba(120, 100, 70, 0.14); overflow: hidden; }
  .bar span { display: block; height: 100%; border-radius: 99px; transition: width 0.6s ease; }
  #barRes { background: #7aa95c; }
  #barCom { background: #5f97c9; }

  /* ---------- Top-right: time + controls ---------- */
  #timePanel { top: 12px; right: 12px; padding: 8px 10px; display: flex; align-items: center; gap: 6px; flex-wrap: wrap; justify-content: flex-end; max-width: calc(100vw - 24px); }
  #clock { font-weight: 800; font-size: 0.95rem; padding: 0 6px; white-space: nowrap; }
  #weather { font-size: 1.15rem; padding-right: 4px; }
  /* prieteni: butonul de langa vreme, cu steluta pentru cereri noi, si panoul de sub el */
  .fr-toggle { position: relative; font-size: 1.05rem; }
  .fr-star { position: absolute; top: -6px; right: -6px; width: 17px; height: 17px; border-radius: 50%; background: #f2b632; color: #fff; font-size: 0.7rem; line-height: 17px; text-align: center; box-shadow: 0 1px 3px rgba(60, 40, 10, 0.35); animation: frPulse 1.6s ease-in-out infinite; }
  @keyframes frPulse { 50% { transform: scale(1.18); } }
  #friendsPanel { top: 62px; right: 12px; width: min(320px, calc(100vw - 24px)); padding: 10px; font-family: 'Fredoka', 'Nunito', system-ui, sans-serif; z-index: 30; }
  .fr-head { display: flex; gap: 6px; align-items: center; }
  .fr-tabs { flex: 1; display: flex; background: #eadfca; border-radius: 10px; padding: 3px; gap: 3px; }
  .fr-tab { flex: 1; padding: 6px 8px; border: none; border-radius: 8px; background: transparent; font: inherit; font-size: 0.82rem; font-weight: 600; color: var(--ink-2); cursor: pointer; white-space: nowrap; }
  .fr-tab.is-on { background: var(--accent); color: #fff; box-shadow: 0 1px 3px rgba(60, 40, 10, 0.25); }
  .fr-head select { flex: 1; padding: 7px 10px; border: 1px solid var(--line); border-radius: 10px; background: var(--panel-solid); font: inherit; font-weight: 600; font-size: 0.85rem; color: var(--ink); }
  .fr-head .rc-close { border: none; background: transparent; cursor: pointer; font-size: 1rem; color: var(--ink-2); padding: 4px 6px; }
  #friendsList { margin-top: 8px; display: grid; grid-template-columns: minmax(0, 1fr); gap: 4px; max-height: min(60vh, 420px); overflow-y: auto; overflow-x: hidden; }
  .fr-row { display: flex; align-items: center; gap: 8px; padding: 5px 6px; border-radius: 10px; }
  .fr-row:hover { background: #f6ecdc; }
  .fr-name { flex: 1; min-width: 0; overflow: hidden; display: flex; flex-direction: column; align-items: flex-start; border: none; background: none; padding: 0; text-align: left; cursor: pointer; font: inherit; color: var(--ink); }
  .fr-name b { font-weight: 600; font-size: 0.85rem; max-width: 100%; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .fr-name small { font-size: 0.7rem; color: var(--ink-2); max-width: 100%; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .fr-btns { display: flex; gap: 4px; flex-shrink: 0; }
  .fr-btn { padding: 5px 9px; border: 1px solid var(--line); border-radius: 8px; background: var(--panel-solid); font: inherit; font-size: 0.72rem; font-weight: 500; cursor: pointer; color: var(--ink); }
  .fr-btn:hover:not(:disabled) { background: #f1e3cc; }
  .fr-btn.is-yes { background: var(--accent); border-color: var(--accent); color: #fff; }
  .fr-btn:disabled { opacity: 0.5; cursor: default; }
  .fr-empty, .fr-note { margin: 6px 4px; font-size: 0.78rem; color: var(--ink-2); line-height: 1.4; }
  .icon-btn {
    min-width: 34px; height: 34px; padding: 0 8px;
    border: 1px solid var(--line); border-radius: 10px;
    background: var(--panel-solid);
    cursor: pointer; font-size: 0.95rem; font-weight: 700;
    transition: background 0.15s ease, border-color 0.15s ease, transform 0.1s ease;
  }
  .icon-btn:hover { border-color: rgba(120, 100, 70, 0.4); }
  .icon-btn:active { transform: scale(0.94); }
  .icon-btn.is-on { background: #f6dfc6; border-color: var(--accent); }
  .vsep { width: 1px; height: 22px; background: var(--line); margin: 0 2px; }

  #zoomPanel { right: 12px; bottom: 150px; padding: 6px; display: flex; flex-direction: column; gap: 6px; }

  /* ---------- Bottom toolbar ---------- */
  #toolbar {
    left: 50%; bottom: 12px; transform: translateX(-50%);
    width: min(980px, calc(100vw - 24px));
    padding: 8px 10px 10px;
  }
  .scroller { display: flex; align-items: stretch; gap: 4px; }
  .scroller > .tabs, .scroller > .tools { flex: 1; min-width: 0; }
  .sc-arrow {
    flex-shrink: 0; width: 26px;
    border: 1px solid var(--line); border-radius: 10px;
    background: var(--panel-solid); color: var(--ink);
    font-size: 1.2rem; font-weight: 800; line-height: 1;
    cursor: pointer;
  }
  .sc-arrow:hover:not(:disabled) { background: #f1e3cc; }
  .sc-arrow:disabled { opacity: 0.3; cursor: default; }
  .sc-arrow[hidden] { display: none; }
  .scroller:first-child .sc-arrow { margin-bottom: 6px; border-radius: 99px; }
  .tabs { display: flex; gap: 4px; overflow-x: auto; padding-bottom: 6px; scrollbar-width: none; }
  .tabs::-webkit-scrollbar, .tools::-webkit-scrollbar { display: none; }
  .tab {
    flex-shrink: 0;
    padding: 4px 12px;
    border: none; border-radius: 99px;
    background: transparent;
    font-size: 0.82rem; font-weight: 800; color: var(--ink-2);
    cursor: pointer;
  }
  .tab.is-active { background: #f1e3cc; color: var(--ink); }
  .tools { display: flex; gap: 6px; overflow-x: auto; scrollbar-width: none; align-items: stretch; }
  .tool {
    flex-shrink: 0;
    width: 74px; padding: 6px 4px 5px;
    border: 1px solid var(--line); border-radius: 12px;
    background: var(--panel-solid);
    cursor: pointer;
    display: flex; flex-direction: column; align-items: center; gap: 2px;
    transition: background 0.15s ease, border-color 0.15s ease, transform 0.1s ease;
  }
  .tool:hover { border-color: rgba(120, 100, 70, 0.4); transform: translateY(-1px); }
  .tool.is-active { background: #f6dfc6; border-color: var(--accent); box-shadow: inset 0 0 0 1px var(--accent); }
  .tool .ti { font-size: 1.35rem; line-height: 1.2; }
  .tool .tl { font-size: 0.68rem; font-weight: 800; line-height: 1.15; text-align: center; }
  .tools .sep { flex-shrink: 0; width: 1px; background: var(--line); margin: 4px 2px; }
  #toolHint { margin-top: 6px; font-size: 0.76rem; color: var(--ink-2); font-weight: 700; text-align: center; min-height: 1.1em; }

  /* ---------- Tooltip / toast / modal ---------- */
  #tip {
    position: fixed; z-index: 20; pointer-events: none;
    max-width: 260px;
    padding: 7px 11px;
    background: rgba(74, 63, 50, 0.94); color: #fffaf0;
    border-radius: 10px;
    font-size: 0.82rem; font-weight: 700; line-height: 1.35;
    box-shadow: var(--shadow);
  }
  #toast {
    position: fixed; z-index: 30; left: 50%; top: 18px; transform: translateX(-50%);
    padding: 8px 16px;
    background: rgba(74, 63, 50, 0.94); color: #fffaf0;
    border-radius: 99px;
    font-weight: 800; font-size: 0.86rem;
    box-shadow: var(--shadow);
    transition: opacity 0.3s ease;
  }
  #modal {
    position: fixed; inset: 0; z-index: 40;
    background: rgba(40, 55, 35, 0.45);
    display: flex; align-items: center; justify-content: center;
    padding: 16px;
  }
  .modal-card {
    width: min(440px, 100%);
    background: var(--panel-solid);
    border-radius: 22px;
    padding: 26px 26px 22px;
    box-shadow: 0 20px 60px rgba(40, 30, 15, 0.35);
    text-align: center;
  }
  .modal-card .logo { font-size: 2.6rem; line-height: 1; }
  .modal-card h1 { margin: 8px 0 4px; font-size: 1.6rem; font-weight: 800; }
  .modal-card p { margin: 6px 0; color: var(--ink-2); font-weight: 600; line-height: 1.5; font-size: 0.92rem; }
  .modal-card input {
    width: 100%; margin-top: 14px;
    padding: 11px 14px;
    border: 1px solid var(--line); border-radius: 12px;
    background: #fff; font: inherit; font-weight: 700; text-align: center; color: var(--ink);
  }
  .modal-card input:focus { outline: none; border-color: var(--accent); }
  .rs-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-top: 12px; }
  .rs-side { display: flex; flex-direction: column; font-size: 0.85rem; font-weight: 700; color: var(--ink-2); }
  .rs-side input { margin-top: 4px; }
  .rs-info { min-height: 1.4em; }
  .rs-info.is-error { color: #c0392b; }
  .modal-actions button:disabled { opacity: 0.45; cursor: default; }
  .modal-actions { display: flex; gap: 8px; margin-top: 16px; }
  .modal-actions button {
    flex: 1;
    padding: 12px;
    border: none; border-radius: 12px;
    font-weight: 800; cursor: pointer;
  }
  .btn-primary { background: var(--accent); color: #fff; }
  .btn-secondary { background: #f1e3cc; color: var(--ink); }
  .howto { margin-top: 14px; padding: 12px 14px; background: #f7efe1; border-radius: 12px; text-align: left; font-size: 0.82rem; font-weight: 600; color: var(--ink-2); line-height: 1.6; }
  .howto b { color: var(--ink); }

  .mode-view .admin-only { display: none !important; }
  .mode-admin .view-only { display: none !important; }

  /* ---------- People panel (search + join) ---------- */
  #peoplePanel {
    top: 12px; left: 50%; transform: translateX(-50%);
    width: min(400px, calc(100vw - 24px - 2 * 240px));
    min-width: 260px;
    padding: 8px;
  }
  .people-row { display: flex; gap: 6px; align-items: center; }
  .search-wrap { position: relative; flex: 1; min-width: 0; }
  .search-bar { display: flex; align-items: center; gap: 2px; padding: 0 4px 0 10px; border: 1px solid var(--line); border-radius: 10px; background: #fff; }
  .search-bar:focus-within { border-color: var(--accent); }
  .sb-lupa { font-size: 0.85rem; flex-shrink: 0; }
  .sb-mode { flex-shrink: 0; width: 30px; height: 28px; border: none; border-radius: 8px; background: transparent; cursor: pointer; font-size: 1rem; line-height: 1; }
  .sb-mode:hover { background: #f1e3cc; }
  #searchInput { flex: 1; min-width: 0; padding: 8px 8px 8px 4px; border: none; background: transparent; font: inherit; font-weight: 700; color: var(--ink); }
  #searchInput:focus { outline: none; }
  #searchResults {
    position: absolute; left: 0; right: 0; top: calc(100% + 6px); z-index: 5;
    background: var(--panel-solid); border: 1px solid var(--line); border-radius: 12px;
    box-shadow: var(--shadow); max-height: 300px; overflow-y: auto; padding: 4px;
  }
  .sr-item {
    display: flex; align-items: center; gap: 10px; width: 100%;
    padding: 7px 8px; border: none; border-radius: 8px; background: transparent;
    cursor: pointer; text-align: left; font-weight: 700;
  }
  .sr-item:hover, .sr-item.is-sel { background: #f3e6d1; }
  .sr-item small { color: var(--ink-2); font-weight: 600; margin-left: auto; white-space: nowrap; }
  .sr-empty { padding: 10px; color: var(--ink-2); font-weight: 700; font-size: 0.85rem; text-align: center; }
  .av {
    flex-shrink: 0; width: 28px; height: 28px; border-radius: 50%;
    display: inline-flex; align-items: center; justify-content: center;
    color: #fff; font-weight: 800; font-size: 0.85rem; border: 2px solid #fff; box-shadow: 0 1px 3px rgba(0,0,0,.2);
  }
  .av.is-big { width: 54px; height: 54px; font-size: 1.5rem; }
  .btn-join {
    flex-shrink: 0; padding: 8px 14px; border: none; border-radius: 10px;
    background: var(--accent); color: #fff; font-weight: 800; cursor: pointer; white-space: nowrap;
  }
  .me-chip {
    flex-shrink: 0; display: flex; align-items: center; gap: 6px;
    padding: 3px 10px 3px 3px; border: 1px solid var(--line); border-radius: 99px;
    background: var(--panel-solid); cursor: pointer; font-weight: 800; max-width: 150px;
  }
  .me-chip { max-width: 220px; }
  .me-chip span:not(.av) { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; min-width: 0; }
  .me-money { flex-shrink: 0; font-size: 0.75rem; color: #3f8a4d; background: #e4f2df; border-radius: 99px; padding: 1px 7px; }
  .me-chip.is-debt .me-money { color: #a3402f; background: #f6d9d2; }

  #residentCard { max-height: min(70vh, 560px); overflow-y: auto; }
  .rc-money { margin: 8px auto 2px; display: inline-block; padding: 4px 14px; border-radius: 99px; background: #e4f2df; color: #3f8a4d; font-weight: 800; font-size: 1.05rem; }
  .rc-money.is-debt { background: #f6d9d2; color: #a3402f; }
  .rc-section { margin: 12px 0 6px; font-size: 0.72rem; font-weight: 800; text-transform: uppercase; letter-spacing: 0.06em; color: var(--ink-2); text-align: left; }
  .rc-list { display: grid; gap: 4px; }
  .rc-row { display: flex; justify-content: space-between; gap: 8px; width: 100%; padding: 7px 10px; border: 1px solid var(--line); border-radius: 10px; background: #fff; cursor: pointer; font-weight: 700; font-size: 0.82rem; text-align: left; }
  .rc-row:hover { border-color: var(--accent); }
  .rc-row small { color: var(--ink-2); white-space: nowrap; }
  .rc-row.is-static { cursor: default; align-items: center; }
  .rc-row.is-static:hover { border-color: var(--line); }
  .rc-row-btns { display: flex; gap: 4px; flex-shrink: 0; }
  .rc-row-btns button { padding: 6px 10px; border: none; border-radius: 8px; font-weight: 800; cursor: pointer; font-size: 0.78rem; }
  .rc-job { font-weight: 800 !important; color: var(--ink) !important; }
  .rc-history { display: grid; gap: 3px; text-align: left; font-size: 0.78rem; font-weight: 700; color: var(--ink-2); }
  .rc-history div { display: flex; justify-content: space-between; gap: 10px; }
  .rc-history span { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .rc-history b { white-space: nowrap; }
  .rc-history .pos { color: #3f8a4d; }
  .rc-history .neg { color: #a3402f; }
  /* fluturasul de salariu */
  .ps-head { font-size: 2rem; line-height: 1; margin-top: 4px; }
  .ps { margin-top: 10px; text-align: left; background: #fbf6ec; border: 1px dashed var(--line); border-radius: 12px; padding: 8px 12px; }
  .ps-row { display: flex; justify-content: space-between; gap: 10px; padding: 2px 0; font-size: 0.8rem; font-weight: 500; color: var(--ink); }
  .ps-row b { white-space: nowrap; font-weight: 600; }
  .ps-row.is-sub { padding-left: 12px; font-size: 0.72rem; color: var(--ink-2); }
  .ps-row.is-sub b { font-weight: 500; }
  .ps-row .pos { color: #3f8a4d; }
  .ps-row .neg { color: #a3402f; }
  .ps-total { margin-top: 6px; padding-top: 6px; border-top: 1px solid var(--line); }
  .ps-total .ps-row { font-size: 0.92rem; font-weight: 600; }
  .ps-balance { margin-top: 10px; display: flex; justify-content: space-between; align-items: center; padding: 8px 12px; border-radius: 12px; background: #e4f2df; color: #3f8a4d; font-weight: 600; }
  .ps-balance b { font-size: 1.05rem; }
  .ps-balance.is-debt { background: #f6d9d2; color: #a3402f; }
  .pc-units { display: grid; gap: 8px; margin-top: 10px; text-align: left; }
  .pc-unit { padding: 10px 12px; border: 1px solid var(--line); border-radius: 12px; background: #fff; }
  .pc-name { font-weight: 800; margin-bottom: 4px; }
  .pc-line { font-size: 0.82rem; font-weight: 600; color: var(--ink-2); }
  .pc-line b { color: var(--ink); }
  .pc-tags { display: flex; flex-wrap: wrap; gap: 4px; margin-top: 6px; }
  .tag { padding: 2px 8px; border-radius: 99px; font-size: 0.72rem; font-weight: 800; }
  .tag.sale { background: #fbe3cf; color: #b0581d; }
  .tag.rent { background: #e4f2df; color: #3f8a4d; }
  .pc-btns { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 8px; }
  .pc-btns button { flex: 1 1 auto; padding: 8px 10px; border: none; border-radius: 10px; font-weight: 800; cursor: pointer; font-size: 0.82rem; }
  .pc-btns button:disabled { opacity: 0.5; cursor: not-allowed; }
  .people-foot { margin-top: 6px; display: flex; align-items: center; justify-content: space-between; gap: 8px; flex-wrap: wrap; }
  #peopleCount { font-size: 0.75rem; font-weight: 700; color: var(--ink-2); text-align: left; }
  .switch { display: inline-flex; align-items: center; gap: 6px; font-size: 0.75rem; font-weight: 800; color: var(--ink-2); cursor: pointer; user-select: none; white-space: nowrap; }
  .switch input { position: absolute; opacity: 0; width: 1px; height: 1px; }
  .switch .sw { position: relative; width: 30px; height: 17px; border-radius: 99px; background: #d9cfbd; transition: background 0.15s ease; flex-shrink: 0; }
  .switch .sw::after { content: ''; position: absolute; top: 2px; left: 2px; width: 13px; height: 13px; border-radius: 50%; background: #fff; box-shadow: 0 1px 2px rgba(0, 0, 0, 0.2); transition: transform 0.15s ease; }
  .switch input:checked + .sw { background: var(--accent); }
  .switch input:checked + .sw::after { transform: translateX(13px); }
  .switch input:focus-visible + .sw { outline: 2px solid var(--accent); outline-offset: 2px; }
  #peopleCount .dot { display: inline-block; width: 7px; height: 7px; border-radius: 50%; background: #5bb35b; margin: 0 3px 0 6px; vertical-align: 1px; }

  #residentCard {
    left: 50%; bottom: 16px; transform: translateX(-50%);
    width: min(320px, calc(100vw - 24px));
    padding: 16px; text-align: center;
  }
  .mode-admin #residentCard { bottom: 150px; }
  #residentCard .rc-close { position: absolute; top: 8px; right: 8px; border: none; background: transparent; cursor: pointer; font-size: 1rem; color: var(--ink-2); }
  #residentCard h3 { margin: 8px 0 2px; font-size: 1.15rem; }
  .shop-body { max-height: min(46vh, 380px); overflow-y: auto; text-align: left; padding-right: 4px; }
  .brand-grid { display: flex; flex-wrap: wrap; gap: 5px; margin-top: 4px; }
  .brand-opt { padding: 5px 9px; border: 1px solid var(--line); border-radius: 99px; background: var(--panel-solid); font: inherit; font-size: 0.74rem; font-weight: 600; color: var(--ink); cursor: pointer; }
  .brand-opt.is-on { background: var(--accent); border-color: var(--accent); color: #fff; }
  .car-sum { text-align: center; font-size: 0.78rem; }
  .ae-block { margin-top: 10px; text-align: left; }
  .ae-block label { display: block; font-size: 0.78rem; font-weight: 700; color: var(--ink-2); margin-bottom: 4px; }
  .ae-block small { display: block; margin-top: 3px; font-size: 0.7rem; color: var(--ink-2); }
  .ae-row { display: flex; gap: 6px; }
  .ae-row input, .ae-row select { flex: 1; min-width: 0; margin: 0; padding: 8px 10px; border: 1px solid var(--line); border-radius: 10px; font: inherit; font-size: 0.82rem; background: #fff; text-align: left; }
  .ae-row button { padding: 8px 12px; border: none; border-radius: 10px; font-weight: 700; cursor: pointer; font-size: 0.8rem; }
  .car-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(110px, 1fr)); gap: 8px; margin-top: 12px; }
  .car-opt { display: flex; flex-direction: column; align-items: center; gap: 2px; padding: 10px 6px; border: 2px solid var(--line); border-radius: 12px; background: var(--panel-solid); cursor: pointer; font: inherit; color: var(--ink); }
  .car-opt span { font-size: 1.6rem; }
  .car-opt small { color: var(--ink-2); font-weight: 600; }
  .car-opt.is-on { border-color: var(--accent); background: #f6dfc6; }
  .car-colors { display: flex; gap: 8px; justify-content: center; margin-top: 12px; }
  .car-col { width: 26px; height: 26px; border-radius: 50%; border: 2px solid #fff; box-shadow: 0 0 0 1px var(--line); cursor: pointer; }
  .car-col.is-on { box-shadow: 0 0 0 2px var(--accent); }
  .car-row { display: flex; justify-content: space-between; align-items: center; gap: 8px; padding: 6px 0; border-bottom: 1px dashed var(--line); text-align: left; }
  .car-info { display: flex; flex-direction: column; min-width: 0; font-size: 0.8rem; }
  .car-info small { color: var(--ink-2); font-size: 0.7rem; font-weight: 500; }
  .car-row .fr-btns { flex-direction: column; }
  .used-list { margin-top: 12px; display: grid; gap: 6px; max-height: 340px; overflow-y: auto; text-align: left; }
  .used-row { display: flex; align-items: center; gap: 8px; padding: 6px 8px; border: 1px solid var(--line); border-radius: 10px; }
  .used-info { flex: 1; min-width: 0; display: flex; flex-direction: column; font-size: 0.85rem; }
  .used-info small { color: var(--ink-2); font-size: 0.7rem; font-weight: 500; }
  .car-dot { display: inline-block; width: 10px; height: 10px; border-radius: 3px; vertical-align: -1px; }
  .on-dot { display: inline-block; width: 9px; height: 9px; border-radius: 50%; margin-right: 6px; vertical-align: 1px; }
  .on-dot.is-on { background: #4caf50; box-shadow: 0 0 0 2px rgba(76, 175, 80, 0.25); }
  .on-dot.is-off { background: #d9534f; }
  #residentCard p { margin: 2px 0; color: var(--ink-2); font-weight: 700; font-size: 0.85rem; }
  .rc-actions { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 12px; }
  .rc-actions button { flex: 1 1 auto; padding: 9px; border: none; border-radius: 10px; font-weight: 800; cursor: pointer; }
  .rc-actions .rc-danger { background: #f6d9d2; color: #a3402f; }

  /* Cardurile (locuitor, casa/bloc, loc de munca): font rotunjit si text mai mic. Fredoka arata
     deja ingrosat la 500-600, asa ca grosimile sunt mai mici decat la Nunito. */
  #residentCard, #residentCard button { font-family: 'Fredoka', 'Nunito', system-ui, sans-serif; }
  #residentCard { font-size: 13px; padding: 14px 14px 12px; }
  #residentCard h3 { font-size: 1.05rem; font-weight: 600; margin: 6px 0 2px; }
  #residentCard p { font-size: 0.8rem; font-weight: 400; }
  #residentCard p b { font-weight: 600; }
  #residentCard .rc-job { font-weight: 500 !important; }
  #residentCard .rc-money { font-size: 0.92rem; font-weight: 600; padding: 3px 12px; }
  #residentCard .rc-section { font-size: 0.64rem; font-weight: 600; margin: 10px 0 5px; }
  #residentCard .rc-row { font-size: 0.76rem; font-weight: 500; padding: 6px 9px; }
  #residentCard .rc-history { font-size: 0.72rem; font-weight: 400; }
  #residentCard .rc-history b { font-weight: 600; }
  #residentCard .pc-units { gap: 6px; }
  #residentCard .pc-unit { padding: 8px 10px; }
  #residentCard .pc-name { font-size: 0.84rem; font-weight: 600; margin-bottom: 2px; }
  #residentCard .pc-line { font-size: 0.75rem; font-weight: 400; }
  #residentCard .pc-line b { font-weight: 600; }
  #residentCard .tag { font-size: 0.66rem; font-weight: 500; padding: 2px 7px; }
  #residentCard .pc-btns button, #residentCard .rc-actions button, #residentCard .rc-row-btns button { font-size: 0.75rem; font-weight: 500; padding: 7px 9px; }
  #residentCard .av { font-weight: 600; }
  #residentCard .av.is-big { width: 44px; height: 44px; font-size: 1.2rem; }
  .emoji-grid { display: grid; grid-template-columns: repeat(8, 1fr); gap: 6px; margin-top: 12px; }
  .emoji-grid button {
    aspect-ratio: 1; border: 2px solid transparent; border-radius: 10px; background: #f7efe1;
    font-size: 1.15rem; cursor: pointer; padding: 0; font-weight: 800; color: var(--ink-2);
  }
  .emoji-grid button.is-sel { border-color: var(--accent); background: #fff; }
  .modal-card input + input { margin-top: 8px; }
  .modal-label { margin: 14px 0 0 !important; font-size: 0.8rem !important; font-weight: 800 !important; }
  .modal-label + .emoji-grid { margin-top: 8px; }
  .modal-switch { margin: 14px 0 0 !important; font-size: 0.85rem !important; }
  .modal-switch a { color: var(--accent); font-weight: 800; text-decoration: none; }
  .modal-switch a:hover { text-decoration: underline; }
  .acc-list { display: flex; flex-wrap: wrap; justify-content: center; gap: 6px; margin-top: 8px; }
  .acc-list button {
    padding: 7px 12px; border: 1px solid var(--line); border-radius: 99px;
    background: #fff; font-weight: 800; cursor: pointer;
  }
  .acc-list button:hover { border-color: var(--accent); color: var(--accent); }
  .modal-err { margin-top: 10px; color: #b5452f; font-weight: 800; font-size: 0.86rem; min-height: 1.2em; }
  .admin-badge {
    display: inline-block; margin-left: 6px; padding: 1px 7px; border-radius: 99px;
    background: #e0894a; color: #fff; font-size: 0.65rem; font-weight: 800; vertical-align: 3px;
  }
  .admin-links { margin-top: 6px; font-size: 0.75rem; font-weight: 700; }
  .admin-links a { color: var(--ink-2); margin-right: 10px; }

  @media (max-width: 1000px) {
    #peoplePanel { top: auto; bottom: 12px; width: calc(100vw - 24px); min-width: 0; }
    .mode-admin #peoplePanel { bottom: 150px; width: min(360px, calc(100vw - 24px)); }
    #searchResults { top: auto; bottom: calc(100% + 6px); }
    .mode-view #residentCard { bottom: 90px; }
    .mode-view #zoomPanel { bottom: 90px; }
  }
  @media (max-width: 640px) {
    .mode-admin #peoplePanel { display: none; }
    #statsPanel { min-width: 0; padding: 8px 10px; }
    .stats { font-size: 0.78rem; gap: 0 10px; }
    .demand { display: none; }
    .mode-admin #timePanel { top: auto; bottom: 156px; right: 8px; padding: 6px; }
    .mode-view #timePanel { padding: 6px; }
    #zoomPanel { display: none; }
    .tool { width: 62px; }
    .tool .tl { font-size: 0.62rem; }
    #toolHint { display: none; }
  }
</style>
</head>
<body class="mode-<?= $cityMode ?>">
<canvas id="game"></canvas>

<div class="panel" id="statsPanel">
  <input id="townName" maxlength="32" spellcheck="false" title="<?= $cityMode === 'admin' ? 'Click ca să redenumești orașul' : '' ?>" <?= $cityMode === 'admin' ? '' : 'readonly tabindex="-1"' ?>>
  <?php if ($cityMode === 'admin'): ?>
    <div class="admin-links"><span class="admin-badge">ADMIN</span> <a href="/" target="_blank">Vezi orașul ↗</a><a href="/admin/?logout">Ieși</a></div>
  <?php endif; ?>
  <div class="stats">
    <span>👥 <b id="statPop">0</b> <small>locuitori</small></span>
    <span>😊 <b id="statHappy">0%</b> <small>fericire</small></span>
    <span>🏡 <b id="statHouses">0</b> <small>case</small></span>
    <span>💼 <b id="statJobs">0</b> <small>locuri</small></span>
  </div>
  <div class="demand">
    <div class="demand-row"><span>Cerere case</span><div class="bar"><span id="barRes" style="width:50%"></span></div></div>
    <div class="demand-row"><span>Cerere magazine</span><div class="bar"><span id="barCom" style="width:50%"></span></div></div>
  </div>
</div>

<div class="panel" id="timePanel">
  <button class="icon-btn view-only" id="btnVehicles" title="Vehiculele mele" hidden>🚗</button>
  <button class="icon-btn view-only" id="btnPayslip" title="Fluturaș de salariu" hidden>🧾</button>
  <button class="icon-btn view-only fr-toggle" id="btnFriends" title="Prieteni" hidden>🤝<span id="friendsStar" class="fr-star" hidden>★</span></button>
  <span id="weather">☀️</span>
  <span id="clock">Ziua 1 · 08:00</span>
  <div class="vsep admin-only"></div>
  <button class="icon-btn admin-only" data-speed="0" title="Pauză">⏸</button>
  <button class="icon-btn admin-only is-on" data-speed="1" title="Viteză normală">▶</button>
  <button class="icon-btn admin-only" data-speed="2" title="Repede">⏩</button>
  <div class="vsep"></div>
  <button class="icon-btn admin-only" id="btnUndo" title="Anulează ultima acțiune (Ctrl+Z)">↶</button>
  <button class="icon-btn" id="btnGrid" title="Grilă (G)">#</button>
  <button class="icon-btn admin-only" id="btnSave" title="Salvează orașul pentru toată lumea">💾</button>
  <button class="icon-btn admin-only" id="btnResize" title="Mărește harta">📐</button>
  <button class="icon-btn admin-only" id="btnNew" title="Hartă nouă">🆕</button>
</div>

<div class="panel" id="peoplePanel">
  <div class="people-row">
    <div class="search-wrap">
      <div class="search-bar">
        <span class="sb-lupa" aria-hidden="true">🔎</span>
        <button type="button" class="sb-mode" id="searchMode" title="Schimbă între căutare de locuitori și de locații">👤</button>
        <input id="searchInput" placeholder="Caută un locuitor…" autocomplete="off" spellcheck="false">
      </div>
      <div id="searchResults" hidden></div>
    </div>
    <button class="me-chip view-only" id="meChip" hidden title="Mergi acasă"></button>
  </div>
  <div class="people-foot">
    <div id="peopleCount">Se încarcă locuitorii…</div>
    <label class="switch" title="Arată sau ascunde ceilalți locuitori pe hartă (P)">
      <input type="checkbox" id="showPeople" checked>
      <span class="sw" aria-hidden="true"></span>Arată locuitori
    </label>
  </div>
</div>

<div class="panel" id="residentCard" hidden></div>

<div class="panel" id="friendsPanel" hidden>
  <div class="fr-head">
    <div class="fr-tabs">
      <button class="fr-tab is-on" data-view="friends" aria-pressed="true">Prieteni</button>
      <button class="fr-tab" data-view="requests" aria-pressed="false">Cereri</button>
    </div>
    <button class="rc-close" id="friendsClose" aria-label="Închide">✕</button>
  </div>
  <div id="friendsList"></div>
</div>

<div class="panel" id="zoomPanel">
  <button class="icon-btn" id="btnZoomIn" title="Mărește">+</button>
  <button class="icon-btn" id="btnZoomOut" title="Micșorează">−</button>
</div>

<div class="panel admin-only" id="toolbar">
  <div class="scroller">
    <button class="sc-arrow" data-dir="-1" aria-label="Înapoi">‹</button>
    <div class="tabs" id="tabs"></div>
    <button class="sc-arrow" data-dir="1" aria-label="Înainte">›</button>
  </div>
  <div class="scroller">
    <button class="sc-arrow" data-dir="-1" aria-label="Înapoi">‹</button>
    <div class="tools" id="tools"></div>
    <button class="sc-arrow" data-dir="1" aria-label="Înainte">›</button>
  </div>
  <div id="toolHint"></div>
</div>

<div id="tip" hidden></div>
<div id="toast" hidden></div>

<div id="modal" hidden>
  <div class="modal-card" id="modalCard"></div>
</div>

<script>window.CITY_MODE = <?= json_encode($cityMode) ?>;</script>
<script src="/city.js?v=<?= @filemtime(__DIR__ . '/city.js') ?>"></script>
</body>
</html>
