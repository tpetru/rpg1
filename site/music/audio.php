<?php
// Proxy audio pentru un videoId: URL-urile YouTube sunt legate de IP-ul serverului, asa ca
// le trimitem noi mai departe browserului, cu suport pentru Range (derulare, iPhone).
require __DIR__ . '/_audio.php';

$id = $_GET['id'] ?? '';
if (!a_valid($id)) { http_response_code(400); exit; }
$info = a_yt($id);
if (!$info) { http_response_code(502); exit; }

@set_time_limit(0);
while (ob_get_level()) ob_end_clean();

const CHUNK = 9 * 1024 * 1024;   // YouTube incetineste cererile mai mari de ~10 MB
$len = (int)$info['len'];
$start = 0; $end = $len ? $len - 1 : null; $partial = false;
if (isset($_SERVER['HTTP_RANGE']) && preg_match('/bytes=(\d*)-(\d*)/', $_SERVER['HTTP_RANGE'], $m)) {
    $partial = true;
    if ($m[1] === '' && $m[2] !== '' && $len) { $start = max(0, $len - (int)$m[2]); }
    else { $start = (int)$m[1]; if ($m[2] !== '') $end = (int)$m[2]; }
}
if ($len && $start >= $len) { http_response_code(416); header("Content-Range: bytes */$len"); exit; }
if ($end === null || $end - $start + 1 > CHUNK) { $end = $start + CHUNK - 1; $partial = true; }
if ($len && $end > $len - 1) $end = $len - 1;

function fetchRange($url, $ua, $start, $end, $sendHeaders) {
    $sep = strpos($url, '?') === false ? '?' : '&';
    $ch = curl_init($url . $sep . "range=$start-$end");
    $status = 0;
    curl_setopt_array($ch, [
        CURLOPT_HTTPHEADER => ['User-Agent: ' . $ua], CURLOPT_FOLLOWLOCATION => true, CURLOPT_CONNECTTIMEOUT => 6,
        CURLOPT_TIMEOUT => 120, CURLOPT_BUFFERSIZE => 65536,
        CURLOPT_HEADERFUNCTION => function ($ch, $h) use (&$status) {
            if (preg_match('#^HTTP/\S+\s+(\d{3})#', $h, $m)) $status = (int)$m[1];
            return strlen($h);
        },
        CURLOPT_WRITEFUNCTION => function ($ch, $data) use (&$status, $sendHeaders) {
            if ($status >= 400) return strlen($data);   // nu trimitem corpul unei erori
            $sendHeaders(); echo $data; flush();
            return connection_aborted() ? 0 : strlen($data);
        },
    ]);
    curl_exec($ch); curl_close($ch);
    return $status;
}

$sent = false;
$sendHeaders = function () use (&$sent, $info, $start, $end, $len, $partial) {
    if ($sent) return; $sent = true;
    http_response_code($partial ? 206 : 200);
    header('Content-Type: ' . ($info['mime'] ?: 'audio/mp4'));
    header('Accept-Ranges: bytes');
    header('Cache-Control: private, max-age=3600');
    if ($len) header('Content-Length: ' . ($end - $start + 1));
    if ($partial) header("Content-Range: bytes $start-$end/" . ($len ?: '*'));
};

$st = fetchRange($info['url'], $info['ua'], $start, $end, $sendHeaders);
if (!$sent && $st >= 400) {
    // URL-ul a expirat: il cerem din nou o singura data
    $info2 = a_yt($id, true);
    if ($info2) { $info['url'] = $info2['url']; $info['ua'] = $info2['ua']; $st = fetchRange($info['url'], $info['ua'], $start, $end, $sendHeaders); }
}
if (!$sent) { http_response_code(502); }
