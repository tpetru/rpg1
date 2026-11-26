<?php
// Cautare YouTube pentru /music, fara cheie API obligatorie.
// Ordinea surselor: cache -> YouTube (innertube JSON) -> YouTube (pagina HTML)
//                   -> YouTube Data API v3 (doar daca exista o cheie) -> Piped / Invidious.
// Cheie optionala: variabila de mediu YOUTUBE_API_KEY sau fisierul /var/www/youtube_api_key.txt
// (in afara webroot-ului, ca sa nu fie public).
//
// GET ?q=text  -> {"ok":true,"source":"...","results":[{id,title,channel,duration,live,thumb}]}
// Erori        -> {"ok":false,"error":"cod","message":"text"} cu status HTTP potrivit.

header('Content-Type: application/json; charset=utf-8');
header('X-Content-Type-Options: nosniff');
header('Cache-Control: no-store');

const MAX_Q = 150;
const MAX_RESULTS = 20;
const CACHE_TTL = 6 * 3600;
const RATE_MAX = 40;      // cautari pe minut pe IP
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';

function out($data, $code = 200) {
    http_response_code($code);
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}
function fail($error, $message, $code) {
    out(['ok' => false, 'error' => $error, 'message' => $message], $code);
}

$q = isset($_GET['q']) ? (string)$_GET['q'] : '';
if (!mb_check_encoding($q, 'UTF-8')) fail('bad_query', 'Text invalid.', 400);
$q = trim(preg_replace('/\s+/u', ' ', preg_replace('/[\x00-\x1F\x7F]/u', ' ', $q)));
if ($q === '') fail('empty', 'Scrie ce melodie cauți.', 400);
if (mb_strlen($q) > MAX_Q) $q = mb_substr($q, 0, MAX_Q);
$diag = isset($_GET['diag']);

// ---------- cache + limitare ----------
$dir = rtrim(sys_get_temp_dir(), '/') . '/nosantos_music';
if (!is_dir($dir)) @mkdir($dir, 0700, true);
$key = md5(mb_strtolower($q));
$cacheFile = "$dir/q_$key.json";
if (!$diag && is_file($cacheFile) && filemtime($cacheFile) > time() - CACHE_TTL) {
    $c = json_decode((string)@file_get_contents($cacheFile), true);
    if (is_array($c) && !empty($c['results'])) { $c['cached'] = true; out($c); }
}

$ip = $_SERVER['REMOTE_ADDR'] ?? 'x';
$rateFile = "$dir/r_" . md5($ip) . '.json';
$now = time();
$hits = json_decode((string)@file_get_contents($rateFile), true);
$hits = is_array($hits) ? array_values(array_filter($hits, function ($t) use ($now) { return $t > $now - 60; })) : [];
if (count($hits) >= RATE_MAX) fail('rate_limit', 'Prea multe căutări într-un minut. Mai încearcă puțin mai târziu.', 429);
$hits[] = $now;
@file_put_contents($rateFile, json_encode($hits), LOCK_EX);

// ---------- HTTP ----------
function http($url, $post = null, $headers = [], $timeout = 8) {
    $headers = array_merge(['User-Agent: ' . UA, 'Accept-Language: en-US,en;q=0.9'], $headers);
    if (function_exists('curl_init')) {
        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true, CURLOPT_FOLLOWLOCATION => true, CURLOPT_MAXREDIRS => 3,
            CURLOPT_CONNECTTIMEOUT => 4, CURLOPT_TIMEOUT => $timeout, CURLOPT_HTTPHEADER => $headers,
            CURLOPT_ENCODING => '',
        ]);
        if ($post !== null) { curl_setopt($ch, CURLOPT_POST, true); curl_setopt($ch, CURLOPT_POSTFIELDS, $post); }
        $body = curl_exec($ch);
        $code = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        return [$code, $body === false ? '' : $body];
    }
    $ctx = stream_context_create(['http' => [
        'method' => $post !== null ? 'POST' : 'GET', 'header' => implode("\r\n", $headers),
        'content' => $post ?? '', 'timeout' => $timeout, 'ignore_errors' => true,
    ]]);
    $body = @file_get_contents($url, false, $ctx);
    $code = 0;
    if (isset($http_response_header[0]) && preg_match('/\s(\d{3})\s/', $http_response_header[0], $m)) $code = (int)$m[1];
    return [$code, $body === false ? '' : $body];
}

