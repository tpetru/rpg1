<?php
// Formateaza o suma cu separator de mii (".") - echivalentul MoneyStr() din gamemode
function ucp_money($amount) {
    return number_format((float)$amount, 0, '.', '.');
}

// Starea unui document de vehicul (asigurare/kit medical/extinctor/ITP), coloana DATE.
// Oglindeste VehicleDoc_IsValid()/VehicleDoc_Status() din bare.pwn: valid pana la finalul zilei calendaristice.
function ucp_doc_status($dateStr) {
    if (empty($dateStr) || $dateStr === '0000-00-00') return ['label' => 'Expired', 'ok' => false, 'days' => null];

    $expDay   = strtotime(date('Y-m-d', strtotime($dateStr)));
    $todayDay = strtotime(date('Y-m-d'));

    if ($expDay < $todayDay) return ['label' => 'Expired', 'ok' => false, 'days' => null];

    $days = (int)round(($expDay - $todayDay) / 86400) + 1;
    return ['label' => $days . ' days', 'ok' => true, 'days' => $days];
}

// Pill color tier for a document close to expiring: bad (expired) / warn (<=2 days) / good (<4 days) / ok (plenty of time)
function ucp_doc_tier($status) {
    if (!$status['ok']) return 'bad';
    if ($status['days'] <= 2) return 'warn';
    if ($status['days'] < 4) return 'good';
    return 'ok';
}

// Status of a driving license (driving_lic_a/b/c/d_exp) - same mechanism as vehicle documents
function ucp_license_status($dateStr) {
    if (empty($dateStr) || $dateStr === '0000-00-00') return ['label' => 'Not held', 'ok' => false];
    return ucp_doc_status($dateStr);
}

function ucp_escape($str) {
    return htmlspecialchars((string)$str, ENT_QUOTES, 'UTF-8');
}

// Faction name by ID (1-8), read from `factions` table in database
function ucp_faction_name($id) {
    static $cache = [];
    $id = (int)$id;

    if (isset($cache[$id])) {
        return $cache[$id];
    }

    try {
        require_once __DIR__ . '/db.php';
        if (isset($GLOBALS['mysqli']) && $GLOBALS['mysqli']->ping()) {
            $res = $GLOBALS['mysqli']->query("SELECT `name` FROM `factions` WHERE `id` = $id LIMIT 1");
            if ($res && $row = $res->fetch_assoc()) {
                $cache[$id] = $row['name'];
                return $row['name'];
            }
        }
    } catch (Exception $e) {
        // Fallback to defaults if DB is unavailable
    }

    $defaults = [
        1 => 'Romanian Police',
        2 => 'Romanian Vehicle Registry',
        3 => 'SMURD',
        4 => 'European Mafia',
        5 => 'American Mafia',
        6 => 'African Mafia',
        7 => 'Asian Mafia',
        8 => 'News Reporters',
    ];
    $cache[$id] = $defaults[$id] ?? 'No faction';
    return $cache[$id];
}

// Faction color by ID (1-8), mirroring FactionColors[] from bare.pwn (0xRRGGBBAA, alpha dropped for CSS)
function ucp_faction_color($id) {
    $colors = [
        1 => '#4488FF',
        2 => '#36D1C2',
        3 => '#FF5500',
        4 => '#3366CC',
        5 => '#AA44AA',
        6 => '#44AA44',
        7 => '#FFCC00',
        8 => '#85648C',
    ];
    return $colors[(int)$id] ?? '#FFFFFF';
}

