<?php
// GET ?id=VIDEOID[&from=N] -> {"ok":true,"url":"...","src":"yt|piped|invidious","next":N+1,"title","author","seconds"}
// "from" sare peste sursele care deja n-au mers in browser.
require __DIR__ . '/_audio.php';
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');

function j($d, $code = 200) { http_response_code($code); echo json_encode($d, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES); exit; }

$id = $_GET['id'] ?? '';
if (!a_valid($id)) j(['ok' => false, 'error' => 'bad_id'], 400);
$from = max(0, min(count(A_SOURCES), (int)($_GET['from'] ?? 0)));

// limita simpla: 60 rezolvari / minut / IP
$rf = a_dir() . '/s_' . md5($_SERVER['REMOTE_ADDR'] ?? 'x') . '.json';
$now = time();
$hits = json_decode((string)@file_get_contents($rf), true);
$hits = is_array($hits) ? array_values(array_filter($hits, function ($t) use ($now) { return $t > $now - 60; })) : [];
if (count($hits) >= 60) j(['ok' => false, 'error' => 'rate_limit'], 429);
$hits[] = $now; @file_put_contents($rf, json_encode($hits), LOCK_EX);

for ($i = $from; $i < count(A_SOURCES); $i++) {
    $s = A_SOURCES[$i];
    $r = call_user_func("a_$s", $id);
    if (!$r) continue;
    $url = $s === 'yt' ? 'audio.php?id=' . $id : $r['url'];
    j(['ok' => true, 'url' => $url, 'src' => $s, 'next' => $i + 1,
       'title' => $r['title'] ?? '', 'author' => $r['author'] ?? '', 'seconds' => $r['seconds'] ?? 0]);
}
j(['ok' => false, 'error' => 'no_stream'], 502);