function fmtDur($s) {
    $s = (int)$s; if ($s <= 0) return '';
    $h = intdiv($s, 3600); $m = intdiv($s % 3600, 60); $x = $s % 60;
    return $h ? sprintf('%d:%02d:%02d', $h, $m, $x) : sprintf('%d:%02d', $m, $x);
}
function txt($node) {
    if (!is_array($node)) return '';
    if (isset($node['simpleText'])) return (string)$node['simpleText'];
    if (isset($node['runs'])) return implode('', array_map(function ($r) { return $r['text'] ?? ''; }, $node['runs']));
    return '';
}
function validId($id) { return is_string($id) && preg_match('/^[A-Za-z0-9_-]{11}$/', $id); }
function item($id, $title, $channel, $duration, $live) {
    return ['id' => $id, 'title' => $title, 'channel' => $channel, 'duration' => $duration, 'live' => (bool)$live,
            'thumb' => "https://i.ytimg.com/vi/$id/mqdefault.jpg"];
}

// Parcurge raspunsul YouTube si colecteaza toate "videoRenderer".
function collectRenderers($node, &$acc) {
    if (!is_array($node) || count($acc) >= MAX_RESULTS) return;
    if (isset($node['videoRenderer']['videoId'])) {
        $v = $node['videoRenderer'];
        if (validId($v['videoId'])) {
            $live = false;
            foreach (($v['badges'] ?? []) as $b) if (stripos(json_encode($b), 'LIVE') !== false) $live = true;
            foreach (($v['thumbnailOverlays'] ?? []) as $o) if (($o['thumbnailOverlayTimeStatusRenderer']['style'] ?? '') === 'LIVE') $live = true;
            $acc[$v['videoId']] = item($v['videoId'], txt($v['title'] ?? null), txt($v['ownerText'] ?? ($v['longBylineText'] ?? null)),
                                       txt($v['lengthText'] ?? null), $live);
        }
        return;
    }
    foreach ($node as $child) if (is_array($child)) collectRenderers($child, $acc);
}

function src_innertube($q) {
    $body = json_encode([
        'context' => ['client' => ['clientName' => 'WEB', 'clientVersion' => '2.20241121.01.00', 'hl' => 'en', 'gl' => 'US']],
        'query' => $q, 'params' => 'EgIQAQ==',   // doar videoclipuri
    ]);
    [$code, $res] = http('https://www.youtube.com/youtubei/v1/search?prettyPrint=false', $body,
        ['Content-Type: application/json', 'Origin: https://www.youtube.com', 'Cookie: SOCS=CAI; CONSENT=YES+']);
    if ($code !== 200) return null;
    $acc = []; collectRenderers(json_decode($res, true), $acc);
    return array_values($acc);
}

function src_html($q) {
    [$code, $res] = http('https://www.youtube.com/results?sp=EgIQAQ%253D%253D&search_query=' . rawurlencode($q), null,
        ['Cookie: SOCS=CAI; CONSENT=YES+']);
    if ($code !== 200 || !preg_match('/var ytInitialData\s*=\s*(\{.+?\});\s*<\/script>/s', $res, $m)) return null;
    $acc = []; collectRenderers(json_decode($m[1], true), $acc);
    return array_values($acc);
}