// GTA:SA vehicle model names (IDs 400-611) - see https://open.mp/docs/scripting/resources/vehicleid
$GLOBALS['vehicleModelNames'] = [
    400=>'Landstalker',401=>'Bravura',402=>'Buffalo',403=>'Linerunner',404=>'Perennial',405=>'Sentinel',
    406=>'Dumper',407=>'Firetruck',408=>'Trashmaster',409=>'Stretch',410=>'Manana',411=>'Infernus',
    412=>'Voodoo',413=>'Pony',414=>'Mule',415=>'Cheetah',416=>'Ambulance',417=>'Leviathan',
    418=>'Moonbeam',419=>'Esperanto',420=>'Taxi',421=>'Washington',422=>'Bobcat',423=>'Mr. Whoopee',
    424=>'BF Injection',425=>'Hunter',426=>'Premier',427=>'Enforcer',428=>'Securicar',429=>'Banshee',
    430=>'Predator',431=>'Bus',432=>'Rhino',433=>'Barracks',434=>'Hotknife',435=>'Trailer',
    436=>'Previon',437=>'Coach',438=>'Cabbie',439=>'Stallion',440=>'Rumpo',441=>'RC Bandit',
    442=>'Romero',443=>'Packer',444=>'Monster',445=>'Admiral',446=>'Squalo',447=>'Seasparrow',
    448=>'Pizzaboy',449=>'Tram',450=>'Trailer 2',451=>'Turismo',452=>'Speeder',453=>'Reefer',
    454=>'Tropic',455=>'Flatbed',456=>'Yankee',457=>'Caddy',458=>'Solair',459=>'RC Van',
    460=>'Skimmer',461=>'PCJ-600',462=>'Faggio',463=>'Freeway',464=>'RC Baron',465=>'RC Raider',
    466=>'Glendale',467=>'Oceanic',468=>'Sanchez',469=>'Sparrow',470=>'Patriot',471=>'Quad',
    472=>'Coastguard',473=>'Dinghy',474=>'Hermes',475=>'Sabre',476=>'Rustler',477=>'ZR-350',
    478=>'Walton',479=>'Regina',480=>'Comet',481=>'BMX',482=>'Burrito',483=>'Camper',
    484=>'Marquis',485=>'Baggage',486=>'Dozer',487=>'Maverick',488=>'News Chopper',489=>'Rancher',
    490=>'FBI Rancher',491=>'Virgo',492=>'Greenwood',493=>'Jetmax',494=>'Hotring Racer A',495=>'Sandking',
    496=>'Blista Compact',497=>'Police Maverick',498=>'Boxville',499=>'Benson',500=>'Mesa',501=>'RC Goblin',
    502=>'Hotring Racer B',503=>'Hotring Racer C',504=>'Bloodring Banger',505=>'Rancher Lure',506=>'Super GT',507=>'Elegant',
    508=>'Journey',509=>'Bike',510=>'Mountain Bike',511=>'Beagle',512=>'Cropduster',513=>'Stuntplane',
    514=>'Tanker',515=>'Roadtrain',516=>'Nebula',517=>'Majestic',518=>'Buccaneer',519=>'Shamal',
    520=>'Hydra',521=>'FCR-900',522=>'NRG-500',523=>'HPV1000',524=>'Cement Truck',525=>'Tow Truck',
    526=>'Fortune',527=>'Cadrona',528=>'FBI Truck',529=>'Willard',530=>'Forklift',531=>'Tractor',
    532=>'Combine Harvester',533=>'Feltzer',534=>'Remington',535=>'Slamvan',536=>'Blade',537=>'Freight',
    538=>'Brown Streak',539=>'Vortex',540=>'Vincent',541=>'Bullet',542=>'Clover',543=>'Sadler',
    544=>'Firetruck LA',545=>'Hustler',546=>'Intruder',547=>'Primo',548=>'Cargobob',549=>'Tampa',
    550=>'Sunrise',551=>'Merit',552=>'Utility Van',553=>'Nevada',554=>'Yosemite',555=>'Windsor',
    556=>'Monster A',557=>'Monster B',558=>'Uranus',559=>'Jester',560=>'Sultan',561=>'Stratum',
    562=>'Elegy',563=>'Raindance',564=>'RC Tiger',565=>'Flash',566=>'Tahoma',567=>'Savanna',
    568=>'Bandito',569=>'Freight Trailer',570=>'Streak Trailer',571=>'Kart',572=>'Mower',573=>'Dune',
    574=>'Sweeper',575=>'Broadway',576=>'Tornado',577=>'AT-400',578=>'DFT-30',579=>'Huntley',
    580=>'Stafford',581=>'BF-400',582=>'Newsvan',583=>'Tug',584=>'Petrol Trailer',585=>'Emperor',
    586=>'Wayfarer',587=>'Euros',588=>'Hotdog',589=>'Club',590=>'Freight Trailer',591=>'Trailer 3',
    592=>'Andromada',593=>'Dodo',594=>'RC Cam',595=>'Launch',596=>'Police Car (LSPD)',597=>'Police Car (SFPD)',
    598=>'Police Car (LVPD)',599=>'Police Ranger',600=>'Picador',601=>'S.W.A.T.',602=>'Alpha',603=>'Phoenix',
    604=>'Glendale (damaged)',605=>'Sadler (damaged)',606=>'Baggage Trailer',607=>'Baggage Trailer',608=>'Stair Trailer',
    609=>'Boxville',610=>'Farm Trailer',611=>'Utility Trailer',
];
function ucp_vehicle_name($modelId) {
    return $GLOBALS['vehicleModelNames'][(int)$modelId] ?? ('Model #' . (int)$modelId);
}
function ucp_vehicle_image($modelId) {
    return 'https://assets.open.mp/assets/images/vehiclePictures/Vehicle_' . (int)$modelId . '.jpg';
}
