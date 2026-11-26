<?php
// Rezolvare flux audio pentru un videoId (folosit de stream.php si audio.php).
// Sursele, in ordine:
//   0 'yt'        - YouTube innertube /player cu clienti care dau URL-uri directe; URL-ul e legat de IP-ul
//                   serverului, deci il servim prin audio.php (proxy cu Range).
//   1 'piped'     - instante Piped (URL-uri deja trecute prin proxy-ul lor, merg direct din browser)
//   2 'invidious' - instante Invidious cu local=true (la fel)

const A_UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';
const A_SOURCES = ['yt', 'piped', 'invidious'];

function a_dir() {
    $d = rtrim(sys_get_temp_dir(), '/') . '/nosantos_music';
    if (!is_dir($d)) @mkdir($d, 0700, true);
    return $d;
}
function a_valid($id) { return is_string($id) && preg_match('/^[A-Za-z0-9_-]{11}$/', $id); }

function a_http($url, $post = null, $headers = [], $timeout = 8) {
    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true, CURLOPT_FOLLOWLOCATION => true, CURLOPT_MAXREDIRS => 3,
        CURLOPT_CONNECTTIMEOUT => 4, CURLOPT_TIMEOUT => $timeout, CURLOPT_ENCODING => '',
        CURLOPT_HTTPHEADER => $headers,
    ]);
    if ($post !== null) { curl_setopt($ch, CURLOPT_POST, true); curl_setopt($ch, CURLOPT_POSTFIELDS, $post); }
    $body = curl_exec($ch);
    $code = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    return [$code, $body === false ? '' : $body];
}

// Alege cel mai bun format audio: m4a (merge peste tot, inclusiv iPhone), apoi orice audio.
function a_pick($formats) {
    $best = null; $bestScore = -1;
    foreach ($formats as $f) {
        $mime = $f['mimeType'] ?? ($f['type'] ?? '');
        if (stripos($mime, 'audio/') !== 0 || empty($f['url'])) continue;
        $score = (stripos($mime, 'mp4') !== false ? 1000000 : 0) + min(999999, (int)($f['bitrate'] ?? 0));
        if ($score > $bestScore) { $bestScore = $score; $best = $f; }
    }
    return $best;
}

// Rezolva prin YouTube direct; rezultatul (URL legat de IP-ul serverului) se tine in cache ~4h.
function a_yt($id, $fresh = false) {
    $cf = a_dir() . "/a_$id.json";
    if (!$fresh && is_file($cf) && filemtime($cf) > time() - 4 * 3600) {
        $c = json_decode((string)@file_get_contents($cf), true);
        if (!empty($c['url'])) return $c;
    }
    $clients = [
        ['clientName' => 'ANDROID_VR', 'clientVersion' => '1.60.19', 'deviceMake' => 'Oculus', 'deviceModel' => 'Quest 3',
         'androidSdkVersion' => 32, 'osName' => 'Android', 'osVersion' => '12L', 'hl' => 'en', 'gl' => 'US',
         '_ua' => 'com.google.android.apps.youtube.vr.oculus/1.60.19 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip', '_n' => 28],
        ['clientName' => 'IOS', 'clientVersion' => '20.10.4', 'deviceMake' => 'Apple', 'deviceModel' => 'iPhone16,2',
         'osName' => 'iPhone', 'osVersion' => '18.3.2.22D82', 'hl' => 'en', 'gl' => 'US',
         '_ua' => 'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)', '_n' => 5],
        ['clientName' => 'ANDROID', 'clientVersion' => '19.44.38', 'androidSdkVersion' => 30, 'osName' => 'Android', 'osVersion' => '11',
         'hl' => 'en', 'gl' => 'US', '_ua' => 'com.google.android.youtube/19.44.38 (Linux; U; Android 11) gzip', '_n' => 3],
    ];
    foreach ($clients as $c) {
        $ua = $c['_ua']; $n = $c['_n']; unset($c['_ua'], $c['_n']);
        $body = json_encode(['context' => ['client' => $c], 'videoId' => $id, 'contentCheckOk' => true, 'racyCheckOk' => true]);
        [$code, $res] = a_http('https://www.youtube.com/youtubei/v1/player?prettyPrint=false', $body, [
            'Content-Type: application/json', 'User-Agent: ' . $ua, 'X-YouTube-Client-Name: ' . $n,
            'X-YouTube-Client-Version: ' . $c['clientVersion'], 'Origin: https://www.youtube.com',
        ]);
        if ($code !== 200) continue;
        $d = json_decode($res, true);
        if (($d['playabilityStatus']['status'] ?? '') !== 'OK') continue;
        $f = a_pick($d['streamingData']['adaptiveFormats'] ?? []);
        if (!$f) continue;
        // verificam ca URL-ul chiar raspunde (unele clienti dau URL-uri care intorc 403)
        $ch = curl_init($f['url']);
        curl_setopt_array($ch, [CURLOPT_NOBODY => false, CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 6,
            CURLOPT_HTTPHEADER => ['User-Agent: ' . $ua, 'Range: bytes=0-1023']]);
        curl_exec($ch); $ok = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE); curl_close($ch);
        if ($ok !== 206 && $ok !== 200) continue;
        $out = [
            'url' => $f['url'], 'ua' => $ua, 'mime' => explode(';', $f['mimeType'])[0],
            'len' => (int)($f['contentLength'] ?? 0),
            'title' => $d['videoDetails']['title'] ?? '', 'author' => $d['videoDetails']['author'] ?? '',
            'seconds' => (int)($d['videoDetails']['lengthSeconds'] ?? 0),
        ];
        @file_put_contents($cf, json_encode($out), LOCK_EX);
        return $out;
    }
    return null;
}

function a_piped($id) {
    foreach (['https://pipedapi.kavin.rocks', 'https://pipedapi.adminforge.de', 'https://api.piped.private.coffee'] as $base) {
        [$code, $res] = a_http("$base/streams/$id", null, ['User-Agent: ' . A_UA], 7);
        if ($code !== 200) continue;
        $d = json_decode($res, true);
        $f = a_pick($d['audioStreams'] ?? []);
        if ($f) return ['url' => $f['url'], 'title' => $d['title'] ?? '', 'author' => $d['uploader'] ?? '', 'seconds' => (int)($d['duration'] ?? 0)];
    }
    return null;
}

function a_invidious($id) {
    foreach (['https://inv.nadeko.net', 'https://invidious.nerdvpn.de', 'https://yewtu.be'] as $base) {
        [$code, $res] = a_http("$base/api/v1/videos/$id?local=true", null, ['User-Agent: ' . A_UA], 7);
        if ($code !== 200) continue;
        $d = json_decode($res, true);
        $f = a_pick($d['adaptiveFormats'] ?? []);
        if ($f) {
            $url = $f['url'];
            if (strpos($url, '/') === 0) $url = $base . $url;
            return ['url' => $url, 'title' => $d['title'] ?? '', 'author' => $d['author'] ?? '', 'seconds' => (int)($d['lengthSeconds'] ?? 0)];
        }
    }
    return null;
}