function apiKey() {
    $k = getenv('YOUTUBE_API_KEY');
    if (!$k && is_readable('/var/www/youtube_api_key.txt')) $k = trim((string)file_get_contents('/var/www/youtube_api_key.txt'));
    return $k ?: null;
}
function src_api($q) {
    $k = apiKey(); if (!$k) return null;
    [$code, $res] = http('https://www.googleapis.com/youtube/v3/search?' . http_build_query([
        'part' => 'snippet', 'type' => 'video', 'videoEmbeddable' => 'true', 'maxResults' => MAX_RESULTS, 'q' => $q, 'key' => $k,
    ]));
    if ($code !== 200) return null;
    $d = json_decode($res, true); $acc = [];
    foreach (($d['items'] ?? []) as $it) {
        $id = $it['id']['videoId'] ?? null; if (!validId($id)) continue;
        $sn = $it['snippet'] ?? [];
        $acc[] = item($id, html_entity_decode($sn['title'] ?? '', ENT_QUOTES), html_entity_decode($sn['channelTitle'] ?? '', ENT_QUOTES),
                      '', ($sn['liveBroadcastContent'] ?? '') === 'live');
    }
    return $acc;
}

function src_piped($q) {
    foreach (['https://pipedapi.kavin.rocks', 'https://pipedapi.adminforge.de', 'https://api.piped.private.coffee'] as $base) {
        [$code, $res] = http("$base/search?filter=videos&q=" . rawurlencode($q), null, [], 6);
        if ($code !== 200) continue;
        $d = json_decode($res, true); $acc = [];
        foreach (($d['items'] ?? []) as $it) {
            if (!preg_match('/v=([A-Za-z0-9_-]{11})/', $it['url'] ?? '', $m)) continue;
            $acc[] = item($m[1], $it['title'] ?? '', $it['uploaderName'] ?? '', fmtDur($it['duration'] ?? 0), ($it['duration'] ?? 0) == -1);
            if (count($acc) >= MAX_RESULTS) break;
        }
        if ($acc) return $acc;
    }
    return null;
}
function src_invidious($q) {
    foreach (['https://inv.nadeko.net', 'https://invidious.nerdvpn.de', 'https://yewtu.be'] as $base) {
        [$code, $res] = http("$base/api/v1/search?type=video&q=" . rawurlencode($q), null, [], 6);
        if ($code !== 200) continue;
        $d = json_decode($res, true); $acc = [];
        foreach ((is_array($d) ? $d : []) as $it) {
            if (($it['type'] ?? '') !== 'video' || !validId($it['videoId'] ?? null)) continue;
            $acc[] = item($it['videoId'], $it['title'] ?? '', $it['author'] ?? '', fmtDur($it['lengthSeconds'] ?? 0), !empty($it['liveNow']));
            if (count($acc) >= MAX_RESULTS) break;
        }
        if ($acc) return $acc;
    }
    return null;
}

$tried = []; $empty = 0;
foreach (['innertube', 'html', 'api', 'piped', 'invidious'] as $s) {
    $t0 = microtime(true);
    $r = call_user_func("src_$s", $q);
    $tried[$s] = ['n' => is_array($r) ? count($r) : null, 'ms' => (int)((microtime(true) - $t0) * 1000)];
    if ($r === null) continue;   // sursa n-a mers, incercam urmatoarea
    if (!$r && ++$empty < 2) continue;   // 0 rezultate: mai verificam o sursa inainte sa credem asta
    $data = ['ok' => true, 'q' => $q, 'source' => $s, 'results' => $r];
    if ($r) @file_put_contents($cacheFile, json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES), LOCK_EX);
    if ($diag) $data['tried'] = $tried;
    out($data);   // poate fi si 0 rezultate: cautarea a mers, dar nu a gasit nimic
}
if ($empty) out(['ok' => true, 'q' => $q, 'source' => 'none', 'results' => []] + ($diag ? ['tried' => $tried] : []));
$err = ['ok' => false, 'error' => 'unavailable', 'message' => 'Căutarea YouTube nu răspunde acum. Încearcă din nou peste câteva secunde.'];
if ($diag) $err['tried'] = $tried;
out($err, 502);
