'use strict';
// No-Santos City - un mic oras/sat "cozy" de construit. Totul e desenat procedural pe canvas:
// harta statica (teren, drumuri, case, copaci) sta intr-un canvas offscreen impartit in bucati
// (chunk-uri) care se redeseneaza doar cand se schimba ceva; peste ea se deseneaza in fiecare cadru
// doar ce se misca (masini, mori de vant, nori, ploaie, luminile de noapte).
(function () {
  // Un singur oras comun, tinut pe server. In modul 'view' (city.no-santos.com) oricine vede harta si
  // locuitorii, dar nu poate construi; in modul 'admin' (/admin, cu parola) harta se editeaza si se
  // salveaza pentru toata lumea.
  const IS_ADMIN = window.CITY_MODE === 'admin';

  // ================= CONFIG =================
  // Harta poate fi marita din admin, deci W/H (si tot ce depinde de ele) se pot schimba.
  const T = 40, CH = 10;
  let W = 80, H = 60;
  let N = W * H;
  let CX = Math.ceil(W / CH), CY = Math.ceil(H / CH);
  const MAX_SIDE = 200, MAX_TILES = 20000;   // la fel ca in _common.php
  const SAVE_KEY = 'nscity_save_v1';
  const SPEEDS = [0, 6, 24];      // minute de joc pe secunda reala
  const TICK_MIN = 5;             // o "bataie" de simulare la fiecare 5 minute de joc
  const FIELD_RATE = 1 / 520;     // cresterea unui camp pe bataie (~2 zile de joc pana se coace)
  const POP = [0, 3, 6, 14];
  const SHOP_JOBS = [0, 3, 6, 12];
  const DIRS = [[0, -1], [1, 0], [0, 1], [-1, 0]];
  // road[i]: 1 drum de tara, 2 strada, 3 autostrada, 4 pietonal, 5 transport in comun
  const ROAD_NAMES = ['', '🟫 <b>Drum de țară</b>', '🛣️ <b>Stradă</b>', '🛤️ <b>Autostradă</b>', '🚶 <b>Stradă pietonală</b>', '🚋 <b>Linie de transport în comun</b>'];
  // half = jumatate din latimea drumului, edge = cat iese bordura, col/edgeCol = asfalt / bordura
  const ROAD_STYLE = [null,
    { half: 0.24, edge: 0.04, col: '#cfb07f', edgeCol: '#b39262' },
    { half: 0.31, edge: 0.08, col: '#7b8087', edgeCol: '#d9d1c3' },
    { half: 0.44, edge: 0.05, col: '#62676e', edgeCol: '#c9c4b8' },
    { half: 0.34, edge: 0.06, col: '#eadcc2', edgeCol: '#cdbb9a' },
    { half: 0.33, edge: 0.08, col: '#a85a4c', edgeCol: '#d9d1c3' }];
  // pe ce drumuri merge fiecare: masinile nu intra pe pietonal; tramvaiele/autobuzele doar pe linia lor
  const VEH_ROADS = { car: [0, 1, 1, 1, 0, 1], taxi: [0, 1, 1, 1, 0, 1], tram: [0, 0, 0, 0, 0, 1], walker: [0, 0, 0, 0, 1, 0] };
  // casele si magazinele nu au intrare din autostrada
  function accessRoad(i) { const r = road[i]; return r !== 0 && r !== 3; }

  // cov = ce fel de serviciu aduce casele din jur (vezi COVERAGE); fara cov nu ajuta casele.
  // jobs trebuie sa fie la fel ca CITY_SPECIAL_SLOTS din _common.php.
  const SPECIALS = {
    park:       { name: 'Parc', icon: '🌳', w: 2, h: 2, radius: 6, jobs: 1, cov: 'leisure', nolight: true, desc: 'Casele din jur cresc mai frumoase.' },
    fountain:   { name: 'Fântână', icon: '⛲', w: 1, h: 1, radius: 4, jobs: 0, cov: 'leisure', nolight: true, desc: 'Loc de întâlnire pentru vecini.' },
    school:     { name: 'Școală', icon: '🏫', w: 3, h: 2, radius: 10, jobs: 8, cov: 'edu', desc: 'Copiii din jur învață aproape de casă.' },
    clinic:     { name: 'Dispensar', icon: '🏥', w: 2, h: 2, radius: 10, jobs: 6, cov: 'health', desc: 'Doctorul satului.' },
    church:     { name: 'Biserică', icon: '⛪', w: 2, h: 3, radius: 9, jobs: 1, cov: 'faith', desc: 'Clopotele se aud până departe.' },
    fire:       { name: 'Pompieri', icon: '🚒', w: 2, h: 2, radius: 10, jobs: 5, cov: 'safety', desc: 'Siguranță pentru tot cartierul.' },
    market:     { name: 'Piață', icon: '🧺', w: 3, h: 3, radius: 8, jobs: 12, cov: 'shop', desc: 'Legume proaspete în fiecare dimineață.' },
    windmill:   { name: 'Moară de vânt', icon: '🌬️', w: 1, h: 1, radius: 5, jobs: 2, cov: 'farm', farm: 1.3, desc: 'Câmpurile din jur cresc mai repede.' },
    barn:       { name: 'Hambar', icon: '🛖', w: 2, h: 2, radius: 6, jobs: 3, cov: 'farm', farm: 1.8, desc: 'Câmpurile din jur cresc mult mai repede.' },
    hospital:   { name: 'Spital', icon: '🏥', w: 4, h: 3, radius: 16, jobs: 20, cov: 'health', desc: 'Urgențe, operații și saloane pentru tot orașul.' },
    medcenter:  { name: 'Clinică medicală', icon: '🩺', w: 3, h: 2, radius: 11, jobs: 8, cov: 'health', desc: 'Medici specialiști și analize.' },
    kinder:     { name: 'Grădiniță', icon: '🧸', w: 2, h: 2, radius: 8, jobs: 4, cov: 'edu', desc: 'Cei mici se joacă și învață.' },
    highschool: { name: 'Liceu', icon: '🎓', w: 4, h: 3, radius: 13, jobs: 12, cov: 'edu', desc: 'Liceul orașului, cu teren de sport.' },
    dorm:       { name: 'Cămin', icon: '🛏️', w: 2, h: 3, radius: 7, jobs: 2, cov: 'edu', desc: 'Cămin pentru elevi și studenți.' },
    lidl:       { name: 'Lidl', icon: '🛒', w: 3, h: 3, radius: 10, jobs: 10, cov: 'shop', brand: { bg: '#0050aa', fg: '#ffe500', text: 'Lidl' }, desc: 'Supermarket cu de toate.' },
    kaufland:   { name: 'Kaufland', icon: '🛒', w: 4, h: 3, radius: 12, jobs: 16, cov: 'shop', brand: { bg: '#e10915', fg: '#ffffff', text: 'Kaufland' }, desc: 'Hipermarket mare, cu parcare.' },
    penny:      { name: 'Penny', icon: '🛒', w: 2, h: 3, radius: 8, jobs: 6, cov: 'shop', brand: { bg: '#cd1414', fg: '#ffe500', text: 'PENNY' }, desc: 'Supermarket de cartier.' },
    carrefour:  { name: 'Carrefour', icon: '🛒', w: 4, h: 3, radius: 12, jobs: 16, cov: 'shop', brand: { bg: '#1e5bc6', fg: '#ffffff', text: 'Carrefour' }, desc: 'Hipermarket mare, cu parcare.' },
    mall:       { name: 'Mall', icon: '🛍️', w: 5, h: 4, radius: 16, jobs: 30, cov: 'shop', brand: { bg: '#7a5cc4', fg: '#ffffff', text: 'MALL' }, desc: 'Magazine, cinema și food court sub același acoperiș.' },
    rompetrol:  { name: 'Rompetrol', icon: '⛽', w: 2, h: 2, radius: 0, jobs: 3, brand: { bg: '#f39200', fg: '#ffffff', text: 'rompetrol', band: '#1d4f91' }, desc: 'Benzinărie cu magazin.' },
    omv:        { name: 'OMV', icon: '⛽', w: 2, h: 2, radius: 0, jobs: 3, brand: { bg: '#0f3f8c', fg: '#ffffff', text: 'OMV', band: '#58b947' }, desc: 'Benzinărie cu magazin.' },
    socar:      { name: 'SOCAR', icon: '⛽', w: 2, h: 2, radius: 0, jobs: 3, brand: { bg: '#1b4f9c', fg: '#ffffff', text: 'SOCAR', band: '#e43b2c' }, desc: 'Benzinărie cu magazin.' },
    factory_s:  { name: 'Fabrică mică', icon: '🏭', w: 2, h: 2, radius: 0, jobs: 6, factory: 1, desc: 'Un atelier de producție.' },
    factory_m:  { name: 'Fabrică medie', icon: '🏭', w: 3, h: 3, radius: 0, jobs: 12, factory: 2, desc: 'Hale și depozite.' },
    factory_l:  { name: 'Fabrică mare', icon: '🏭', w: 4, h: 3, radius: 0, jobs: 20, factory: 3, desc: 'Multe locuri de muncă.' },
    factory_xl: { name: 'Fabrică gigantică', icon: '🏭', w: 6, h: 4, radius: 0, jobs: 40, factory: 4, desc: 'Cel mai mare angajator din oraș.' },
    solar:      { name: 'Parc fotovoltaic', icon: '☀️', w: 4, h: 3, radius: 0, jobs: 2, nolight: true, desc: 'Curent verde de la soare.' },
    parking_s:  { name: 'Parcare mică', icon: '🅿️', w: 2, h: 2, radius: 0, jobs: 1, desc: 'Câteva locuri de parcare.' },
    parking_l:  { name: 'Parcare mare', icon: '🅿️', w: 4, h: 3, radius: 0, jobs: 2, desc: 'Parcare mare, cu alei.' },
    busdepot:   { name: 'Autobază', icon: '🚌', w: 5, h: 3, radius: 14, jobs: 10, cov: 'transport', desc: 'Autobuzele orașului dorm aici.' },
    tramdepot:  { name: 'Depou de tramvaie', icon: '🚋', w: 5, h: 3, radius: 14, jobs: 8, cov: 'transport', desc: 'Tramvaiele orașului, pe șinele lor.' },
    stadium_s:  { name: 'Stadion mic', icon: '⚽', w: 4, h: 3, radius: 10, jobs: 6, cov: 'leisure', stadium: 1, desc: 'Terenul echipei locale.' },
    stadium_m:  { name: 'Stadion mediu', icon: '🏟️', w: 5, h: 4, radius: 13, jobs: 12, cov: 'leisure', stadium: 2, desc: 'Meciuri în fiecare weekend.' },
    stadium_l:  { name: 'Stadion mare', icon: '🏟️', w: 7, h: 5, radius: 17, jobs: 22, cov: 'leisure', stadium: 3, desc: 'Arena orașului, cu pistă de atletism.' },
    pool:       { name: 'Piscină', icon: '🏊', w: 3, h: 2, radius: 9, jobs: 3, cov: 'leisure', desc: 'Bălăceală vara, cu șezlonguri.' },
    // apts trebuie sa fie la fel ca CITY_BLOC_APTS din _common.php
    house_floor: { name: 'Casă cu etaj', icon: '🏘️', w: 2, h: 2, radius: 0, jobs: 0, pop: 5, homeKind: 'hfloor', desc: 'Casă pe două niveluri, cu balcon.' },
    house_pool: { name: 'Casă cu piscină', icon: '🏊', w: 3, h: 2, radius: 0, jobs: 0, pop: 5, homeKind: 'hpool', desc: 'Casă cu piscină în curte.' },
    villa:      { name: 'Vilă', icon: '🏡', w: 3, h: 3, radius: 0, jobs: 0, pop: 6, homeKind: 'villa', desc: 'Vilă cu grădină, terasă și garaj.' },
    mansion:    { name: 'Conac', icon: '🏰', w: 4, h: 4, radius: 0, jobs: 0, pop: 8, homeKind: 'mansion', desc: 'Conac cu curte interioară și grădini.' },
    bloc:       { name: 'Bloc', icon: '🏢', w: 2, h: 2, radius: 0, jobs: 0, apts: 12, pop: 30, desc: 'Bloc cu 12 apartamente de vânzare sau de închiriat.' },
    amusement:  { name: 'Parc de distracții', icon: '🎡', w: 5, h: 4, radius: 14, jobs: 10, cov: 'leisure', desc: 'Roată mare, carusel și montagne russe.' },
    bar:        { name: 'Bar', icon: '🍺', w: 2, h: 2, radius: 8, jobs: 4, cov: 'leisure', desc: 'Bere la halbă și muzică seara.' },
    restaurant: { name: 'Restaurant', icon: '🍽️', w: 3, h: 2, radius: 10, jobs: 8, cov: 'leisure', desc: 'Masă bună, cu terasă.' },
    aumovio:    { name: 'AuNau-movio', icon: '💻', w: 4, h: 3, radius: 0, jobs: 5, desc: 'Companie IT: dezvoltare de software pentru automotive.' },
    dealership: { name: 'Dealership auto', icon: '🚗', w: 3, h: 2, radius: 0, jobs: 5, desc: 'Aici își cumpără locuitorii mașini personale.' },
    usedlot:    { name: 'Parc auto', icon: '🅿️', w: 4, h: 3, radius: 0, jobs: 3, desc: 'Mașini second-hand, de la jucători și de la parc.' },
    airport:    { name: 'Aeroport', icon: '✈️', w: 8, h: 5, radius: 20, jobs: 40, cov: 'transport', desc: 'Zboruri spre toată lumea.' }
  };
  // Tipurile de servicii. Casele cresc dupa cate tipuri diferite le acopera (doua parcuri = un singur
  // tip); fermele ajuta doar campurile.
  const COVERAGE = ['health', 'edu', 'safety', 'faith', 'shop', 'transport', 'leisure', 'farm'];
  const COV_NAMES = { health: 'sănătate', edu: 'educație', safety: 'siguranță', faith: 'credință', shop: 'cumpărături', transport: 'transport', leisure: 'relaxare' };
  function covBit(k) { return k ? 1 << COVERAGE.indexOf(k) : 0; }

  const PLOW = { base: '#c9b49a', row: '#b29c80', rw: 0.5 };
  const CROPS = [
    { name: 'Grâu', icon: '🌾', stages: [PLOW, { base: '#c5b698', row: '#9dbb73', rw: 0.3 }, { base: '#aac57d', row: '#8db262', rw: 0.6 }, { base: '#cac776', row: '#b3b05a', rw: 0.7 }, { base: '#e7c870', row: '#d3a94e', rw: 0.66 }] },
    { name: 'Porumb', icon: '🌽', stages: [PLOW, { base: '#c5b698', row: '#8fb46a', rw: 0.3 }, { base: '#a0c075', row: '#77a156', rw: 0.7 }, { base: '#87ac5f', row: '#62904a', rw: 0.85 }, { base: '#c2b56f', row: '#a4954f', rw: 0.8, dot: '#ecd88a' }] },
    { name: 'Floarea-soarelui', icon: '🌻', stages: [PLOW, { base: '#c5b698', row: '#98b871', rw: 0.3 }, { base: '#a7c37f', row: '#83aa5f', rw: 0.6 }, { base: '#98b76e', row: '#76a056', rw: 0.8, dot: '#c9c866' }, { base: '#90ae67', row: '#6c924f', rw: 0.85, dot: '#f4c534' }] },
    { name: 'Lavandă', icon: '💜', stages: [PLOW, { base: '#c2b8a6', row: '#a7b48c', rw: 0.3 }, { base: '#b3b298', row: '#99a387', rw: 0.6 }, { base: '#afa7b7', row: '#9c90ba', rw: 0.75 }, { base: '#b7a9d0', row: '#8a72c0', rw: 0.8, dot: '#b49be0' }] }
  ];
  const STAGE_NAMES = ['Arat', 'Răsare', 'Crește', 'Se coace', 'Gata de recoltat'];
  const ROOFS = ['#c96e4f', '#b65b45', '#7b8fb0', '#6e9a7a', '#a86f8c', '#d08a57', '#8a6f5a'];
  const AWNINGS = ['#d9534f', '#4a8fc9', '#5aa469', '#e8a33c', '#9b6cc4'];
  const CAR_COLORS = ['#d9534f', '#4a8fc9', '#f1c84b', '#f7f4ee', '#5aa469', '#3b4048', '#e8873c', '#9b6cc4'];
  const TREE_NAMES = ['', 'Stejar', 'Brad', 'Mesteacăn', 'Flori'];

  const CATEGORIES = [
    { id: 'roads', name: '🛣️ Drumuri' },
    { id: 'housing', name: '🏠 Locuințe' },
    { id: 'zones', name: '🏪 Magazine' },
    { id: 'farms', name: '🌾 Ferme' },
    { id: 'services', name: '🏥 Servicii' },
    { id: 'edu', name: '🎓 Educație' },
    { id: 'shops', name: '🛍️ Comerț' },
    { id: 'industry', name: '🏭 Industrie' },
    { id: 'transport', name: '🚌 Transport' },
    { id: 'leisure', name: '🎡 Agrement' },
    { id: 'nature', name: '🌳 Natură' }
  ];
  const TOOLS = [
    { id: 'hand', cat: 'base', icon: '✋', name: 'Mână', tip: 'Trage ca să muți harta (merge și cu săgețile / WASD sau scroll pe touchpad). Rotița = zoom. Cu orice unealtă: Space + trage = mută harta.' },
    { id: 'look', cat: 'base', icon: '🔍', name: 'Privește', tip: 'Treci cu mouse-ul (sau atinge) ca să vezi ce e pe fiecare pătrățel.' },
    { id: 'bulldoze', cat: 'base', kind: 'bulldoze', icon: '🚜', name: 'Buldozer', tip: 'Trage peste o zonă ca să ștergi tot. Merge oricând și cu click dreapta.' },
    { id: 'dirt', cat: 'roads', kind: 'road', road: 1, icon: '🟫', name: 'Drum de țară', tip: 'Trage de la un punct la altul pentru un drum de pământ. Poate trece și peste apă (pod).' },
    { id: 'street', cat: 'roads', kind: 'road', road: 2, icon: '🛣️', name: 'Stradă', tip: 'Stradă asfaltată, cu felinare. Mașinile merg mai repede.' },
    { id: 'highway', cat: 'roads', kind: 'road', road: 3, icon: '🛤️', name: 'Autostradă', tip: 'Două benzi pe sens, cu parapet la mijloc. Mașinile merg cel mai repede, dar casele nu au ieșire la autostradă.' },
    { id: 'walkway', cat: 'roads', kind: 'road', road: 4, icon: '🚶', name: 'Pietonal', tip: 'Stradă pietonală cu dale și jardiniere: doar oameni, fără mașini.' },
    { id: 'transit', cat: 'roads', kind: 'road', road: 5, icon: '🚋', name: 'Transport în comun', tip: 'Linie de tramvai și autobuz. Mașinile doar o traversează la intersecții.' },
    { id: 'res', cat: 'housing', kind: 'zone', zone: 1, icon: '🏡', name: 'Case', tip: 'Desenează un cartier lângă un drum - vor apărea case singure.' },
    { id: 'sp_house_floor', cat: 'housing', kind: 'special', spec: 'house_floor', icon: SPECIALS.house_floor.icon, name: 'Casă cu etaj', tip: 'O casă cu etaj, de vânzare sau de închiriat. Nu are nevoie de servicii ca să apară.' },
    { id: 'sp_house_pool', cat: 'housing', kind: 'special', spec: 'house_pool', icon: SPECIALS.house_pool.icon, name: 'Casă cu piscină', tip: 'O casă cu piscină, de vânzare sau de închiriat.' },
    { id: 'sp_villa', cat: 'housing', kind: 'special', spec: 'villa', icon: SPECIALS.villa.icon, name: 'Vilă', tip: 'O vilă mare cu grădină: locuință scumpă, de vânzare sau de închiriat.' },
    { id: 'sp_mansion', cat: 'housing', kind: 'special', spec: 'mansion', icon: SPECIALS.mansion.icon, name: 'Conac', tip: 'Cel mai scump conac din oraș, cu curte interioară.' },
    { id: 'sp_bloc', cat: 'housing', kind: 'special', spec: 'bloc', icon: '🏢', name: 'Bloc', tip: 'Bloc cu 12 apartamente: de vânzare de la Primărie și de închiriat. Nu are nevoie de servicii ca să apară.' },
    { id: 'com', cat: 'zones', kind: 'zone', zone: 2, icon: '🏪', name: 'Magazine', tip: 'Magazine și ateliere: locuri de muncă pentru locuitori.' },
    { id: 'crop0', cat: 'farms', kind: 'zone', zone: 3, crop: 0, icon: '🌾', name: 'Grâu', tip: 'Un câmp de grâu. Nu are nevoie de drum.' },
    { id: 'crop1', cat: 'farms', kind: 'zone', zone: 3, crop: 1, icon: '🌽', name: 'Porumb', tip: 'Un câmp de porumb.' },
    { id: 'crop2', cat: 'farms', kind: 'zone', zone: 3, crop: 2, icon: '🌻', name: 'Floarea-soarelui', tip: 'Un câmp de floarea-soarelui.' },
    { id: 'crop3', cat: 'farms', kind: 'zone', zone: 3, crop: 3, icon: '💜', name: 'Lavandă', tip: 'Un câmp de lavandă.' },
    { id: 'sp_barn', cat: 'farms', kind: 'special', spec: 'barn', icon: '🛖', name: 'Hambar', tip: 'Câmpurile din jur cresc mult mai repede.' },
    { id: 'sp_windmill', cat: 'farms', kind: 'special', spec: 'windmill', icon: '🌬️', name: 'Moară', tip: 'Câmpurile din jur cresc mai repede.' },
    { id: 'sp_clinic', cat: 'services', kind: 'special', spec: 'clinic', icon: SPECIALS.clinic.icon, name: 'Dispensar', tip: 'Ajută casele din jur să crească.' },
    { id: 'sp_medcenter', cat: 'services', kind: 'special', spec: 'medcenter', icon: SPECIALS.medcenter.icon, name: 'Clinică', tip: 'Clinică medicală: ajută casele din jur să crească.' },
    { id: 'sp_hospital', cat: 'services', kind: 'special', spec: 'hospital', icon: SPECIALS.hospital.icon, name: 'Spital', tip: 'Spitalul acoperă o zonă mare și are multe locuri de muncă.' },
    { id: 'sp_fire', cat: 'services', kind: 'special', spec: 'fire', icon: SPECIALS.fire.icon, name: 'Pompieri', tip: 'Ajută casele din jur să crească.' },
    { id: 'sp_church', cat: 'services', kind: 'special', spec: 'church', icon: SPECIALS.church.icon, name: 'Biserică', tip: 'Ajută casele din jur să crească.' },
    { id: 'sp_kinder', cat: 'edu', kind: 'special', spec: 'kinder', icon: SPECIALS.kinder.icon, name: 'Grădiniță', tip: 'Ajută casele din jur să crească.' },
    { id: 'sp_school', cat: 'edu', kind: 'special', spec: 'school', icon: SPECIALS.school.icon, name: 'Școală', tip: 'Ajută casele din jur să crească.' },
    { id: 'sp_highschool', cat: 'edu', kind: 'special', spec: 'highschool', icon: SPECIALS.highschool.icon, name: 'Liceu', tip: 'Liceu cu teren de sport. Ajută casele din jur să crească.' },
    { id: 'sp_dorm', cat: 'edu', kind: 'special', spec: 'dorm', icon: SPECIALS.dorm.icon, name: 'Cămin', tip: 'Cămin de elevi. Ajută casele din jur să crească.' },
    { id: 'sp_market', cat: 'shops', kind: 'special', spec: 'market', icon: SPECIALS.market.icon, name: 'Piață', tip: 'Multe locuri de muncă și case mai frumoase în jur.' },
    { id: 'sp_penny', cat: 'shops', kind: 'special', spec: 'penny', icon: SPECIALS.penny.icon, name: 'Penny', tip: 'Supermarket mic. Ajută casele din jur să crească.' },
    { id: 'sp_lidl', cat: 'shops', kind: 'special', spec: 'lidl', icon: SPECIALS.lidl.icon, name: 'Lidl', tip: 'Supermarket. Ajută casele din jur să crească.' },
    { id: 'sp_kaufland', cat: 'shops', kind: 'special', spec: 'kaufland', icon: SPECIALS.kaufland.icon, name: 'Kaufland', tip: 'Hipermarket cu parcare. Ajută casele din jur să crească.' },
    { id: 'sp_carrefour', cat: 'shops', kind: 'special', spec: 'carrefour', icon: SPECIALS.carrefour.icon, name: 'Carrefour', tip: 'Hipermarket cu parcare. Ajută casele din jur să crească.' },
    { id: 'sp_mall', cat: 'shops', kind: 'special', spec: 'mall', icon: SPECIALS.mall.icon, name: 'Mall', tip: 'Cel mai mare magazin: multe locuri de muncă, acoperă o zonă mare.' },
    { id: 'sp_rompetrol', cat: 'shops', kind: 'special', spec: 'rompetrol', icon: SPECIALS.rompetrol.icon, name: 'Rompetrol', tip: 'Benzinărie. Pune-o lângă un drum.' },
    { id: 'sp_omv', cat: 'shops', kind: 'special', spec: 'omv', icon: SPECIALS.omv.icon, name: 'OMV', tip: 'Benzinărie. Pune-o lângă un drum.' },
    { id: 'sp_socar', cat: 'shops', kind: 'special', spec: 'socar', icon: SPECIALS.socar.icon, name: 'SOCAR', tip: 'Benzinărie. Pune-o lângă un drum.' },
    { id: 'sp_factory_s', cat: 'industry', kind: 'special', spec: 'factory_s', icon: SPECIALS.factory_s.icon, name: 'Fabrică mică', tip: 'Locuri de muncă. Nu ajută casele.' },
    { id: 'sp_factory_m', cat: 'industry', kind: 'special', spec: 'factory_m', icon: SPECIALS.factory_m.icon, name: 'Fabrică medie', tip: 'Locuri de muncă. Nu ajută casele.' },
    { id: 'sp_factory_l', cat: 'industry', kind: 'special', spec: 'factory_l', icon: SPECIALS.factory_l.icon, name: 'Fabrică mare', tip: 'Multe locuri de muncă. Nu ajută casele.' },
    { id: 'sp_factory_xl', cat: 'industry', kind: 'special', spec: 'factory_xl', icon: SPECIALS.factory_xl.icon, name: 'Gigantică', tip: 'Fabrică gigantică: foarte multe locuri de muncă.' },
    { id: 'sp_solar', cat: 'industry', kind: 'special', spec: 'solar', icon: SPECIALS.solar.icon, name: 'Fotovoltaic', tip: 'Parc fotovoltaic: panouri solare, câțiva tehnicieni.' },
    { id: 'sp_parking_s', cat: 'transport', kind: 'special', spec: 'parking_s', icon: SPECIALS.parking_s.icon, name: 'Parcare mică', tip: 'Câteva locuri de parcare.' },
    { id: 'sp_parking_l', cat: 'transport', kind: 'special', spec: 'parking_l', icon: SPECIALS.parking_l.icon, name: 'Parcare mare', tip: 'Parcare mare cu alei.' },
    { id: 'sp_busdepot', cat: 'transport', kind: 'special', spec: 'busdepot', icon: SPECIALS.busdepot.icon, name: 'Autobuze', tip: 'Autobază: transport în comun pentru casele din jur.' },
    { id: 'sp_tramdepot', cat: 'transport', kind: 'special', spec: 'tramdepot', icon: SPECIALS.tramdepot.icon, name: 'Tramvaie', tip: 'Depou de tramvaie: transport în comun pentru casele din jur.' },
    { id: 'sp_park', cat: 'leisure', kind: 'special', spec: 'park', icon: SPECIALS.park.icon, name: 'Parc', tip: 'Casele din jur devin mai frumoase.' },
    { id: 'sp_fountain', cat: 'leisure', kind: 'special', spec: 'fountain', icon: SPECIALS.fountain.icon, name: 'Fântână', tip: 'O fântână pentru vecini.' },
    { id: 'sp_pool', cat: 'leisure', kind: 'special', spec: 'pool', icon: SPECIALS.pool.icon, name: 'Piscină', tip: 'Loc de relaxare pentru casele din jur.' },
    { id: 'sp_stadium_s', cat: 'leisure', kind: 'special', spec: 'stadium_s', icon: SPECIALS.stadium_s.icon, name: 'Stadion mic', tip: 'Loc de relaxare, cu fotbaliști angajați.' },
    { id: 'sp_stadium_m', cat: 'leisure', kind: 'special', spec: 'stadium_m', icon: SPECIALS.stadium_m.icon, name: 'Stadion mediu', tip: 'Loc de relaxare, cu fotbaliști angajați.' },
    { id: 'sp_stadium_l', cat: 'leisure', kind: 'special', spec: 'stadium_l', icon: SPECIALS.stadium_l.icon, name: 'Stadion mare', tip: 'Arena orașului.' },
    { id: 'sp_bar', cat: 'leisure', kind: 'special', spec: 'bar', icon: SPECIALS.bar.icon, name: 'Bar', tip: 'Loc de relaxare pentru casele din jur.' },
    { id: 'sp_restaurant', cat: 'leisure', kind: 'special', spec: 'restaurant', icon: SPECIALS.restaurant.icon, name: 'Restaurant', tip: 'Loc de relaxare pentru casele din jur.' },
    { id: 'sp_aumovio', cat: 'industry', kind: 'special', spec: 'aumovio', icon: SPECIALS.aumovio.icon, name: 'AuNau-movio', tip: 'Companie IT cu 5 locuri de muncă bine plătite (programatori).' },
    { id: 'sp_dealership', cat: 'shops', kind: 'special', spec: 'dealership', icon: SPECIALS.dealership.icon, name: 'Dealership', tip: 'Dealership auto: locuitorii își cumpără aici mașini personale și circulă cu ele.' },
    { id: 'sp_usedlot', cat: 'shops', kind: 'special', spec: 'usedlot', icon: SPECIALS.usedlot.icon, name: 'Parc auto', tip: 'Parc auto: jucătorii vând și cumpără aici mașini second-hand.' },
    { id: 'sp_airport', cat: 'transport', kind: 'special', spec: 'airport', icon: SPECIALS.airport.icon, name: 'Aeroport', tip: 'Aeroport mare: foarte multe locuri de muncă și transport pentru casele din jur.' },
    { id: 'sp_amusement', cat: 'leisure', kind: 'special', spec: 'amusement', icon: SPECIALS.amusement.icon, name: 'Distracții', tip: 'Parc de distracții cu roată mare.' },
    { id: 'oak', cat: 'nature', kind: 'tree', deco: 1, icon: '🌳', name: 'Stejar', tip: 'Click sau trage ca să plantezi copaci.' },
    { id: 'pine', cat: 'nature', kind: 'tree', deco: 2, icon: '🌲', name: 'Brad', tip: 'Click sau trage ca să plantezi brazi.' },
    { id: 'birch', cat: 'nature', kind: 'tree', deco: 3, icon: '🍃', name: 'Mesteacăn', tip: 'Click sau trage ca să plantezi mesteceni.' },
    { id: 'flowers', cat: 'nature', kind: 'tree', deco: 4, icon: '🌸', name: 'Flori', tip: 'Click sau trage ca să pui flori.' },
    { id: 'forest', cat: 'nature', kind: 'forest', icon: '🌲', name: 'Pădure', tip: 'Trage un dreptunghi ca să crești o pădure.' },
    { id: 'water', cat: 'nature', kind: 'water', icon: '💧', name: 'Lac', tip: 'Trage un dreptunghi ca să faci un lac.' },
    { id: 'land', cat: 'nature', kind: 'land', icon: '🏞️', name: 'Pământ', tip: 'Trage peste apă ca să o umpli cu pământ.' }
  ];
  const TOOL = {};
  TOOLS.forEach(function (t) { TOOL[t.id] = t; });

  // ================= STATE =================
  let ground = new Uint8Array(N);     // 0 iarba, 1 apa
  let road = new Uint8Array(N);       // 0, 1 pamant, 2 asfalt (vezi ROAD_NAMES)
  let zone = new Uint8Array(N);       // 0, 1 case, 2 magazine, 3 camp
  let crop = new Uint8Array(N);
  let level = new Uint8Array(N);      // nivelul cladirii din zona (0 = teren gol)
  let deco = new Uint8Array(N);       // 0, 1 stejar, 2 brad, 3 mesteacan, 4 flori
  let growth = new Float32Array(N);
  let spec = new Int16Array(N).fill(-1);
  let svcMask = new Uint16Array(N);   // ce tipuri de servicii acopera fiecare patratel (bit per tip)
  let farmBoost = new Float32Array(N).fill(1);
  // Aloca din nou toate straturile pentru o harta w x h (goala).
  function allocWorld(w, h) {
    W = w; H = h; N = W * H; CX = Math.ceil(W / CH); CY = Math.ceil(H / CH);
    ground = new Uint8Array(N); road = new Uint8Array(N); zone = new Uint8Array(N); crop = new Uint8Array(N);
    level = new Uint8Array(N); deco = new Uint8Array(N); growth = new Float32Array(N);
    spec = new Int16Array(N).fill(-1); svcMask = new Uint16Array(N); farmBoost = new Float32Array(N).fill(1);
    grassCol = new Array(N);
    computeGrass();
    chunkCanvases = new Array(CX * CY).fill(null);
    dirty.clear();
    markAll();
  }
  let specials = [];

  // ox/oy: cate coloane/randuri s-au adaugat in total la vest/nord (serverul muta proprietatile cu atat)
  const S = { name: 'Satul Verde', seed: 1, minutes: 8 * 60, weather: 0, weatherUntil: 12 * 60, speed: 1, ox: 0, oy: 0 };
  const stats = { pop: 0, houses: 0, shops: 0, fields: 0, jobs: 0, happy: 0, roads: 0 };
  const demand = { res: 0.6, com: 0.2 };
  let cars = [];                    // vehicule si pietoni: k = 'car' | 'tram' | 'walker'
  const roadCount = new Array(6).fill(0);
  let undoStack = [];
  let unsaved = false;

  // ================= UTIL =================
  function idx(x, y) { return y * W + x; }
  function inb(x, y) { return x >= 0 && y >= 0 && x < W && y < H; }
  function clamp(v, a, b) { return v < a ? a : v > b ? b : v; }
  function h2(x, y, s) {
    let n = (x * 374761393 + y * 668265263 + s * 1442695041) | 0;
    n = Math.imul(n ^ (n >>> 13), 1274126177);
    n = n ^ (n >>> 16);
    return (n >>> 0) / 4294967295;
  }
  function mulberry32(a) {
    return function () {
      a |= 0; a = (a + 0x6D2B79F5) | 0;
      let t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }
  function vnoise(x, y, s, seed) {
    const X = Math.floor(x / s), Y = Math.floor(y / s), fx = x / s - X, fy = y / s - Y;
    const a = h2(X, Y, seed), b = h2(X + 1, Y, seed), c = h2(X, Y + 1, seed), d = h2(X + 1, Y + 1, seed);
    const ux = fx * fx * (3 - 2 * fx), uy = fy * fy * (3 - 2 * fy);
    return a + (b - a) * ux + (c - a) * uy + (a - b - c + d) * ux * uy;
  }
  function shade(hex, amt) {
    const n = parseInt(hex.slice(1), 16);
    let r = n >> 16, g = (n >> 8) & 255, b = n & 255;
    const t = amt < 0 ? 0 : 255, p = Math.abs(amt);
    r = Math.round(r + (t - r) * p); g = Math.round(g + (t - g) * p); b = Math.round(b + (t - b) * p);
    return 'rgb(' + r + ',' + g + ',' + b + ')';
  }
  function rr(c, x, y, w, h, r) {
    const R = typeof r === 'number' ? [r, r, r, r] : r;
    c.beginPath();
    c.moveTo(x + R[0], y);
    c.arcTo(x + w, y, x + w, y + h, R[1]);
    c.arcTo(x + w, y + h, x, y + h, R[2]);
    c.arcTo(x, y + h, x, y, R[3]);
    c.arcTo(x, y, x + w, y, R[0]);
    c.closePath();
  }
  function isWater(x, y) { return !inb(x, y) || ground[idx(x, y)] === 1; }
  function isField(x, y) { return inb(x, y) && zone[idx(x, y)] === 3; }
  function stageOf(g) { return g < 0.08 ? 0 : g < 0.35 ? 1 : g < 0.7 ? 2 : g < 1 ? 3 : 4; }
  function roadNear(x, y) {
    for (let dy = -2; dy <= 2; dy++) for (let dx = -2; dx <= 2; dx++) {
      if (Math.abs(dx) + Math.abs(dy) > 2) continue;
      const nx = x + dx, ny = y + dy;
      if (inb(nx, ny) && accessRoad(idx(nx, ny))) return true;
    }
    return false;
  }
  function roadDir(x, y) {
    for (let r = 1; r <= 2; r++) {
      for (let d = 0; d < 4; d++) {
        const order = [2, 0, 1, 3][d];
        const nx = x + DIRS[order][0] * r, ny = y + DIRS[order][1] * r;
        if (inb(nx, ny) && accessRoad(idx(nx, ny))) return order;
      }
    }
    return 2;
  }
  function roadMask(x, y) {
    let m = 0;
    if (y > 0 && road[idx(x, y - 1)]) m |= 1;
    if (x < W - 1 && road[idx(x + 1, y)]) m |= 2;
    if (y < H - 1 && road[idx(x, y + 1)]) m |= 4;
    if (x > 0 && road[idx(x - 1, y)]) m |= 8;
    return m;
  }

  // ================= WORLD GENERATION =================
  function clearWorld() {
    ground.fill(0); road.fill(0); zone.fill(0); crop.fill(0); level.fill(0); deco.fill(0); growth.fill(0); spec.fill(-1);
    specials = [];
  }

  function generate(seed) {
    clearWorld();
    const rnd = mulberry32(seed);
    const ph = rnd() * 6.28, ph2 = rnd() * 6.28;
    // rau serpuit de la vest la est
    for (let x = 0; x < W; x++) {
      const cy = H * 0.7 + Math.sin(x * 0.11 + ph) * 4 + Math.sin(x * 0.043 + ph2) * 5;
      const hw = 1.3 + Math.sin(x * 0.07 + ph2) * 0.45;
      for (let y = 0; y < H; y++) if (Math.abs(y - cy) < hw) ground[idx(x, y)] = 1;
    }
    // un lac
    const lx = 8 + rnd() * (W * 0.3), ly = 6 + rnd() * 10, rx = 3 + rnd() * 3, ry = 2.2 + rnd() * 2;
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      const d = ((x - lx) / rx) ** 2 + ((y - ly) / ry) ** 2;
      if (d < 1 + (vnoise(x, y, 2, seed + 3) - 0.5) * 0.6) ground[idx(x, y)] = 1;
    }
    // paduri si flori
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      const i = idx(x, y);
      if (ground[i]) continue;
      const n = vnoise(x, y, 9, seed + 1) * 0.7 + vnoise(x, y, 3, seed + 2) * 0.3;
      const r = rnd();
      if (n > 0.62 && r < 0.85) deco[i] = vnoise(x, y, 6, seed + 4) > 0.5 ? 2 : (r < 0.15 ? 3 : 1);
      else if (r < 0.015) deco[i] = 1;
      else if (r < 0.03) deco[i] = 4;
    }
    // doua drumuri de tara care se intersecteaza (unul trece raul pe pod)
    const ry0 = Math.floor(H * 0.36), rx0 = Math.floor(W * 0.46);
    for (let x = 0; x < W; x++) { const i = idx(x, ry0); road[i] = 1; deco[i] = 0; }
    for (let y = 0; y < H; y++) { const i = idx(rx0, y); road[i] = 1; deco[i] = 0; }
    S.minutes = 8 * 60; S.weather = 0; S.weatherUntil = 14 * 60;
    cam.x = (rx0 + 0.5) * T; cam.y = (ry0 + 0.5) * T;
    cam.z = 1;
  }

  // ================= COVERAGE (cladiri speciale) =================
  function recomputeCoverage() {
    svcMask.fill(0); farmBoost.fill(1);
    specials.forEach(function (s) {
      if (!s) return;
      const d = SPECIALS[s.t], bit = covBit(d.cov);
      const cx = s.x + d.w / 2, cy = s.y + d.h / 2, r = d.radius;
      if (!bit || !r) return;
      for (let y = Math.max(0, Math.floor(cy - r)); y < Math.min(H, Math.ceil(cy + r)); y++) {
        for (let x = Math.max(0, Math.floor(cx - r)); x < Math.min(W, Math.ceil(cx + r)); x++) {
          const dx = x + 0.5 - cx, dy = y + 0.5 - cy;
          if (dx * dx + dy * dy > r * r) continue;
          const i = idx(x, y);
          svcMask[i] |= bit;
          if (d.farm) farmBoost[i] = Math.max(farmBoost[i], d.farm);
        }
      }
    });
  }
  const LEISURE_BITS = covBit('leisure');
  const FARM_BITS = covBit('farm');
  function serviceCount(i) {
    let m = svcMask[i] & ~FARM_BITS, n = 0;
    while (m) { n += m & 1; m >>= 1; }
    return n;
  }
  function happinessOf(i) { return Math.min(1, serviceCount(i) / 4); }
  function covList(i) {
    const have = COVERAGE.filter(function (k) { return COV_NAMES[k] && (svcMask[i] & covBit(k)); }).map(function (k) { return COV_NAMES[k]; });
    return have.length ? 'are: ' + have.join(', ') : 'deocamdată niciunul';
  }

  // ================= OFFSCREEN RENDER =================
  // Harta statica e desenata in bucati de CH x CH patratele, fiecare in canvas-ul ei: o singura
  // imagine pentru toata harta ar depasi limita de marime a canvas-ului pe telefoane la hartile mari.
  let chunkCanvases = new Array(CX * CY).fill(null);
  const dirty = new Set();
  let grassCol = new Array(N);

  function computeGrass() {
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      const t = vnoise(x, y, 6, 77) * 0.6 + vnoise(x, y, 2, 78) * 0.4;
      const r = Math.round(156 + t * 18), g = Math.round(198 + t * 16), b = Math.round(118 + t * 16);
      grassCol[idx(x, y)] = 'rgb(' + r + ',' + g + ',' + b + ')';
    }
  }
  function markChunkAt(x, y) {
    if (!inb(x, y)) return;
    dirty.add(Math.floor(x / CH) + Math.floor(y / CH) * CX);
  }
  function markTile(x, y) {
    for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) markChunkAt(x + dx, y + dy);
  }
  function markRect(x0, y0, x1, y1) {
    const cx0 = Math.max(0, Math.floor((x0 - 1) / CH)), cy0 = Math.max(0, Math.floor((y0 - 1) / CH));
    const cx1 = Math.min(CX - 1, Math.floor((x1 + 1) / CH)), cy1 = Math.min(CY - 1, Math.floor((y1 + 1) / CH));
    for (let cy = cy0; cy <= cy1; cy++) for (let cx = cx0; cx <= cx1; cx++) dirty.add(cx + cy * CX);
  }
  function markAll() { for (let i = 0; i < CX * CY; i++) dirty.add(i); }

  function renderChunk(ci) {
    const cx = ci % CX, cy = Math.floor(ci / CX);
    const x0 = cx * CH, y0 = cy * CH, x1 = Math.min(W, x0 + CH), y1 = Math.min(H, y0 + CH);
    const ax0 = Math.max(0, x0 - 1), ay0 = Math.max(0, y0 - 1), ax1 = Math.min(W, x1 + 1), ay1 = Math.min(H, y1 + 1);
    let cv = chunkCanvases[ci];
    if (!cv) { cv = chunkCanvases[ci] = document.createElement('canvas'); cv.width = CH * T; cv.height = CH * T; }
    const c = cv.getContext('2d');
    c.save();
    c.setTransform(1, 0, 0, 1, -x0 * T, -y0 * T);
    c.clearRect(x0 * T, y0 * T, CH * T, CH * T);
    c.beginPath(); c.rect(x0 * T, y0 * T, (x1 - x0) * T, (y1 - y0) * T); c.clip();
    let x, y;
    for (y = ay0; y < ay1; y++) for (x = ax0; x < ax1; x++) drawGrass(c, x, y);
    for (y = ay0; y < ay1; y++) for (x = ax0; x < ax1; x++) if (ground[idx(x, y)]) drawWater(c, x, y);
    for (y = ay0; y < ay1; y++) for (x = ax0; x < ax1; x++) drawZoneGround(c, x, y);
    for (y = ay0; y < ay1; y++) for (x = ax0; x < ax1; x++) if (zone[idx(x, y)] === 3) drawField(c, x, y);
    for (let pass = 0; pass < 3; pass++) {
      for (y = ay0; y < ay1; y++) for (x = ax0; x < ax1; x++) if (road[idx(x, y)]) drawRoad(c, x, y, pass);
    }
    for (y = ay0; y < ay1; y++) for (x = ax0; x < ax1; x++) drawBuilding(c, x, y, true);
    for (y = ay0; y < ay1; y++) for (x = ax0; x < ax1; x++) drawBuilding(c, x, y, false);
    specials.forEach(function (s) {
      if (!s) return;
      const d = SPECIALS[s.t];
      if (s.x < ax1 && s.x + d.w > ax0 && s.y < ay1 && s.y + d.h > ay0) drawSpecial(c, s);
    });
    for (y = ay0; y < ay1; y++) for (x = ax0; x < ax1; x++) { const dv = deco[idx(x, y)]; if (dv && dv < 4) drawTree(c, x, y, dv, true); }
    for (y = ay0; y < ay1; y++) for (x = ax0; x < ax1; x++) { const dv = deco[idx(x, y)]; if (dv) drawTree(c, x, y, dv, false); }
    c.restore();
  }

  function drawGrass(c, x, y) {
    const i = idx(x, y), px = x * T, py = y * T;
    c.fillStyle = grassCol[i];
    c.fillRect(px, py, T, T);
    c.fillStyle = 'rgba(110,150,80,0.35)';
    for (let k = 0; k < 3; k++) {
      if (h2(x, y, 11 + k) < 0.55) c.fillRect(px + h2(x, y, 21 + k) * (T - 4), py + h2(x, y, 31 + k) * (T - 6), 1.6, 4);
    }
  }

  function drawWater(c, x, y) {
    const px = x * T, py = y * T, R = T * 0.45, ex = T * 0.12;
    const n = isWater(x, y - 1), e = isWater(x + 1, y), s = isWater(x, y + 1), w = isWater(x - 1, y);
    const rad = [!n && !w ? R : 0, !n && !e ? R : 0, !s && !e ? R : 0, !s && !w ? R : 0];
    const x0 = px - (w ? 0 : ex), y0 = py - (n ? 0 : ex), x1 = px + T + (e ? 0 : ex), y1 = py + T + (s ? 0 : ex);
    c.fillStyle = '#e2d6a9';
    rr(c, x0, y0, x1 - x0, y1 - y0, rad.map(function (r) { return r ? r + ex : 0; }));
    c.fill();
    c.fillStyle = '#86c1db';
    rr(c, px, py, T, T, rad);
    c.fill();
    c.strokeStyle = 'rgba(255,255,255,0.32)';
    c.lineWidth = 1.5;
    if (h2(x, y, 41) < 0.5) {
      c.beginPath(); c.arc(px + h2(x, y, 42) * T, py + h2(x, y, 43) * T, T * 0.12, 0.2, 2.6); c.stroke();
    }
  }

  function drawZoneGround(c, x, y) {
    const i = idx(x, y), z = zone[i];
    if ((z !== 1 && z !== 2) || road[i] || ground[i]) return;
    const px = x * T, py = y * T;
    if (z === 1) c.fillStyle = 'rgba(196,230,152,0.6)';
    else c.fillStyle = level[i] ? 'rgba(224,218,206,0.95)' : 'rgba(190,208,230,0.6)';
    c.fillRect(px, py, T, T);
    if (!level[i]) {
      c.strokeStyle = z === 1 ? 'rgba(255,255,255,0.7)' : 'rgba(110,140,180,0.6)';
      c.lineWidth = 1.5;
      c.setLineDash([4, 4]);
      c.strokeRect(px + 5, py + 5, T - 10, T - 10);
      c.setLineDash([]);
    }
  }

  function drawField(c, x, y) {
    const i = idx(x, y), st = CROPS[crop[i]].stages[stageOf(growth[i])];
    const px = x * T, py = y * T, rowH = T / 5;
    c.fillStyle = st.base;
    c.fillRect(px, py, T, T);
    c.fillStyle = st.row;
    for (let r = 0; r < 5; r++) c.fillRect(px, py + r * rowH + rowH * (1 - st.rw) / 2, T, rowH * st.rw);
    if (st.dot) {
      c.fillStyle = st.dot;
      for (let r = 0; r < 5; r++) for (let k = 0; k < 5; k++) {
        c.beginPath();
        c.arc(px + (k + 0.5) * T / 5 + (r % 2) * 2, py + (r + 0.5) * rowH, 1.8, 0, 6.29);
        c.fill();
      }
    }
    c.fillStyle = 'rgba(95,72,40,0.28)';
    if (!isField(x, y - 1)) c.fillRect(px, py, T, 2);
    if (!isField(x, y + 1)) c.fillRect(px, py + T - 2, T, 2);
    if (!isField(x - 1, y)) c.fillRect(px, py, 2, T);
    if (!isField(x + 1, y)) c.fillRect(px + T - 2, py, 2, T);
  }

  function roadShapePath(c, x, y, half) {
    const cx = x * T + T / 2, cy = y * T + T / 2, m = roadMask(x, y);
    c.beginPath();
    if (!m) { c.arc(cx, cy, half * 1.15, 0, 6.29); return; }
    c.rect(cx - half, cy - half, half * 2, half * 2);
    if (m & 1) c.rect(cx - half, y * T, half * 2, T / 2);
    if (m & 4) c.rect(cx - half, cy, half * 2, T / 2);
    if (m & 2) c.rect(cx, cy - half, T / 2, half * 2);
    if (m & 8) c.rect(x * T, cy - half, T / 2, half * 2);
  }
  function roadShape(c, x, y, half) {
    const cx = x * T + T / 2, cy = y * T + T / 2, m = roadMask(x, y);
    c.beginPath();
    if (!m) { c.arc(cx, cy, half * 1.15, 0, 6.29); c.fill(); return; }
    c.rect(cx - half, cy - half, half * 2, half * 2);
    if (m & 1) c.rect(cx - half, y * T, half * 2, T / 2);
    if (m & 4) c.rect(cx - half, cy, half * 2, T / 2);
    if (m & 2) c.rect(cx, cy - half, T / 2, half * 2);
    if (m & 8) c.rect(x * T, cy - half, T / 2, half * 2);
    c.fill();
  }
  function drawRoad(c, x, y, pass) {
    const i = idx(x, y), type = road[i], bridge = ground[i] === 1;
    const st = ROAD_STYLE[type] || ROAD_STYLE[1], half = T * st.half;
    const cx = x * T + T / 2, cy = y * T + T / 2, m = roadMask(x, y);
    if (pass === 0) {
      if (bridge) {
        c.fillStyle = 'rgba(30,60,80,0.25)';
        c.save(); c.translate(3, 4); roadShape(c, x, y, half + T * 0.12); c.restore();
        c.fillStyle = '#9a7650';
        roadShape(c, x, y, half + T * 0.12);
      }
      c.fillStyle = st.edgeCol;
      roadShape(c, x, y, Math.min(T / 2, half + T * st.edge));
    } else if (pass === 1) {
      c.fillStyle = st.col;
      roadShape(c, x, y, half);
    } else {
      const vertical = m === 5, horizontal = m === 10;
      // ln(off, w, dash): o linie de-a lungul drumului, la distanta off de mijloc
      const ln = function (off, w, dash) {
        if (!dash) { if (vertical) c.fillRect(cx + off - w / 2, y * T, w, T); else c.fillRect(x * T, cy + off - w / 2, T, w); return; }
        for (let k = -1; k <= 1; k += 2) {
          const o = k * T * 0.25;
          if (vertical) c.fillRect(cx + off - w / 2, cy + o - T * 0.1, w, T * 0.2); else c.fillRect(cx + o - T * 0.1, cy + off - w / 2, T * 0.2, w);
        }
      };
      if (type === 3 && (vertical || horizontal)) {
        c.fillStyle = 'rgba(255,255,255,0.85)'; ln(-half + 2.5, 1.5); ln(half - 2.5, 1.5);
        c.fillStyle = 'rgba(255,255,255,0.7)'; ln(-T * 0.22, 1.6, true); ln(T * 0.22, 1.6, true);
        c.fillStyle = '#c3c6ca'; ln(0, 3.2); c.fillStyle = '#8d9196'; ln(0, 1);
      } else if (type === 4) {
        // rosturile dalelor, doar pe suprafata drumului
        c.save(); roadShapePath(c, x, y, half); c.clip();
        c.strokeStyle = 'rgba(160,135,100,0.35)'; c.lineWidth = 1; c.beginPath();
        for (let k = 1; k < 4; k++) {
          const p = T * k / 4;
          c.moveTo(x * T + p, y * T); c.lineTo(x * T + p, y * T + T);
          c.moveTo(x * T, y * T + p); c.lineTo(x * T + T, y * T + p);
        }
        c.stroke(); c.restore();
        if ((vertical || horizontal) && h2(x, y, 61) < 0.35) {   // jardiniera
          const side = h2(x, y, 62) < 0.5 ? -1 : 1, off = side * (half - T * 0.09);
          const px = vertical ? cx + off : cx, py = vertical ? cy : cy + off;
          c.fillStyle = '#b79f7c'; c.beginPath(); c.arc(px, py, T * 0.09, 0, 6.29); c.fill();
          c.fillStyle = '#6fae5c'; c.beginPath(); c.arc(px, py, T * 0.065, 0, 6.29); c.fill();
          c.fillStyle = AWNINGS[Math.floor(h2(x, y, 63) * AWNINGS.length) % AWNINGS.length]; c.beginPath(); c.arc(px - 1, py - 1, T * 0.025, 0, 6.29); c.fill();
        }
      } else if (type === 5 && (vertical || horizontal)) {
        c.fillStyle = 'rgba(255,255,255,0.8)'; ln(-half + 2, 1.4); ln(half - 2, 1.4);
        c.fillStyle = '#4b4f55';
        for (let k = -1; k <= 1; k += 2) { ln(k * T * 0.13 - T * 0.045, 1.6); ln(k * T * 0.13 + T * 0.045, 1.6); }
        c.fillStyle = 'rgba(255,255,255,0.6)'; ln(0, 1.2, true);
      } else if (type === 2 && (vertical || horizontal)) {
        c.fillStyle = 'rgba(255,255,255,0.75)';
        for (let k = -1; k <= 1; k += 2) {
          const off = k * T * 0.25;
          if (vertical) c.fillRect(cx - 1, cy + off - T * 0.1, 2, T * 0.2);
          else c.fillRect(cx + off - T * 0.1, cy - 1, T * 0.2, 2);
        }
      } else if (type === 1 && (vertical || horizontal)) {
        c.fillStyle = 'rgba(140,110,70,0.35)';
        for (let k = -1; k <= 1; k += 2) {
          const off = k * half * 0.45;
          if (vertical) c.fillRect(cx + off - 1, y * T, 2, T);
          else c.fillRect(x * T, cy + off - 1, T, 2);
        }
      }
      if (bridge) {
        c.fillStyle = '#6f5236';
        const rh = half + T * 0.1;
        if (vertical) { c.fillRect(cx - rh, y * T, 2.5, T); c.fillRect(cx + rh - 2.5, y * T, 2.5, T); }
        else if (horizontal) { c.fillRect(x * T, cy - rh, T, 2.5); c.fillRect(x * T, cy + rh - 2.5, T, 2.5); }
      }
    }
  }

  function houseBox(x, y, lv, sizes, push) {
    const dir = roadDir(x, y), d = DIRS[dir];
    const s = sizes[lv] * T;
    const cx = x * T + T / 2 + d[0] * T * push, cy = y * T + T / 2 + d[1] * T * push;
    return { dir: dir, d: d, s: s, cx: cx, cy: cy, x: cx - s / 2, y: cy - s / 2 };
  }
  const HOUSE_SIZES = [0, 0.52, 0.64, 0.78];
  const SHOP_SIZES = [0, 0.6, 0.74, 0.88];

  function drawBuilding(c, x, y, shadow) {
    const i = idx(x, y), lv = level[i];
    if (!lv || road[i] || ground[i]) return;
    if (zone[i] === 1) drawHouse(c, x, y, lv, shadow);
    else if (zone[i] === 2) drawShop(c, x, y, lv, shadow);
  }

  function drawHouse(c, x, y, lv, shadow) {
    const b = houseBox(x, y, lv, HOUSE_SIZES, 0.1), hv = h2(x, y, 5);
    if (shadow) {
      c.fillStyle = 'rgba(40,55,30,0.22)';
      rr(c, b.x + T * 0.07, b.y + T * (lv === 3 ? 0.13 : 0.09), b.s, b.s, 3);
      c.fill();
      return;
    }
    // aleea spre drum - cand drumul e chiar langa casa, intra putin in patratelul lui, pana la asfalt
    c.fillStyle = '#e4dbc8';
    const pw = T * 0.1;
    const nx = x + b.d[0], ny = y + b.d[1];
    const ext = inb(nx, ny) && road[idx(nx, ny)] ? T * 0.22 : 0;
    if (b.dir === 2) c.fillRect(b.cx - pw / 2, b.y + b.s, pw, y * T + T - (b.y + b.s) + ext);
    else if (b.dir === 0) c.fillRect(b.cx - pw / 2, y * T - ext, pw, b.y - y * T + ext);
    else if (b.dir === 1) c.fillRect(b.x + b.s, b.cy - pw / 2, x * T + T - (b.x + b.s) + ext, pw);
    else c.fillRect(x * T - ext, b.cy - pw / 2, b.x - x * T + ext, pw);
    // gradinita sau gard
    if (lv === 1 && hv < 0.5) {
      const gx = b.x - b.d[0] * T * 0.22 + T * 0.04, gy = b.y - b.d[1] * T * 0.22 + T * 0.04;
      c.fillStyle = '#a88a62'; c.fillRect(gx, gy, b.s * 0.5, b.s * 0.32);
      c.fillStyle = '#7fb05a';
      for (let k = 0; k < 3; k++) { c.beginPath(); c.arc(gx + 3 + k * b.s * 0.15, gy + b.s * 0.16, 1.8, 0, 6.29); c.fill(); }
    }
    if (lv === 2 && hv < 0.45) {
      c.strokeStyle = 'rgba(150,115,75,0.8)'; c.lineWidth = 1.5;
      c.strokeRect(x * T + 3, y * T + 3, T - 6, T - 6);
    }
    const col = ROOFS[Math.floor(hv * ROOFS.length)];
    if (lv === 3) {
      c.fillStyle = '#e2dacb'; rr(c, b.x, b.y, b.s, b.s, 3); c.fill();
      c.strokeStyle = col; c.lineWidth = 3; rr(c, b.x + 1.5, b.y + 1.5, b.s - 3, b.s - 3, 2); c.stroke();
      c.fillStyle = '#bfb6a7';
      c.fillRect(b.x + b.s * 0.2, b.y + b.s * 0.22, b.s * 0.2, b.s * 0.16);
      c.fillRect(b.x + b.s * 0.58, b.y + b.s * 0.6, b.s * 0.18, b.s * 0.14);
      return;
    }
    const ridgeH = b.dir === 0 || b.dir === 2;
    c.save();
    rr(c, b.x, b.y, b.s, b.s, 2); c.clip();
    c.fillStyle = col; c.fillRect(b.x, b.y, b.s, b.s);
    c.fillStyle = shade(col, -0.2);
    if (ridgeH) c.fillRect(b.x, b.cy, b.s, b.s / 2); else c.fillRect(b.cx, b.y, b.s / 2, b.s);
    c.restore();
    c.strokeStyle = shade(col, 0.28); c.lineWidth = 1.6;
    c.beginPath();
    if (ridgeH) { c.moveTo(b.x + 2, b.cy); c.lineTo(b.x + b.s - 2, b.cy); }
    else { c.moveTo(b.cx, b.y + 2); c.lineTo(b.cx, b.y + b.s - 2); }
    c.stroke();
    if (lv >= 2) {
      c.fillStyle = '#7d6a5c';
      c.fillRect(b.x + b.s * 0.68, b.y + b.s * 0.14, b.s * 0.13, b.s * 0.13);
    }
  }

  function drawShop(c, x, y, lv, shadow) {
    const b = houseBox(x, y, lv, SHOP_SIZES, 0.05), hv = h2(x, y, 6);
    if (shadow) {
      c.fillStyle = 'rgba(40,55,30,0.22)';
      rr(c, b.x + T * 0.07, b.y + T * 0.1, b.s, b.s, 3);
      c.fill();
      return;
    }
    c.fillStyle = '#d6d8db'; rr(c, b.x, b.y, b.s, b.s, 2); c.fill();
    c.strokeStyle = '#b1b5ba'; c.lineWidth = 1.5; rr(c, b.x + 1, b.y + 1, b.s - 2, b.s - 2, 2); c.stroke();
    const aw = b.s * 0.2, col = AWNINGS[Math.floor(hv * AWNINGS.length)];
    let ax = b.x, ay = b.y, axw = b.s, ayh = aw;
    if (b.dir === 2) ay = b.y + b.s - aw;
    else if (b.dir === 1) { ax = b.x + b.s - aw; axw = aw; ayh = b.s; }
    else if (b.dir === 3) { axw = aw; ayh = b.s; }
    c.fillStyle = '#fff'; c.fillRect(ax, ay, axw, ayh);
    c.fillStyle = col;
    const stripes = 6;
    for (let k = 0; k < stripes; k += 2) {
      if (b.dir === 0 || b.dir === 2) c.fillRect(ax + k * axw / stripes, ay, axw / stripes, ayh);
      else c.fillRect(ax, ay + k * ayh / stripes, axw, ayh / stripes);
    }
    if (lv >= 2) {
      c.fillStyle = '#b4b8bd';
      c.fillRect(b.cx - b.s * 0.15 - b.d[0] * b.s * 0.15, b.cy - b.s * 0.12 - b.d[1] * b.s * 0.15, b.s * 0.22, b.s * 0.18);
    }
    if (lv === 3) {
      c.fillStyle = '#9ea3a9';
      c.fillRect(b.cx + b.s * 0.12 - b.d[0] * b.s * 0.2, b.cy + b.s * 0.05 - b.d[1] * b.s * 0.2, b.s * 0.14, b.s * 0.14);
    }
  }

  function treeGeom(x, y) {
    return { cx: x * T + T / 2 + (h2(x, y, 3) - 0.5) * T * 0.3, cy: y * T + T / 2 + (h2(x, y, 4) - 0.5) * T * 0.3, k: 0.85 + h2(x, y, 5) * 0.3 };
  }
  function drawTree(c, x, y, type, shadow) {
    const g = treeGeom(x, y), k = g.k;
    if (type === 4) {
      if (shadow) return;
      const cols = ['#f49ac1', '#f7d154', '#ffffff', '#b28ee0', '#f2876b'];
      for (let n = 0; n < 7; n++) {
        c.fillStyle = cols[Math.floor(h2(x, y, 50 + n) * cols.length)];
        c.beginPath();
        c.arc(x * T + 5 + h2(x, y, 60 + n) * (T - 10), y * T + 5 + h2(x, y, 70 + n) * (T - 10), 2.4, 0, 6.29);
        c.fill();
      }
      return;
    }
    const r = (type === 1 ? 0.4 : type === 2 ? 0.33 : 0.3) * T * k;
    if (shadow) {
      c.fillStyle = 'rgba(35,55,30,0.24)';
      c.beginPath(); c.ellipse(g.cx + r * 0.35, g.cy + r * 0.45, r, r * 0.85, 0, 0, 6.29); c.fill();
      return;
    }
    if (type === 1) {
      const pal = ['#5e9b4f', '#67a556', '#548f48'];
      const col = pal[Math.floor(h2(x, y, 8) * pal.length)];
      c.fillStyle = col; c.beginPath(); c.arc(g.cx, g.cy, r, 0, 6.29); c.fill();
      c.fillStyle = shade(col, 0.16); c.beginPath(); c.arc(g.cx - r * 0.25, g.cy - r * 0.25, r * 0.55, 0, 6.29); c.fill();
    } else if (type === 2) {
      c.fillStyle = '#3e7650';
      c.beginPath();
      for (let n = 0; n < 16; n++) {
        const a = n / 16 * 6.283, rad = n % 2 ? r * 0.62 : r;
        if (n === 0) c.moveTo(g.cx + Math.cos(a) * rad, g.cy + Math.sin(a) * rad);
        else c.lineTo(g.cx + Math.cos(a) * rad, g.cy + Math.sin(a) * rad);
      }
      c.closePath(); c.fill();
      c.fillStyle = '#4f8c5e'; c.beginPath(); c.arc(g.cx, g.cy, r * 0.42, 0, 6.29); c.fill();
    } else {
      c.fillStyle = '#93c26b'; c.beginPath(); c.arc(g.cx, g.cy, r, 0, 6.29); c.fill();
      c.fillStyle = '#b1d68a'; c.beginPath(); c.arc(g.cx - r * 0.2, g.cy - r * 0.22, r * 0.5, 0, 6.29); c.fill();
    }
  }

  function smallTree(c, cx, cy, r) {
    c.fillStyle = 'rgba(35,55,30,0.24)'; c.beginPath(); c.arc(cx + r * 0.35, cy + r * 0.45, r, 0, 6.29); c.fill();
    c.fillStyle = '#5e9b4f'; c.beginPath(); c.arc(cx, cy, r, 0, 6.29); c.fill();
    c.fillStyle = '#76b062'; c.beginPath(); c.arc(cx - r * 0.25, cy - r * 0.25, r * 0.5, 0, 6.29); c.fill();
  }
  function gableRoof(c, x, y, w, h, col, horizontal) {
    c.fillStyle = 'rgba(40,55,30,0.22)'; rr(c, x + T * 0.08, y + T * 0.1, w, h, 3); c.fill();
    c.save(); rr(c, x, y, w, h, 2); c.clip();
    c.fillStyle = col; c.fillRect(x, y, w, h);
    c.fillStyle = shade(col, -0.2);
    if (horizontal) c.fillRect(x, y + h / 2, w, h / 2); else c.fillRect(x + w / 2, y, w / 2, h);
    c.restore();
    c.strokeStyle = shade(col, 0.28); c.lineWidth = 1.8; c.beginPath();
    if (horizontal) { c.moveTo(x + 2, y + h / 2); c.lineTo(x + w - 2, y + h / 2); }
    else { c.moveTo(x + w / 2, y + 2); c.lineTo(x + w / 2, y + h - 2); }
    c.stroke();
  }
  function flatRoof(c, x, y, w, h, col, border) {
    c.fillStyle = 'rgba(40,55,30,0.22)'; rr(c, x + T * 0.08, y + T * 0.12, w, h, 3); c.fill();
    c.fillStyle = col; rr(c, x, y, w, h, 3); c.fill();
    c.strokeStyle = border; c.lineWidth = 2; rr(c, x + 1, y + 1, w - 2, h - 2, 2); c.stroke();
  }

  function drawSpecial(c, s) {
    const d = SPECIALS[s.t], px = s.x * T, py = s.y * T, pw = d.w * T, ph = d.h * T, m = T * 0.08;
    switch (s.t) {
      case 'park':
        c.fillStyle = '#b8dc92'; rr(c, px + m, py + m, pw - 2 * m, ph - 2 * m, 10); c.fill();
        c.strokeStyle = '#77a95f'; c.lineWidth = T * 0.12; rr(c, px + m, py + m, pw - 2 * m, ph - 2 * m, 10); c.stroke();
        c.strokeStyle = '#efe5c9'; c.lineWidth = T * 0.16; c.lineCap = 'round';
        c.beginPath(); c.moveTo(px + m * 3, py + ph - m * 3); c.quadraticCurveTo(px + pw * 0.15, py + ph * 0.2, px + pw - m * 3, py + m * 3); c.stroke();
        c.lineCap = 'butt';
        c.fillStyle = '#8ecbe3'; c.beginPath(); c.ellipse(px + pw * 0.68, py + ph * 0.7, T * 0.32, T * 0.22, 0, 0, 6.29); c.fill();
        smallTree(c, px + pw * 0.27, py + ph * 0.3, T * 0.24);
        smallTree(c, px + pw * 0.72, py + ph * 0.28, T * 0.2);
        smallTree(c, px + pw * 0.3, py + ph * 0.75, T * 0.18);
        c.fillStyle = '#9b7653'; c.fillRect(px + pw * 0.48, py + ph * 0.45, T * 0.3, T * 0.08);
        break;
      case 'fountain':
        c.fillStyle = '#e7dfcf'; c.fillRect(px + 2, py + 2, pw - 4, ph - 4);
        c.fillStyle = 'rgba(40,55,30,0.2)'; c.beginPath(); c.arc(px + pw / 2 + 2, py + ph / 2 + 3, T * 0.38, 0, 6.29); c.fill();
        c.fillStyle = '#c9c0b0'; c.beginPath(); c.arc(px + pw / 2, py + ph / 2, T * 0.38, 0, 6.29); c.fill();
        c.fillStyle = '#8ccbe6'; c.beginPath(); c.arc(px + pw / 2, py + ph / 2, T * 0.3, 0, 6.29); c.fill();
        c.fillStyle = '#c9c0b0'; c.beginPath(); c.arc(px + pw / 2, py + ph / 2, T * 0.08, 0, 6.29); c.fill();
        break;
      case 'school':
        c.fillStyle = '#e8dcc0'; rr(c, px + 2, py + 2, pw - 4, ph - 4, 6); c.fill();
        c.strokeStyle = '#d6c7a5'; c.lineWidth = 2;
        c.beginPath(); c.arc(px + pw * 0.78, py + ph * 0.72, T * 0.28, 0, 6.29); c.stroke();
        gableRoof(c, px + m * 2, py + m * 2, pw - m * 4, ph * 0.5, '#c0533f', true);
        c.fillStyle = '#6f6f6f'; c.fillRect(px + pw * 0.15, py + ph * 0.66, 2, T * 0.45);
        c.fillStyle = '#3b6fc4'; c.fillRect(px + pw * 0.15 + 2, py + ph * 0.66, T * 0.22, T * 0.14);
        break;
      case 'clinic':
        c.fillStyle = '#e1e6ea'; rr(c, px + 2, py + 2, pw - 4, ph - 4, 6); c.fill();
        flatRoof(c, px + m * 2, py + m * 2, pw - m * 4, ph - m * 5, '#f5f6f8', '#c8cdd3');
        c.fillStyle = '#d9534f';
        c.fillRect(px + pw / 2 - T * 0.08, py + ph * 0.45 - T * 0.26, T * 0.16, T * 0.52);
        c.fillRect(px + pw / 2 - T * 0.26, py + ph * 0.45 - T * 0.08, T * 0.52, T * 0.16);
        break;
      case 'church':
        c.fillStyle = '#c4dfa0'; rr(c, px + 2, py + 2, pw - 4, ph - 4, 6); c.fill();
        gableRoof(c, px + pw * 0.2, py + m * 2, pw * 0.6, ph * 0.66, '#8c6f5a', false);
        c.fillStyle = 'rgba(40,55,30,0.22)'; c.fillRect(px + pw * 0.3 + T * 0.08, py + ph * 0.66 + T * 0.1, pw * 0.4, pw * 0.4);
        c.fillStyle = '#e9e1d2'; c.fillRect(px + pw * 0.3, py + ph * 0.66, pw * 0.4, pw * 0.4);
        c.fillStyle = '#6f5747'; c.beginPath(); c.arc(px + pw / 2, py + ph * 0.66 + pw * 0.2, pw * 0.13, 0, 6.29); c.fill();
        c.fillStyle = '#e6c25a';
        c.fillRect(px + pw / 2 - 1.5, py + ph * 0.66 + pw * 0.2 - 7, 3, 14);
        c.fillRect(px + pw / 2 - 5, py + ph * 0.66 + pw * 0.2 - 3, 10, 3);
        break;
      case 'fire':
        c.fillStyle = '#d4d4d2'; rr(c, px + 2, py + 2, pw - 4, ph - 4, 6); c.fill();
        flatRoof(c, px + m * 2, py + m * 2, pw - m * 4, ph * 0.62, '#b84034', '#963328');
        c.fillStyle = '#f3e6c9';
        for (let k = 0; k < 2; k++) c.fillRect(px + pw * (0.2 + k * 0.38), py + ph * 0.62 + m * 2, pw * 0.24, T * 0.12);
        break;
      case 'market':
        c.fillStyle = '#e8dfcd'; rr(c, px + 2, py + 2, pw - 4, ph - 4, 8); c.fill();
        for (let yy = 0; yy < 2; yy++) for (let xx = 0; xx < 3; xx++) {
          const sx = px + pw * (0.12 + xx * 0.28), sy = py + ph * (0.18 + yy * 0.42), sw = pw * 0.22, sh = ph * 0.26;
          const col = AWNINGS[(xx + yy * 3 + s.x) % AWNINGS.length];
          c.fillStyle = 'rgba(40,55,30,0.2)'; c.fillRect(sx + 3, sy + 4, sw, sh);
          c.fillStyle = '#fff'; c.fillRect(sx, sy, sw, sh);
          c.fillStyle = col;
          for (let k = 0; k < 4; k += 2) c.fillRect(sx + k * sw / 4, sy, sw / 4, sh);
        }
        break;
      case 'windmill':
        c.fillStyle = '#e6dcc6'; rr(c, px + 4, py + 4, pw - 8, ph - 8, 6); c.fill();
        c.fillStyle = 'rgba(40,55,30,0.22)'; c.beginPath(); c.arc(px + pw / 2 + 3, py + ph / 2 + 4, T * 0.28, 0, 6.29); c.fill();
        c.fillStyle = '#f1ebe0'; c.beginPath(); c.arc(px + pw / 2, py + ph / 2, T * 0.28, 0, 6.29); c.fill();
        c.fillStyle = '#a2765a'; c.beginPath(); c.arc(px + pw / 2, py + ph / 2, T * 0.17, 0, 6.29); c.fill();
        break;
      case 'barn':
        c.fillStyle = '#d8c79f'; rr(c, px + 2, py + 2, pw - 4, ph - 4, 6); c.fill();
        gableRoof(c, px + m * 2, py + m * 2, pw * 0.62, ph - m * 4, '#b5452f', false);
        c.fillStyle = '#e8c35a';
        c.beginPath(); c.arc(px + pw * 0.83, py + ph * 0.28, T * 0.15, 0, 6.29); c.fill();
        c.beginPath(); c.arc(px + pw * 0.83, py + ph * 0.6, T * 0.15, 0, 6.29); c.fill();
        c.strokeStyle = '#c9a344'; c.lineWidth = 1.2;
        c.beginPath(); c.arc(px + pw * 0.83, py + ph * 0.28, T * 0.08, 0, 6.29); c.stroke();
        c.beginPath(); c.arc(px + pw * 0.83, py + ph * 0.6, T * 0.08, 0, 6.29); c.stroke();
        break;
      default:
        drawBigSpecial(c, s, d, px, py, pw, ph, m);
    }
  }

  // ---- cladirile mari: spital, magazine, fabrici, stadioane... ----
  const SIGN_FONT = 'px Fredoka, Nunito, system-ui, sans-serif';
  function pad(c, px, py, pw, ph, col, r) { c.fillStyle = col; rr(c, px + 2, py + 2, pw - 4, ph - 4, r === undefined ? 6 : r); c.fill(); }
  function shadowRect(c, x, y, w, h, r) { c.fillStyle = 'rgba(40,55,30,0.22)'; rr(c, x + T * 0.07, y + T * 0.1, w, h, r); c.fill(); }
  // firma de pe acoperis: textul se micsoreaza ca sa incapa in maxW
  function sign(c, text, cx, cy, maxW, hgt, bg, fg) {
    let fs = Math.round(hgt * 0.7);
    c.font = '700 ' + fs + SIGN_FONT;
    let tw = c.measureText(text).width;
    if (tw + hgt * 0.6 > maxW) { fs = Math.max(6, Math.floor(fs * (maxW - hgt * 0.6) / tw)); c.font = '700 ' + fs + SIGN_FONT; tw = c.measureText(text).width; }
    const w = Math.min(maxW, tw + hgt * 0.6);
    c.fillStyle = 'rgba(30,40,30,0.25)'; rr(c, cx - w / 2 + 1.5, cy - hgt / 2 + 2, w, hgt, hgt * 0.3); c.fill();
    c.fillStyle = bg; rr(c, cx - w / 2, cy - hgt / 2, w, hgt, hgt * 0.3); c.fill();
    c.fillStyle = fg; c.textAlign = 'center'; c.textBaseline = 'middle';
    c.fillText(text, cx, cy + fs * 0.05);
    c.textAlign = 'start'; c.textBaseline = 'alphabetic';
  }
  function cross(c, cx, cy, sz, col) {
    c.fillStyle = col;
    c.fillRect(cx - sz * 0.17, cy - sz / 2, sz * 0.34, sz);
    c.fillRect(cx - sz / 2, cy - sz * 0.17, sz, sz * 0.34);
  }
  function parkedCar(c, x, y, vertical, n) {
    const L = T * 0.34, Wd = T * 0.19;
    c.save(); c.translate(x, y); if (vertical) c.rotate(Math.PI / 2);
    c.fillStyle = 'rgba(20,30,20,0.25)'; rr(c, -L / 2 + 1.5, -Wd / 2 + 2, L, Wd, 3); c.fill();
    c.fillStyle = CAR_COLORS[n % CAR_COLORS.length]; rr(c, -L / 2, -Wd / 2, L, Wd, 3); c.fill();
    c.fillStyle = 'rgba(40,60,90,0.55)'; c.fillRect(L * 0.02, -Wd * 0.36, L * 0.22, Wd * 0.72);
    c.restore();
  }
  // asfalt cu randuri de locuri de parcare; masinile parcate sunt mereu aceleasi (dupa pozitie)
  function parkingLot(c, x, y, w, h, seed, fill) {
    c.fillStyle = '#8f9396'; rr(c, x, y, w, h, 4); c.fill();
    const rows = Math.max(1, Math.floor((h - T * 0.1) / (T * 0.72)));
    const rowH = h / rows, depth = Math.min(rowH * 0.8, T * 0.42), sw = T * 0.27;
    const stalls = Math.max(1, Math.floor((w - T * 0.12) / sw)), sx0 = x + (w - stalls * sw) / 2;
    c.strokeStyle = 'rgba(255,255,255,0.75)'; c.lineWidth = 1.2;
    for (let r = 0; r < rows; r++) {
      const sy = y + rowH * r + (r % 2 ? rowH - depth - T * 0.04 : T * 0.04);
      c.beginPath();
      for (let k = 0; k <= stalls; k++) { c.moveTo(sx0 + k * sw, sy); c.lineTo(sx0 + k * sw, sy + depth); }
      c.stroke();
      for (let k = 0; k < stalls; k++) {
        if (h2(seed + k, r, 41) < fill) parkedCar(c, sx0 + (k + 0.5) * sw, sy + depth / 2, true, Math.floor(h2(seed, k + r * 31, 42) * 97));
      }
    }
  }
  function busTop(c, x, y, len, wid, col) {
    c.fillStyle = 'rgba(20,30,20,0.25)'; rr(c, x + 2, y + 2.5, len, wid, 3); c.fill();
    c.fillStyle = col; rr(c, x, y, len, wid, 3); c.fill();
    c.fillStyle = shade(col, 0.35); c.fillRect(x + len * 0.06, y + wid * 0.22, len * 0.88, wid * 0.56);
    c.fillStyle = 'rgba(60,70,80,0.55)';
    c.fillRect(x + len * 0.25, y + wid * 0.3, len * 0.12, wid * 0.4);
    c.fillRect(x + len * 0.6, y + wid * 0.3, len * 0.12, wid * 0.4);
  }
  function factoryChimneys(s, d) {
    const px = s.x * T, py = s.y * T, pw = d.w * T, ph = d.h * T, n = Math.min(3, d.factory), out = [];
    const cx = px + pw - T * 0.08 * 2 - pw * 0.13;
    for (let k = 0; k < n; k++) out.push({ x: cx, y: py + ph * (n === 1 ? 0.3 : 0.2 + k * (0.32 / (n - 1))), r: T * (0.12 + d.factory * 0.025) });
    return out;
  }

  function drawBigSpecial(c, s, d, px, py, pw, ph, m) {
    const b = d.brand;
    if (d.factory) {
      const n = d.factory;
      pad(c, px, py, pw, ph, '#cbc6bb', 4);
      const hx = px + m * 2, hy = py + m * 2, hw = pw * 0.7 - m * 2, hh = ph * 0.7 - m * 2;
      shadowRect(c, hx, hy, hw, hh, 3);
      c.save(); rr(c, hx, hy, hw, hh, 3); c.clip();
      c.fillStyle = '#a3abb3'; c.fillRect(hx, hy, hw, hh);
      const step = T * 0.32;
      for (let k = 0; k * step < hw; k++) {
        c.fillStyle = '#8b939b'; c.fillRect(hx + k * step, hy, step * 0.42, hh);
        c.fillStyle = '#c3d6e2'; c.fillRect(hx + k * step + step * 0.42, hy, step * 0.12, hh);
      }
      c.restore();
      c.strokeStyle = '#7d858d'; c.lineWidth = 2; rr(c, hx + 1, hy + 1, hw - 2, hh - 2, 2); c.stroke();
      // depozitul cu acoperis albastru si camioanele la rampa
      const wy = hy + hh + T * 0.12, wh = py + ph - m * 2 - wy;
      if (n >= 2) flatRoof(c, hx, wy, hw * 0.55, wh, '#5f7fa6', '#4d6a8e');
      for (let k = 0; k < Math.min(n, 3); k++) {
        const tx = hx + (n >= 2 ? hw * 0.6 : T * 0.1) + k * T * 0.36;
        if (tx + T * 0.24 > hx + hw) break;
        c.fillStyle = 'rgba(20,30,20,0.25)'; c.fillRect(tx + 2, wy + 2, T * 0.22, Math.min(wh, T * 0.5));
        c.fillStyle = '#f2f0ea'; c.fillRect(tx, wy, T * 0.22, Math.min(wh, T * 0.5) - T * 0.12);
        c.fillStyle = ['#d9534f', '#4a8fc9', '#5aa469'][k]; c.fillRect(tx, wy + Math.min(wh, T * 0.5) - T * 0.12, T * 0.22, T * 0.12);
      }
      // rezervoare la fabricile mari
      if (n >= 3) {
        const tr = Math.min(pw * 0.1, T * 0.32), tx = px + pw - m * 2 - pw * 0.13;
        for (let k = 0; k < 2; k++) {
          const ty = py + ph * (0.66 + k * 0.2);
          c.fillStyle = 'rgba(40,55,30,0.22)'; c.beginPath(); c.arc(tx + 2, ty + 3, tr, 0, 6.29); c.fill();
          c.fillStyle = '#dcdfe2'; c.beginPath(); c.arc(tx, ty, tr, 0, 6.29); c.fill();
          c.strokeStyle = '#b5bac0'; c.lineWidth = 1.2; c.beginPath(); c.arc(tx, ty, tr * 0.6, 0, 6.29); c.stroke();
        }
      }
      factoryChimneys(s, d).forEach(function (ch) {
        c.fillStyle = 'rgba(40,55,30,0.25)'; c.beginPath(); c.arc(ch.x + 3, ch.y + 4, ch.r, 0, 6.29); c.fill();
        c.fillStyle = '#a55a44'; c.beginPath(); c.arc(ch.x, ch.y, ch.r, 0, 6.29); c.fill();
        c.strokeStyle = '#e9e3da'; c.lineWidth = 1.5; c.beginPath(); c.arc(ch.x, ch.y, ch.r * 0.78, 0, 6.29); c.stroke();
        c.fillStyle = '#3e3430'; c.beginPath(); c.arc(ch.x, ch.y, ch.r * 0.5, 0, 6.29); c.fill();
      });
      return;
    }
    if (d.stadium) {
      const n = d.stadium;
      pad(c, px, py, pw, ph, '#cfd2c8', 8);
      const ox = px + m * 2, oy = py + m * 2, ow = pw - m * 4, oh = ph - m * 4;
      const stand = T * (0.3 + n * 0.1), track = n >= 2 ? T * (0.14 + n * 0.06) : 0;
      shadowRect(c, ox, oy, ow, oh, Math.min(ow, oh) * 0.3);
      c.fillStyle = '#c94f3d'; rr(c, ox, oy, ow, oh, Math.min(ow, oh) * 0.3); c.fill();
      c.strokeStyle = 'rgba(255,255,255,0.35)'; c.lineWidth = 1;
      for (let k = 1; k < 4; k++) {
        const ins = stand * k / 4;
        rr(c, ox + ins, oy + ins, ow - ins * 2, oh - ins * 2, Math.max(2, Math.min(ow, oh) * 0.3 - ins)); c.stroke();
      }
      if (n === 1) {   // stadionul mic are tribune doar pe laturile lungi
        c.fillStyle = '#cfd2c8'; c.fillRect(ox, oy + stand, stand, oh - stand * 2); c.fillRect(ox + ow - stand, oy + stand, stand, oh - stand * 2);
      }
      if (track) {
        c.fillStyle = '#c8664b'; rr(c, ox + stand, oy + stand, ow - stand * 2, oh - stand * 2, Math.min(ow, oh) * 0.22); c.fill();
        c.strokeStyle = 'rgba(255,255,255,0.6)'; c.lineWidth = 0.8;
        rr(c, ox + stand + track / 2, oy + stand + track / 2, ow - stand * 2 - track, oh - stand * 2 - track, Math.min(ow, oh) * 0.18); c.stroke();
      }
      const fx = ox + stand + track, fy = oy + stand + track, fw = ow - (stand + track) * 2, fh = oh - (stand + track) * 2;
      c.fillStyle = '#5fa64a'; c.fillRect(fx, fy, fw, fh);
      c.fillStyle = '#6db556';
      for (let k = 0; k < 10; k += 2) c.fillRect(fx + fw * k / 10, fy, fw / 10, fh);
      c.strokeStyle = '#f4f6f0'; c.lineWidth = 1.3;
      const l = 3, lx = fx + l, ly = fy + l, lw = fw - l * 2, lh = fh - l * 2;
      c.strokeRect(lx, ly, lw, lh);
      c.beginPath(); c.moveTo(lx + lw / 2, ly); c.lineTo(lx + lw / 2, ly + lh); c.stroke();
      c.beginPath(); c.arc(lx + lw / 2, ly + lh / 2, lh * 0.16, 0, 6.29); c.stroke();
      c.strokeRect(lx, ly + lh * 0.25, lw * 0.14, lh * 0.5);
      c.strokeRect(lx + lw * 0.86, ly + lh * 0.25, lw * 0.14, lh * 0.5);
      c.fillStyle = '#f4f6f0'; c.fillRect(lx - 2, ly + lh * 0.42, 2, lh * 0.16); c.fillRect(lx + lw, ly + lh * 0.42, 2, lh * 0.16);
      if (n >= 2) {   // stalpii de nocturna din colturi
        c.fillStyle = '#5b5f63';
        [[px + m, py + m], [px + pw - m - 5, py + m], [px + m, py + ph - m - 5], [px + pw - m - 5, py + ph - m - 5]].forEach(function (p) { c.fillRect(p[0], p[1], 5, 5); });
      }
      return;
    }
    if (b && d.w === 2 && d.h === 2) {   // benzinarie
      pad(c, px, py, pw, ph, '#a1a5a8', 5);
      flatRoof(c, px + m * 2, py + m * 2, pw - m * 4, ph * 0.28, '#eeece6', '#c9c5bc');
      c.fillStyle = b.band; c.fillRect(px + m * 2, py + m * 2 + ph * 0.28 - T * 0.08, pw - m * 4, T * 0.08);
      parkedCar(c, px + pw * 0.22, py + ph * 0.9, false, s.x + s.y);
      c.fillStyle = 'rgba(30,40,30,0.25)'; rr(c, px + pw * 0.1 + 3, py + ph * 0.42 + 4, pw * 0.8, ph * 0.38, 4); c.fill();
      c.fillStyle = '#fbfbf9'; rr(c, px + pw * 0.1, py + ph * 0.42, pw * 0.8, ph * 0.38, 4); c.fill();
      c.strokeStyle = b.bg; c.lineWidth = 3; rr(c, px + pw * 0.1 + 1.5, py + ph * 0.42 + 1.5, pw * 0.8 - 3, ph * 0.38 - 3, 3); c.stroke();
      sign(c, b.text, px + pw / 2, py + ph * 0.61, pw * 0.72, T * 0.32, b.bg, b.fg);
      c.fillStyle = b.bg; c.fillRect(px + pw * 0.82, py + ph * 0.84, T * 0.14, T * 0.2);
      return;
    }
    if (b) {   // supermarket / mall: cladirea sus, parcarea jos
      const isMall = s.t === 'mall';
      pad(c, px, py, pw, ph, '#d7d5cf', 6);
      const bx = px + m * 2, by = py + m * 2, bw = pw - m * 4, bh = ph * (isMall ? 0.6 : 0.52);
      flatRoof(c, bx, by, bw, bh, '#eceae5', '#c7c3ba');
      c.fillStyle = '#d3d0c8';
      for (let k = 0; k < d.w; k++) c.fillRect(bx + T * 0.2 + k * T * 0.9, by + T * 0.14, T * 0.2, T * 0.14);
      if (isMall) {
        c.fillStyle = '#a9d6e8'; rr(c, bx + bw * 0.38, by + bh * 0.16, bw * 0.24, bh * 0.68, 6); c.fill();
        c.strokeStyle = '#e8f6fb'; c.lineWidth = 1;
        for (let k = 1; k < 4; k++) { c.beginPath(); c.moveTo(bx + bw * 0.38, by + bh * (0.16 + k * 0.17)); c.lineTo(bx + bw * 0.62, by + bh * (0.16 + k * 0.17)); c.stroke(); }
        sign(c, b.text, bx + bw * 0.19, by + bh * 0.5, bw * 0.3, T * 0.4, b.bg, b.fg);
        sign(c, '🎬 CINEMA', bx + bw * 0.81, by + bh * 0.5, bw * 0.32, T * 0.3, '#3b4048', '#ffe08a');
      } else {
        sign(c, b.text, px + pw / 2, by + bh * 0.48, bw * 0.84, Math.min(T * 0.44, bh * 0.5), b.bg, b.fg);
      }
      c.fillStyle = b.bg; c.fillRect(bx, by + bh - T * 0.1, bw, T * 0.1);
      const ly = by + bh + T * 0.1;
      parkingLot(c, bx, ly, bw, py + ph - m * 2 - ly, s.x * 13 + s.y * 7, 0.55);
      return;
    }
    switch (s.t) {
      case 'bloc': {
        pad(c, px, py, pw, ph, '#c9d8b4', 6);
        const bx = px + m * 2, by = py + m * 2, bw = pw - m * 4, bh = ph * 0.64;
        flatRoof(c, bx, by, bw, bh, '#c4bdb3', '#a39b90');
        c.strokeStyle = 'rgba(120,112,102,0.35)'; c.lineWidth = 1;
        for (let k = 1; k < 3; k++) { c.beginPath(); c.moveTo(bx + bw * k / 3, by + 3); c.lineTo(bx + bw * k / 3, by + bh - 3); c.stroke(); }
        for (let k = 0; k < 3; k++) {   // casa scarii si boxele de pe acoperis, cate una pe scara
          const sx = bx + bw * (k + 0.5) / 3;
          c.fillStyle = 'rgba(40,55,30,0.2)'; c.fillRect(sx - T * 0.13 + 2, by + bh * 0.3 + 3, T * 0.26, T * 0.26);
          c.fillStyle = '#a8a096'; c.fillRect(sx - T * 0.13, by + bh * 0.3, T * 0.26, T * 0.26);
          c.fillStyle = '#d9d4cc'; c.fillRect(sx - T * 0.06, by + bh * 0.72, T * 0.12, T * 0.1);
        }
        c.strokeStyle = '#7d756b'; c.lineWidth = 1;
        c.beginPath(); c.moveTo(bx + bw * 0.12, by + bh * 0.2); c.lineTo(bx + bw * 0.12 + T * 0.18, by + bh * 0.2 - T * 0.08); c.stroke();
        parkingLot(c, bx, py + ph * 0.72, pw * 0.64, ph * 0.28 - m * 2, s.x * 5 + s.y * 9, 0.6);
        smallTree(c, px + pw * 0.84, py + ph * 0.84, T * 0.2);
        break;
      }
      case 'hospital':
        pad(c, px, py, pw, ph, '#dfe4e8', 6);
        parkingLot(c, px + m * 2, py + ph * 0.66, pw * 0.5, ph * 0.34 - m * 2, s.x * 7 + s.y, 0.6);
        flatRoof(c, px + m * 2, py + m * 2, pw * 0.58, ph * 0.6, '#f4f5f7', '#c5ccd3');
        flatRoof(c, px + pw * 0.6, py + m * 2, pw * 0.4 - m * 2, ph - m * 4, '#eef0f3', '#c5ccd3');
        cross(c, px + pw * 0.31, py + ph * 0.33, T * 0.55, '#d9534f');
        c.fillStyle = '#9aa3ab'; c.beginPath(); c.arc(px + pw * 0.8, py + ph * 0.64, T * 0.4, 0, 6.29); c.fill();
        c.strokeStyle = '#f4f5f7'; c.lineWidth = 1.5; c.beginPath(); c.arc(px + pw * 0.8, py + ph * 0.64, T * 0.32, 0, 6.29); c.stroke();
        c.font = '700 ' + Math.round(T * 0.4) + SIGN_FONT; c.fillStyle = '#f4f5f7'; c.textAlign = 'center'; c.textBaseline = 'middle';
        c.fillText('H', px + pw * 0.8, py + ph * 0.645); c.textAlign = 'start'; c.textBaseline = 'alphabetic';
        c.fillStyle = 'rgba(20,30,20,0.25)'; rr(c, px + pw * 0.66 + 2, py + ph * 0.18 + 2, T * 0.42, T * 0.21, 3); c.fill();
        c.fillStyle = '#fbfbfb'; rr(c, px + pw * 0.66, py + ph * 0.18, T * 0.42, T * 0.21, 3); c.fill();
        c.fillStyle = '#d9534f'; c.fillRect(px + pw * 0.66, py + ph * 0.18 + T * 0.08, T * 0.42, T * 0.05);
        break;
      case 'medcenter':
        pad(c, px, py, pw, ph, '#dfeae6', 6);
        flatRoof(c, px + m * 2, py + m * 2, pw * 0.7, ph - m * 5, '#e9f4f1', '#b9d3cb');
        c.fillStyle = '#9ccfe0'; c.fillRect(px + m * 2 + pw * 0.46, py + m * 2 + 2, pw * 0.12, ph - m * 5 - 4);
        cross(c, px + m * 2 + pw * 0.23, py + ph * 0.45, T * 0.45, '#2ba56b');
        smallTree(c, px + pw * 0.86, py + ph * 0.28, T * 0.18);
        smallTree(c, px + pw * 0.86, py + ph * 0.7, T * 0.16);
        break;
      case 'kinder': {
        pad(c, px, py, pw, ph, '#cfe6a6', 6);
        c.strokeStyle = '#ffffff'; c.lineWidth = 1.5; c.setLineDash([3, 3]); rr(c, px + 4, py + 4, pw - 8, ph - 8, 5); c.stroke(); c.setLineDash([]);
        gableRoof(c, px + m * 2, py + m * 2, pw * 0.56, ph * 0.5, '#e98c5a', false);
        c.fillStyle = '#f2dc8f'; rr(c, px + pw * 0.62, py + ph * 0.6, pw * 0.28, ph * 0.28, 3); c.fill();
        c.strokeStyle = '#c9a86a'; c.lineWidth = 1.5; rr(c, px + pw * 0.62, py + ph * 0.6, pw * 0.28, ph * 0.28, 3); c.stroke();
        c.fillStyle = '#e8534a'; rr(c, px + pw * 0.7, py + ph * 0.14, T * 0.14, T * 0.5, 3); c.fill();
        c.strokeStyle = '#7b6a5a'; c.lineWidth = 1.5;
        c.beginPath(); c.moveTo(px + pw * 0.14, py + ph * 0.7); c.lineTo(px + pw * 0.5, py + ph * 0.7); c.stroke();
        ['#4a8fc9', '#f1c84b', '#9b6cc4'].forEach(function (col, k) {
          c.fillStyle = col; c.beginPath(); c.arc(px + pw * (0.2 + k * 0.13), py + ph * 0.82, T * 0.06, 0, 6.29); c.fill();
        });
        break;
      }
      case 'highschool':
        pad(c, px, py, pw, ph, '#e6dcc4', 6);
        gableRoof(c, px + m * 2, py + m * 2, pw * 0.58, ph * 0.5, '#9a5a45', true);
        gableRoof(c, px + m * 2, py + m * 2 + ph * 0.5, pw * 0.22, ph * 0.5 - m * 4, '#9a5a45', false);
        c.fillStyle = '#d77a4a'; c.fillRect(px + pw * 0.64, py + m * 3, pw * 0.36 - m * 5, ph * 0.56);
        c.strokeStyle = '#f6efe2'; c.lineWidth = 1.2;
        c.strokeRect(px + pw * 0.64 + 3, py + m * 3 + 3, pw * 0.36 - m * 5 - 6, ph * 0.56 - 6);
        c.beginPath(); c.moveTo(px + pw * 0.64 + 3, py + m * 3 + ph * 0.28); c.lineTo(px + pw - m * 2 - 3, py + m * 3 + ph * 0.28); c.stroke();
        c.beginPath(); c.arc(px + pw * 0.82 - m, py + m * 3 + ph * 0.28, T * 0.14, 0, 6.29); c.stroke();
        c.fillStyle = '#6f6f6f'; c.fillRect(px + pw * 0.36, py + ph * 0.62, 2, T * 0.5);
        c.fillStyle = '#2b4fa8'; c.fillRect(px + pw * 0.36 + 2, py + ph * 0.62, T * 0.08, T * 0.16);
        c.fillStyle = '#f2c81a'; c.fillRect(px + pw * 0.36 + 2 + T * 0.08, py + ph * 0.62, T * 0.08, T * 0.16);
        c.fillStyle = '#d23a2f'; c.fillRect(px + pw * 0.36 + 2 + T * 0.16, py + ph * 0.62, T * 0.08, T * 0.16);
        smallTree(c, px + pw * 0.58, py + ph * 0.82, T * 0.2);
        smallTree(c, px + pw * 0.84, py + ph * 0.84, T * 0.18);
        break;
      case 'dorm':
        pad(c, px, py, pw, ph, '#ddd5c6', 6);
        flatRoof(c, px + m * 2, py + m * 2, pw - m * 4, ph * 0.72, '#c9b8a3', '#a8957f');
        c.fillStyle = '#b3a28c';
        for (let yy = 0; yy < 4; yy++) for (let xx = 0; xx < 2; xx++) c.fillRect(px + pw * (0.24 + xx * 0.36), py + ph * (0.1 + yy * 0.15), T * 0.16, T * 0.16);
        c.fillStyle = '#9b8873'; c.fillRect(px + pw * 0.42, py + ph * 0.32, T * 0.28, T * 0.28);
        c.strokeStyle = '#6a6f74'; c.lineWidth = 1.2;
        for (let k = 0; k < 4; k++) { c.beginPath(); c.moveTo(px + pw * (0.18 + k * 0.12), py + ph * 0.8); c.lineTo(px + pw * (0.18 + k * 0.12), py + ph * 0.9); c.stroke(); }
        smallTree(c, px + pw * 0.8, py + ph * 0.86, T * 0.16);
        break;
      case 'solar': {
        pad(c, px, py, pw, ph, '#b9d08e', 4);
        c.strokeStyle = '#8c8f86'; c.lineWidth = 1; c.setLineDash([2, 2]); rr(c, px + 3, py + 3, pw - 6, ph - 6, 3); c.stroke(); c.setLineDash([]);
        const x0 = px + m * 3, x1 = px + pw - m * 3, rowsEnd = py + ph - m * 3 - T * 0.32;
        for (let ry = py + m * 3; ry + T * 0.3 <= rowsEnd; ry += T * 0.48) {
          c.fillStyle = 'rgba(40,55,30,0.25)'; c.fillRect(x0 + 2, ry + 3, x1 - x0, T * 0.3);
          c.fillStyle = '#2f4f86'; c.fillRect(x0, ry, x1 - x0, T * 0.3);
          c.fillStyle = '#8fb0e0'; c.fillRect(x0, ry, x1 - x0, 1.5);
          c.strokeStyle = '#5a7cb5'; c.lineWidth = 0.8; c.beginPath();
          for (let gx = x0 + T * 0.2; gx < x1; gx += T * 0.2) { c.moveTo(gx, ry); c.lineTo(gx, ry + T * 0.3); }
          c.moveTo(x0, ry + T * 0.15); c.lineTo(x1, ry + T * 0.15); c.stroke();
        }
        flatRoof(c, x1 - T * 0.5, rowsEnd + T * 0.06, T * 0.5, T * 0.24, '#d8d9d4', '#a9aba4');
        c.fillStyle = '#f1c84b'; c.fillRect(x1 - T * 0.3, rowsEnd + T * 0.12, T * 0.1, T * 0.1);
        break;
      }
      case 'parking_s':
      case 'parking_l': {
        pad(c, px, py, pw, ph, '#c9c6bd', 4);
        const big = s.t === 'parking_l', top = big ? T * 0.42 : 0;
        if (big) for (let tx = px + T * 0.4; tx < px + pw - T * 0.2; tx += T * 0.8) smallTree(c, tx, py + T * 0.24, T * 0.17);
        parkingLot(c, px + m * 2, py + m * 2 + top, pw - m * 4, ph - m * 4 - top, s.x * 11 + s.y * 3, big ? 0.55 : 0.5);
        c.fillStyle = '#2f6fd0'; rr(c, px + pw - T * 0.36, py + ph - T * 0.36, T * 0.26, T * 0.26, 3); c.fill();
        c.font = '700 ' + Math.round(T * 0.22) + SIGN_FONT; c.fillStyle = '#fff'; c.textAlign = 'center'; c.textBaseline = 'middle';
        c.fillText('P', px + pw - T * 0.23, py + ph - T * 0.22); c.textAlign = 'start'; c.textBaseline = 'alphabetic';
        break;
      }
      case 'busdepot': {
        pad(c, px, py, pw, ph, '#c3c0b8', 5);
        const hw = pw * 0.42;
        flatRoof(c, px + m * 2, py + m * 2, hw, ph - m * 4, '#8d9aa6', '#73808c');
        c.strokeStyle = '#a7b2bc'; c.lineWidth = 1;
        for (let k = 1; k < 5; k++) { c.beginPath(); c.moveTo(px + m * 2 + 3, py + m * 2 + (ph - m * 4) * k / 5); c.lineTo(px + m * 2 + hw - 3, py + m * 2 + (ph - m * 4) * k / 5); c.stroke(); }
        sign(c, 'AUTOBAZĂ', px + m * 2 + hw / 2, py + ph / 2, hw * 0.9, T * 0.3, '#2f6fb0', '#fff');
        c.fillStyle = '#8f9396'; rr(c, px + m * 2 + hw + T * 0.1, py + m * 2, pw - hw - m * 4 - T * 0.1, ph - m * 4, 4); c.fill();
        const ax = px + m * 2 + hw + T * 0.2, len = pw - hw - m * 4 - T * 0.3;
        for (let k = 0; k < 4; k++) busTop(c, ax, py + m * 2 + T * 0.12 + k * T * 0.68, Math.min(len, T * 1.0), T * 0.28, k % 2 ? '#f2b632' : '#3f8fd0');
        break;
      }
      case 'tramdepot': {
        pad(c, px, py, pw, ph, '#c3c0b8', 5);
        const rails = [0.22, 0.5, 0.78];
        rails.forEach(function (f) {
          const ry = py + ph * f;
          c.fillStyle = '#8a7d6c';
          for (let rx = px + 3; rx < px + pw - 3; rx += T * 0.16) c.fillRect(rx, ry - T * 0.13, T * 0.06, T * 0.26);
          c.fillStyle = '#5b5f63'; c.fillRect(px + 2, ry - T * 0.09, pw - 4, 1.6); c.fillRect(px + 2, ry + T * 0.07, pw - 4, 1.6);
        });
        const hw = pw * 0.5;
        flatRoof(c, px + m * 2, py + m * 2, hw, ph - m * 4, '#a8705a', '#8a5a47');
        c.fillStyle = '#c3d6e2';
        for (let k = 0; k < 4; k++) c.fillRect(px + m * 2 + hw * (0.15 + k * 0.2), py + m * 2 + 4, hw * 0.06, ph - m * 4 - 8);
        sign(c, 'DEPOU', px + m * 2 + hw / 2, py + ph / 2, hw * 0.7, T * 0.3, '#d23c2f', '#fff');
        rails.forEach(function (f, k) {
          if (k === 1) return;
          const ty = py + ph * f - T * 0.13, tx = px + m * 2 + hw + T * 0.18, len = Math.min(pw - hw - m * 4 - T * 0.3, T * 1.5);
          c.fillStyle = 'rgba(20,30,20,0.25)'; rr(c, tx + 2, ty + 2.5, len, T * 0.26, 4); c.fill();
          c.fillStyle = '#d23c2f'; rr(c, tx, ty, len, T * 0.26, 4); c.fill();
          c.fillStyle = '#f3ead5'; c.fillRect(tx + len * 0.05, ty + T * 0.07, len * 0.9, T * 0.12);
          c.strokeStyle = '#3b4048'; c.lineWidth = 1.2; c.beginPath(); c.moveTo(tx + len * 0.4, ty + T * 0.13); c.lineTo(tx + len * 0.6, ty + T * 0.13); c.stroke();
          c.fillStyle = '#7a3029'; c.fillRect(tx + len * 0.33, ty, 1.2, T * 0.26); c.fillRect(tx + len * 0.66, ty, 1.2, T * 0.26);
        });
        break;
      }
      case 'pool': {
        pad(c, px, py, pw, ph, '#ece4d3', 6);
        const qx = px + m * 3, qy = py + m * 3, qw = pw * 0.62, qh = ph - m * 6;
        c.fillStyle = '#58c3e8'; rr(c, qx, qy, qw, qh, 4); c.fill();
        c.strokeStyle = '#e9f6fb'; c.lineWidth = 2; rr(c, qx, qy, qw, qh, 4); c.stroke();
        c.strokeStyle = 'rgba(255,255,255,0.6)'; c.lineWidth = 1; c.setLineDash([3, 3]);
        for (let k = 1; k < 4; k++) { c.beginPath(); c.moveTo(qx + 3, qy + qh * k / 4); c.lineTo(qx + qw - 3, qy + qh * k / 4); c.stroke(); }
        c.setLineDash([]);
        c.fillStyle = '#7fd4ef'; c.beginPath(); c.arc(px + pw * 0.84, py + ph * 0.74, T * 0.22, 0, 6.29); c.fill();
        for (let k = 0; k < 3; k++) { c.fillStyle = '#ffffff'; c.fillRect(px + pw * 0.74 + k * T * 0.2, py + ph * 0.14, T * 0.12, T * 0.3); }
        ['#e8534a', '#f1c84b'].forEach(function (col, k) {
          const ux = px + pw * (0.78 + k * 0.12), uy = py + ph * 0.48;
          c.fillStyle = 'rgba(40,55,30,0.2)'; c.beginPath(); c.arc(ux + 2, uy + 3, T * 0.16, 0, 6.29); c.fill();
          c.fillStyle = col; c.beginPath(); c.arc(ux, uy, T * 0.16, 0, 6.29); c.fill();
          c.fillStyle = '#ffffff'; c.beginPath(); c.moveTo(ux, uy); c.arc(ux, uy, T * 0.16, 0, 1.57); c.closePath(); c.fill();
          c.beginPath(); c.moveTo(ux, uy); c.arc(ux, uy, T * 0.16, 3.14, 4.71); c.closePath(); c.fill();
        });
        break;
      }
      case 'bar':
      case 'restaurant': {
        const isBar = s.t === 'bar';
        pad(c, px, py, pw, ph, '#d8ccb4', 6);
        const bx = px + m * 2, by = py + m * 2, bw = isBar ? pw * 0.7 : pw * 0.66, bh = ph * 0.62;
        flatRoof(c, bx, by, bw, bh, isBar ? '#5d4a52' : '#c9a37a', isBar ? '#43343b' : '#a98558');
        if (!isBar) { c.fillStyle = '#c0392b'; for (let k = 0; k < 6; k += 2) c.fillRect(bx + 2 + k * (bw - 4) / 6, by + bh - T * 0.14, (bw - 4) / 6, T * 0.14); }
        sign(c, isBar ? 'BAR' : 'RESTAURANT', bx + bw / 2, by + bh * 0.42, bw * 0.9, T * (isBar ? 0.3 : 0.26), isBar ? '#e0457b' : '#ffffff', isBar ? '#fff' : '#a33');
        // terasa: mese rotunde cu umbrele
        const n = isBar ? 2 : 3, tx0 = isBar ? px + pw * 0.8 : px + m * 2, ty = py + ph * (isBar ? 0 : 0.78);
        for (let k = 0; k < n; k++) {
          const cx = isBar ? tx0 : tx0 + (k + 0.5) * (pw - m * 4) / n, cy = isBar ? py + ph * (0.3 + k * 0.4) : ty + 0;
          c.fillStyle = 'rgba(40,55,30,0.2)'; c.beginPath(); c.arc(cx + 2, cy + 3, T * 0.17, 0, 6.29); c.fill();
          c.fillStyle = AWNINGS[(k + s.x) % AWNINGS.length]; c.beginPath(); c.arc(cx, cy, T * 0.17, 0, 6.29); c.fill();
          c.fillStyle = 'rgba(255,255,255,0.55)'; c.beginPath(); c.arc(cx, cy, T * 0.06, 0, 6.29); c.fill();
        }
        break;
      }
      case 'aumovio': {
        pad(c, px, py, pw, ph, '#cfd3d6', 5);
        const bx = px + m * 2, by = py + m * 2, bw = pw - m * 4, bh = ph * 0.62;
        shadowRect(c, bx, by, bw, bh, 4);
        c.fillStyle = '#2d3a4a'; rr(c, bx, by, bw, bh, 4); c.fill();
        c.fillStyle = '#7fb6d6';   // fatada de sticla: ferestre in grila
        for (let yy = 0; yy < 3; yy++) for (let xx = 0; xx < 9; xx++) c.fillRect(bx + 4 + xx * (bw - 8) / 9, by + bh * 0.52 + yy * bh * 0.15, (bw - 8) / 9 - 2, bh * 0.11);
        c.fillStyle = '#9fa8b0'; c.fillRect(bx + bw * 0.04, by + bh * 0.08, T * 0.3, T * 0.2); c.fillRect(bx + bw * 0.3, by + bh * 0.08, T * 0.2, T * 0.2);   // echipamente pe acoperis
        sign(c, 'AUNAU-MOVIO', bx + bw * 0.62, by + bh * 0.27, bw * 0.6, T * 0.3, '#f26b1d', '#fff');
        parkingLot(c, bx, by + bh + T * 0.1, bw, py + ph - m * 2 - (by + bh + T * 0.1), s.x * 5 + s.y, 0.7);
        break;
      }
      case 'house_floor': {
        pad(c, px, py, pw, ph, '#cde3b0', 6);
        const hx = px + m * 2, hy = py + m * 2, hw = pw - m * 4, hh = ph - m * 4;
        gableRoof(c, hx, hy, hw, hh * 0.62, '#b8573e', true);
        gableRoof(c, hx + hw * 0.18, hy + hh * 0.38, hw * 0.64, hh * 0.58, '#d0705a', false);   // al doilea nivel
        c.fillStyle = '#f2e8d4'; c.fillRect(hx + hw * 0.62, hy + hh * 0.78, hw * 0.3, T * 0.1);   // balcon
        c.fillStyle = '#e8d8bc'; c.fillRect(hx + hw * 0.1, hy + hh * 0.86, T * 0.1, hh * 0.12);
        smallTree(c, px + pw * 0.14, py + ph * 0.82, T * 0.14);
        break;
      }
      case 'house_pool': {
        pad(c, px, py, pw, ph, '#cde3b0', 6);
        const hx = px + m * 2, hy = py + m * 2, hw = pw * 0.46, hh = ph - m * 4;
        gableRoof(c, hx, hy, hw, hh, '#c9694b', false);
        const qx = px + pw * 0.56, qy = py + ph * 0.18, qw = pw * 0.38, qh = ph * 0.58;
        c.fillStyle = '#efe5cd'; rr(c, qx - 4, qy - 4, qw + 8, qh + 8, 5); c.fill();
        c.fillStyle = '#58c3e8'; rr(c, qx, qy, qw, qh, 4); c.fill();
        c.strokeStyle = 'rgba(255,255,255,0.6)'; c.lineWidth = 1; c.beginPath(); c.moveTo(qx + 4, qy + qh * 0.35); c.lineTo(qx + qw - 4, qy + qh * 0.35); c.stroke();
        c.fillStyle = '#ffffff'; c.fillRect(qx + 2, qy + qh + 6, T * 0.18, T * 0.08); c.fillRect(qx + T * 0.3, qy + qh + 6, T * 0.18, T * 0.08);
        smallTree(c, px + pw * 0.92, py + ph * 0.88, T * 0.14);
        break;
      }
      case 'villa': {
        pad(c, px, py, pw, ph, '#c4de9e', 6);
        c.strokeStyle = '#a89878'; c.lineWidth = 1.5; rr(c, px + 4, py + 4, pw - 8, ph - 8, 5); c.stroke();
        const hx = px + pw * 0.14, hy = py + ph * 0.14, hw = pw * 0.72, hh = ph * 0.44;
        gableRoof(c, hx, hy, hw, hh, '#8f4a3a', true);
        gableRoof(c, hx + hw * 0.55, hy + hh * 0.5, hw * 0.45, hh * 0.8, '#a95a46', false);   // aripa
        c.fillStyle = '#ece3d0'; rr(c, px + pw * 0.14, py + ph * 0.66, pw * 0.34, ph * 0.18, 3); c.fill();   // terasa
        c.fillStyle = '#58c3e8'; rr(c, px + pw * 0.56, py + ph * 0.7, pw * 0.26, ph * 0.18, 3); c.fill();
        c.fillStyle = '#9ea1a4'; c.fillRect(px + pw * 0.46, py + ph * 0.86, T * 0.12, ph * 0.12);
        parkedCar(c, px + pw * 0.9, py + ph * 0.5, true, s.x + s.y);
        smallTree(c, px + pw * 0.1, py + ph * 0.9, T * 0.18);
        smallTree(c, px + pw * 0.92, py + ph * 0.1, T * 0.16);
        break;
      }
      case 'mansion': {
        pad(c, px, py, pw, ph, '#b9d98f', 6);
        c.strokeStyle = '#8a8f78'; c.lineWidth = 2; rr(c, px + 4, py + 4, pw - 8, ph - 8, 5); c.stroke();
        c.fillStyle = '#a8c97a';
        for (let k = 0; k < 6; k++) { c.fillRect(px + pw * 0.1 + k * pw * 0.14, py + ph * 0.86, pw * 0.1, T * 0.12); }
        const bx = px + pw * 0.1, by = py + ph * 0.08, bw = pw * 0.8, bh = ph * 0.6;
        shadowRect(c, bx, by, bw, bh, 3);
        // U: doua aripi si corpul din spate, cu curte in mijloc
        flatRoof(c, bx, by, bw, bh * 0.38, '#7a4a3c', '#5c372d');
        flatRoof(c, bx, by, bw * 0.28, bh, '#8a5646', '#5c372d');
        flatRoof(c, bx + bw * 0.72, by, bw * 0.28, bh, '#8a5646', '#5c372d');
        c.fillStyle = '#e9dfc9'; c.fillRect(bx + bw * 0.28, by + bh * 0.38, bw * 0.44, bh * 0.62);   // curtea
        c.fillStyle = '#8ccbe6'; c.beginPath(); c.arc(bx + bw / 2, by + bh * 0.68, T * 0.3, 0, 6.29); c.fill();
        c.fillStyle = '#c9c0b0'; c.beginPath(); c.arc(bx + bw / 2, by + bh * 0.68, T * 0.1, 0, 6.29); c.fill();
        c.strokeStyle = '#d6cdb8'; c.lineWidth = T * 0.18; c.beginPath(); c.moveTo(px + pw * 0.5, by + bh); c.lineTo(px + pw * 0.5, py + ph - 4); c.stroke();
        smallTree(c, px + pw * 0.08, py + ph * 0.8, T * 0.2);
        smallTree(c, px + pw * 0.92, py + ph * 0.8, T * 0.2);
        break;
      }
      case 'dealership': {
        pad(c, px, py, pw, ph, '#cfd3d6', 5);
        const bx = px + m * 2, by = py + m * 2, bw = pw - m * 4, bh = ph * 0.55;
        shadowRect(c, bx, by, bw, bh, 3);
        c.fillStyle = '#eef1f3'; rr(c, bx, by, bw, bh, 3); c.fill();
        c.fillStyle = '#9fd0e6'; c.fillRect(bx + 3, by + bh - T * 0.2, bw - 6, T * 0.14);
        sign(c, 'AUTO', bx + bw / 2, by + bh * 0.38, bw * 0.5, T * 0.3, '#c0392b', '#fff');
        for (let k = 0; k < 4; k++) parkedCar(c, bx + bw * (0.12 + k * 0.25), py + ph * 0.84, false, s.x + k * 3);
        break;
      }
      case 'usedlot': {
        pad(c, px, py, pw, ph, '#c9cbc9', 4);
        parkingLot(c, px + m * 2, py + m * 2 + T * 0.34, pw - m * 4, ph - m * 4 - T * 0.34, s.x * 7 + s.y * 5, 0.9);
        sign(c, 'PARC AUTO', px + pw / 2, py + m * 2 + T * 0.17, pw * 0.6, T * 0.28, '#e8a33c', '#3b2a12');
        c.strokeStyle = '#d9534f'; c.lineWidth = 1.2; c.setLineDash([3, 3]);
        c.beginPath(); c.moveTo(px + 4, py + T * 0.36); c.lineTo(px + pw - 4, py + T * 0.36); c.stroke(); c.setLineDash([]);
        break;
      }
      case 'airport': {
        pad(c, px, py, pw, ph, '#bfc4c4', 4);
        // pista jos, cu marcaje; avion parcat
        const ry = py + ph * 0.7, rh = ph * 0.22;
        c.fillStyle = '#4b5056'; c.fillRect(px + 3, ry, pw - 6, rh);
        c.fillStyle = '#f1f1ea';
        for (let x = px + T * 0.4; x < px + pw - T * 0.6; x += T * 0.6) c.fillRect(x, ry + rh / 2 - 1.5, T * 0.32, 3);
        for (let k = 0; k < 5; k++) { c.fillRect(px + 6, ry + 4 + k * (rh - 8) / 5, 4, 2); c.fillRect(px + pw - 10, ry + 4 + k * (rh - 8) / 5, 4, 2); }
        // terminal
        const tx = px + m * 3, ty = py + m * 3, tw = pw * 0.55, th = ph * 0.34;
        shadowRect(c, tx, ty, tw, th, 4);
        c.fillStyle = '#e5e9ec'; rr(c, tx, ty, tw, th, 4); c.fill();
        c.fillStyle = '#9fd0e6'; c.fillRect(tx + 4, ty + th - T * 0.18, tw - 8, T * 0.12);
        sign(c, 'AEROPORT', tx + tw / 2, ty + th * 0.4, tw * 0.8, T * 0.3, '#2f5fa0', '#fff');
        // turn de control
        const kx = tx + tw + T * 0.5, ky = ty + th * 0.5;
        c.fillStyle = 'rgba(40,55,30,0.22)'; c.beginPath(); c.arc(kx + 2, ky + 3, T * 0.3, 0, 6.29); c.fill();
        c.fillStyle = '#d9dcdf'; c.beginPath(); c.arc(kx, ky, T * 0.3, 0, 6.29); c.fill();
        c.fillStyle = '#7fb3cf'; c.beginPath(); c.arc(kx, ky, T * 0.18, 0, 6.29); c.fill();
        // platforma cu avioane
        const ax = px + pw * 0.08, ay = py + ph * 0.42;
        [[0.1, 0], [0.34, 0]].forEach(function (o, k) {
          const cx = ax + pw * o[0] + T * 0.5, cy = ay + T * 0.3;
          c.fillStyle = 'rgba(40,55,30,0.22)'; c.fillRect(cx - T * 0.45 + 2, cy - T * 0.07 + 3, T * 0.9, T * 0.14);
          c.fillStyle = '#f7f7f4'; c.fillRect(cx - T * 0.45, cy - T * 0.07, T * 0.9, T * 0.14);
          c.beginPath(); c.moveTo(cx - T * 0.05, cy); c.lineTo(cx - T * 0.2, cy - T * 0.4); c.lineTo(cx + T * 0.08, cy - T * 0.4); c.lineTo(cx + T * 0.15, cy); c.lineTo(cx + T * 0.08, cy + T * 0.4); c.lineTo(cx - T * 0.2, cy + T * 0.4); c.closePath(); c.fill();
          c.fillStyle = ['#2f5fa0', '#c0392b'][k]; c.fillRect(cx - T * 0.45, cy - T * 0.03, T * 0.12, T * 0.06);
        });
        parkingLot(c, px + pw * 0.66, py + ph * 0.42, pw * 0.3, ph * 0.22, s.x * 3 + s.y, 0.5);
        break;
      }
      case 'amusement': {
        pad(c, px, py, pw, ph, '#cfe3a8', 8);
        c.strokeStyle = '#efe2c4'; c.lineWidth = T * 0.22; c.lineCap = 'round';
        c.beginPath(); c.moveTo(px + pw * 0.1, py + ph * 0.86); c.quadraticCurveTo(px + pw * 0.5, py + ph * 0.6, px + pw * 0.9, py + ph * 0.86); c.stroke();
        c.beginPath(); c.moveTo(px + pw * 0.5, py + ph * 0.72); c.lineTo(px + pw * 0.5, py + ph * 0.2); c.stroke();
        c.lineCap = 'butt';
        // montagne russe
        c.strokeStyle = '#a0522d'; c.lineWidth = 3;
        c.beginPath(); c.ellipse(px + pw * 0.77, py + ph * 0.32, pw * 0.16, ph * 0.2, 0.3, 0, 6.29); c.stroke();
        c.beginPath(); c.ellipse(px + pw * 0.77, py + ph * 0.32, pw * 0.07, ph * 0.09, -0.4, 0, 6.29); c.stroke();
        c.strokeStyle = '#f1e2c6'; c.lineWidth = 1; c.setLineDash([2, 3]);
        c.beginPath(); c.ellipse(px + pw * 0.77, py + ph * 0.32, pw * 0.16, ph * 0.2, 0.3, 0, 6.29); c.stroke(); c.setLineDash([]);
        // tarabele
        for (let k = 0; k < 3; k++) {
          const sx = px + pw * (0.6 + k * 0.11), sy = py + ph * 0.66, col = AWNINGS[(k + s.x) % AWNINGS.length];
          c.fillStyle = 'rgba(40,55,30,0.2)'; c.fillRect(sx + 2, sy + 3, T * 0.32, T * 0.26);
          c.fillStyle = '#fff'; c.fillRect(sx, sy, T * 0.32, T * 0.26);
          c.fillStyle = col; c.fillRect(sx, sy, T * 0.08, T * 0.26); c.fillRect(sx + T * 0.16, sy, T * 0.08, T * 0.26);
        }
        // locurile pentru roata mare si carusel (se invart in stratul animat)
        const wh = amusementParts(s, d);
        c.fillStyle = '#d9d2c3'; c.beginPath(); c.arc(wh.wx, wh.wy, wh.wr * 1.08, 0, 6.29); c.fill();
        c.fillStyle = '#d9d2c3'; c.beginPath(); c.arc(wh.cx, wh.cy, wh.cr * 1.15, 0, 6.29); c.fill();
        smallTree(c, px + pw * 0.08, py + ph * 0.12, T * 0.18);
        smallTree(c, px + pw * 0.93, py + ph * 0.62, T * 0.16);
        break;
      }
    }
  }
  function amusementParts(s, d) {
    const px = s.x * T, py = s.y * T, pw = d.w * T, ph = d.h * T;
    return { wx: px + pw * 0.26, wy: py + ph * 0.38, wr: T * 0.95, cx: px + pw * 0.36, cy: py + ph * 0.8, cr: T * 0.38 };
  }
  // fontul firmelor se incarca dupa primul desen: redesenam harta cand e gata
  if (document.fonts && document.fonts.ready) document.fonts.ready.then(function () { markAll(); });

  // ================= ACTIONS =================
  function snapshot() {
    return {
      ground: ground.slice(), road: road.slice(), zone: zone.slice(), crop: crop.slice(), level: level.slice(),
      deco: deco.slice(), growth: growth.slice(), specials: JSON.stringify(specials)
    };
  }
  function pushUndo() {
    undoStack.push(snapshot());
    if (undoStack.length > 30) undoStack.shift();
  }
  function undo() {
    const s = undoStack.pop();
    if (!s) { toast('Nu mai e nimic de anulat'); return; }
    ground.set(s.ground); road.set(s.road); zone.set(s.zone); crop.set(s.crop); level.set(s.level); deco.set(s.deco); growth.set(s.growth);
    specials = JSON.parse(s.specials);
    rebuildSpecIndex();
    recomputeCoverage();
    cars = [];
    markAll();
    unsaved = true;
  }
  function rebuildSpecIndex() {
    spec.fill(-1);
    specials.forEach(function (s, n) {
      if (!s) return;
      const d = SPECIALS[s.t];
      for (let y = s.y; y < s.y + d.h; y++) for (let x = s.x; x < s.x + d.w; x++) spec[idx(x, y)] = n;
    });
  }
  function clearTile(i) { zone[i] = 0; level[i] = 0; deco[i] = 0; growth[i] = 0; }

  function roadPath(a, b) {
    const pts = [];
    const dx = Math.sign(b.x - a.x), dy = Math.sign(b.y - a.y);
    if (Math.abs(b.x - a.x) >= Math.abs(b.y - a.y)) {
      for (let x = a.x; x !== b.x; x += dx) pts.push({ x: x, y: a.y });
      for (let y = a.y; y !== b.y; y += dy) pts.push({ x: b.x, y: y });
    } else {
      for (let y = a.y; y !== b.y; y += dy) pts.push({ x: a.x, y: y });
      for (let x = a.x; x !== b.x; x += dx) pts.push({ x: x, y: b.y });
    }
    pts.push({ x: b.x, y: b.y });
    return pts;
  }
  function applyRoad(path, type) {
    let changed = 0;
    path.forEach(function (p) {
      if (!inb(p.x, p.y)) return;
      const i = idx(p.x, p.y);
      if (spec[i] >= 0 || road[i] === type) return;
      road[i] = type; clearTile(i);
      markTile(p.x, p.y); changed++;
    });
    if (changed) routeCache.clear();
    return changed;
  }
  function rectOf(a, b) {
    return { x0: Math.max(0, Math.min(a.x, b.x)), y0: Math.max(0, Math.min(a.y, b.y)), x1: Math.min(W - 1, Math.max(a.x, b.x)), y1: Math.min(H - 1, Math.max(a.y, b.y)) };
  }
  function applyRect(tool, r) {
    const kind = tool.kind;
    if (kind === 'bulldoze' || kind === 'water') routeCache.clear();
    if (kind === 'bulldoze') {
      specials.forEach(function (s, n) {
        if (!s) return;
        const d = SPECIALS[s.t];
        if (s.x <= r.x1 && s.x + d.w > r.x0 && s.y <= r.y1 && s.y + d.h > r.y0) removeSpecial(n);
      });
    }
    for (let y = r.y0; y <= r.y1; y++) for (let x = r.x0; x <= r.x1; x++) {
      const i = idx(x, y);
      if (kind === 'bulldoze') { road[i] = 0; clearTile(i); }
      else if (kind === 'zone') {
        if (ground[i] || road[i] || spec[i] >= 0) continue;
        if (tool.zone === 3) {
          if (zone[i] === 3 && crop[i] === tool.crop) continue;
          clearTile(i); zone[i] = 3; crop[i] = tool.crop; growth[i] = 0;
        } else {
          if (zone[i] === tool.zone) continue;
          if (zone[i] === 3) deco[i] = 0;
          zone[i] = tool.zone; level[i] = 0; growth[i] = 0;
        }
      } else if (kind === 'forest') {
        if (ground[i] || road[i] || spec[i] >= 0 || zone[i] || deco[i]) continue;
        const rv = Math.random();
        if (rv < 0.75) deco[i] = rv < 0.33 ? 2 : rv < 0.45 ? 3 : 1;
      } else if (kind === 'water') {
        if (spec[i] >= 0) continue;
        ground[i] = 1; clearTile(i);
      } else if (kind === 'land') {
        ground[i] = 0;
      }
    }
    markRect(r.x0, r.y0, r.x1, r.y1);
  }
  function paintTree(t, type) {
    if (!inb(t.x, t.y)) return;
    const i = idx(t.x, t.y);
    if (ground[i] || road[i] || spec[i] >= 0 || zone[i] === 3 || level[i]) return;
    if (deco[i] === type) return;
    deco[i] = type;
    markTile(t.x, t.y);
  }
  function specialValid(key, x, y) {
    const d = SPECIALS[key];
    if (x < 0 || y < 0 || x + d.w > W || y + d.h > H) return false;
    for (let yy = y; yy < y + d.h; yy++) for (let xx = x; xx < x + d.w; xx++) {
      const i = idx(xx, yy);
      if (ground[i] || road[i] || spec[i] >= 0) return false;
    }
    return true;
  }
  function specialOrigin(key, t) {
    const d = SPECIALS[key];
    return { x: t.x - Math.floor((d.w - 1) / 2), y: t.y - Math.floor((d.h - 1) / 2) };
  }
  function placeSpecial(key, x, y) {
    const d = SPECIALS[key];
    const n = specials.length;
    specials.push({ t: key, x: x, y: y });
    for (let yy = y; yy < y + d.h; yy++) for (let xx = x; xx < x + d.w; xx++) {
      const i = idx(xx, yy);
      clearTile(i); spec[i] = n;
    }
    markRect(x, y, x + d.w - 1, y + d.h - 1);
    recomputeCoverage();
  }
  function removeSpecial(n) {
    const s = specials[n];
    if (!s) return;
    const d = SPECIALS[s.t];
    for (let yy = s.y; yy < s.y + d.h; yy++) for (let xx = s.x; xx < s.x + d.w; xx++) spec[idx(xx, yy)] = -1;
    specials[n] = null;
    markRect(s.x, s.y, s.x + d.w - 1, s.y + d.h - 1);
    recomputeCoverage();
  }

  // ================= SIMULATION =================
  // mutate = false: doar numara (vizitatorii vad harta exact cum a salvat-o adminul, nu o "cresc" ei).
  function simTick(mutate) {
    if (mutate === undefined) mutate = true;
    let pop = 0, houses = 0, shops = 0, comJobs = 0, fields = 0, happySum = 0, roads = 0;
    roadCount.fill(0);
    // cu cerere negativa tot mai apare cate ceva, dar rar - ca orasul sa nu ramana blocat
    const resP = 0.035 * (demand.res > 0 ? 0.15 + 0.85 * demand.res : 0.05);
    const comP = 0.03 * (demand.com > 0 ? 0.15 + 0.85 * demand.com : 0.05);
    const rain = S.weather === 2 ? 1.25 : 1;
    for (let i = 0; i < N; i++) {
      if (road[i]) { roads++; roadCount[road[i]]++; continue; }
      const z = zone[i];
      if (!z) continue;
      const x = i % W, y = (i / W) | 0;
      if (z === 3) {
        fields++;
        if (!mutate) continue;
        const before = stageOf(growth[i]);
        let g = growth[i] + FIELD_RATE * farmBoost[i] * rain * (0.8 + Math.random() * 0.4);
        if (g > 1.35) g = 0;
        growth[i] = g;
        if (stageOf(g) !== before) markTile(x, y);
        continue;
      }
      const lv = level[i];
      if (!lv) {
        if (mutate && !ground[i] && spec[i] < 0 && Math.random() < (z === 1 ? resP : comP) && roadNear(x, y)) {
          level[i] = 1; deco[i] = 0; markTile(x, y); unsaved = true;
        }
        continue;
      }
      if (z === 1) { houses++; pop += POP[lv]; happySum += happinessOf(i); }
      else { shops++; comJobs += SHOP_JOBS[lv]; }
      if (mutate && lv < 3 && Math.random() < 0.012) {
        const sc = serviceCount(i);
        // o casa cumparata de un jucator nu se transforma singura in bloc (si-ar pierde casa)
        if ((lv === 1 && sc >= 1) || (lv === 2 && sc >= 3 && (svcMask[i] & LEISURE_BITS) && !ownedHouseTiles.has(i))) {
          level[i] = lv + 1; markTile(x, y); unsaved = true;
        }
      }
    }
    let specJobs = 0;
    specials.forEach(function (s) { if (s) { specJobs += SPECIALS[s.t].jobs; pop += SPECIALS[s.t].pop || 0; } });
    const jobs = comJobs + Math.round(fields * 0.25) + specJobs;
    demand.res = clamp((jobs * 2 + 18 - pop) / 40, -1, 1);
    demand.com = clamp((pop * 0.32 + 4 - comJobs) / 16, -1, 1);
    stats.pop = pop; stats.houses = houses; stats.shops = shops; stats.fields = fields;
    stats.jobs = jobs; stats.roads = roads;
    stats.happy = houses ? happySum / houses : 0;
  }

  let simAcc = 0, carAcc = 0;
  function realMinutes() { const d = new Date(); return d.getHours() * 60 + d.getMinutes() + d.getSeconds() / 60; }

  function update(dt) {
    if (!IS_ADMIN) {
      // vizitatorii vad orasul la ora reala (noaptea e noapte si in oras); vremea vine de la admin
      S.minutes = Math.floor(S.minutes / 1440) * 1440 + realMinutes();
    } else {
      const mins = dt * SPEEDS[S.speed];
      S.minutes += mins;
      simAcc += mins;
      let guard = 0;
      while (simAcc >= TICK_MIN && guard++ < 20) { simAcc -= TICK_MIN; simTick(true); }
    }
    if (IS_ADMIN && S.minutes >= S.weatherUntil) {
      const r = Math.random();
      S.weather = r < 0.58 ? 0 : r < 0.84 ? 1 : 2;
      S.weatherUntil = S.minutes + 180 + Math.random() * 480;
    }
    carAcc += dt;
    if (carAcc > 0.6) { carAcc = 0; balanceCars(); }
    const cs = !IS_ADMIN ? 1 : S.speed === 0 ? 0 : S.speed === 1 ? 1 : 2.4;
    if (cs) updateCars(dt * cs);
    updateWeatherFx(dt);
  }

  // ================= CARS =================
  function canDrive(k, i) { return VEH_ROADS[k][road[i]] === 1; }
  function roadNeighbors(x, y, k) {
    const out = [];
    for (let d = 0; d < 4; d++) {
      const nx = x + DIRS[d][0], ny = y + DIRS[d][1];
      if (inb(nx, ny) && canDrive(k, idx(nx, ny))) out.push({ x: nx, y: ny });
    }
    return out;
  }
  const VEH_COLORS = { car: CAR_COLORS, taxi: ['#f2c230'], tram: ['#d23c2f', '#f2b632', '#3f8fd0'], walker: ['#d9534f', '#4a8fc9', '#f1c84b', '#5aa469', '#9b6cc4', '#e8873c', '#3b4048'] };
  // masinile pornesc doar de pe drumurile lor (nu din mijlocul unei linii de tramvai)
  const SPAWN_ROADS = { car: [0, 1, 1, 1, 0, 0], taxi: [0, 1, 1, 1, 0, 0], tram: VEH_ROADS.tram, walker: VEH_ROADS.walker };
  function spawnVehicle(k) {
    for (let tries = 0; tries < 30; tries++) {
      const i = Math.floor(Math.random() * N);
      if (SPAWN_ROADS[k][road[i]] !== 1) continue;
      const x = i % W, y = (i / W) | 0, nb = roadNeighbors(x, y, k);
      if (!nb.length) continue;
      const to = nb[Math.floor(Math.random() * nb.length)], cols = VEH_COLORS[k];
      cars.push({ k: k, fx: x, fy: y, tx: to.x, ty: to.y, t: Math.random(), v: 0.8 + Math.random() * 0.5,
        col: cols[Math.floor(Math.random() * cols.length)], bus: Math.random() < 0.4, lane: (Math.random() - 0.5) * T * 0.4 });
      return;
    }
  }
  function balanceCars() {
    const targets = {
      car: Math.min(70, Math.floor((roadCount[1] + roadCount[2] + roadCount[3]) / 5), 2 + Math.floor(stats.pop / 6)),
      taxi: Math.min(10, Math.floor((roadCount[1] + roadCount[2] + roadCount[3]) / 25)),
      tram: Math.min(16, Math.floor(roadCount[5] / 6)),
      walker: Math.min(40, Math.floor(roadCount[4] / 2))
    };
    Object.keys(targets).forEach(function (k) {
      const mine = cars.filter(function (v) { return v.k === k; });
      if (mine.length < targets[k]) spawnVehicle(k);
      else if (mine.length > targets[k] + 3) cars.splice(cars.indexOf(mine[Math.floor(Math.random() * mine.length)]), 1);
    });
  }
  const VEH_SPEED = { car: [0, 1.1, 1.9, 2.8, 0, 1.5], taxi: [0, 1.1, 1.9, 2.8, 0, 1.5], tram: [0, 0, 0, 0, 0, 1.3], walker: [0, 0, 0, 0, 0.32, 0] };
  function updateCars(dt) {
    for (let n = cars.length - 1; n >= 0; n--) {
      const car = cars[n];
      if (!canDrive(car.k, idx(car.fx, car.fy)) || !canDrive(car.k, idx(car.tx, car.ty))) { cars.splice(n, 1); continue; }
      car.t += dt * VEH_SPEED[car.k][road[idx(car.tx, car.ty)]] * car.v;
      while (car.t >= 1) {
        car.t -= 1;
        const nb = roadNeighbors(car.tx, car.ty, car.k);
        let opts = nb.filter(function (p) { return !(p.x === car.fx && p.y === car.fy); });
        // masinile doar traverseaza liniile de tramvai: nu o iau de-a lungul lor cat au alta cale
        if (car.k === 'car' || car.k === 'taxi') {
          const off = opts.filter(function (p) { return road[idx(p.x, p.y)] !== 5; });
          if (off.length) opts = off;
        }
        if (!opts.length) opts = nb;
        if (!opts.length) { car.t = 0; break; }
        const nx = opts[Math.floor(Math.random() * opts.length)];
        car.fx = car.tx; car.fy = car.ty; car.tx = nx.x; car.ty = nx.y;
      }
    }
  }
  function carPose(car) {
    const dx = car.tx - car.fx, dy = car.ty - car.fy;
    const x = (car.fx + dx * car.t + 0.5) * T, y = (car.fy + dy * car.t + 0.5) * T;
    const lane = car.k === 'walker' ? car.lane : road[idx(car.tx, car.ty)] === 3 ? T * 0.22 : T * 0.13;
    return { x: x - dy * lane, y: y + dx * lane, a: Math.atan2(dy, dx) };
  }

  // ================= WEATHER FX =================
  const clouds = [];
  for (let n = 0; n < 12; n++) {
    const parts = [];
    for (let k = 0; k < 4; k++) parts.push([(Math.random() - 0.5) * 4 * T, (Math.random() - 0.5) * 2 * T, (1.5 + Math.random() * 1.8) * T]);
    clouds.push({ x: Math.random() * W * T, y: Math.random() * H * T, parts: parts, v: 0.7 + Math.random() * 0.6 });
  }
  const drops = [];
  for (let n = 0; n < 170; n++) drops.push({ x: Math.random(), y: Math.random(), v: 0.9 + Math.random() * 0.6, l: 10 + Math.random() * 10 });
  function updateWeatherFx(dt) {
    clouds.forEach(function (cl) {
      cl.x += dt * cl.v * T * 0.35;
      if (cl.x > W * T + 6 * T) { cl.x = -6 * T; cl.y = Math.random() * H * T; }
    });
    drops.forEach(function (d) {
      d.y += dt * d.v * 1.4; d.x += dt * d.v * 0.25;
      if (d.y > 1.05) { d.y = -0.05; d.x = Math.random(); }
      if (d.x > 1) d.x -= 1;
    });
  }
  function darkness() {
    const h = (S.minutes % 1440) / 60;
    if (h < 5) return 1;
    if (h < 7.5) return 1 - (h - 5) / 2.5;
    if (h < 18) return 0;
    if (h < 21) return (h - 18) / 3;
    return 1;
  }
  function duskGlow() {
    const h = (S.minutes % 1440) / 60;
    const a = Math.max(0, 1 - Math.abs(h - 18.6) / 1.4), b = Math.max(0, 1 - Math.abs(h - 6.3) / 1.1);
    return Math.max(a, b);
  }

  // ================= MAIN RENDER =================
  const canvas = document.getElementById('game');
  const ctx = canvas.getContext('2d');
  let dpr = 1, cw = 0, ch = 0;
  const cam = { x: W * T / 2, y: H * T / 2, z: 1 };
  let showGrid = false;

  const glow = document.createElement('canvas');
  glow.width = glow.height = 64;
  (function () {
    const g = glow.getContext('2d'), gr = g.createRadialGradient(32, 32, 0, 32, 32, 32);
    gr.addColorStop(0, 'rgba(255,214,140,1)'); gr.addColorStop(0.35, 'rgba(255,190,110,0.45)'); gr.addColorStop(1, 'rgba(255,170,90,0)');
    g.fillStyle = gr; g.fillRect(0, 0, 64, 64);
  })();

  function resize() {
    dpr = Math.min(window.devicePixelRatio || 1, 2);
    cw = window.innerWidth; ch = window.innerHeight;
    canvas.width = Math.round(cw * dpr); canvas.height = Math.round(ch * dpr);
    clampCam();
  }
  function minZoom() { return Math.max(0.2, Math.min(cw / (W * T), ch / (H * T)) * 0.95); }
  function clampCam() {
    cam.z = clamp(cam.z, minZoom(), 2.2);
    cam.x = clamp(cam.x, 0, W * T); cam.y = clamp(cam.y, 0, H * T);
  }
  function screenToWorld(sx, sy) { return { x: (sx - cw / 2) / cam.z + cam.x, y: (sy - ch / 2) / cam.z + cam.y }; }
  function tileAt(sx, sy) { const w = screenToWorld(sx, sy); return { x: Math.floor(w.x / T), y: Math.floor(w.y / T) }; }
  function zoomAt(sx, sy, f) {
    const w = screenToWorld(sx, sy);
    cam.z = clamp(cam.z * f, minZoom(), 2.2);
    cam.x = w.x - (sx - cw / 2) / cam.z;
    cam.y = w.y - (sy - ch / 2) / cam.z;
    clampCam();
  }

  function processDirty() {
    if (!dirty.size) return;
    let n = 0;
    for (const ci of dirty) { renderChunk(ci); dirty.delete(ci); if (++n > 24) break; }
  }

  function draw(now) {
    const c = ctx, z = cam.z;
    c.setTransform(dpr, 0, 0, dpr, 0, 0);
    c.fillStyle = '#5f8a52'; c.fillRect(0, 0, cw, ch);
    const vx0 = cam.x - cw / 2 / z, vy0 = cam.y - ch / 2 / z, vx1 = vx0 + cw / z, vy1 = vy0 + ch / z;
    // bucatile vizibile; marginile sunt rotunjite la pixel ca sa nu apara linii intre ele
    c.setTransform(1, 0, 0, 1, 0, 0);
    c.imageSmoothingEnabled = true;
    const sp = CH * T, ex = function (wx) { return Math.round((wx - vx0) * z * dpr); }, ey = function (wy) { return Math.round((wy - vy0) * z * dpr); };
    const kx0 = Math.max(0, Math.floor(vx0 / sp)), ky0 = Math.max(0, Math.floor(vy0 / sp));
    const kx1 = Math.min(CX - 1, Math.floor(vx1 / sp)), ky1 = Math.min(CY - 1, Math.floor(vy1 / sp));
    for (let ky = ky0; ky <= ky1; ky++) for (let kx = kx0; kx <= kx1; kx++) {
      const cv = chunkCanvases[kx + ky * CX];
      if (!cv) continue;
      const wx1 = Math.min(W, (kx + 1) * CH) * T, wy1 = Math.min(H, (ky + 1) * CH) * T;
      const X0 = ex(kx * sp), Y0 = ey(ky * sp), X1 = ex(wx1), Y1 = ey(wy1);
      if (X1 > X0 && Y1 > Y0) c.drawImage(cv, 0, 0, wx1 - kx * sp, wy1 - ky * sp, X0, Y0, X1 - X0, Y1 - Y0);
    }
    c.setTransform(dpr, 0, 0, dpr, 0, 0);
    const tx0 = Math.max(0, Math.floor(vx0 / T) - 1), ty0 = Math.max(0, Math.floor(vy0 / T) - 1);
    const tx1 = Math.min(W, Math.ceil(vx1 / T) + 1), ty1 = Math.min(H, Math.ceil(vy1 / T) + 1);

    const toWorld = function () { c.setTransform(dpr * z, 0, 0, dpr * z, dpr * (cw / 2 - cam.x * z), dpr * (ch / 2 - cam.y * z)); };
    toWorld();
    c.strokeStyle = 'rgba(40,60,30,0.4)'; c.lineWidth = 4 / z; c.strokeRect(0, 0, W * T, H * T);
    drawAnimated(c, now, vx0, vy0, vx1, vy1);
    drawCars(c, vx0, vy0, vx1, vy1, false);
    drawClouds(c);

    // lumina zilei
    c.setTransform(dpr, 0, 0, dpr, 0, 0);
    const dk = darkness(), dusk = duskGlow();
    if (dusk > 0) { c.fillStyle = 'rgba(255,140,70,' + (dusk * 0.12).toFixed(3) + ')'; c.fillRect(0, 0, cw, ch); }
    if (S.weather === 1) { c.fillStyle = 'rgba(80,90,110,0.08)'; c.fillRect(0, 0, cw, ch); }
    if (S.weather === 2) { c.fillStyle = 'rgba(55,65,90,0.17)'; c.fillRect(0, 0, cw, ch); }
    if (dk > 0) { c.fillStyle = 'rgba(16,24,60,' + (dk * 0.55).toFixed(3) + ')'; c.fillRect(0, 0, cw, ch); }
    if (dk > 0.08) { toWorld(); drawLights(c, dk, tx0, ty0, tx1, ty1, vx0, vy0, vx1, vy1); }

    if (S.weather === 2) drawRain(c);

    toWorld();
    if (showGrid && z > 0.4) drawGrid(c, tx0, ty0, tx1, ty1);
    drawResidents(c, now, vx0, vy0, vx1, vy1);
    drawPreview(c);
  }

  function drawAnimated(c, now, vx0, vy0, vx1, vy1) {
    const windSpeed = S.weather === 2 ? 0.0032 : S.weather === 1 ? 0.0022 : 0.0013;
    specials.forEach(function (s) {
      if (!s) return;
      const d = SPECIALS[s.t];
      if (d.factory || s.t === 'amusement') {
        if (s.x * T > vx1 + T || (s.x + d.w) * T < vx0 - T || s.y * T > vy1 + T * 2 || (s.y + d.h) * T < vy0 - T) return;
        if (d.factory) drawSmoke(c, now, s, d); else drawRides(c, now, s, d);
        return;
      }
      if (s.t !== 'windmill' && s.t !== 'fountain') return;
      const cx = (s.x + 0.5) * T, cy = (s.y + 0.5) * T;
      if (cx < vx0 - T || cx > vx1 + T || cy < vy0 - T || cy > vy1 + T) return;
      if (s.t === 'windmill') {
        const a0 = now * windSpeed + s.x;
        c.save(); c.translate(cx, cy);
        for (let k = 0; k < 4; k++) {
          c.rotate(Math.PI / 2);
          c.save(); c.rotate(a0);
          c.fillStyle = 'rgba(40,55,30,0.18)'; c.fillRect(4, 3 + 4, T * 0.62, T * 0.14);
          c.fillStyle = '#f4efe6'; c.fillRect(2, -T * 0.07, T * 0.62, T * 0.14);
          c.strokeStyle = '#9b8a76'; c.lineWidth = 1; c.strokeRect(2, -T * 0.07, T * 0.62, T * 0.14);
          c.restore();
        }
        c.fillStyle = '#6f5747'; c.beginPath(); c.arc(0, 0, T * 0.07, 0, 6.29); c.fill();
        c.restore();
      } else {
        const p = (now / 900 + s.x * 0.3) % 1;
        c.strokeStyle = 'rgba(255,255,255,' + (0.7 * (1 - p)).toFixed(3) + ')'; c.lineWidth = 1.5;
        c.beginPath(); c.arc(cx, cy, T * (0.1 + p * 0.18), 0, 6.29); c.stroke();
      }
    });
  }

  function drawSmoke(c, now, s, d) {
    factoryChimneys(s, d).forEach(function (ch, n) {
      for (let k = 0; k < 3; k++) {
        const p = (now / 2600 + k / 3 + n * 0.21 + s.x * 0.13) % 1;
        c.fillStyle = 'rgba(232,232,228,' + (0.45 * (1 - p)).toFixed(3) + ')';
        c.beginPath(); c.arc(ch.x + p * T * 0.45, ch.y - p * T * 0.85, ch.r * (0.6 + p * 1.4), 0, 6.29); c.fill();
      }
    });
  }
  function drawRides(c, now, s, d) {
    const p = amusementParts(s, d), a = now * 0.00035 + s.x;
    c.save(); c.translate(p.wx, p.wy);
    c.strokeStyle = 'rgba(40,55,30,0.18)'; c.lineWidth = 3; c.beginPath(); c.arc(4, 5, p.wr, 0, 6.29); c.stroke();
    c.rotate(a);
    c.strokeStyle = '#efe9dc'; c.lineWidth = 1.2; c.beginPath();
    for (let k = 0; k < 8; k++) { c.moveTo(0, 0); c.lineTo(Math.cos(k * 0.785) * p.wr, Math.sin(k * 0.785) * p.wr); }
    c.stroke();
    c.strokeStyle = '#f4f0e6'; c.lineWidth = 3; c.beginPath(); c.arc(0, 0, p.wr, 0, 6.29); c.stroke();
    for (let k = 0; k < 8; k++) {
      c.fillStyle = AWNINGS[k % AWNINGS.length];
      c.beginPath(); c.arc(Math.cos(k * 0.785) * p.wr, Math.sin(k * 0.785) * p.wr, T * 0.09, 0, 6.29); c.fill();
    }
    c.fillStyle = '#8a6f5a'; c.beginPath(); c.arc(0, 0, T * 0.1, 0, 6.29); c.fill();
    c.restore();
    c.save(); c.translate(p.cx, p.cy); c.rotate(-a * 2.2);
    for (let k = 0; k < 8; k++) {
      c.fillStyle = k % 2 ? '#e8534a' : '#fff4dc';
      c.beginPath(); c.moveTo(0, 0); c.arc(0, 0, p.cr, k * 0.785, (k + 1) * 0.785); c.closePath(); c.fill();
    }
    c.fillStyle = '#e6c25a'; c.beginPath(); c.arc(0, 0, p.cr * 0.3, 0, 6.29); c.fill();
    c.restore();
  }

  function drawCars(c, vx0, vy0, vx1, vy1) {
    const L = T * 0.34, Wd = T * 0.19;
    cars.forEach(function (car) {
      const p = carPose(car);
      if (p.x < vx0 - T || p.x > vx1 + T || p.y < vy0 - T || p.y > vy1 + T) return;
      if (car.k === 'walker') {
        c.fillStyle = 'rgba(20,30,20,0.25)'; c.beginPath(); c.arc(p.x + 1.2, p.y + 1.5, T * 0.06, 0, 6.29); c.fill();
        c.fillStyle = car.col; c.beginPath(); c.arc(p.x, p.y, T * 0.06, 0, 6.29); c.fill();
        c.fillStyle = '#e8c4a0'; c.beginPath(); c.arc(p.x, p.y, T * 0.032, 0, 6.29); c.fill();
        return;
      }
      if (car.k === 'tram') {
        c.save(); c.translate(p.x, p.y); c.rotate(p.a);
        if (car.bus) busTop(c, -T * 0.42, -T * 0.12, T * 0.84, T * 0.24, car.col);
        else {
          const tl = T * 0.95, tw = T * 0.22;
          c.fillStyle = 'rgba(20,30,20,0.25)'; rr(c, -tl / 2 + 2, -tw / 2 + 2.5, tl, tw, 4); c.fill();
          c.fillStyle = '#d23c2f'; rr(c, -tl / 2, -tw / 2, tl, tw, 4); c.fill();
          c.fillStyle = '#f3ead5'; c.fillRect(-tl * 0.45, -tw * 0.25, tl * 0.9, tw * 0.5);
          c.fillStyle = '#7a3029'; c.fillRect(-tl * 0.17, -tw / 2, 1.2, tw); c.fillRect(tl * 0.17, -tw / 2, 1.2, tw);
          c.strokeStyle = '#3b4048'; c.lineWidth = 1.2; c.beginPath(); c.moveTo(-tl * 0.08, 0); c.lineTo(tl * 0.08, 0); c.stroke();
        }
        c.restore();
        return;
      }
      c.save(); c.translate(p.x, p.y); c.rotate(p.a);
      c.fillStyle = 'rgba(20,30,20,0.25)'; rr(c, -L / 2 + 2, -Wd / 2 + 2.5, L, Wd, 3); c.fill();
      c.fillStyle = car.col; rr(c, -L / 2, -Wd / 2, L, Wd, 3); c.fill();
      c.fillStyle = 'rgba(40,60,90,0.55)'; c.fillRect(L * 0.02, -Wd * 0.36, L * 0.22, Wd * 0.72);
      c.fillStyle = 'rgba(255,255,255,0.25)'; c.fillRect(-L * 0.3, -Wd * 0.36, L * 0.3, Wd * 0.72);
      if (car.k === 'taxi') { c.fillStyle = '#fff'; c.fillRect(-L * 0.12, -Wd * 0.18, L * 0.2, Wd * 0.36); c.fillStyle = '#c0392b'; c.fillRect(-L * 0.08, -Wd * 0.08, L * 0.12, Wd * 0.16); }
      c.restore();
    });
  }

  function drawClouds(c) {
    const a = S.weather === 0 ? 0.05 : S.weather === 1 ? 0.1 : 0.13;
    const count = S.weather === 0 ? 4 : clouds.length;
    c.fillStyle = 'rgba(30,40,60,' + a + ')';
    for (let n = 0; n < count; n++) {
      const cl = clouds[n];
      c.beginPath();
      cl.parts.forEach(function (p) { c.moveTo(cl.x + p[0] + p[2], cl.y + p[1]); c.arc(cl.x + p[0], cl.y + p[1], p[2], 0, 6.29); });
      c.fill();
    }
  }

  function drawLights(c, dk, tx0, ty0, tx1, ty1, vx0, vy0, vx1, vy1) {
    c.globalCompositeOperation = 'lighter';
    const late = (S.minutes % 1440) / 60;
    const lateNight = late > 23.5 || late < 5;
    for (let y = ty0; y < ty1; y++) for (let x = tx0; x < tx1; x++) {
      const i = idx(x, y);
      if (level[i] && (zone[i] === 1 || zone[i] === 2) && !road[i]) {
        const on = h2(x, y, 90) < (lateNight ? 0.3 : 0.85);
        if (!on) continue;
        const r = T * (0.45 + level[i] * 0.1);
        c.globalAlpha = 0.55 * dk;
        c.drawImage(glow, x * T + T / 2 - r, y * T + T / 2 - r, r * 2, r * 2);
      } else if (((road[i] === 2 || road[i] === 4 || road[i] === 5) && (x + y) % 3 === 0) || (road[i] === 3 && (x + y) % 2 === 0)) {
        const r = T * 0.5;
        c.globalAlpha = 0.5 * dk;
        c.drawImage(glow, x * T + T * 0.15 - r, y * T + T * 0.15 - r, r * 2, r * 2);
      }
    }
    specials.forEach(function (s) {
      if (!s || SPECIALS[s.t].nolight) return;
      const d = SPECIALS[s.t], r = T * Math.max(d.w, d.h) * 0.5;
      c.globalAlpha = 0.45 * dk;
      c.drawImage(glow, (s.x + d.w / 2) * T - r, (s.y + d.h / 2) * T - r, r * 2, r * 2);
      if (d.stadium >= 2) {   // nocturna
        const fr = T * (0.9 + d.stadium * 0.3);
        c.globalAlpha = 0.7 * dk;
        [[0.08, 0.08], [0.92, 0.08], [0.08, 0.92], [0.92, 0.92]].forEach(function (f) {
          c.drawImage(glow, (s.x + d.w * f[0]) * T - fr, (s.y + d.h * f[1]) * T - fr, fr * 2, fr * 2);
        });
      }
    });
    cars.forEach(function (car) {
      if (car.k === 'walker') return;
      const p = carPose(car);
      if (p.x < vx0 || p.x > vx1 || p.y < vy0 || p.y > vy1) return;
      const r = T * 0.32, hx = p.x + Math.cos(p.a) * T * 0.3, hy = p.y + Math.sin(p.a) * T * 0.3;
      c.globalAlpha = 0.7 * dk;
      c.drawImage(glow, hx - r, hy - r, r * 2, r * 2);
    });
    c.globalAlpha = 1;
    c.globalCompositeOperation = 'source-over';
  }

  function drawRain(c) {
    c.setTransform(dpr, 0, 0, dpr, 0, 0);
    c.strokeStyle = 'rgba(210,225,245,0.45)'; c.lineWidth = 1.2;
    c.beginPath();
    drops.forEach(function (d) {
      const x = d.x * cw, y = d.y * ch;
      c.moveTo(x, y); c.lineTo(x - d.l * 0.22, y - d.l);
    });
    c.stroke();
  }

  function drawGrid(c, tx0, ty0, tx1, ty1) {
    c.strokeStyle = 'rgba(40,40,30,0.12)'; c.lineWidth = 1 / cam.z;
    c.beginPath();
    for (let x = tx0; x <= tx1; x++) { c.moveTo(x * T, ty0 * T); c.lineTo(x * T, ty1 * T); }
    for (let y = ty0; y <= ty1; y++) { c.moveTo(tx0 * T, y * T); c.lineTo(tx1 * T, y * T); }
    c.stroke();
  }

  const PREVIEW_COLORS = {
    res: 'rgba(122,190,90,0.45)', com: 'rgba(90,150,210,0.45)', crop0: 'rgba(225,190,90,0.5)', crop1: 'rgba(150,190,90,0.5)',
    crop2: 'rgba(240,200,60,0.5)', crop3: 'rgba(160,130,210,0.5)', forest: 'rgba(60,120,70,0.45)', water: 'rgba(90,170,220,0.5)',
    land: 'rgba(200,170,120,0.5)', bulldoze: 'rgba(220,80,60,0.4)'
  };
  function drawPreview(c) {
    const tool = TOOL[input.activeTool || input.tool];
    if (!tool) return;
    const lw = 2 / cam.z;
    if (input.mode === 'road' && input.start && input.cur) {
      const path = roadPath(input.start, input.cur);
      path.forEach(function (p) {
        if (!inb(p.x, p.y)) return;
        const bad = spec[idx(p.x, p.y)] >= 0;
        c.fillStyle = bad ? 'rgba(220,80,60,0.5)' : tool.road === 2 ? 'rgba(110,115,125,0.6)' : 'rgba(200,165,110,0.65)';
        c.fillRect(p.x * T + 3, p.y * T + 3, T - 6, T - 6);
      });
      return;
    }
    if (input.mode === 'rect' && input.start && input.cur) {
      const r = rectOf(input.start, input.cur);
      c.fillStyle = PREVIEW_COLORS[tool.id] || 'rgba(255,255,255,0.3)';
      c.fillRect(r.x0 * T, r.y0 * T, (r.x1 - r.x0 + 1) * T, (r.y1 - r.y0 + 1) * T);
      c.strokeStyle = 'rgba(255,255,255,0.9)'; c.lineWidth = lw;
      c.strokeRect(r.x0 * T, r.y0 * T, (r.x1 - r.x0 + 1) * T, (r.y1 - r.y0 + 1) * T);
      return;
    }
    const hv = input.hover;
    if (!hv || input.mode === 'pan' || input.pointers.size > 1) return;
    if (tool.kind === 'special') {
      const d = SPECIALS[tool.spec], o = specialOrigin(tool.spec, hv), ok = specialValid(tool.spec, o.x, o.y);
      c.fillStyle = ok ? 'rgba(120,200,110,0.45)' : 'rgba(220,80,60,0.45)';
      c.fillRect(o.x * T, o.y * T, d.w * T, d.h * T);
      c.strokeStyle = ok ? 'rgba(255,255,255,0.9)' : 'rgba(255,220,210,0.9)'; c.lineWidth = lw;
      c.strokeRect(o.x * T, o.y * T, d.w * T, d.h * T);
      if (ok) {
        const cx = (o.x + d.w / 2) * T, cy = (o.y + d.h / 2) * T;
        c.strokeStyle = 'rgba(255,255,255,0.35)'; c.setLineDash([6 / cam.z, 6 / cam.z]);
        c.beginPath(); c.arc(cx, cy, d.radius * T, 0, 6.29); c.stroke(); c.setLineDash([]);
      }
      return;
    }
    if (!inb(hv.x, hv.y)) return;
    if (tool.kind === 'tree') {
      c.strokeStyle = 'rgba(255,255,255,0.85)'; c.lineWidth = lw;
      c.beginPath(); c.arc((hv.x + 0.5) * T, (hv.y + 0.5) * T, T * 0.4, 0, 6.29); c.stroke();
      return;
    }
    if (tool.id === 'hand') return;
    c.strokeStyle = tool.kind === 'bulldoze' ? 'rgba(230,90,70,0.95)' : 'rgba(255,255,255,0.9)';
    c.lineWidth = lw;
    c.strokeRect(hv.x * T + 1, hv.y * T + 1, T - 2, T - 2);
  }

  // ================= INSPECT =================
  function describe(x, y) {
    const base = describeTile(x, y), wp = workplaceAt(x, y);
    return wp ? base + '<br>' + workplaceLine(wp) + '<br><small>click pentru detalii</small>' : base;
  }
  function describeTile(x, y) {
    if (!inb(x, y)) return '';
    const i = idx(x, y);
    if (spec[i] >= 0 && blocAt(x, y) && propsAt(x, y).length) return propertyTip(x, y);
    if (spec[i] >= 0) {
      const s = specials[spec[i]], d = SPECIALS[s.t];
      return d.icon + ' <b>' + d.name + '</b><br>' + d.desc + (d.jobs ? '<br>💼 ' + d.jobs + (d.jobs === 1 ? ' loc' : ' locuri') + ' de muncă' : '') +
        (COV_NAMES[d.cov] ? '<br>🏡 aduce ' + COV_NAMES[d.cov] + ' caselor din jur' : '');
    }
    if (road[i]) return (ROAD_NAMES[road[i]] || ROAD_NAMES[1]) + (ground[i] ? ' · pod peste apă' : '');
    if (ground[i]) return '💧 <b>Apă</b>';
    const z = zone[i], lv = level[i];
    if (z === 3) {
      const cr = CROPS[crop[i]], st = stageOf(growth[i]);
      return cr.icon + ' <b>Câmp de ' + cr.name.toLowerCase() + '</b><br>' + STAGE_NAMES[st] + ' · ' + Math.min(100, Math.round(growth[i] * 100)) + '%' +
        (farmBoost[i] > 1 ? '<br>🛖 crește mai repede datorită fermei' : '');
    }
    if (z === 1 && lv && propsAt(x, y).length) return propertyTip(x, y);
    if (z === 1 && lv) {
      const sc = serviceCount(i);
      let hint = lv === 1 ? (sc ? 'Se va mări în curând.' : 'O școală, un dispensar sau o piață în apropiere o fac să crească.')
        : lv === 2 ? 'Cu 3 feluri de servicii aproape (' + covList(i) + ') și un loc de relaxare devine bloc.' : 'Cea mai mare casă posibilă!';
      return '🏡 <b>' + ['', 'Căsuță', 'Casă', 'Bloc mic'][lv] + '</b> · ' + POP[lv] + ' locuitori<br>😊 fericire ' + Math.round(happinessOf(i) * 100) + '%<br><small>' + hint + '</small>';
    }
    if (z === 2 && lv) return '🏪 <b>' + ['', 'Prăvălie', 'Magazin', 'Magazin mare'][lv] + '</b> · ' + SHOP_JOBS[lv] + ' locuri de muncă';
    if (z === 1 || z === 2) {
      return (z === 1 ? '🏡 Teren pentru case' : '🏪 Teren pentru magazine') + '<br><small>' +
        (roadNear(x, y) ? 'Așteaptă să se construiască ceva.' : 'Are nevoie de un drum (nu autostradă) la cel mult 2 pătrățele.') + '</small>';
    }
    if (deco[i]) return (deco[i] === 4 ? '🌸 ' : '🌳 ') + '<b>' + TREE_NAMES[deco[i]] + '</b>';
    return '🌱 Iarbă';
  }

  // ================= INPUT =================
  const input = { tool: 'hand', activeTool: null, mode: null, start: null, cur: null, last: null, hover: null, pointers: new Map(), pinch: null, space: false, downAt: null, moved: 0 };
  const tipEl = document.getElementById('tip');
  let tipTimer = null;

  // Cand mouse-ul e peste un card / panou / fereastra (orice in afara hartii), nu se mai arata tooltip-ul hartii.
  let overUi = false;
  document.addEventListener('pointermove', function (e) {
    overUi = e.target !== canvas;
    if (overUi) tipEl.hidden = true;
  }, true);
  document.addEventListener('pointerleave', function () { overUi = false; });
  function showTip(html, sx, sy) {
    if (!html || overUi) { tipEl.hidden = true; return; }
    tipEl.innerHTML = html;
    tipEl.hidden = false;
    const r = tipEl.getBoundingClientRect();
    tipEl.style.left = clamp(sx + 16, 8, cw - r.width - 8) + 'px';
    tipEl.style.top = clamp(sy + 16, 8, ch - r.height - 8) + 'px';
  }

  function pointerPos(e) { const r = canvas.getBoundingClientRect(); return { x: e.clientX - r.left, y: e.clientY - r.top }; }

  function bresenham(a, b, fn) {
    let x0 = a.x, y0 = a.y;
    const dx = Math.abs(b.x - x0), dy = -Math.abs(b.y - y0), sx = x0 < b.x ? 1 : -1, sy = y0 < b.y ? 1 : -1;
    let err = dx + dy, guard = 0;
    while (guard++ < 400) {
      fn({ x: x0, y: y0 });
      if (x0 === b.x && y0 === b.y) break;
      const e2 = 2 * err;
      if (e2 >= dy) { err += dy; x0 += sx; }
      if (e2 <= dx) { err += dx; y0 += sy; }
    }
  }

  canvas.addEventListener('contextmenu', function (e) { e.preventDefault(); });
  canvas.addEventListener('pointerdown', function (e) {
    canvas.setPointerCapture(e.pointerId);
    const p = pointerPos(e);
    input.pointers.set(e.pointerId, p);
    tipEl.hidden = true;
    if (input.pointers.size === 2) {
      input.mode = null; input.activeTool = null;
      const pts = Array.from(input.pointers.values());
      const mid = { x: (pts[0].x + pts[1].x) / 2, y: (pts[0].y + pts[1].y) / 2 };
      input.pinch = { dist: Math.hypot(pts[0].x - pts[1].x, pts[0].y - pts[1].y) || 1, z: cam.z, world: screenToWorld(mid.x, mid.y) };
      return;
    }
    if (input.pointers.size > 2) return;
    input.downAt = p; input.moved = 0;
    const toolId = e.button === 2 && IS_ADMIN ? 'bulldoze' : input.tool;
    const tool = TOOL[toolId];
    input.activeTool = toolId;
    const t = tileAt(p.x, p.y);
    input.hover = t;
    if (e.button === 1 || input.space || !tool.kind) {
      input.mode = 'pan'; input.last = p;
      canvas.style.cursor = 'grabbing';
      return;
    }
    if (tool.kind === 'road') { input.mode = 'road'; input.start = t; input.cur = t; }
    else if (tool.kind === 'special') { input.mode = 'special'; input.cur = t; }
    else if (tool.kind === 'tree') { input.mode = 'paint'; pushUndo(); paintTree(t, tool.deco); input.last = t; unsaved = true; }
    else { input.mode = 'rect'; input.start = t; input.cur = t; }
  });

  canvas.addEventListener('pointermove', function (e) {
    const p = pointerPos(e);
    if (input.pointers.has(e.pointerId)) {
      const prev = input.pointers.get(e.pointerId);
      input.moved += Math.hypot(p.x - prev.x, p.y - prev.y);
      input.pointers.set(e.pointerId, p);
    }
    if (input.pinch && input.pointers.size >= 2) {
      const pts = Array.from(input.pointers.values());
      const mid = { x: (pts[0].x + pts[1].x) / 2, y: (pts[0].y + pts[1].y) / 2 };
      const dist = Math.hypot(pts[0].x - pts[1].x, pts[0].y - pts[1].y) || 1;
      cam.z = clamp(input.pinch.z * dist / input.pinch.dist, minZoom(), 2.2);
      cam.x = input.pinch.world.x - (mid.x - cw / 2) / cam.z;
      cam.y = input.pinch.world.y - (mid.y - ch / 2) / cam.z;
      clampCam();
      return;
    }
    const t = tileAt(p.x, p.y);
    input.hover = t;
    if (input.mode === 'pan' && input.last) {
      cam.x -= (p.x - input.last.x) / cam.z; cam.y -= (p.y - input.last.y) / cam.z;
      input.last = p; clampCam();
      return;
    }
    if (input.mode === 'road' || input.mode === 'rect' || input.mode === 'special') { input.cur = t; return; }
    if (input.mode === 'paint') {
      const tool = TOOL[input.activeTool];
      if (input.last.x !== t.x || input.last.y !== t.y) { bresenham(input.last, t, function (q) { paintTree(q, tool.deco); }); input.last = t; }
      return;
    }
    if (e.pointerType === 'mouse' && !input.mode && (input.tool === 'look' || input.tool === 'hand')) {
      const r = residentAt(p.x, p.y);
      if (r) { showTip(residentTip(r), p.x, p.y); canvas.style.cursor = 'pointer'; return; }
      const mk = markerAt(p.x, p.y);
      if (mk) { showTip(propertyTip(mk.x, mk.y), p.x, p.y); canvas.style.cursor = 'pointer'; return; }
      canvas.style.cursor = '';
      if (input.tool === 'look' || !IS_ADMIN) showTip(describe(t.x, t.y), p.x, p.y);
      else tipEl.hidden = true;
    }
  });

  function endPointer(e) {
    const p = pointerPos(e);
    input.pointers.delete(e.pointerId);
    if (input.pinch) { if (input.pointers.size < 2) input.pinch = null; input.mode = null; return; }
    const tool = TOOL[input.activeTool];
    const mode = input.mode;
    input.mode = null;
    canvas.style.cursor = '';
    if (!tool || e.type === 'pointercancel') { input.activeTool = null; return; }
    if (mode === 'pan' && input.moved < 6 && (input.tool === 'look' || input.tool === 'hand')) {
      const r = residentAt(p.x, p.y), mk = r ? null : markerAt(p.x, p.y);
      const pt = tileAt(p.x, p.y);
      if (r) { tipEl.hidden = true; openResidentCard(r); }
      else if (mk) { tipEl.hidden = true; openPropertyCard(mk.x, mk.y); }
      else if (propsAt(pt.x, pt.y).length) { tipEl.hidden = true; openPropertyCard(pt.x, pt.y); }
      else if (workplaceAt(pt.x, pt.y)) { tipEl.hidden = true; openWorkplaceCard(workplaceAt(pt.x, pt.y)); }
      else {
        closeResidentCard();
        if (input.tool === 'look' || !IS_ADMIN) {
          const t = tileAt(p.x, p.y);
          showTip(describe(t.x, t.y), p.x, p.y);
          clearTimeout(tipTimer);
          if (e.pointerType !== 'mouse') tipTimer = setTimeout(function () { tipEl.hidden = true; }, 2600);
        }
      }
    }
    if (mode === 'road' && input.start && input.cur) {
      pushUndo();
      if (!applyRoad(roadPath(input.start, input.cur), tool.road)) undoStack.pop(); else unsaved = true;
    } else if (mode === 'rect' && input.start && input.cur) {
      pushUndo(); applyRect(tool, rectOf(input.start, input.cur)); unsaved = true;
    } else if (mode === 'special' && input.cur) {
      const o = specialOrigin(tool.spec, input.cur);
      if (specialValid(tool.spec, o.x, o.y)) { pushUndo(); placeSpecial(tool.spec, o.x, o.y); unsaved = true; }
      else toast('Nu încape aici - caută un loc liber, fără drum sau apă');
    }
    input.start = null; input.cur = null; input.activeTool = null;
  }
  canvas.addEventListener('pointerup', endPointer);
  canvas.addEventListener('pointercancel', endPointer);
  canvas.addEventListener('pointerleave', function () { input.hover = null; if (input.tool === 'look') tipEl.hidden = true; });
  // Rotita mouse-ului face zoom; scroll-ul cu doua degete pe touchpad muta harta (pinch pe touchpad
  // vine tot ca wheel, dar cu ctrlKey, si face zoom). Touchpad-ul se recunoaste dupa deltaX sau dupa
  // pasii mici, fractionari - rotita mouse-ului trimite pasi mari (~100px sau linii intregi).
  canvas.addEventListener('wheel', function (e) {
    e.preventDefault();
    const p = pointerPos(e);
    const lineMode = e.deltaMode === 1;
    const k = lineMode ? 16 : 1;
    if (e.ctrlKey) { zoomAt(p.x, p.y, Math.exp(-e.deltaY * k * 0.01)); return; }
    const touchpad = !lineMode && (e.deltaX !== 0 || (Math.abs(e.deltaY) < 50 && e.deltaY % 1 !== 0));
    if (touchpad || e.shiftKey) {
      cam.x += (e.shiftKey && !e.deltaX ? e.deltaY : e.deltaX) * k / cam.z;
      if (!e.shiftKey) cam.y += e.deltaY * k / cam.z;
      clampCam();
      return;
    }
    zoomAt(p.x, p.y, Math.exp(-e.deltaY * k * 0.0015));
  }, { passive: false });

  const panKeys = new Set();
  const PAN_CODES = { ArrowLeft: [-1, 0], KeyA: [-1, 0], ArrowRight: [1, 0], KeyD: [1, 0], ArrowUp: [0, -1], KeyW: [0, -1], ArrowDown: [0, 1], KeyS: [0, 1] };
  function keyPan(dt) {
    if (!panKeys.size) return;
    let dx = 0, dy = 0;
    panKeys.forEach(function (code) { dx += PAN_CODES[code][0]; dy += PAN_CODES[code][1]; });
    cam.x += dx * 700 * dt / cam.z; cam.y += dy * 700 * dt / cam.z;
    clampCam();
  }

  window.addEventListener('keydown', function (e) {
    if (e.target.tagName === 'INPUT') return;
    if (PAN_CODES[e.code] && !e.ctrlKey && !e.metaKey) { panKeys.add(e.code); e.preventDefault(); return; }
    if (e.code === 'Space') { input.space = true; e.preventDefault(); }
    else if (e.key.toLowerCase() === 'g') toggleGrid();
    else if (e.key.toLowerCase() === 'p') setShowOthers(!showOthers);
    else if (e.key === 'Escape') { closeResidentCard(); if (IS_ADMIN) selectTool('hand'); }
    else if (!IS_ADMIN) return;
    else if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'z') { e.preventDefault(); undo(); }
    else if (e.key.toLowerCase() === 'b') selectTool('bulldoze');
    else if (e.key.toLowerCase() === 'l') selectTool('look');
    else if (e.key.toLowerCase() === 'h') selectTool('hand');
    else if (/^[0-9]$/.test(e.key) && CATEGORIES[(+e.key + 9) % 10]) selectCategory(CATEGORIES[(+e.key + 9) % 10].id);
  });
  window.addEventListener('keyup', function (e) { if (e.code === 'Space') input.space = false; panKeys.delete(e.code); });
  window.addEventListener('blur', function () { panKeys.clear(); input.space = false; });

  // ================= UI =================
  const tabsEl = document.getElementById('tabs'), toolsEl = document.getElementById('tools'), hintEl = document.getElementById('toolHint');
  let currentCat = 'roads';

  function toolButton(t) {
    const b = document.createElement('button');
    b.className = 'tool' + (t.id === input.tool ? ' is-active' : '');
    b.title = t.tip;
    b.innerHTML = '<span class="ti"></span><span class="tl"></span>';
    b.querySelector('.ti').textContent = t.icon;
    b.querySelector('.tl').textContent = t.name;
    b.addEventListener('click', function () { selectTool(t.id); });
    return b;
  }
  function renderToolbar() {
    // innerHTML = '' ar readuce randurile la inceput: pastram cat erau derulate
    const keepTabs = tabsEl.scrollLeft, keepTools = toolsEl.scrollLeft;
    tabsEl.innerHTML = '';
    CATEGORIES.forEach(function (cat) {
      const b = document.createElement('button');
      b.className = 'tab' + (cat.id === currentCat ? ' is-active' : '');
      b.textContent = cat.name;
      b.addEventListener('click', function () { selectCategory(cat.id); });
      tabsEl.appendChild(b);
    });
    toolsEl.innerHTML = '';
    TOOLS.filter(function (t) { return t.cat === 'base'; }).forEach(function (t) { toolsEl.appendChild(toolButton(t)); });
    const sep = document.createElement('div'); sep.className = 'sep'; toolsEl.appendChild(sep);
    TOOLS.filter(function (t) { return t.cat === currentCat; }).forEach(function (t) { toolsEl.appendChild(toolButton(t)); });
    hintEl.textContent = TOOL[input.tool].tip;
    tabsEl.scrollLeft = keepTabs; toolsEl.scrollLeft = keepTools;
    updateScrollArrows();
  }
  // Sagetile de la capetele randurilor de categorii / unelte: apar doar cand randul nu incape,
  // si se dezactiveaza cand esti deja la capat. Rotita mouse-ului deruleaza si ea randul.
  function updateScrollArrows() {
    document.querySelectorAll('#toolbar .scroller').forEach(function (sc) {
      const row = sc.querySelector('.tabs, .tools'), arrows = sc.querySelectorAll('.sc-arrow');
      const over = row.scrollWidth > row.clientWidth + 1;
      arrows[0].hidden = arrows[1].hidden = !over;
      arrows[0].disabled = row.scrollLeft <= 1;
      arrows[1].disabled = row.scrollLeft + row.clientWidth >= row.scrollWidth - 1;
    });
  }
  function scrollActiveIntoView() {
    [tabsEl.querySelector('.tab.is-active'), toolsEl.querySelector('.tool.is-active')].forEach(function (el) {
      if (!el) return;
      const row = el.parentNode, r = row.getBoundingClientRect(), e = el.getBoundingClientRect();
      if (e.left < r.left || e.right > r.right) row.scrollLeft += (e.left + e.right) / 2 - (r.left + r.right) / 2;
    });
  }
  document.querySelectorAll('#toolbar .scroller').forEach(function (sc) {
    const row = sc.querySelector('.tabs, .tools');
    sc.querySelectorAll('.sc-arrow').forEach(function (a) {
      a.addEventListener('click', function () {
        row.scrollBy({ left: +a.dataset.dir * row.clientWidth * 0.7, behavior: 'smooth' });
        setTimeout(updateScrollArrows, 450);   // in caz ca browserul nu trimite 'scroll' la derularea animata
      });
    });
    row.addEventListener('scroll', updateScrollArrows, { passive: true });
    row.addEventListener('wheel', function (e) {
      if (row.scrollWidth <= row.clientWidth || Math.abs(e.deltaX) > Math.abs(e.deltaY)) return;
      e.preventDefault();
      row.scrollLeft += e.deltaY;
    }, { passive: false });
  });
  window.addEventListener('resize', updateScrollArrows);
  function selectCategory(id) { currentCat = id; renderToolbar(); toolsEl.scrollLeft = 0; scrollActiveIntoView(); updateScrollArrows(); }
  function selectTool(id) {
    input.tool = id;
    const t = TOOL[id];
    if (t.cat !== 'base') currentCat = t.cat;
    tipEl.hidden = true;
    canvas.style.cursor = t.kind ? 'crosshair' : '';
    renderToolbar();
  }
  function toggleGrid() {
    showGrid = !showGrid;
    document.getElementById('btnGrid').classList.toggle('is-on', showGrid);
  }

  const toastEl = document.getElementById('toast');
  let toastTimer = null;
  function toast(msg) {
    toastEl.textContent = msg;
    toastEl.hidden = false; toastEl.style.opacity = '1';
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { toastEl.style.opacity = '0'; setTimeout(function () { toastEl.hidden = true; }, 300); }, 2200);
  }

  document.querySelectorAll('[data-speed]').forEach(function (b) {
    b.addEventListener('click', function () { setSpeed(+b.getAttribute('data-speed')); });
  });
  function setSpeed(s) {
    S.speed = s;
    document.querySelectorAll('[data-speed]').forEach(function (b) { b.classList.toggle('is-on', +b.getAttribute('data-speed') === s); });
  }
  document.getElementById('btnUndo').addEventListener('click', undo);
  document.getElementById('btnGrid').addEventListener('click', toggleGrid);
  document.getElementById('btnSave').addEventListener('click', function () { save(true); });
  document.getElementById('btnNew').addEventListener('click', function () { openNewGameModal(true); });
  document.getElementById('btnResize').addEventListener('click', openResizeModal);
  document.getElementById('btnZoomIn').addEventListener('click', function () { zoomAt(cw / 2, ch / 2, 1.25); });
  document.getElementById('btnZoomOut').addEventListener('click', function () { zoomAt(cw / 2, ch / 2, 0.8); });

  const townEl = document.getElementById('townName');
  townEl.addEventListener('input', function () { S.name = townEl.value.trim() || 'Orașul meu'; unsaved = true; });
  townEl.addEventListener('keydown', function (e) { if (e.key === 'Enter') townEl.blur(); });

  const el = {
    pop: document.getElementById('statPop'), happy: document.getElementById('statHappy'), houses: document.getElementById('statHouses'),
    jobs: document.getElementById('statJobs'), res: document.getElementById('barRes'), com: document.getElementById('barCom'),
    clock: document.getElementById('clock'), weather: document.getElementById('weather')
  };
  function updateHud() {
    el.pop.textContent = stats.pop.toLocaleString('ro-RO');
    el.happy.textContent = Math.round(stats.happy * 100) + '%';
    el.houses.textContent = stats.houses;
    el.jobs.textContent = stats.jobs;
    el.res.style.width = Math.round((demand.res + 1) * 50) + '%';
    el.com.style.width = Math.round((demand.com + 1) * 50) + '%';
    const day = Math.floor(S.minutes / 1440) + 1, m = Math.floor(S.minutes % 1440);
    const hhmm = String(Math.floor(m / 60)).padStart(2, '0') + ':' + String(m % 60).padStart(2, '0');
    el.clock.textContent = IS_ADMIN ? 'Ziua ' + day + ' · ' + hhmm : hhmm;
    const night = darkness() > 0.5;
    el.weather.textContent = S.weather === 2 ? '🌧️' : S.weather === 1 ? '⛅' : night ? '🌙' : '☀️';
    el.weather.title = ['Senin', 'Înnorat', 'Ploaie'][S.weather] + (S.weather === 2 ? ' - câmpurile cresc mai repede' : '');
  }

  // ================= SAVE / LOAD (pe server) =================
  function b64(u8) {
    let s = '';
    for (let i = 0; i < u8.length; i += 8192) s += String.fromCharCode.apply(null, u8.subarray(i, i + 8192));
    return btoa(s);
  }
  function unb64(str) {
    const s = atob(str || ''), u = new Uint8Array(s.length);
    for (let i = 0; i < s.length; i++) u[i] = s.charCodeAt(i);
    return u;
  }
  function serialize() {
    const g8 = new Uint8Array(N);
    for (let i = 0; i < N; i++) g8[i] = Math.round(clamp(growth[i] / 1.35, 0, 1) * 255);
    return {
      v: 1, w: W, h: H, ox: S.ox, oy: S.oy, name: S.name, seed: S.seed, minutes: S.minutes, weather: S.weather, weatherUntil: S.weatherUntil,
      ground: b64(ground), road: b64(road), zone: b64(zone), crop: b64(crop), level: b64(level), deco: b64(deco), growth: b64(g8),
      specials: specials.filter(Boolean)
    };
  }
  let serverVersion = 0, saving = false, saveAgain = false;
  function save(manual) {
    if (!IS_ADMIN) return;
    if (saving) { saveAgain = true; return; }   // ex. marirea hartii in timpul unei salvari
    saving = true;
    unsaved = false;
    fetch('/admin/save.php', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(serialize()), credentials: 'same-origin' })
      .then(function (r) { return r.json(); })
      .then(function (d) {
        if (!d.ok) throw new Error(d.error || 'save failed');
        serverVersion = d.version;
        if (manual) toast('Orașul a fost salvat pentru toată lumea ✓');
        fetchResidents();
      })
      .catch(function (err) {
        unsaved = true;
        toast(err.message === 'not_authenticated' ? 'Sesiunea de admin a expirat - reîncarcă pagina'
          : err.message === 'map_resized' ? 'Harta a fost mărită din altă fereastră - reîncarcă pagina.'
          : 'Nu s-a putut salva orașul. Reîncerc în curând.');
      })
      .finally(function () { saving = false; if (saveAgain) { saveAgain = false; save(false); } });
  }
  // Salvarea veche din browser (de dinainte ca orasul sa fie comun) - adminul o poate urca pe server.
  function readOldLocalSave() {
    try {
      const d = JSON.parse(localStorage.getItem(SAVE_KEY) || 'null');
      return d && d.v === 1 ? d : null;
    } catch (err) { return null; }
  }
  function load(d) {
    const w = d.w || 80, h = d.h || 60, names = ['ground', 'road', 'zone', 'crop', 'level', 'deco'];
    if (!(w >= 10 && h >= 10 && w <= MAX_SIDE && h <= MAX_SIDE && w * h <= MAX_TILES)) return false;
    for (let k = 0; k < names.length; k++) if (unb64(d[names[k]]).length !== w * h) return false;
    const ox = d.ox || 0, oy = d.oy || 0;
    if (w !== W || h !== H) {
      // adminul a marit harta: camera ramane deasupra acelorasi case
      if (serverVersion) { cam.x += (ox - S.ox) * T; cam.y += (oy - S.oy) * T; }
      allocWorld(w, h);
      cars = [];
    }
    S.ox = ox; S.oy = oy;
    const layers = { ground: ground, road: road, zone: zone, crop: crop, level: level, deco: deco };
    for (const k in layers) layers[k].set(unb64(d[k]));
    const g8 = unb64(d.growth);
    for (let i = 0; i < N; i++) growth[i] = (g8[i] || 0) / 255 * 1.35;
    specials = (d.specials || []).filter(function (s) { return s && SPECIALS[s.t]; });
    rebuildSpecIndex();
    S.name = d.name || 'Orașul meu'; S.seed = d.seed || 1;
    if (IS_ADMIN) S.minutes = d.minutes || 480;
    S.weather = d.weather || 0; S.weatherUntil = d.weatherUntil || S.minutes + 240;
    return true;
  }
  function startWorld() {
    roadsChanged();
    recomputeCoverage();
    undoStack = [];
    townEl.value = S.name;
    simTick(false);
    markAll();
    while (dirty.size) processDirty();
    clampCam();
  }
  // Camera pe zona construita, la prima incarcare.
  function centerOnTown() {
    let x0 = W, y0 = H, x1 = -1, y1 = -1;
    for (let i = 0; i < N; i++) {
      if (!road[i] && !zone[i] && spec[i] < 0) continue;
      const x = i % W, y = (i / W) | 0;
      if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y;
    }
    if (x1 < 0) { cam.x = W * T / 2; cam.y = H * T / 2; cam.z = 1; clampCam(); return; }
    cam.x = (x0 + x1 + 1) / 2 * T; cam.y = (y0 + y1 + 1) / 2 * T;
    cam.z = clamp(Math.min(cw / ((x1 - x0 + 3) * T), ch / ((y1 - y0 + 3) * T)), minZoom(), 1.3);
    clampCam();
  }
  function pollState() {
    fetch('/api/state.php?v=' + serverVersion, { credentials: 'same-origin' })
      .then(function (r) { return r.json(); })
      .then(function (res) {
        if (!res.ok || res.unchanged || !res.data) return;
        const first = serverVersion === 0;
        if (!load(res.data)) return;
        serverVersion = res.version;
        startWorld();
        if (first) { centerOnTown(); if (modalKind === 'construction') { modalKind = null; modal.hidden = true; } }
      })
      .catch(function () {});
  }
  if (IS_ADMIN) {
    setInterval(function () { if (unsaved) save(false); }, 20000);
    window.addEventListener('beforeunload', function () {
      if (unsaved && navigator.sendBeacon) navigator.sendBeacon('/admin/save.php', new Blob([JSON.stringify(serialize())], { type: 'application/json' }));
    });
  } else {
    setInterval(pollState, 20000);
  }

  // ================= MODAL =================
  const modal = document.getElementById('modal'), modalCard = document.getElementById('modalCard');
  let modalKind = null;   // ce popup e deschis acum ('welcome', 'login', 'construction'...)
  function escapeHtml(s) { return String(s).replace(/[&<>"']/g, function (ch) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]; }); }

  function openNewGameModal(fromButton) {
    modalCard.innerHTML =
      '<div class="logo">🏡🌳🛣️</div><h1>' + (fromButton ? 'Hartă nouă?' : 'Orașul tău') + '</h1>' +
      '<p>' + (fromButton ? 'Harta curentă se pierde pentru toată lumea. Locuitorii se mută singuri în case noi, pe măsură ce apar.' : 'Încă nu există un oraș. Dă-i un nume și începe să construiești - toată lumea îl va vedea pe city.no-santos.com.') + '</p>' +
      '<input id="newName" maxlength="32" placeholder="Numele orașului" value="' + escapeHtml(fromButton ? S.name : 'Satul Verde') + '">' +
      '<div class="modal-actions">' + (fromButton ? '<button class="btn-secondary" id="mCancel">Renunță</button>' : '') +
      '<button class="btn-primary" id="mStart">' + (fromButton ? 'Generează' : 'Începe') + '</button></div>';
    modal.hidden = false;
    const nameIn = document.getElementById('newName');
    nameIn.focus();
    document.getElementById('mStart').addEventListener('click', function () {
      S.name = nameIn.value.trim() || 'Satul Verde';
      S.seed = Math.floor(Math.random() * 1e9);
      generate(S.seed);
      cars = [];
      startWorld();
      save(true);
      modal.hidden = true;
      selectTool('hand');
    });
    nameIn.addEventListener('keydown', function (e) { if (e.key === 'Enter') document.getElementById('mStart').click(); });
    const cancel = document.getElementById('mCancel');
    if (cancel) cancel.addEventListener('click', function () { modal.hidden = true; });
  }
  // Adauga pamant pe margini. Tot ce era pe harta se muta cu (vest, nord) patratele; serverul muta la fel
  // proprietatile si locurile de munca, la salvare (dupa S.ox / S.oy).
  function resizeWorld(addN, addS, addW, addE) {
    const old = { W: W, H: H, ground: ground, road: road, zone: zone, crop: crop, level: level, deco: deco, growth: growth };
    allocWorld(W + addW + addE, H + addN + addS);
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      const ox = x - addW, oy = y - addN, i = idx(x, y);
      if (ox >= 0 && oy >= 0 && ox < old.W && oy < old.H) {
        const j = oy * old.W + ox;
        ground[i] = old.ground[j]; road[i] = old.road[j]; zone[i] = old.zone[j]; crop[i] = old.crop[j];
        level[i] = old.level[j]; deco[i] = old.deco[j]; growth[i] = old.growth[j];
      } else {
        // pamant nou: iarba cu paduri si flori, ca la generarea hartii
        const n = vnoise(x - S.ox - addW, y - S.oy - addN, 9, S.seed + 1) * 0.7 + vnoise(x, y, 3, S.seed + 2) * 0.3, r = h2(x - S.ox - addW, y - S.oy - addN, 97);
        if (n > 0.62 && r < 0.85) deco[i] = vnoise(x, y, 6, S.seed + 4) > 0.5 ? 2 : (r < 0.15 ? 3 : 1);
        else if (r < 0.015) deco[i] = 1;
        else if (r < 0.03) deco[i] = 4;
      }
    }
    specials.forEach(function (sp) { if (sp) { sp.x += addW; sp.y += addN; } });
    S.ox += addW; S.oy += addN;
    // ce stim de la server se muta si el, pana la urmatoarea citire
    properties.forEach(function (p) { p.x += addW; p.y += addN; });
    residents.forEach(function (r) { if (r.x !== null && r.x !== undefined) { r.x += addW; r.y += addN; } });
    workplaces.forEach(function (w) { w.x += addW; w.y += addN; });
    setProperties(properties);
    rebuildSpecIndex();
    recomputeCoverage();
    cars = []; undoStack = [];
    cam.x += addW * T; cam.y += addN * T;
    simTick(false);
    clampCam();
    unsaved = true;
    save(true);
  }
  function openResizeModal() {
    const side = function (id, label) { return '<label class="rs-side">' + label + '<input id="' + id + '" type="number" min="0" max="' + MAX_SIDE + '" step="1" value="0"></label>'; };
    showModal('resize',
      '<div class="logo">📐</div><h1>Mărește harta</h1>' +
      '<p>Acum: <b>' + W + ' × ' + H + '</b> pătrățele. Câte pătrățele adaugi pe fiecare parte?</p>' +
      '<div class="rs-grid">' + side('rsN', '⬆️ Nord') + side('rsS', '⬇️ Sud') + side('rsW', '⬅️ Vest') + side('rsE', '➡️ Est') + '</div>' +
      '<p id="rsInfo" class="rs-info"></p>' +
      '<div class="modal-actions"><button class="btn-secondary" id="mCancel">Renunță</button><button class="btn-primary" id="mResize">Mărește</button></div>');
    const ids = ['rsN', 'rsS', 'rsW', 'rsE'], info = document.getElementById('rsInfo'), btn = document.getElementById('mResize');
    const vals = function () { return ids.map(function (id) { return Math.max(0, Math.floor(+document.getElementById(id).value || 0)); }); };
    const check = function () {
      const v = vals(), nw = W + v[2] + v[3], nh = H + v[0] + v[1];
      let err = '';
      if (nw > MAX_SIDE || nh > MAX_SIDE) err = 'Maxim ' + MAX_SIDE + ' pătrățele pe o latură.';
      else if (nw * nh > MAX_TILES) err = 'Maxim ' + MAX_TILES + ' de pătrățele în total (ar fi ' + nw * nh + ').';
      info.textContent = err || ('Noua hartă: ' + nw + ' × ' + nh + (nw === W && nh === H ? ' (nimic de adăugat)' : ''));
      info.classList.toggle('is-error', !!err);
      btn.disabled = !!err || (nw === W && nh === H);
    };
    ids.forEach(function (id) { document.getElementById(id).addEventListener('input', check); });
    check();
    btn.addEventListener('click', function () {
      const v = vals();
      hideModal();
      resizeWorld(v[0], v[1], v[2], v[3]);
      toast('Harta are acum ' + W + ' × ' + H + ' pătrățele');
    });
    document.getElementById('mCancel').addEventListener('click', hideModal);
  }
  function showUnderConstruction() {
    modalKind = 'construction';
    modalCard.innerHTML = '<div class="logo">🚧</div><h1>Orașul e în construcție</h1><p>Primarul încă trasează primele drumuri. Ai deja cont - te muți singur în chirie când apar primele apartamente. Revino curând!</p>';
    modal.hidden = false;
  }

  // ================= LOCUITORI =================
  const EMOJIS = ['', '😀', '😎', '🤠', '👩', '👨', '🧔', '👵', '🐱', '🐶', '🦊', '🐻', '🐸', '🌻', '⚽', '🎸'];
  const AVATAR_COLORS = ['#e0894a', '#7aa95c', '#5f97c9', '#b46fb0', '#d9534f', '#3e9c8f', '#c99a2e', '#8a6fd1', '#e06f8b', '#5b7f9e'];
  let residents = [], meId = null, residentsLoaded = false, highlight = null, camAnim = null;
  // proprietatile de pe harta (vezi api/residents.php): { id, x, y, u (apartamentul), k (house1/house2/apt),
  // o (proprietar, null = Primăria), s (pret de vanzare sau null), r (chirie pe zi sau null), oc (locatar) }
  let properties = [], propsByTile = {}, myInfo = null, prices = null, openCard = null;
  // locurile de munca: { id, k (shop/school/.../field), n (nume), x, y, sl (locuri), wk (angajati) }
  let workplaces = [];
  let usedCars = [];  // masinile scoase la vanzare in parcul auto
  let carsMap = {};   // id locuitor -> [model, culoare]: cu ce masina circula
  let ownedHouseTiles = new Set();   // pentru simularea adminului: case cumparate, care nu devin blocuri
  const KIND_NAMES = { house1: 'Căsuță', house2: 'Casă', apt: 'Apartament', hfloor: 'Casă cu etaj', hpool: 'Casă cu piscină', villa: 'Vilă', mansion: 'Conac' };
  const KIND_ICONS = { house1: '🏡', house2: '🏠', apt: '🏢', hfloor: '🏘️', hpool: '🏊', villa: '🏡', mansion: '🏰' };
  function blocAt(x, y) {
    if (!inb(x, y) || spec[idx(x, y)] < 0) return null;
    const sp = specials[spec[idx(x, y)]];
    return sp && (SPECIALS[sp.t].apts || SPECIALS[sp.t].homeKind) ? sp : null;   // Bloc sau o locuinta pusa ca cladire
  }
  function propsAt(x, y) {
    const b = blocAt(x, y);
    return propsByTile[b ? b.x + ',' + b.y : x + ',' + y] || [];
  }
  // mijlocul unei locuinte, in pixeli: la bloc e mijlocul cladirii, nu patratelul din stanga-sus
  function homeCenter(x, y) {
    const b = blocAt(x, y);
    if (b && b.x === x && b.y === y) { const d = SPECIALS[b.t]; return { x: (x + d.w / 2) * T, y: (y + d.h / 2) * T }; }
    return { x: (x + 0.5) * T, y: (y + 0.5) * T };
  }
  function blockName(x, y) { const b = blocAt(x, y); return b && b.t === 'bloc' ? 'Bloc' : 'Bloc mic'; }
  function residentById(id) { return residents.find(function (r) { return r.id === id; }) || null; }
  function fmtLei(n) { return Math.round(n).toLocaleString('ro-RO') + ' LEI'; }
  function propLabel(p) { return p.k === 'apt' ? 'Apartamentul ' + (p.u + 1) : KIND_NAMES[p.k]; }

  function strHash(s) { let h = 0; for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) | 0; return Math.abs(h); }
  function avatarColor(r) { return AVATAR_COLORS[strHash(r.u) % AVATAR_COLORS.length]; }
  function avatarLabel(r) { return r.e || Array.from(r.u)[0].toUpperCase(); }
  function avatarHtml(r, big) {
    return '<span class="av' + (big ? ' is-big' : '') + '" style="background:' + avatarColor(r) + '">' + escapeHtml(avatarLabel(r)) + '</span>';
  }
  function fmtDate(iso) { return new Date(iso + 'T12:00:00').toLocaleDateString('ro-RO', { day: 'numeric', month: 'long', year: 'numeric' }); }
  function meResident() { return residents.find(function (r) { return r.id === meId; }) || null; }

  function fetchResidents() {
    return fetch('/api/residents.php', { credentials: 'same-origin' })
      .then(function (r) { return r.json(); })
      .then(function (d) {
        if (!d.ok) return;
        // contul a disparut intre timp (sters de admin, sau te-ai delogat din alt tab)
        const lostAccount = !IS_ADMIN && residentsLoaded && meId !== null && d.me === null;
        residents = d.residents; meId = d.me; residentsLoaded = true; invalidateMoves(); posCache = null;
        setProperties(d.properties || []);
        workplaces = d.workplaces || [];
        carsMap = d.cars || {};
        usedCars = d.used || [];
        d.residents.forEach(function (r) { r.car = carsMap[r.id] ? { m: carsMap[r.id][0], c: carsMap[r.id][1] } : null; });
        prices = d.prices || prices;
        myInfo = d.meInfo || null;
        if (myInfo && myInfo.daily) {
          const dl = myInfo.daily, tx = dl.taxes || 0;
          toast('☀️ Bună dimineața! ' + (dl.job ? 'Salariul net' : 'Ajutorul de șomaj') + ': +' + fmtLei(dl.salary - tx) + (tx ? ' (taxe −' + fmtLei(tx) + ')' : '') + (dl.rent ? ' · chiria: −' + fmtLei(dl.rent) : '') + (dl.spent ? ' · cheltuieli: −' + fmtLei(dl.spent) : ''));
        }
        if (lostAccount && modal.hidden) { closeResidentCard(); toast('Nu mai ești intrat în cont.'); openWelcome(); }
        social = d.social || null;
        updatePeopleUi();
        updateFriendsUi();
        refreshSearch();
        refreshOpenCard();
      })
      .catch(function () {});
  }
  setInterval(fetchResidents, IS_ADMIN ? 20000 : 10000);

  function setProperties(list) {
    properties = list;
    propsByTile = {};
    const owned = new Set();
    list.forEach(function (p) {
      (propsByTile[p.x + ',' + p.y] = propsByTile[p.x + ',' + p.y] || []).push(p);
      if (p.o !== null && p.k !== 'apt') owned.add(idx(p.x, p.y));
    });
    ownedHouseTiles = owned;
  }
  // Ce se poate face acum cu o proprietate, din punctul de vedere al jucatorului.
  function propOffer(p) {
    return { sale: p.s !== null && p.o !== meId, rent: p.r !== null && p.oc === null && p.o !== meId };
  }

  function propertyTip(x, y) {
    const list = propsAt(x, y), p0 = list[0];
    if (p0.k === 'apt') {
      const free = list.filter(function (p) { const o = propOffer(p); return p.oc === null && (o.sale || o.rent); }).length;
      return '🏢 <b>' + blockName(x, y) + '</b> · ' + list.length + ' apartamente<br>' + (free ? '🔑 ' + free + (free === 1 ? ' liber' : ' libere') + ' de cumpărat sau închiriat' : 'toate ocupate') + '<br><small>click pentru detalii</small>';
    }
    const owner = p0.o === null ? 'Primăria' : (residentById(p0.o) || { u: '?' }).u;
    return KIND_ICONS[p0.k] + ' <b>' + KIND_NAMES[p0.k] + '</b> · proprietar: ' + escapeHtml(owner) +
      (p0.s !== null && p0.o !== meId ? '<br>🏷️ de vânzare · ' + fmtLei(p0.s) : '') + '<br><small>click pentru detalii</small>';
  }

  // Semnele de pe harta: "De vânzare" pe case, "N libere" pe blocuri. Desenate sub avatare.
  let markerHits = [];   // dreptunghiurile etichetelor desenate (coordonate de lume), pentru click
  function drawPropertyMarkers(c, vx0, vy0, vx1, vy1) {
    markerHits = [];
    const alpha = detailAlpha();
    if (!properties.length || !alpha) return;
    c.globalAlpha = alpha;
    const px1 = 1 / cam.z;
    c.textAlign = 'center'; c.textBaseline = 'middle';
    c.font = '800 ' + (10 * px1).toFixed(2) + 'px Nunito, system-ui, sans-serif';
    Object.keys(propsByTile).forEach(function (key) {
      const list = propsByTile[key], p0 = list[0];
      const hc = homeCenter(p0.x, p0.y), cx = hc.x, cy = hc.y + (blocAt(p0.x, p0.y) ? T * 0.66 : T * 0.36);
      if (cx < vx0 - T || cx > vx1 + T || cy < vy0 - T || cy > vy1 + T) return;
      let label = null, col = null;
      if (p0.k !== 'apt') {
        const off = propOffer(p0);
        if (off.sale) { label = p0.o === null ? 'De vânzare' : fmtLei(p0.s); col = '#e0894a'; }
        else if (off.rent) { label = 'De închiriat'; col = '#4f9a5b'; }
      } else {
        const free = list.filter(function (p) { const o = propOffer(p); return p.oc === null && (o.sale || o.rent); }).length;
        if (free) { label = free + (free === 1 ? ' liber' : ' libere'); col = '#4f9a5b'; }
      }
      if (!label) return;
      const tw = c.measureText(label).width, w = tw + 12 * px1, h = 15 * px1;
      markerHits.push({ x0: cx - w / 2, y0: cy - h / 2, x1: cx + w / 2, y1: cy + h / 2, tx: p0.x, ty: p0.y });
      c.fillStyle = 'rgba(20,30,20,0.25)'; rr(c, cx - w / 2 + px1, cy - h / 2 + 1.5 * px1, w, h, 7 * px1); c.fill();
      c.fillStyle = col; rr(c, cx - w / 2, cy - h / 2, w, h, 7 * px1); c.fill();
      c.fillStyle = '#fff'; c.fillText(label, cx, cy + 0.5 * px1);
    });
    c.globalAlpha = 1;
  }
  // eticheta de sub cursor -> patratelul casei / blocului ei
  function markerAt(sx, sy) {
    if (detailAlpha() < 0.5) return null;
    const w = screenToWorld(sx, sy), pad = 3 / cam.z;
    for (let n = markerHits.length - 1; n >= 0; n--) {
      const m = markerHits[n];
      if (w.x >= m.x0 - pad && w.x <= m.x1 + pad && w.y >= m.y0 - pad && w.y <= m.y1 + pad) return { x: m.tx, y: m.ty };
    }
    return null;
  }

  // Locuitorii si etichetele caselor apar doar de aproape: de la DETAIL_ZOOM - DETAIL_FADE incep sa se
  // vada, la DETAIL_ZOOM sunt intregi. Tu si locuitorul cautat se vad mereu.
  const DETAIL_ZOOM = 0.85, DETAIL_FADE = 0.15;
  function detailAlpha() { return clamp((cam.z - (DETAIL_ZOOM - DETAIL_FADE)) / DETAIL_FADE, 0, 1); }
  // Filtrul "Arată locuitori": ceilalti locuitori pot fi ascunsi de pe harta (alegerea ramane in browser).
  const SHOW_PEOPLE_KEY = 'nscity_show_people';
  const showPeopleEl = document.getElementById('showPeople');
  let showOthers = true;
  try { showOthers = localStorage.getItem(SHOW_PEOPLE_KEY) !== '0'; } catch (e) { /* fara localStorage: raman vizibili */ }
  showPeopleEl.checked = showOthers;
  function setShowOthers(on) {
    showOthers = on;
    showPeopleEl.checked = on;
    try { localStorage.setItem(SHOW_PEOPLE_KEY, on ? '1' : '0'); } catch (e) { /* nu conteaza */ }
    if (!on && openCard && openCard.type === 'resident' && openCard.id !== meId) closeResidentCard();
  }
  showPeopleEl.addEventListener('change', function () { setShowOthers(showPeopleEl.checked); });
  function alwaysShown(r) { return r.id === meId || (highlight && highlight.id === r.id && performance.now() < highlight.until); }
  function avatarRadius() { return clamp(9 + cam.z * 5, 8, 17) / cam.z; }

  // ================= ZIUA LOCUITORILOR =================
  // Fiecare locuitor are programul lui (acasa -> serviciu -> pauza de masa -> cumparaturi -> acasa,
  // iar in weekend / ca somer cateva iesiri), calculat din ora reala a Bucurestiului si din id-ul lui:
  // toti vizitatorii il vad in acelasi loc, fara ca serverul sa tina evidenta. Merg pe drumuri, pe
  // cel mai scurt traseu; un patratel de drum dureaza MOVE_SEC_PER_TILE secunde.
  const MOVE_SEC_PER_TILE = 6;
  const TAXI_CAR = { m: 'taxi', c: '#f2c230', taxi: true };   // cine n-are masina merge cu taxiul, nu pe jos
  const bucFmt = new Intl.DateTimeFormat('en-GB', { timeZone: 'Europe/Bucharest', hourCycle: 'h23', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit', weekday: 'short' });
  const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  let clockCache = null;
  function cityClock() {
    const now = Date.now();
    if (clockCache && now - clockCache.at < 200) return clockCache;
    const p = {};
    bucFmt.formatToParts(new Date(now)).forEach(function (q) { p[q.type] = q.value; });
    clockCache = {
      at: now,
      day: Math.floor(Date.UTC(+p.year, +p.month - 1, +p.day) / 86400000),
      min: +p.hour * 60 + +p.minute + (+p.second + (now % 1000) / 1000) / 60,
      dow: WEEKDAYS.indexOf(p.weekday)
    };
    return clockCache;
  }

  // Locurile in care merg: magazine si supermarketuri, locuri de relaxare, plus casa si serviciul fiecaruia.
  let moveData = null;
  function invalidateMoves() { moveData = null; }
  function placeFor(x, y, w, h, name, role) {
    return { tx: x, ty: y, w: w, h: h, x: (x + w / 2) * T, y: (y + h / 2) * T, r: Math.max(w, h) * T * 0.3, name: name, role: role, acc: undefined };
  }
  function moves() {
    if (moveData) return moveData;
    const md = { shops: [], fun: [], jobs: {}, homes: {}, sched: {} };
    specials.forEach(function (sp) {
      if (!sp) return;
      const d = SPECIALS[sp.t];
      if (d.cov === 'shop') md.shops.push(placeFor(sp.x, sp.y, d.w, d.h, d.name, 'shop'));
      else if (d.cov === 'leisure' || sp.t === 'church') md.fun.push(placeFor(sp.x, sp.y, d.w, d.h, d.name, 'fun'));
    });
    for (let i = 0; i < N; i++) {
      if (zone[i] === 2 && level[i] && !road[i]) md.shops.push(placeFor(i % W, (i / W) | 0, 1, 1, ['', 'Prăvălie', 'Magazin', 'Magazin mare'][level[i]], 'shop'));
    }
    workplaces.forEach(function (w) {
      const d = SPECIALS[w.k];
      md.jobs[w.id] = d ? placeFor(w.x, w.y, d.w, d.h, w.n, 'job') : placeFor(w.x, w.y, 1, 1, w.n, 'job');
    });
    moveData = md;
    return md;
  }
  function homePlace(r) {
    if (r.x === null) return null;
    const md = moves(), k = r.x + ',' + r.y;
    if (!md.homes[k]) {
      const b = blocAt(r.x, r.y);
      md.homes[k] = b ? placeFor(b.x, b.y, SPECIALS.bloc.w, SPECIALS.bloc.h, 'Bloc', 'home') : placeFor(r.x, r.y, 1, 1, 'Casă', 'home');
    }
    return md.homes[k];
  }
  // patratelul de drum cel mai apropiat de un loc (cel mult 3 patratele departare), sau -1
  function accessOf(pl) {
    if (pl.acc !== undefined) return pl.acc;
    let best = -1, bd = 1e9;
    for (let ring = 1; ring <= 3 && best < 0; ring++) {
      for (let y = pl.ty - ring; y < pl.ty + pl.h + ring; y++) for (let x = pl.tx - ring; x < pl.tx + pl.w + ring; x++) {
        if (!inb(x, y) || !road[idx(x, y)]) continue;
        const d = Math.abs(x + 0.5 - pl.x / T) + Math.abs(y + 0.5 - pl.y / T);
        if (d < bd) { bd = d; best = idx(x, y); }
      }
    }
    pl.acc = best;
    return best;
  }
  // unul dintre cele mai apropiate 6 locuri (uneori oricare), ales "la intamplare" dar la fel pentru toti
  function pickPlace(list, from, seed) {
    if (!list.length) return null;
    if (h2(seed, 3, 91) < 0.2) return list[Math.floor(h2(seed, 4, 92) * list.length) % list.length];
    const best = [];
    list.forEach(function (pl) {
      const d = Math.abs(pl.x - from.x) + Math.abs(pl.y - from.y);
      if (best.length < 6) best.push([d, pl]); else if (d < best[5][0]) best[5] = [d, pl]; else return;
      best.sort(function (a, b) { return a[0] - b[0]; });
    });
    return best[Math.floor(h2(seed, 5, 93) * best.length) % best.length][1];
  }
  function travelMinutes(a, b, car) {
    const tiles = (Math.abs(a.x - b.x) + Math.abs(a.y - b.y)) / T;
    return (tiles * 1.3 + 2) * MOVE_SEC_PER_TILE * (car ? 0.3 : 1) / 60;
  }
  // Programul pe azi: plecari (leg) spre un loc, la un minut din zi.
  function scheduleOf(r, clk) {
    const md = moves();
    let sc = md.sched[r.id];
    if (sc && sc.day === clk.day) return sc;
    const home = homePlace(r);
    if (!home) return null;
    const job = r.w ? md.jobs[r.w] || null : null;
    const R = function (k) { return h2(r.id, clk.day, k); }, seed = function (k) { return r.id * 31 + clk.day * 7 + k; };
    const legs = [];
    if (job && clk.dow >= 1 && clk.dow <= 5) {
      let t = 390 + R(1) * 120;                                     // pleaca la serviciu intre 6:30 si 8:30
      legs.push({ to: job, at: t });
      if (R(2) < 0.45) {                                            // pauza de masa la un magazin de langa serviciu
        const lunch = 690 + R(3) * 90, p = pickPlace(md.shops, job, seed(1));
        if (p) { legs.push({ to: p, at: lunch }); legs.push({ to: job, at: lunch + 20 + R(4) * 25 }); }
      }
      t = 930 + R(5) * 150;                                         // iese de la serviciu intre 15:30 si 18:00
      if (R(6) < 0.5) {
        const p = pickPlace(R(7) < 0.7 ? md.shops : md.fun, home, seed(2));
        if (p) { legs.push({ to: p, at: t }); t += 30 + R(8) * 70; }
      }
      legs.push({ to: home, at: t });
      if (R(9) < 0.25) {                                            // seara in oras
        const ev = Math.max(t + 60, 1140 + R(10) * 90), p = pickPlace(md.fun, home, seed(3));
        if (p) { legs.push({ to: p, at: ev }); legs.push({ to: home, at: ev + 60 + R(11) * 90 }); }
      }
    } else {                                                        // weekend sau somer: cateva iesiri
      const outs = 1 + Math.floor(R(12) * 3);
      for (let k = 0; k < outs; k++) {
        const start = 540 + k * 210 + R(13 + k) * 120, p = pickPlace(R(20 + k) < 0.55 ? md.shops : md.fun, home, seed(10 + k));
        if (!p) continue;
        legs.push({ to: p, at: start }); legs.push({ to: home, at: start + 40 + R(30 + k) * 110 });
      }
    }
    let from = home, free = 0;
    legs.forEach(function (lg) {
      lg.from = from;
      lg.at = Math.max(lg.at, free);
      lg.dur = travelMinutes(from, lg.to, true);   // cu masina proprie sau cu taxiul
      free = lg.at + lg.dur + 5;
      from = lg.to;
    });
    sc = { day: clk.day, home: home, job: job, legs: legs };
    md.sched[r.id] = sc;
    return sc;
  }

  // Cel mai scurt drum pe strazi intre doua patratele de drum (cautare in latime), tinut minte.
  const routeCache = new Map();
  let bfsPrev = null, bfsSeen = null, bfsQueue = null, bfsStamp = 0;
  function bfsRoute(a, b, car) {
    const key = a + ':' + b + (car ? 'c' : '');
    if (routeCache.has(key)) return routeCache.get(key);
    if (!bfsPrev || bfsPrev.length !== N) { bfsPrev = new Int32Array(N); bfsSeen = new Uint32Array(N); bfsQueue = new Int32Array(N); bfsStamp = 0; }
    bfsStamp++;
    let head = 0, tail = 0;
    bfsQueue[tail++] = a; bfsSeen[a] = bfsStamp; bfsPrev[a] = -1;
    while (head < tail) {
      const i = bfsQueue[head++];
      if (i === b) break;
      const x = i % W, y = (i / W) | 0;
      for (let d = 0; d < 4; d++) {
        const nx = x + DIRS[d][0], ny = y + DIRS[d][1];
        if (!inb(nx, ny)) continue;
        const j = idx(nx, ny);
        if (!road[j] || (car && road[j] === 4) || bfsSeen[j] === bfsStamp) continue;
        bfsSeen[j] = bfsStamp; bfsPrev[j] = i; bfsQueue[tail++] = j;
      }
    }
    let out = null;
    if (bfsSeen[b] === bfsStamp) { out = []; for (let i = b; i !== -1; i = bfsPrev[i]) out.push(i); out.reverse(); }
    if (routeCache.size > 4000) routeCache.clear();
    routeCache.set(key, out);
    return out;
  }
  function roadsChanged() { routeCache.clear(); invalidateMoves(); }
  // punctele drumului unei plecari (in pixeli), cu lungimile cumulate
  function legPoints(lg, car) {
    const ck = car ? 'ptsCar' : 'pts';
    if (lg[ck]) return lg[ck];
    const pts = [{ x: lg.from.x, y: lg.from.y }], a = accessOf(lg.from), b = accessOf(lg.to);
    const route = a >= 0 && b >= 0 ? bfsRoute(a, b, car) : null;
    pts.drive = !!car && !!route;   // fara traseu pentru masini, merge pe jos
    if (route) route.forEach(function (i) { pts.push({ x: (i % W + 0.5) * T, y: (((i / W) | 0) + 0.5) * T }); });
    pts.push({ x: lg.to.x, y: lg.to.y });
    let len = 0;
    pts[0].d = 0;
    for (let k = 1; k < pts.length; k++) { len += Math.hypot(pts[k].x - pts[k - 1].x, pts[k].y - pts[k - 1].y); pts[k].d = len; }
    pts.len = len;
    lg[ck] = pts;
    return pts;
  }
  function pointAlong(pts, f) {
    const target = f * pts.len;
    let k = 1;
    while (k < pts.length - 1 && pts[k].d < target) k++;
    const a = pts[k - 1], b = pts[k], seg = b.d - a.d || 1, t = clamp((target - a.d) / seg, 0, 1);
    const dx = b.x - a.x, dy = b.y - a.y, dl = Math.hypot(dx, dy) || 1, lane = T * 0.16;
    // pe partea dreapta a drumului, ca masinile
    return { x: a.x + dx * t - dy / dl * lane, y: a.y + dy * t + dx / dl * lane, a: Math.atan2(dy, dx) };
  }
  // Unde e acum un locuitor: { x, y, moving, place | to }, sau null daca n-are casa.
  function residentNow(r) {
    const clk = cityClock(), sc = scheduleOf(r, clk);
    if (!sc) return null;
    let at = sc.home;
    for (let k = 0; k < sc.legs.length; k++) {
      const lg = sc.legs[k];
      if (clk.min < lg.at) break;
      if (clk.min < lg.at + lg.dur) {
        const pts = legPoints(lg, true), p = pointAlong(pts, (clk.min - lg.at) / lg.dur);
        return { x: p.x, y: p.y, moving: true, to: lg.to, sc: sc, car: pts.drive ? (r.car || TAXI_CAR) : null, a: p.a };
      }
      at = lg.to;
    }
    // cei din acelasi loc stau imprastiati putin in jurul lui
    const ang = h2(r.id, 5, 71) * 6.283, rad = at.r * (0.25 + 0.75 * h2(r.id, 6, 72));
    return { x: at.x + Math.cos(ang) * rad, y: at.y + Math.sin(ang) * rad - T * 0.2, moving: false, place: at, sc: sc };
  }
  function placeText(pl, sc, going) {
    if (pl === sc.home) return going ? 'spre casă' : 'acasă';
    if (pl === sc.job) return (going ? 'spre serviciu, la ' : 'la serviciu, la ') + lowerFirst(pl.name);
    return (going ? 'spre ' : (pl.role === 'shop' ? 'la cumpărături, la ' : 'la plimbare, la ')) + lowerFirst(pl.name);
  }
  function whereText(r) {
    const p = residentNow(r);
    if (!p) return '';
    return p.moving ? (p.car ? (p.car.taxi ? '🚕 cu taxiul, în drum ' : '🚗 cu mașina, în drum ') : '🚶 în drum ') + placeText(p.to, p.sc, true) : '📍 acum ' + placeText(p.place, p.sc, false);
  }

  // Pozitiile tuturor locuitorilor acum (calculate cel mult o data la 40 ms).
  let posCache = null;
  function residentPositions() {
    const now = performance.now();
    if (posCache && now - posCache.at < 40 && posCache.n === residents.length) return posCache.list;
    const out = [];
    residents.forEach(function (r) {
      const p = residentNow(r);
      if (p) out.push({ r: r, x: p.x, y: p.y, moving: p.moving, car: p.car, a: p.a });
    });
    // cei care merg se deseneaza peste cei care stau
    out.sort(function (a, b) { return (a.moving ? 1 : 0) - (b.moving ? 1 : 0); });
    posCache = { at: now, n: residents.length, list: out };
    return out;
  }
  function residentPos(r) {
    const p = residentNow(r);
    return p ? { x: p.x, y: p.y } : null;
  }
  function residentAt(sx, sy) {
    const w = screenToWorld(sx, sy), small = cam.z < 0.45, R = small ? 6 / cam.z : avatarRadius();
    const pos = residentPositions();
    const shown = detailAlpha() >= 0.5;
    for (let n = pos.length - 1; n >= 0; n--) {
      if ((!shown || !showOthers) && !alwaysShown(pos[n].r)) continue;
      if (Math.hypot(w.x - pos[n].x, w.y - pos[n].y) <= R * 1.25) return pos[n].r;
    }
    return null;
  }
  function residentTip(r) {
    return avatarHtml(r) + ' <b>' + escapeHtml(r.u) + '</b>' + (r.on ? ' · 🟢 online' : '') + (r.id === meId ? ' · tu' : '') +
      '<br>' + escapeHtml(whereText(r)) + '<br>' + jobText(r) + '<br>' + (r.st === 'own' ? '🔑 locuiește în casa lui' : r.st === 'rent' ? '📝 stă în chirie' : '🧳 fără casă') + ' · în oraș din ' + fmtDate(r.j);
  }

  function drawResidents(c, now, vx0, vy0, vx1, vy1) {
    drawPropertyMarkers(c, vx0, vy0, vx1, vy1);
    if (!residents.length) return;
    const small = cam.z < 0.45, R = small ? 5 / cam.z : avatarRadius(), px1 = 1 / cam.z, alpha = detailAlpha();
    c.textAlign = 'center'; c.textBaseline = 'middle';
    residentPositions().forEach(function (p) {
      if (p.x < vx0 - 2 * T || p.x > vx1 + 2 * T || p.y < vy0 - 2 * T || p.y > vy1 + 2 * T) return;
      const r = p.r, isMe = r.id === meId, isHi = highlight && highlight.id === r.id && now < highlight.until;
      if (!isMe && !isHi && (!alpha || !showOthers)) return;
      c.globalAlpha = isMe || isHi ? 1 : alpha;
      if (p.car) {   // la volan: masina in culoarea lui, cu un mic cerc de avatar pe ea
        const moto = p.car.m === 'moto', L = T * (moto ? 0.26 : 0.34), Wd = T * (moto ? 0.08 : 0.19);
        c.save(); c.translate(p.x, p.y); c.rotate(p.a || 0);
        c.fillStyle = 'rgba(20,30,20,0.25)'; rr(c, -L / 2 + 2, -Wd / 2 + 2.5, L, Wd, 3); c.fill();
        c.fillStyle = p.car.c; rr(c, -L / 2, -Wd / 2, L, Wd, 3); c.fill();
        c.fillStyle = 'rgba(40,60,90,0.55)'; c.fillRect(L * 0.02, -Wd * 0.36, L * 0.22, Wd * 0.72);
        if (p.car.taxi) { c.fillStyle = '#fff'; c.fillRect(-L * 0.12, -Wd * 0.18, L * 0.2, Wd * 0.36); c.fillStyle = '#c0392b'; c.fillRect(-L * 0.08, -Wd * 0.08, L * 0.12, Wd * 0.16); }
        c.restore();
        c.fillStyle = isMe ? '#f2c14e' : '#fff'; c.beginPath(); c.arc(p.x, p.y, Math.max(2.6 * px1, R * 0.34), 0, 6.29); c.fill();
        c.fillStyle = avatarColor(r); c.beginPath(); c.arc(p.x, p.y, Math.max(1.8 * px1, R * 0.24), 0, 6.29); c.fill();
        if (isHi) { const k = (now % 1200) / 1200; c.strokeStyle = 'rgba(224,137,74,' + (1 - k).toFixed(3) + ')'; c.lineWidth = 3 * px1; c.beginPath(); c.arc(p.x, p.y, R * (1.3 + k * 1.8), 0, 6.29); c.stroke(); }
        return;
      }
      if (!small) {
        c.fillStyle = '#fff';
        c.beginPath(); c.moveTo(p.x - R * 0.4, p.y + R * 0.7); c.lineTo(p.x + R * 0.4, p.y + R * 0.7); c.lineTo(p.x, p.y + R * 1.45); c.closePath(); c.fill();
      }
      c.fillStyle = 'rgba(20,30,20,0.28)'; c.beginPath(); c.arc(p.x + 1.5 * px1, p.y + 2.5 * px1, R + 2 * px1, 0, 6.29); c.fill();
      c.fillStyle = isMe ? '#f2c14e' : '#fff'; c.beginPath(); c.arc(p.x, p.y, R + 2 * px1 * (isMe ? 1.6 : 1), 0, 6.29); c.fill();
      c.fillStyle = avatarColor(r); c.beginPath(); c.arc(p.x, p.y, R, 0, 6.29); c.fill();
      if (!small) {
        c.fillStyle = '#fff';
        c.font = '800 ' + (R * (r.e ? 1.15 : 1.05)).toFixed(2) + 'px Nunito, system-ui, sans-serif';
        c.fillText(avatarLabel(r), p.x, p.y + R * 0.06);
      }
      if (r.on) {
        const ox = p.x + R * 0.72, oy = p.y - R * 0.72, rr2 = Math.max(R * 0.28, 3 * px1);
        c.fillStyle = '#fff'; c.beginPath(); c.arc(ox, oy, rr2 + 1.5 * px1, 0, 6.29); c.fill();
        c.fillStyle = '#5bb35b'; c.beginPath(); c.arc(ox, oy, rr2, 0, 6.29); c.fill();
      }
      if (isHi) {
        const k = (now % 1200) / 1200;
        c.strokeStyle = 'rgba(224,137,74,' + (1 - k).toFixed(3) + ')'; c.lineWidth = 3 * px1;
        c.beginPath(); c.arc(p.x, p.y, R * (1.3 + k * 1.8), 0, 6.29); c.stroke();
      }
      if (!small && (cam.z > 1.6 || isMe || isHi)) {   // numele: doar de foarte aproape (oamenii se strang la serviciu)
        c.font = '800 ' + (11 * px1).toFixed(2) + 'px Nunito, system-ui, sans-serif';
        const tw = c.measureText(r.u).width, ly = p.y + R * 1.45 + 9 * px1;
        c.fillStyle = 'rgba(74,63,50,0.88)'; rr(c, p.x - tw / 2 - 6 * px1, ly - 8 * px1, tw + 12 * px1, 16 * px1, 8 * px1); c.fill();
        c.fillStyle = '#fffaf0'; c.fillText(r.u, p.x, ly + 0.5 * px1);
      }
    });
    c.globalAlpha = 1;
  }

  function flyTo(r) {
    if (r.x === null) { toast(r.u + ' încă nu are o casă - se mută când apar case noi'); return; }
    const p = residentPos(r) || { x: (r.x + 0.5) * T, y: (r.y + 0.5) * T };
    camAnim = { fx: cam.x, fy: cam.y, fz: cam.z, tx: p.x, ty: p.y, tz: Math.max(cam.z, 1.4), t0: performance.now(), dur: 900, follow: r };
    highlight = { id: r.id, until: performance.now() + 6500 };
  }
  function stepCamAnim(now) {
    if (!camAnim) return;
    if (camAnim.follow) { const fp = residentPos(camAnim.follow); if (fp) { camAnim.tx = fp.x; camAnim.ty = fp.y; } }
    const t = clamp((now - camAnim.t0) / camAnim.dur, 0, 1), e = t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
    cam.x = camAnim.fx + (camAnim.tx - camAnim.fx) * e;
    cam.y = camAnim.fy + (camAnim.ty - camAnim.fy) * e;
    cam.z = camAnim.fz + (camAnim.tz - camAnim.fz) * e;
    clampCam();
    if (t >= 1) camAnim = null;
  }
  canvas.addEventListener('pointerdown', function () { camAnim = null; });
  canvas.addEventListener('wheel', function () { camAnim = null; });

  // --- cardul unui locuitor ---
  const cardEl = document.getElementById('residentCard');
  function jobLine(r, isMe) {
    if (!r.jk) return '🪑 Șomer' + (isMe ? ' · ajutor ' + fmtLei(prices ? prices.unemployed : 0) + '/zi - te angajezi singur când se eliberează un loc' : '');
    const j = jobInfo(r.jk), w = workplaces.find(function (q) { return q.id === r.w; });
    return j.icon + ' ' + j.title + (w ? ' la ' + lowerFirst(workplaceLabel(w)) : '') + (isMe ? ' · ' + fmtLei(j.salary) + '/zi' : '');
  }
  function homeLine(r) {
    if (r.x === null) return '🧳 fără casă deocamdată - se mută singur când apare un apartament liber';
    const home = properties.find(function (p) { return p.id === r.h; });
    const where = home ? propLabel(home) + (home.k === 'apt' ? ' din blocul (' + home.x + ',' + home.y + ')' : ' (' + home.x + ',' + home.y + ')') : '';
    if (r.st === 'own') return '🔑 locuiește în ' + where.replace(/^./, function (ch) { return ch.toLowerCase(); }) + ', care e a lui';
    const landlord = home && home.o !== null ? residentById(home.o) : null;
    return '📝 stă în chirie: ' + where.replace(/^./, function (ch) { return ch.toLowerCase(); }) + (landlord ? ', la ' + landlord.u : ', la Primărie');
  }

  function openResidentCard(r) {
    openCard = { type: 'resident', id: r.id };
    const isMe = r.id === meId;
    let extra = '';
    if (isMe && myInfo) {
      const mine = properties.filter(function (p) { return p.o === meId; });
      extra =
        '<div class="rc-money' + (myInfo.balance < 0 ? ' is-debt' : '') + '">💰 ' + fmtLei(myInfo.balance) + '</div>' +
        (r.st === 'rent' ? '<p>Chiria ta: ' + fmtLei(myInfo.rent) + ' pe zi</p>' : '') + '<p><small>Salariul vine în fiecare zi în care intri în oraș.</small></p>' +
        ((myInfo.vehicles || []).length ? '<div class="rc-section">Mașinile tale</div><div class="rc-list">' + myInfo.vehicles.map(function (v) {
          return '<div class="car-row"><div class="car-info"><b><i class="car-dot" style="background:' + v.c + '"></i> ' + escapeHtml(carName(v)) + '</b><small>' + escapeHtml(carStats(v)) + '</small><small>valoare ' + fmtLei(v.v) + (v.l !== null ? ' · 📌 la vânzare cu ' + fmtLei(v.l) : '') + '</small></div>' +
            '<div class="fr-btns">' + (v.l !== null ? '<button class="fr-btn" data-unlist="' + v.id + '">Retrage</button>' : '<button class="fr-btn" data-list="' + v.id + '">Pune la vânzare</button>') + '<button class="fr-btn" data-sell="' + v.id + '">Vinde la dealer</button></div></div>';
        }).join('') + '</div>' : '') +
        (mine.length ? '<div class="rc-section">Proprietățile tale</div><div class="rc-list">' + mine.map(function (p) {
          return '<button class="rc-row" data-prop="' + p.id + '"><span>' + KIND_ICONS[p.k] + ' ' + escapeHtml(propLabel(p)) + ' (' + p.x + ',' + p.y + ')</span><small>' +
            (p.oc === meId ? 'aici locuiești' : p.oc !== null ? 'închiriat' : 'gol') + (p.s !== null ? ' · de vânzare' : '') + '</small></button>';
        }).join('') + '</div>' : '') +
        (myInfo.history.length ? '<div class="rc-section">Ultimele mișcări</div><div class="rc-history">' + myInfo.history.slice(0, 6).map(function (t) {
          return '<div><span>' + escapeHtml(t.n) + '</span><b class="' + (t.a < 0 ? 'neg' : 'pos') + '">' + (t.a > 0 ? '+' : '−') + fmtLei(Math.abs(t.a)) + '</b></div>';
        }).join('') + '</div>' : '');
    }
    cardEl.innerHTML = '<button class="rc-close" aria-label="Închide">✕</button>' + avatarHtml(r, true) +
      '<h3></h3><p>În oraș din ' + escapeHtml(fmtDate(r.j)) + '</p><p class="rc-where"></p><p class="rc-job"></p><p class="rc-home"></p>' + extra +
      '<div class="rc-actions">' +
      (r.x !== null ? '<button class="btn-secondary" data-act="go">📍 Arată pe hartă</button>' : '') +
      (!isMe ? friendButtons(r) : '') +
      (isMe ? '<button class="btn-secondary" data-act="jobs">💼 Schimbă jobul</button>' : '') +
      (isMe && myInfo && myInfo.job ? '<button class="btn-secondary" data-act="work">🏢 Unde lucrez</button>' : '') +
      (isMe ? '<button class="btn-secondary" data-act="logout">Ieși din cont</button><button class="rc-danger" data-act="leave">Șterge contul</button>' : '') +
      (IS_ADMIN ? '<button class="btn-primary" data-act="aedit">🛠️ Editează</button>' : '') +
      (IS_ADMIN ? '<button class="rc-danger" data-act="remove">Scoate din oraș</button>' : '') +
      '</div>';
    const h3 = cardEl.querySelector('h3');
    h3.textContent = r.u + (isMe ? ' (tu)' : social && social.friends.indexOf(r.id) >= 0 ? ' 🤝' : '');
    const dot = document.createElement('span');
    dot.className = 'on-dot ' + (r.on ? 'is-on' : 'is-off');
    dot.title = r.on ? 'online' : 'offline';
    h3.insertBefore(dot, h3.firstChild);
    cardEl.querySelector('.rc-home').textContent = homeLine(r);
    cardEl.querySelector('.rc-where').textContent = whereText(r);
    cardEl.querySelector('.rc-job').textContent = jobLine(r, isMe);
    cardEl.hidden = false;
    cardEl.querySelector('.rc-close').addEventListener('click', closeResidentCard);
    cardEl.querySelectorAll('[data-act]').forEach(function (b) {
      b.addEventListener('click', function () {
        const act = b.getAttribute('data-act');
        if (act === 'go') flyTo(r);
        else if (act === 'logout') logout();
        else if (act === 'jobs') openJobList();
        else if (act === 'work') { const w = workplaces.find(function (q) { return q.id === myInfo.job.id; }); if (w) { flyToTile(w.x, w.y); openWorkplaceCard(w); } }
        else if (act === 'leave') deleteAccount();
        else if (act === 'remove') removeResident(r);
        else if (act === 'aedit') openAdminEdit(r);
        else if (act.indexOf('fr-') === 0) friendAction(act.slice(3), r, b);
      });
    });
    cardEl.querySelectorAll('[data-sell]').forEach(function (b) { b.addEventListener('click', function () { sellCar(+b.getAttribute('data-sell')); }); });
    cardEl.querySelectorAll('[data-list]').forEach(function (b) { b.addEventListener('click', function () { listCar(+b.getAttribute('data-list')); }); });
    cardEl.querySelectorAll('[data-unlist]').forEach(function (b) { b.addEventListener('click', function () { carAction({ action: 'unlist', id: +b.getAttribute('data-unlist') }); }); });
    cardEl.querySelectorAll('[data-prop]').forEach(function (b) {
      b.addEventListener('click', function () {
        const p = properties.find(function (q) { return q.id === +b.getAttribute('data-prop'); });
        if (p) { flyToTile(p.x, p.y); openPropertyCard(p.x, p.y); }
      });
    });
  }
  function closeResidentCard() { cardEl.hidden = true; openCard = null; }
  function refreshOpenCard() {
    if (!openCard || cardEl.hidden) return;
    if (openCard.type === 'resident') { const r = residentById(openCard.id); if (r) openResidentCard(r); else closeResidentCard(); }
    else if (openCard.type === 'property') { if (propsAt(openCard.x, openCard.y).length) openPropertyCard(openCard.x, openCard.y); else closeResidentCard(); }
    else if (openCard.type === 'workplace') { const w = workplaces.find(function (q) { return q.id === openCard.id; }); if (w) openWorkplaceCard(w); else closeResidentCard(); }
    else if (openCard.type === 'jobs') openJobList();
    else if (openCard.type === 'payslip') openPayslip();
    else if (openCard.type === 'vehicles') openMyVehicles();
  }

  // --- fluturasul de salariu: ce primesti si ce platesti pe zi, si cati bani ai ---
  function openPayslip() {
    const me = meResident();
    if (!myInfo || !myInfo.payslip || !me) return;
    openCard = { type: 'payslip' };
    const p = myInfo.payslip, rt = p.rates, minus = function (v) { return v ? '−' + fmtLei(v) : fmtLei(0); };
    const row = function (label, val, cls, sub) {
      return '<div class="ps-row' + (sub ? ' is-sub' : '') + '"><span>' + label + '</span><b class="' + (cls || '') + '">' + val + '</b></div>';
    };
    const balance = myInfo.balance;
    cardEl.innerHTML = '<button class="rc-close" aria-label="Închide">✕</button>' +
      '<div class="ps-head">🧾</div><h3>Fluturaș de salariu</h3>' +
      '<p>' + escapeHtml(me.u) + ' · ' + (p.job ? escapeHtml(p.job) : 'șomer') + ' · ' + new Date().toLocaleDateString('ro-RO') + '</p>' +
      '<div class="ps">' +
        row(p.job ? 'Salariu brut' : 'Ajutor de șomaj', fmtLei(p.gross), 'pos') +
        row('Taxe', minus(p.taxes), p.taxes ? 'neg' : '') +
        (p.job
          ? row('CAS (pensie) ' + rt[0] + '%', minus(p.cas), '', true) + row('CASS (sănătate) ' + rt[1] + '%', minus(p.cass), '', true) + row('Impozit pe venit ' + rt[2] + '%', minus(p.income), '', true)
          : row('ajutorul de șomaj nu se impozitează', '', '', true)) +
        row('Chirie', minus(p.rent), p.rent ? 'neg' : '') +
        (!p.rent && me.st === 'own' ? row('locuiești în casa ta', '', '', true) : '') +
        row('Cheltuieli (ieșiri)', minus(p.spend), p.spend ? 'neg' : '') +
        (p.spend_items || []).map(function (it) { return row(escapeHtml(it.n), '−' + fmtLei(it.a), '', true); }).join('') +
        (p.tenants ? row('Chirii de la chiriași (' + p.tenants + ')', '+' + fmtLei(p.rent_in), 'pos') : '') +
        '<div class="ps-total">' + row('Venit total pe zi', (p.total < 0 ? '−' : '+') + fmtLei(Math.abs(p.total)), p.total < 0 ? 'neg' : 'pos') + '</div>' +
      '</div>' +
      '<div class="ps-balance' + (balance < 0 ? ' is-debt' : '') + '"><span>Total cont</span><b>' + fmtLei(balance) + '</b></div>' +
      '<p><small>' + (p.paid_today ? '✅ Ziua de azi e plătită. ' : '⏳ Ziua de azi se plătește când intri în oraș. ') +
        'Salariul și chiria se plătesc o dată pe zi, în zilele în care treci pe aici' + (p.tenants ? '; chiriașii tăi plătesc în zilele în care trec ei.' : '.') + '</small></p>' +
      '<div class="rc-actions"><button class="btn-secondary" data-act="back">← Înapoi</button></div>';
    cardEl.hidden = false;
    cardEl.querySelector('.rc-close').addEventListener('click', closeResidentCard);
    cardEl.querySelector('[data-act="back"]').addEventListener('click', function () { openResidentCard(me); });
  }
  function flyToTile(x, y) {
    camAnim = { fx: cam.x, fy: cam.y, fz: cam.z, tx: (x + 0.5) * T, ty: (y + 0.5) * T, tz: Math.max(cam.z, 1.4), t0: performance.now(), dur: 900 };
  }

  // --- cardul unei case / al unui bloc ---
  function openPropertyCard(x, y) {
    const list = propsAt(x, y);
    if (!list.length) return;
    openCard = { type: 'property', x: x, y: y };
    const isBlock = list[0].k === 'apt';
    const canAct = !IS_ADMIN && meId !== null && myInfo;
    const rows = list.map(function (p) {
      const owner = p.o === null ? 'Primăria' : (residentById(p.o) || { u: '?' }).u + (p.o === meId ? ' (tu)' : '');
      const occ = p.oc === null ? null : residentById(p.oc);
      const occText = !occ ? 'liber' : occ.id === meId ? 'locuiești tu' + (p.o === meId ? '' : ' (în chirie)') : escapeHtml(occ.u) + (p.o === p.oc ? '' : ' (chiriaș)');
      const off = propOffer(p);
      const tags = [];
      if (p.s !== null && p.o !== meId) tags.push('<span class="tag sale">de vânzare · ' + fmtLei(p.s) + '</span>');
      if (p.s !== null && p.o === meId) tags.push('<span class="tag sale">o vinzi cu ' + fmtLei(p.s) + '</span>');
      if (off.rent) tags.push('<span class="tag rent">de închiriat · ' + fmtLei(p.r) + '/zi</span>');
      if (p.o === meId && p.ro) tags.push('<span class="tag rent">o oferi cu ' + fmtLei(p.r) + '/zi</span>');
      else if (p.o === meId && p.s !== null && p.oc === null) tags.push('<span class="tag rent">cât e de vânzare, se poate închiria cu ' + fmtLei(p.r) + '/zi</span>');
      const btns = [];
      if (canAct) {
        if (p.o === meId) {
          if (p.oc === null) btns.push('<button class="btn-primary" data-pa="move_in" data-id="' + p.id + '">Mută-te aici</button>');
          btns.push(p.s === null ? '<button class="btn-secondary" data-pa="sell" data-id="' + p.id + '">Vinde…</button>'
                                 : '<button class="btn-secondary" data-pa="sell_cancel" data-id="' + p.id + '">Retrage de la vânzare</button>');
          btns.push(!p.ro ? '<button class="btn-secondary" data-pa="lease" data-id="' + p.id + '">Închiriază altora…</button>'
                                                   : '<button class="btn-secondary" data-pa="lease_cancel" data-id="' + p.id + '">Retrage oferta de chirie</button>');
        } else {
          if (off.sale) {
            const short = myInfo.balance < p.s;
            btns.push('<button class="btn-primary" data-pa="buy" data-id="' + p.id + '"' + (short ? ' disabled title="Îți mai trebuie ' + fmtLei(p.s - myInfo.balance) + '"' : '') + '>Cumpără · ' + fmtLei(p.s) + '</button>');
          }
          if (off.rent && myInfo.home !== p.id) btns.push('<button class="btn-secondary" data-pa="rent" data-id="' + p.id + '">Închiriază · ' + fmtLei(p.r) + '/zi</button>');
        }
      }
      return '<div class="pc-unit">' +
        (isBlock ? '<div class="pc-name">🚪 ' + escapeHtml(propLabel(p)) + '</div>' : '') +
        '<div class="pc-line">👤 Proprietar: <b>' + escapeHtml(owner) + '</b></div>' +
        '<div class="pc-line">🛏️ Locuiește: <b>' + occText + '</b></div>' +
        (tags.length ? '<div class="pc-tags">' + tags.join('') + '</div>' : '') +
        (btns.length ? '<div class="pc-btns">' + btns.join('') + '</div>' : '') +
        '</div>';
    }).join('');
    const title = isBlock ? '🏢 ' + blockName(x, y) + ' · ' + list.length + ' apartamente' : (KIND_ICONS[list[0].k] + ' ' + KIND_NAMES[list[0].k]);
    cardEl.innerHTML = '<button class="rc-close" aria-label="Închide">✕</button><h3>' + title + '</h3><p>pe strada (' + x + ',' + y + ')</p>' +
      (!IS_ADMIN && meId === null ? '<p>Intră în cont ca să poți cumpăra sau închiria.</p>' : '') +
      (canAct ? '<p>Ai <b>' + fmtLei(myInfo.balance) + '</b></p>' : '') +
      '<div class="pc-units">' + rows + '</div>';
    cardEl.hidden = false;
    cardEl.querySelector('.rc-close').addEventListener('click', closeResidentCard);
    cardEl.querySelectorAll('[data-pa]').forEach(function (b) {
      b.addEventListener('click', function () { propertyAction(b.getAttribute('data-pa'), +b.getAttribute('data-id'), b); });
    });
  }

  function propertyAction(action, id, btn) {
    const p = properties.find(function (q) { return q.id === id; });
    if (!p) return;
    const fields = { action: action, id: id };
    if (action === 'sell') {
      const suggest = prices ? prices[p.k] : '';
      const v = prompt('La ce preț vinzi ' + propLabel(p).toLowerCase() + '? (LEI)', suggest);
      if (v === null) return;
      fields.price = parseInt(String(v).replace(/[^0-9]/g, ''), 10) || 0;
    } else if (action === 'lease') {
      const v = prompt('Cât să plătească chiriașul pe zi? (LEI)', prices && prices.rents ? prices.rents[p.k] : '');
      if (v === null) return;
      fields.price = parseInt(String(v).replace(/[^0-9]/g, ''), 10) || 0;
    } else if (action === 'buy') {
      if (!confirm('Cumperi ' + propLabel(p).toLowerCase() + ' cu ' + fmtLei(p.s) + '?')) return;
    } else if (action === 'rent') {
      if (!confirm('Te muți în chirie aici, cu ' + fmtLei(p.r) + ' pe zi? Locuința de acum rămâne liberă.')) return;
    }
    btn.disabled = true;
    postForm('/api/property.php', fields)
      .then(function (d) {
        if (!d.ok) throw new Error(d.error || 'Nu s-a putut.');
        toast(d.message || 'Gata ✓');
        myInfo = d.meInfo;
        return fetchResidents();
      })
      .catch(function (err) { toast(err.message); btn.disabled = false; });
  }

  function postForm(url, fields) {
    return fetch(url, { method: 'POST', credentials: 'same-origin', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: new URLSearchParams(fields).toString() })
      .then(function (r) { return r.json(); });
  }
  function logout() {
    postForm('/api/logout.php', {}).then(function () {
      meId = null; closeResidentCard(); toast('Ai ieșit din cont.');
      fetchResidents();
      openWelcome();
    }).catch(function () { toast('Nu s-a putut. Încearcă din nou.'); });
  }
  function deleteAccount() {
    if (!confirm('Sigur ștergi contul? Pleci din oraș, iar casa ta rămâne liberă pentru altcineva. Nu se poate anula.')) return;
    postForm('/api/leave.php', {}).then(function () {
      meId = null; closeResidentCard(); toast('Contul a fost șters. Ușa rămâne deschisă!');
      fetchResidents();
      openWelcome();
    }).catch(function () { toast('Nu s-a putut. Încearcă din nou.'); });
  }
  // --- admin: editeaza un locuitor (bani, job, casa, masini) ---
  function adminEdit(fields) {
    return postForm('/admin/resident_edit.php', fields).then(function (d) {
      if (!d.ok) throw new Error(d.error || 'Nu s-a putut.');
      return d;
    });
  }
  function openAdminEdit(r) {
    showModal('aedit', '<div class="logo">🛠️</div><h1>' + escapeHtml(r.u) + '</h1><p>Se încarcă…</p>');
    adminEdit({ id: r.id, action: 'info' }).then(function (info) { renderAdminEdit(r, info); }).catch(function (e) { toast(e.message); hideModal(); });
  }
  function renderAdminEdit(r, info) {
    const cur = residentById(r.id) || r;
    const jobs = workplaces.slice().sort(function (a, b) { return a.n.localeCompare(b.n, 'ro') || a.x - b.x; });
    const home = properties.find(function (p) { return p.id === cur.h; });
    showModal('aedit',
      '<div class="logo">🛠️</div><h1>' + escapeHtml(r.u) + '</h1>' +
      '<div class="ae-block"><label>💰 Bani (LEI)</label><div class="ae-row"><input id="aeMoney" type="number" step="1" value="' + info.balance + '"><button class="btn-primary" id="aeMoneyGo">Setează</button></div></div>' +
      '<div class="ae-block"><label>💼 Job</label><div class="ae-row"><select id="aeJob"><option value="0"' + (!cur.w ? ' selected' : '') + '>Șomer</option>' + jobs.map(function (w) {
        const free = w.sl - w.wk, mine = cur.w === w.id;
        return '<option value="' + w.id + '"' + (mine ? ' selected' : '') + (free <= 0 && !mine ? ' disabled' : '') + '>' + escapeHtml(w.n) + ' (' + w.x + ',' + w.y + ') · ' + escapeHtml(jobInfo(w.k).title) + ' · ' + free + '/' + w.sl + ' libere</option>';
      }).join('') + '</select><button class="btn-primary" id="aeJobGo">Schimbă</button></div><small>Un șomer e angajat din nou automat când intră în oraș.</small></div>' +
      '<div class="ae-block"><label>🏠 Casa · acum: ' + (home ? escapeHtml(propLabel(home)) + ' (' + home.x + ',' + home.y + ')' : 'fără casă') + '</label><div class="ae-row"><input id="aeX" type="number" min="0" placeholder="x"><input id="aeY" type="number" min="0" placeholder="y"><button class="btn-primary" id="aeHomeGo">Mută</button><button class="btn-secondary" id="aeHomeClear">Fără casă</button></div><small>Se mută în prima locuință liberă de pe pătratul (x, y).</small></div>' +
      '<div class="ae-block"><label>🚗 Vehicule (' + info.vehicles.length + ')</label>' + (info.vehicles.length ? info.vehicles.map(function (v) {
        return '<div class="car-row"><div class="car-info"><b><i class="car-dot" style="background:' + v.c + '"></i> ' + escapeHtml(carName(v)) + '</b><small>' + escapeHtml(carStats(v)) + '</small></div><button class="fr-btn" data-cardel="' + v.id + '">Șterge</button></div>';
      }).join('') : '<small>Nu are vehicule.</small>') + '</div>' +
      '<div class="modal-actions"><button class="btn-secondary" id="mCancel">Închide</button></div>');
    const go = function (fields, btn) {
      if (btn) btn.disabled = true;
      adminEdit(Object.assign({ id: r.id }, fields)).then(function (d) {
        toast(d.message); fetchResidents().then(function () { renderAdminEdit(r, d); });
      }).catch(function (e) { toast(e.message); if (btn) btn.disabled = false; });
    };
    const $ = function (id) { return document.getElementById(id); };
    $('aeMoneyGo').addEventListener('click', function () { go({ action: 'money', amount: Math.round(+$('aeMoney').value || 0) }, this); });
    $('aeJobGo').addEventListener('click', function () { go({ action: 'job', workplace: $('aeJob').value }, this); });
    $('aeHomeGo').addEventListener('click', function () { go({ action: 'home', x: $('aeX').value, y: $('aeY').value }, this); });
    $('aeHomeClear').addEventListener('click', function () { go({ action: 'home_clear' }, this); });
    modalCard.querySelectorAll('[data-cardel]').forEach(function (b) {
      b.addEventListener('click', function () { if (confirm('Ștergi mașina? Nu se returnează bani.')) go({ action: 'car_delete', car: b.getAttribute('data-cardel') }, b); });
    });
    $('mCancel').addEventListener('click', hideModal);
  }
  function removeResident(r) {
    if (!confirm('Scoți pe ' + r.u + ' din oraș?')) return;
    postForm('/admin/resident_delete.php', { id: r.id }).then(function (d) {
      if (!d.ok) throw new Error();
      closeResidentCard(); toast(r.u + ' a fost scos din oraș'); fetchResidents();
    }).catch(function () { toast('Nu s-a putut. Încearcă din nou.'); });
  }

  // --- joburi ---
  function jobInfo(k) { return prices && prices.jobs && prices.jobs[k] ? prices.jobs[k] : { title: k, salary: 0, icon: '💼' }; }
  function jobText(r) {
    if (!r.jk) return '🪑 șomer';
    const j = jobInfo(r.jk);
    return j.icon + ' ' + j.title.toLowerCase();
  }
  // numele de firme (Lidl, Kaufland...) raman cu majuscula
  function lowerFirst(t) { return /^(Lidl|Kaufland|Penny|Carrefour|AuNau-movio)\b/.test(t) ? t : t.charAt(0).toLowerCase() + t.slice(1); }
  function workplaceLabel(w) { return w.n + ' (' + w.x + ',' + w.y + ')'; }
  // Locul de munca de pe un patratel: magazinul de acolo, cladirea speciala care il acopera, sau
  // campul (campurile sunt impartite in patrate de 4x4, fiecare cu fermierii lui).
  function workplaceAt(x, y) {
    if (!inb(x, y)) return null;
    const i = idx(x, y);
    if (spec[i] >= 0) {
      const sp = specials[spec[i]];
      return workplaces.find(function (w) { return w.k === sp.t && w.x === sp.x && w.y === sp.y; }) || null;
    }
    if (zone[i] === 2 && level[i]) return workplaces.find(function (w) { return w.k === 'shop' && w.x === x && w.y === y; }) || null;
    if (zone[i] === 3) {
      return workplaces.find(function (w) { return w.k === 'field' && Math.floor(w.x / 4) === Math.floor(x / 4) && Math.floor(w.y / 4) === Math.floor(y / 4); }) || null;
    }
    return null;
  }
  function workplaceLine(w) {
    const j = jobInfo(w.k);
    return '💼 ' + j.title + ' · ' + fmtLei(j.salary) + '/zi · ' + (w.sl - w.wk > 0 ? (w.sl - w.wk) + ' din ' + w.sl + ' locuri libere' : 'toate cele ' + w.sl + ' locuri ocupate');
  }

  function openWorkplaceCard(w) {
    openCard = { type: 'workplace', id: w.id };
    const j = jobInfo(w.k);
    const workers = residents.filter(function (r) { return r.w === w.id; });
    const mine = myInfo && myInfo.job && myInfo.job.id === w.id;
    const free = w.sl - w.wk;
    const canTake = !IS_ADMIN && meId !== null && myInfo && !mine && free > 0;
    cardEl.innerHTML = '<button class="rc-close" aria-label="Închide">✕</button>' +
      '<h3></h3><p>' + j.icon + ' ' + escapeHtml(j.title) + ' · <b>' + fmtLei(j.salary) + '</b> pe zi</p>' +
      '<p>' + (free > 0 ? '🟢 ' + free + ' din ' + w.sl + ' locuri libere' : '🔴 toate cele ' + w.sl + ' locuri sunt ocupate') + '</p>' +
      (workers.length ? '<div class="rc-section">Lucrează aici</div><div class="rc-list">' + workers.map(function (r) {
        return '<button class="rc-row" data-res="' + r.id + '"><span>' + avatarHtml(r) + ' ' + escapeHtml(r.u) + (r.id === meId ? ' (tu)' : '') + '</span><small>' + (r.on ? '🟢 online' : '') + '</small></button>';
      }).join('') + '</div>' : '<p>Niciun locuitor nu lucrează încă aici.</p>') +
      (mine ? '<p><b>Aici lucrezi tu.</b></p>' : '') +
      '<div class="rc-actions">' + (w.k === 'dealership' && !IS_ADMIN && meId !== null && myInfo ? '<button class="btn-primary" data-cars="1">🚗 Cumpără o mașină nouă</button>' : '') +
      (w.k === 'usedlot' && !IS_ADMIN && meId !== null && myInfo ? '<button class="btn-primary" data-used="1">🅿️ Mașini second-hand (' + usedCars.length + ')</button>' : '') +
      (canTake ? '<button class="btn-primary" data-take="' + w.id + '">💼 Lucrează aici</button>' : '') + '</div>';
    cardEl.querySelector('h3').textContent = workplaceLabel(w);
    cardEl.hidden = false;
    cardEl.querySelector('.rc-close').addEventListener('click', closeResidentCard);
    cardEl.querySelectorAll('[data-res]').forEach(function (b) {
      b.addEventListener('click', function () { const r = residentById(+b.getAttribute('data-res')); if (r) openResidentCard(r); });
    });
    const tb = cardEl.querySelector('[data-take]');
    if (tb) tb.addEventListener('click', function () { takeJob(w, tb); });
    const cb = cardEl.querySelector('[data-cars]');
    if (cb) cb.addEventListener('click', openCarShop);
    const ub = cardEl.querySelector('[data-used]');
    if (ub) ub.addEventListener('click', openUsedLot);
  }

  function fmtAge(days) {
    if (days < 30) return days + (days === 1 ? ' zi' : ' zile');
    const y = Math.floor(days / 365), mo = Math.floor((days % 365) / 30);
    if (!y) return mo + (mo === 1 ? ' lună' : ' luni');
    return y + (y === 1 ? ' an' : ' ani') + (mo ? ' și ' + mo + (mo === 1 ? ' lună' : ' luni') : '');
  }
  function carStats(v) {
    return v.ow + (v.ow === 1 ? ' proprietar' : ' proprietari') + ' · ' + fmtAge(v.age) + ' · ' + v.km.toLocaleString('ro-RO') + ' km';
  }
  function openUsedLot() {
    if (!myInfo) return;
    const mine = myInfo.vehicles || [];
    const draw = function () {
      showModal('used', '<div class="logo">🅿️</div><h1>Parc auto</h1>' +
        '<p>Ai <b>' + fmtLei(myInfo.balance) + '</b> · mașini: ' + mine.length + '/' + prices.maxCars + '</p>' +
        '<div class="used-list">' + (usedCars.length ? usedCars.map(function (v) {
          const own = v.o === meId, short = myInfo.balance < v.l, full = mine.length >= prices.maxCars;
          return '<div class="used-row"><i class="car-dot" style="background:' + v.c + '"></i><div class="used-info"><b>' + escapeHtml(carName(v)) + '</b><small>' + escapeHtml(carStats(v)) + '</small><small>' +
            (v.s ? 'vândut de ' + escapeHtml(v.s) : 'din stocul parcului') + ' · valoare ' + fmtLei(v.v) + '</small></div>' +
            '<button class="fr-btn is-yes" data-buyused="' + v.id + '"' + (own || short || full ? ' disabled title="' + (own ? 'E mașina ta' : full ? 'Ai deja ' + prices.maxCars + ' mașini' : 'Îți mai trebuie ' + fmtLei(v.l - myInfo.balance)) + '"' : '') + '>' + fmtLei(v.l) + '</button></div>';
        }).join('') : '<p>Nicio mașină la vânzare acum.</p>') + '</div>' +
        '<div class="modal-actions"><button class="btn-secondary" id="mCancel">Închide</button></div>');
      modalCard.querySelectorAll('[data-buyused]').forEach(function (b) {
        b.addEventListener('click', function () {
          b.disabled = true;
          postForm('/api/vehicles.php', { action: 'buyused', id: b.getAttribute('data-buyused') }).then(function (d) {
            if (!d.ok) throw new Error(d.error || 'Nu s-a putut.');
            myInfo.vehicles = d.vehicles; myInfo.balance = d.balance;
            usedCars = usedCars.filter(function (u) { return u.id !== +b.getAttribute('data-buyused'); });
            hideModal(); toast(d.message); fetchResidents();
          }).catch(function (err) { toast(err.message); fetchResidents().then(function () { if (modalKind === 'used') draw(); }); });
        });
      });
      document.getElementById('mCancel').addEventListener('click', hideModal);
    };
    draw();
  }

  // --- masini personale: magazinul de la dealership si vanzarea ---
  function carName(v) {
    if (v && v.n) return v.n;
    const m = v && v.m ? v.m : v;
    return prices && prices.cars && prices.cars[m] ? prices.cars[m].name : m;
  }
  function openCarShop() {
    if (!prices || !prices.brands || !myInfo) return;
    const mine = myInfo.vehicles || [], colors = prices.colors;
    let brand = null, body = null, color = colors[0].c;
    const extraOf = function (c) { return colors.find(function (q) { return q.c === c; }).x; };
    const priceNow = function () { return brand && body ? prices.brands[brand].b[body] + extraOf(color) : 0; };
    const brandBtn = function (k) { return '<button class="brand-opt' + (brand === k ? ' is-on' : '') + '" data-brand="' + k + '">' + escapeHtml(prices.brands[k].n) + '</button>'; };
    const html = function () {
      const keys = Object.keys(prices.brands), cars = keys.filter(function (k) { return prices.brands[k].t === 'car'; }), motos = keys.filter(function (k) { return prices.brands[k].t === 'moto'; });
      const total = priceNow();
      return '<div class="logo">🚗</div><h1>Dealership auto</h1>' +
        '<p>Ai <b>' + fmtLei(myInfo.balance) + '</b> · vehicule: ' + mine.length + '/' + prices.maxCars + '</p>' +
        '<div class="shop-body">' +
        '<div class="rc-section">1 · Marca</div><div class="brand-grid">' + cars.map(brandBtn).join('') + '</div>' +
        '<div class="rc-section">Motociclete</div><div class="brand-grid">' + motos.map(brandBtn).join('') + '</div>' +
        (brand && prices.brands[brand].t === 'car' ? '<div class="rc-section">2 · Caroseria</div><div class="car-grid">' + Object.keys(prices.brands[brand].b).map(function (k) {
          const price = prices.brands[brand].b[k];
          return '<button class="car-opt' + (body === k ? ' is-on' : '') + '" data-body="' + k + '"><span>' + prices.cars[k].icon + '</span><b>' + escapeHtml(prices.cars[k].name) + '</b><small>de la ' + fmtLei(price) + '</small></button>';
        }).join('') + '</div>' : '') +
        (brand && body ? '<div class="rc-section">' + (prices.brands[brand].t === 'car' ? '3' : '2') + ' · Culoarea</div><div class="car-colors">' + colors.map(function (c) {
          return '<button class="car-col' + (c.c === color ? ' is-on' : '') + '" data-color="' + c.c + '" style="background:' + c.c + '" title="' + c.n + (c.x ? ' · +' + fmtLei(c.x) : ' · fără supliment') + '" aria-label="' + c.n + '"></button>';
        }).join('') + '</div><p class="car-sum">' + escapeHtml(colors.find(function (c) { return c.c === color; }).n) + (extraOf(color) ? ' · supliment ' + fmtLei(extraOf(color)) : ' · fără supliment') + '</p>' : '') +
        '</div>' +
        '<div class="modal-actions"><button class="btn-secondary" id="mCancel">Închide</button><button class="btn-primary" id="mBuy"' + (!total || myInfo.balance < total || mine.length >= prices.maxCars ? ' disabled' : '') + '>Cumpără' + (total ? ' · ' + fmtLei(total) : '') + '</button></div>';
    };
    const draw = function () {
      const keep = modalCard.querySelector('.shop-body'), top = keep ? keep.scrollTop : 0;
      showModal('cars', html());
      const sb = modalCard.querySelector('.shop-body'); if (sb) sb.scrollTop = top;
      modalCard.querySelectorAll('[data-brand]').forEach(function (b) { b.addEventListener('click', function () {
        brand = b.getAttribute('data-brand');
        const bodies = Object.keys(prices.brands[brand].b);
        body = bodies.indexOf(body) >= 0 ? body : (bodies.length === 1 ? bodies[0] : null);
        draw();
      }); });
      modalCard.querySelectorAll('[data-body]').forEach(function (b) { b.addEventListener('click', function () { body = b.getAttribute('data-body'); draw(); }); });
      modalCard.querySelectorAll('[data-color]').forEach(function (b) { b.addEventListener('click', function () { color = b.getAttribute('data-color'); draw(); }); });
      document.getElementById('mCancel').addEventListener('click', hideModal);
      document.getElementById('mBuy').addEventListener('click', function () {
        this.disabled = true;
        postForm('/api/vehicles.php', { action: 'buy', brand: brand, model: body, color: color }).then(function (d) {
          if (!d.ok) throw new Error(d.error || 'Nu s-a putut.');
          myInfo.vehicles = d.vehicles; myInfo.balance = d.balance;
          hideModal(); toast(d.message); fetchResidents();
        }).catch(function (err) { toast(err.message); draw(); });
      });
    };
    draw();
  }
  function sellCar(id) {
    const v = (myInfo.vehicles || []).find(function (q) { return q.id === id; });
    if (!v || !confirm('Vinzi ' + carName(v) + ' la dealer cu ' + fmtLei(Math.floor(v.v * prices.carResale / 100)) + ' (' + prices.carResale + '% din valoarea de acum, ' + fmtLei(v.v) + ')? Dacă o pui la vânzare în parcul auto poți cere mai mult.')) return;
    carAction({ action: 'sell', id: id });
  }
  function listCar(id) {
    const v = (myInfo.vehicles || []).find(function (q) { return q.id === id; });
    if (!v) return;
    const ans = prompt('Cu cât scoți ' + carName(v) + ' la vânzare în parcul auto? (valoare acum: ' + v.v + ' LEI)', v.v);
    if (ans === null) return;
    carAction({ action: 'list', id: id, price: Math.round(+String(ans).replace(/[^0-9]/g, '')) || 0 });
  }
  function carAction(fields) {
    postForm('/api/vehicles.php', fields).then(function (d) {
      if (!d.ok) throw new Error(d.error || 'Nu s-a putut.');
      myInfo.vehicles = d.vehicles; myInfo.balance = d.balance;
      toast(d.message); fetchResidents();
    }).catch(function (err) { toast(err.message); });
  }

  function openJobList() {
    openCard = { type: 'jobs' };
    const current = myInfo && myInfo.job ? myInfo.job.id : null;
    const free = workplaces.filter(function (w) { return w.wk < w.sl && w.id !== current; })
      .sort(function (a, b) { return jobInfo(b.k).salary - jobInfo(a.k).salary || a.n.localeCompare(b.n, 'ro'); });
    cardEl.innerHTML = '<button class="rc-close" aria-label="Închide">✕</button><h3>💼 Locuri de muncă libere</h3>' +
      '<p>' + (myInfo && myInfo.job ? 'Acum: ' + escapeHtml(myInfo.job.title) + ' · ' + fmtLei(myInfo.job.salary) + '/zi' : 'Acum ești șomer · ' + fmtLei(prices ? prices.unemployed : 0) + '/zi') + '</p>' +
      (free.length ? '<div class="rc-list">' + free.map(function (w) {
        const j = jobInfo(w.k);
        return '<div class="rc-row is-static"><span>' + j.icon + ' <b>' + escapeHtml(j.title) + '</b> · ' + escapeHtml(workplaceLabel(w)) + '<br><small>' + fmtLei(j.salary) + '/zi · ' + (w.sl - w.wk) + ' libere</small></span>' +
          '<span class="rc-row-btns"><button class="btn-secondary" data-show="' + w.id + '" title="Arată pe hartă">📍</button><button class="btn-primary" data-take="' + w.id + '">Ia jobul</button></span></div>';
      }).join('') + '</div>' : '<p>Nu e niciun loc liber acum. Când orașul crește, apar locuri noi.</p>');
    cardEl.hidden = false;
    cardEl.querySelector('.rc-close').addEventListener('click', closeResidentCard);
    cardEl.querySelectorAll('[data-show]').forEach(function (b) {
      b.addEventListener('click', function () { const w = workplaces.find(function (q) { return q.id === +b.getAttribute('data-show'); }); if (w) flyToTile(w.x, w.y); });
    });
    cardEl.querySelectorAll('[data-take]').forEach(function (b) {
      b.addEventListener('click', function () { const w = workplaces.find(function (q) { return q.id === +b.getAttribute('data-take'); }); if (w) takeJob(w, b); });
    });
  }

  function takeJob(w, btn) {
    const j = jobInfo(w.k);
    if (!confirm('Te angajezi ca ' + j.title.toLowerCase() + ' la ' + lowerFirst(workplaceLabel(w)) + ', cu ' + fmtLei(j.salary) + ' pe zi?' + (myInfo && myInfo.job ? ' Îți lași jobul de acum.' : ''))) return;
    btn.disabled = true;
    postForm('/api/job.php', { id: w.id })
      .then(function (d) {
        if (!d.ok) throw new Error(d.error || 'Nu s-a putut.');
        toast(d.message);
        myInfo = d.meInfo;
        openCard = null;
        return fetchResidents().then(function () { const me = meResident(); if (me) openResidentCard(me); });
      })
      .catch(function (err) { toast(err.message); btn.disabled = false; });
  }

  // --- prieteni: lista, cererile, butoanele de pe carduri ---
  let social = null, friendsView = 'friends';   // { friends: [id], incoming: [id], outgoing: [id], max } - doar cand esti intrat in cont
  const friendsBtn = document.getElementById('btnFriends'), friendsStar = document.getElementById('friendsStar');
  const friendsPanel = document.getElementById('friendsPanel'), friendsTabs = friendsPanel.querySelectorAll('.fr-tab'), friendsList = document.getElementById('friendsList');
  function friendButtons(r) {
    if (!social || IS_ADMIN) return '';
    if (social.friends.indexOf(r.id) >= 0) return '<button class="btn-secondary" data-act="fr-remove">💔 Elimină prieten</button>';
    if (social.outgoing.indexOf(r.id) >= 0) return '<button class="btn-secondary" data-act="fr-cancel">⏳ Cerere trimisă · anulează</button>';
    if (social.incoming.indexOf(r.id) >= 0) return '<button class="btn-primary" data-act="fr-accept">✅ Acceptă prietenia</button><button class="btn-secondary" data-act="fr-decline">Refuză</button>';
    const full = social.friends.length >= social.max;
    return '<button class="btn-primary" data-act="fr-request"' + (full ? ' disabled title="Ai deja ' + social.max + ' prieteni"' : '') + '>➕ Adaugă prieten</button>';
  }
  function friendAction(action, r, btn) {
    if (action === 'remove' && !confirm('Elimini din prieteni: ' + r.u + '?')) return;
    if (btn) btn.disabled = true;
    postForm('/api/friends.php', { action: action, id: r.id })
      .then(function (d) {
        if (!d.ok) throw new Error(d.error || 'Nu s-a putut.');
        social = d.social;
        toast(d.message);
        updateFriendsUi();
        refreshOpenCard();
      })
      .catch(function (err) { toast(err.message); if (btn) btn.disabled = false; });
  }
  // --- vehiculele mele (iconita de langa fluturas) ---
  function openMyVehicles() {
    if (!myInfo || !prices) return;
    openCard = { type: 'vehicles' };
    const cars = myInfo.vehicles || [];
    cardEl.innerHTML = '<button class="rc-close" aria-label="Închide">✕</button><div class="ps-head">🚗</div><h3>Vehiculele mele</h3>' +
      '<p>' + cars.length + '/' + prices.maxCars + ' vehicule · ai ' + fmtLei(myInfo.balance) + '</p>' +
      (cars.length ? '<div class="rc-list">' + cars.map(function (v) {
        return '<div class="car-row"><div class="car-info"><b><i class="car-dot" style="background:' + v.c + '"></i> ' + escapeHtml(carName(v)) + '</b><small>' + escapeHtml(carStats(v)) + '</small><small>valoare ' + fmtLei(v.v) + (v.l !== null ? ' · 📌 la vânzare cu ' + fmtLei(v.l) : '') + '</small></div>' +
          '<div class="fr-btns">' + (v.l !== null ? '<button class="fr-btn" data-unlist="' + v.id + '">Retrage</button>' : '<button class="fr-btn" data-list="' + v.id + '">Pune la vânzare</button>') + '<button class="fr-btn" data-sell="' + v.id + '">Vinde la dealer</button></div></div>';
      }).join('') + '</div>' : '<p class="fr-empty">Nu ai niciun vehicul. Cumpără unul de la un dealership sau din parcul auto.</p>');
    cardEl.hidden = false;
    cardEl.querySelector('.rc-close').addEventListener('click', closeResidentCard);
    cardEl.querySelectorAll('[data-sell]').forEach(function (b) { b.addEventListener('click', function () { sellCar(+b.getAttribute('data-sell')); }); });
    cardEl.querySelectorAll('[data-list]').forEach(function (b) { b.addEventListener('click', function () { listCar(+b.getAttribute('data-list')); }); });
    cardEl.querySelectorAll('[data-unlist]').forEach(function (b) { b.addEventListener('click', function () { carAction({ action: 'unlist', id: +b.getAttribute('data-unlist') }); }); });
  }
  const vehiclesBtn = document.getElementById('btnVehicles');
  vehiclesBtn.addEventListener('click', function () { if (openCard && openCard.type === 'vehicles') closeResidentCard(); else openMyVehicles(); });
  const payslipBtn = document.getElementById('btnPayslip');
  payslipBtn.addEventListener('click', function () { if (openCard && openCard.type === 'payslip') closeResidentCard(); else openPayslip(); });
  function updateFriendsUi() {
    payslipBtn.hidden = !(myInfo && myInfo.payslip) || IS_ADMIN;
    vehiclesBtn.hidden = payslipBtn.hidden;
    const on = !!social && !IS_ADMIN;
    friendsBtn.hidden = !on;
    if (!on) { friendsPanel.hidden = true; return; }
    const n = social.incoming.length;
    friendsStar.hidden = !n;
    friendsBtn.title = 'Prieteni' + (n ? ' · ' + n + (n === 1 ? ' cerere nouă' : ' cereri noi') : '');
    friendsTabs[0].textContent = 'Prieteni (' + social.friends.length + '/' + social.max + ')';
    friendsTabs[1].textContent = 'Cereri' + (n ? ' (' + n + ')' : '');
    if (!friendsPanel.hidden) renderFriends();
  }
  function friendRow(id, buttons) {
    const r = residentById(id);
    if (!r) return '';
    const where = whereText(r);
    return '<div class="fr-row" data-id="' + id + '">' + avatarHtml(r) +
      '<div class="fr-name" data-fr="open" role="button" tabindex="0"><b>' + escapeHtml(r.u) + '</b><small>' + (r.on ? '🟢 online' : '⚪ offline') + (where ? ' · ' + escapeHtml(where.replace(/^\S+ /, '')) : '') + '</small></div>' +
      '<div class="fr-btns">' + buttons + '</div></div>';
  }
  function renderFriends() {
    const view = friendsView;
    friendsTabs.forEach(function (b) { const on = b.getAttribute('data-view') === view; b.classList.toggle('is-on', on); b.setAttribute('aria-pressed', on); });
    let html = '';
    if (view === 'friends') {
      html = social.friends.map(function (id) { return friendRow(id, '<button class="fr-btn" data-fr="remove">Elimină</button>'); }).join('');
      if (!html) html = '<p class="fr-empty">Încă n-ai prieteni. Dă click pe un locuitor de pe hartă și apoi pe „Adaugă prieten”.</p>';
      if (social.outgoing.length) html += '<p class="fr-note">⏳ ' + social.outgoing.length + (social.outgoing.length === 1 ? ' cerere trimisă așteaptă' : ' cereri trimise așteaptă') + ' răspuns.</p>';
    } else {
      html = social.incoming.map(function (id) { return friendRow(id, '<button class="fr-btn is-yes" data-fr="accept">Acceptă</button><button class="fr-btn" data-fr="decline">Refuză</button>'); }).join('');
      if (!html) html = '<p class="fr-empty">Nicio cerere de prietenie nouă.</p>';
    }
    friendsList.innerHTML = html;
    friendsList.querySelectorAll('[data-fr]').forEach(function (b) {
      b.addEventListener('click', function () {
        const r = residentById(+b.closest('.fr-row').getAttribute('data-id'));
        if (!r) return;
        const act = b.getAttribute('data-fr');
        if (act === 'open') { flyTo(r); openResidentCard(r); }
        else friendAction(act, r, b);
      });
    });
  }
  function toggleFriendsPanel(show) {
    friendsPanel.hidden = !show;
    if (!show) return;
    if (social && social.incoming.length) friendsView = 'requests';
    updateFriendsUi();
  }
  friendsBtn.addEventListener('click', function () { toggleFriendsPanel(friendsPanel.hidden); });
  friendsTabs.forEach(function (b) { b.addEventListener('click', function () { friendsView = b.getAttribute('data-view'); renderFriends(); }); });
  document.getElementById('friendsClose').addEventListener('click', function () { toggleFriendsPanel(false); });

  // --- panoul de sus: cautare + contul meu ---
  const searchIn = document.getElementById('searchInput'), searchRes = document.getElementById('searchResults');
  const meChip = document.getElementById('meChip'), countEl = document.getElementById('peopleCount');
  let searchMatches = [], searchSel = 0;
  function norm(s) { return s.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, ''); }

  function updatePeopleUi() {
    const online = residents.filter(function (r) { return r.on; }).length;
    countEl.innerHTML = residents.length
      ? '🧑‍🤝‍🧑 ' + residents.length + (residents.length === 1 ? ' locuitor' : ' locuitori') + (online ? '<span class="dot"></span>' + online + ' online' : '')
      : (IS_ADMIN ? 'Încă nu s-a mutat nimeni în oraș.' : 'Încă nu s-a mutat nimeni. Fii primul!');
    if (IS_ADMIN) return;
    const me = meResident();
    meChip.hidden = !me;
    if (me) {
      meChip.innerHTML = avatarHtml(me) + '<span></span><b class="me-money"></b>';
      meChip.querySelector('span:not(.av)').textContent = me.u;
      meChip.querySelector('.me-money').textContent = myInfo ? fmtLei(myInfo.balance) : '';
      meChip.classList.toggle('is-debt', !!myInfo && myInfo.balance < 0);
    }
  }
  // Cautarea are doua moduri (butonul de langa lupa): 👤 locuitori, 📍 locatii (cladirile cu nume de pe harta:
  // magazine, spital, scoala, benzinarii... - nu casele, blocurile sau strazile).
  let searchGps = false;
  const searchModeBtn = document.getElementById('searchMode');
  function placeMatches(q) {
    const list = [];
    specials.forEach(function (sp) {
      if (!sp) return;
      const d = SPECIALS[sp.t];
      if (d.apts || d.homeKind) return;
      if (norm(d.name).indexOf(q) < 0) return;
      list.push({ place: true, sp: sp, d: d });
    });
    const c = { x: cam.x / T, y: cam.y / T };
    return list.sort(function (a, b) {
      return (norm(a.d.name).indexOf(q) === 0 ? 0 : 1) - (norm(b.d.name).indexOf(q) === 0 ? 0 : 1) ||
        Math.hypot(a.sp.x - c.x, a.sp.y - c.y) - Math.hypot(b.sp.x - c.x, b.sp.y - c.y);
    }).slice(0, 8);
  }
  searchModeBtn.addEventListener('click', function () {
    searchGps = !searchGps;
    searchModeBtn.textContent = searchGps ? '📍' : '👤';
    searchIn.placeholder = searchGps ? 'Caută o locație (ex. Lidl, spital)…' : 'Caută un locuitor…';
    searchSel = 0;
    searchIn.focus();
    refreshSearch();
  });
  searchModeBtn.addEventListener('mousedown', function (e) { e.preventDefault(); });
  function refreshSearch() {
    const q = norm(searchIn.value.trim());
    if (!q || document.activeElement !== searchIn) { searchRes.hidden = true; return; }
    if (searchGps) {
      searchMatches = placeMatches(q);
      searchSel = clamp(searchSel, 0, Math.max(0, searchMatches.length - 1));
      searchRes.innerHTML = '';
      if (!searchMatches.length) searchRes.innerHTML = '<div class="sr-empty">Nicio locație cu numele ăsta</div>';
      searchMatches.forEach(function (m, n) {
        const b = document.createElement('button');
        b.type = 'button';
        b.className = 'sr-item' + (n === searchSel ? ' is-sel' : '');
        b.innerHTML = '<span class="av" style="background:#e8d9bd">' + m.d.icon + '</span><span></span><small>(' + m.sp.x + ',' + m.sp.y + ')</small>';
        b.querySelector('span:not(.av)').textContent = m.d.name;
        b.addEventListener('mousedown', function (e) { e.preventDefault(); });
        b.addEventListener('click', function () { chooseResult(m); });
        searchRes.appendChild(b);
      });
      searchRes.hidden = false;
      return;
    }
    searchMatches = residents.filter(function (r) { return norm(r.u).indexOf(q) >= 0; })
      .sort(function (a, b) { return (norm(a.u).indexOf(q) === 0 ? 0 : 1) - (norm(b.u).indexOf(q) === 0 ? 0 : 1) || a.u.localeCompare(b.u, 'ro'); })
      .slice(0, 8);
    searchSel = clamp(searchSel, 0, Math.max(0, searchMatches.length - 1));
    searchRes.innerHTML = '';
    if (!searchMatches.length) {
      searchRes.innerHTML = '<div class="sr-empty">Niciun locuitor cu numele ăsta</div>';
    } else {
      searchMatches.forEach(function (r, n) {
        const b = document.createElement('button');
        b.type = 'button';
        b.className = 'sr-item' + (n === searchSel ? ' is-sel' : '');
        b.innerHTML = avatarHtml(r) + '<span></span><small>' + (r.x === null ? 'fără casă' : r.on ? '🟢 online' : '') + '</small>';
        b.querySelector('span:not(.av)').textContent = r.u;
        b.addEventListener('mousedown', function (e) { e.preventDefault(); });
        b.addEventListener('click', function () { chooseResult(r); });
        searchRes.appendChild(b);
      });
    }
    searchRes.hidden = false;
  }
  function chooseResult(r) {
    if (r.place) {
      searchIn.value = r.d.name;
      searchRes.hidden = true;
      searchIn.blur();
      const tx = r.sp.x + Math.floor((r.d.w - 1) / 2), ty = r.sp.y + Math.floor((r.d.h - 1) / 2);
      flyToTile(tx, ty);
      const w = workplaceAt(tx, ty);
      if (w) openWorkplaceCard(w);
      return;
    }
    searchIn.value = r.u;
    searchRes.hidden = true;
    searchIn.blur();
    flyTo(r);
    openResidentCard(r);
  }
  searchIn.addEventListener('input', function () { searchSel = 0; refreshSearch(); });
  searchIn.addEventListener('focus', refreshSearch);
  searchIn.addEventListener('blur', function () { setTimeout(function () { searchRes.hidden = true; }, 120); });
  searchIn.addEventListener('keydown', function (e) {
    if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      e.preventDefault();
      searchSel = clamp(searchSel + (e.key === 'ArrowDown' ? 1 : -1), 0, Math.max(0, searchMatches.length - 1));
      refreshSearch();
    } else if (e.key === 'Enter') {
      if (searchMatches[searchSel]) chooseResult(searchMatches[searchSel]);
    } else if (e.key === 'Escape') {
      searchIn.blur();
    }
  });
  meChip.addEventListener('click', function () { const me = meResident(); if (me) { flyTo(me); openResidentCard(me); } });

  // --- conturi: popup de bun venit, cont nou, login ---
  function showModal(kind, html) { modalKind = kind; modalCard.innerHTML = html; modal.hidden = false; }
  function hideModal() { modalKind = null; modal.hidden = true; }
  function byId(id) { return document.getElementById(id); }

  function openWelcome() {
    const noMap = serverVersion === 0;
    showModal('welcome',
      '<div class="logo">🏡🌳🛣️</div><h1>' + (noMap ? 'Bine ai venit!' : 'Bine ai venit în ' + escapeHtml(S.name) + '!') + '</h1>' +
      '<p>Un oraș comun, construit de primar. Te muți în chirie într-un apartament, primești 5.000 LEI de bun venit și un salariu în fiecare zi în care treci pe aici - strânge bani și cumpără-ți casa ta.</p>' +
      (noMap ? '<p><b>🚧 Orașul e încă în construcție.</b> Te poți înscrie de pe acum - te muți singur când apar primele apartamente.</p>' : '') +
      '<div class="modal-actions"><button class="btn-secondary" id="wLogin">🔑 Vino acasă</button><button class="btn-primary" id="wRegister">🏡 Mută-te în oraș</button></div>');
    byId('wLogin').addEventListener('click', function () { openLogin(''); });
    byId('wRegister').addEventListener('click', openRegister);
  }

  function emojiGrid(grid, nameIn, onPick) {
    EMOJIS.forEach(function (em) {
      const b = document.createElement('button');
      b.type = 'button';
      b.textContent = em || 'A';
      b.title = em ? '' : 'Inițiala numelui';
      if (!em) b.className = 'is-sel';
      b.addEventListener('click', function () {
        onPick(em);
        grid.querySelectorAll('button').forEach(function (x) { x.classList.toggle('is-sel', x === b); });
      });
      grid.appendChild(b);
    });
    nameIn.addEventListener('input', function () {
      const first = Array.from(nameIn.value.trim())[0];
      grid.firstChild.textContent = first ? first.toUpperCase() : 'A';
    });
  }

  function afterAuth(resident, msg) {
    meId = resident.id;
    hideModal();
    toast(msg);
    fetchResidents().then(function () {
      const me = meResident();
      if (me && me.x !== null) { flyTo(me); openResidentCard(me); }
      else if (serverVersion === 0) showUnderConstruction();
      else if (me) openResidentCard(me);
    });
  }

  function openRegister() {
    showModal('register',
      '<div class="logo">🏡</div><h1>Mută-te în oraș</h1><p>Alege-ți un nume - apare pe hartă, deasupra casei tale - și o parolă, ca să poți veni oricând acasă.</p>' +
      '<input id="rName" maxlength="24" placeholder="Numele contului" autocomplete="username">' +
      '<input id="rPass" type="password" maxlength="72" placeholder="Parola (minim 6 caractere)" autocomplete="new-password">' +
      '<input id="rPass2" type="password" maxlength="72" placeholder="Repetă parola" autocomplete="new-password">' +
      '<p class="modal-label">Alege-ți o iconiță</p><div class="emoji-grid" id="emojiGrid"></div>' +
      '<div class="modal-err" id="mErr"></div>' +
      '<div class="modal-actions"><button class="btn-secondary" id="mBack">Înapoi</button><button class="btn-primary" id="mGo">Mută-te</button></div>' +
      '<p class="modal-switch">Locuiești deja aici? <a href="#" id="mSwitch">Vino acasă</a></p>');
    const nameIn = byId('rName'), passIn = byId('rPass'), pass2In = byId('rPass2'), errEl = byId('mErr'), go = byId('mGo');
    let emoji = '';
    emojiGrid(byId('emojiGrid'), nameIn, function (em) { emoji = em; });
    nameIn.focus();
    function submit() {
      const name = nameIn.value.trim();
      if (name.length < 2) { errEl.textContent = 'Numele trebuie să aibă cel puțin 2 caractere.'; nameIn.focus(); return; }
      if (passIn.value.length < 6) { errEl.textContent = 'Parola trebuie să aibă cel puțin 6 caractere.'; passIn.focus(); return; }
      if (passIn.value !== pass2In.value) { errEl.textContent = 'Parolele nu sunt la fel.'; pass2In.focus(); return; }
      go.disabled = true; errEl.textContent = '';
      postForm('/api/register.php', { username: name, password: passIn.value, emoji: emoji })
        .then(function (d) {
          if (d.ok) { afterAuth(d.resident, 'Bun venit în oraș, ' + d.resident.u + '! 🏡'); return; }
          if (d.code === 'ip_limit') { openIpLimit(d); return; }
          errEl.textContent = d.error || 'Nu s-a putut face mutarea.';
        })
        .catch(function () { errEl.textContent = 'Nu s-a putut contacta serverul. Încearcă din nou.'; })
        .finally(function () { go.disabled = false; });
    }
    go.addEventListener('click', submit);
    [nameIn, passIn, pass2In].forEach(function (i) { i.addEventListener('keydown', function (e) { if (e.key === 'Enter') submit(); }); });
    byId('mBack').addEventListener('click', openWelcome);
    byId('mSwitch').addEventListener('click', function (e) { e.preventDefault(); openLogin(nameIn.value.trim()); });
  }

  function openIpLimit(d) {
    showModal('limit',
      '<div class="logo">🚫</div><h1>Nu mai poți muta pe nimeni</h1><p id="limitMsg"></p>' +
      (d.accounts && d.accounts.length ? '<p class="modal-label">Locuitorii mutați de pe conexiunea ta:</p><div class="acc-list" id="accList"></div>' : '') +
      '<div class="modal-actions"><button class="btn-secondary" id="mBack">Înapoi</button><button class="btn-primary" id="mLogin">🔑 Vino acasă</button></div>');
    byId('limitMsg').textContent = d.error;
    const list = byId('accList');
    (d.accounts || []).forEach(function (name) {
      const b = document.createElement('button');
      b.type = 'button';
      b.textContent = name;
      b.title = 'Vino acasă ca ' + name;
      b.addEventListener('click', function () { openLogin(name); });
      list.appendChild(b);
    });
    byId('mBack').addEventListener('click', openWelcome);
    byId('mLogin').addEventListener('click', function () { openLogin(''); });
  }

  function openLogin(prefill) {
    showModal('login',
      '<div class="logo">🔑</div><h1>Vino acasă</h1><p>Bine ai revenit! Scrie-ți numele și parola ca să deschizi ușa.</p>' +
      '<input id="lName" maxlength="24" placeholder="Numele contului" autocomplete="username">' +
      '<input id="lPass" type="password" maxlength="72" placeholder="Parola" autocomplete="current-password">' +
      '<div class="modal-err" id="mErr"></div>' +
      '<div class="modal-actions"><button class="btn-secondary" id="mBack">Înapoi</button><button class="btn-primary" id="mGo">Deschide ușa</button></div>' +
      '<p class="modal-switch">Încă nu locuiești aici? <a href="#" id="mSwitch">Mută-te în oraș</a></p>');
    const nameIn = byId('lName'), passIn = byId('lPass'), errEl = byId('mErr'), go = byId('mGo');
    nameIn.value = prefill || '';
    (prefill ? passIn : nameIn).focus();
    function submit() {
      if (!nameIn.value.trim() || !passIn.value) { errEl.textContent = 'Completează numele și parola.'; return; }
      go.disabled = true; errEl.textContent = '';
      postForm('/api/login.php', { username: nameIn.value.trim(), password: passIn.value })
        .then(function (d) {
          if (d.ok) { afterAuth(d.resident, 'Bine ai revenit, ' + d.resident.u + '! 👋'); return; }
          errEl.textContent = d.error || 'Ușa nu s-a deschis.';
          passIn.select();
        })
        .catch(function () { errEl.textContent = 'Nu s-a putut contacta serverul. Încearcă din nou.'; })
        .finally(function () { go.disabled = false; });
    }
    go.addEventListener('click', submit);
    [nameIn, passIn].forEach(function (i) { i.addEventListener('keydown', function (e) { if (e.key === 'Enter') submit(); }); });
    byId('mBack').addEventListener('click', openWelcome);
    byId('mSwitch').addEventListener('click', function (e) { e.preventDefault(); openRegister(); });
  }

  // ================= BOOT =================
  computeGrass();
  resize();
  window.addEventListener('resize', resize);
  renderToolbar();
  markAll();
  const stateLoaded = fetch('/api/state.php', { credentials: 'same-origin' })
    .then(function (r) { return r.json(); })
    .then(function (res) {
      if (res.data && load(res.data)) {
        serverVersion = res.version;
        startWorld();
        centerOnTown();
        return;
      }
      if (!IS_ADMIN) return;
      const old = readOldLocalSave();
      if (old && load(old)) {
        startWorld(); centerOnTown();
        save(false);
        toast('Am urcat pe server orașul salvat în acest browser ✓');
      } else {
        openNewGameModal(false);
      }
    })
    .catch(function () { toast('Nu s-a putut încărca orașul. Reîncarcă pagina.'); });
  // Vizitatorii fara cont vad intai popup-ul de bun venit (Mută-te în oraș / Vino acasă).
  Promise.all([stateLoaded, fetchResidents()]).then(function () {
    if (IS_ADMIN) return;
    if (meId === null) openWelcome();
    else if (serverVersion === 0) showUnderConstruction();
  });

  let last = performance.now(), hudAcc = 0;
  function frame(now) {
    const dt = Math.min(0.1, (now - last) / 1000);
    last = now;
    if (modal.hidden) { update(dt); keyPan(dt); } else updateWeatherFx(dt);
    stepCamAnim(now);
    processDirty();
    draw(now);
    hudAcc += dt;
    if (hudAcc > 0.25) { hudAcc = 0; updateHud(); }
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
})();
