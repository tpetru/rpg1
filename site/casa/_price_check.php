<?php
// Extragerea pretului dintr-o pagina de produs - folosita atat de shopping_check.php (declansat
// manual din UI, pentru casa curenta) cat si de cron_check_all.php (task Windows programat, pentru
// toate casele). Tine toata logica de scraping intr-un singur loc, ca sa nu se dezalinieze intre
// cele doua puncte de intrare.

function casa_ensure_price_history_table(mysqli $mysqli): void
{
    $mysqli->query(
        'CREATE TABLE IF NOT EXISTS casa_price_history (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            product_id INT UNSIGNED NOT NULL,
            price DECIMAL(10,2) NULL,
            currency VARCHAR(8) NULL,
            ok TINYINT(1) NOT NULL DEFAULT 0,
            error VARCHAR(255) NULL,
            checked_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY product_checked (product_id, checked_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );
    $mysqli->query('ALTER TABLE casa_price_history ADD COLUMN IF NOT EXISTS unit_price DECIMAL(10,2) NULL AFTER currency');
}

// Downloads a product page pretending to be a normal browser - a bare PHP user-agent gets blocked
// or served a stripped page by most shops.
function casa_fetch_page(string $url): array
{
    $browserUa = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36';
    $result = casa_fetch_page_with_ua($url, $browserUa);
    // Some WAFs (ceramall.ro) flag a full Chrome UA that arrives without Chrome's other headers
    // and answer 403, but let a bare "Mozilla/5.0" through - retry with that before giving up.
    if (!$result['ok'] && ($result['error'] ?? '') === 'HTTP 403') {
        $retry = casa_fetch_page_with_ua($url, 'Mozilla/5.0');
        if ($retry['ok']) return $retry;
    }
    return $result;
}

function casa_fetch_page_with_ua(string $url, string $userAgent): array
{
    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_MAXREDIRS => 5,
        CURLOPT_CONNECTTIMEOUT => 8,
        CURLOPT_TIMEOUT => 20,
        CURLOPT_SSL_VERIFYPEER => false,
        CURLOPT_ENCODING => '',
        CURLOPT_USERAGENT => $userAgent,
        CURLOPT_HTTPHEADER => [
            'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language: ro-RO,ro;q=0.9,en;q=0.8',
        ],
    ]);
    $body = curl_exec($ch);
    $status = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $err = curl_error($ch);
    curl_close($ch);

    if ($body === false) return ['ok' => false, 'error' => $err !== '' ? $err : 'fetch failed'];
    if ($status >= 400) return ['ok' => false, 'error' => 'HTTP ' . $status];
    return ['ok' => true, 'html' => $body];
}

// Normalizes "1.299,99" / "1,299.99" / "1299" to a float. The last separator in the string decides
// which one is the decimal point.
function casa_parse_price_string(string $raw): ?float
{
    $raw = trim($raw);
    if ($raw === '') return null;
    $clean = preg_replace('/[^\d.,]/', '', $raw);
    if ($clean === '' || $clean === null) return null;

    $lastComma = strrpos($clean, ',');
    $lastDot = strrpos($clean, '.');
    if ($lastComma !== false && ($lastDot === false || $lastComma > $lastDot)) {
        $clean = str_replace('.', '', $clean);
        $clean = str_replace(',', '.', $clean);
    } else {
        $clean = str_replace(',', '', $clean);
    }
    if (!is_numeric($clean)) return null;
    $value = (float)$clean;
    return $value > 0 ? $value : null;
}

// Price per m2 from an Offer's priceSpecification: shops selling tiles by the box publish the box
// price plus the box's area as referenceQuantity (SQM), so per-m2 = box price / area.
function casa_unit_price_from_offer(array $offer, float $boxPrice): ?float
{
    foreach ((array)($offer['priceSpecification'] ?? []) as $spec) {
        if (!is_array($spec) || isset($spec['priceType'])) continue;
        $ref = $spec['referenceQuantity'] ?? null;
        if (!is_array($ref) || ($ref['unitCode'] ?? '') !== 'SQM') continue;
        $area = (float)($ref['value'] ?? 0);
        if ($area > 0 && $area != 1.0) return round($boxPrice / $area, 2);
    }
    return null;
}

// Walks a decoded JSON-LD blob looking for a Product/Offer price, whatever nesting the shop used.
function casa_price_from_jsonld($node): ?array
{
    if (!is_array($node)) return null;

    if (isset($node['offers'])) {
        $offers = $node['offers'];
        if (isset($offers['price'])) {
            $p = casa_parse_price_string((string)$offers['price']);
            if ($p !== null) return ['price' => $p, 'currency' => $offers['priceCurrency'] ?? null];
        }
        if (is_array($offers)) {
            foreach ($offers as $offer) {
                if (is_array($offer) && isset($offer['price'])) {
                    $p = casa_parse_price_string((string)$offer['price']);
                    if ($p !== null) return ['price' => $p, 'currency' => $offer['priceCurrency'] ?? null, 'unit_price' => casa_unit_price_from_offer($offer, $p)];
                }
            }
        }
    }
    if (isset($node['price'])) {
        $p = casa_parse_price_string((string)$node['price']);
        if ($p !== null) return ['price' => $p, 'currency' => $node['priceCurrency'] ?? null];
    }

    foreach ($node as $child) {
        if (is_array($child)) {
            $found = casa_price_from_jsonld($child);
            if ($found !== null) return $found;
        }
    }
    return null;
}

// Tries the structured formats first (JSON-LD, OpenGraph, microdata) - those are what shops publish
// for Google/Facebook, so they work across most stores without per-site rules. Loose text matching
// is only the last resort.
function casa_extract_price(string $html): ?array
{
    if (preg_match_all('#<script[^>]*type=["\']application/ld\+json["\'][^>]*>(.*?)</script>#is', $html, $m)) {
        foreach ($m[1] as $block) {
            $data = json_decode(trim($block), true);
            if (!is_array($data)) continue;
            $found = casa_price_from_jsonld($data);
            if ($found !== null) return $found + ['source' => 'json-ld'];
        }
    }

    if (preg_match('/<meta[^>]+(?:property|name)=["\'](?:product:price:amount|og:price:amount)["\'][^>]*content=["\']([^"\']+)["\']/i', $html, $m)
        || preg_match('/<meta[^>]+content=["\']([^"\']+)["\'][^>]*(?:property|name)=["\'](?:product:price:amount|og:price:amount)["\']/i', $html, $m)) {
        $p = casa_parse_price_string($m[1]);
        if ($p !== null) {
            $currency = null;
            if (preg_match('/<meta[^>]+(?:property|name)=["\'](?:product:price:currency|og:price:currency)["\'][^>]*content=["\']([A-Za-z]{3})["\']/i', $html, $c)) {
                $currency = strtoupper($c[1]);
            }
            return ['price' => $p, 'currency' => $currency, 'source' => 'og-meta'];
        }
    }

    // Magento stores (dedeman.ro and others built on the same platform) render the actual price
    // the shopper sees via a data-price-amount/data-price-type="finalPrice" pair, separate from any
    // itemprop="price" microdata on the page - which on these sites can belong to a secondary/unit
    // price (e.g. Dedeman marks a "per m2" reference price the same way, so grabbing the first
    // itemprop="price" match picks that instead of the real product price). Try this first when
    // present, since it's exactly the number rendered on screen.
    if (preg_match('/data-price-amount=["\']([\d.]+)["\'][^>]*data-price-type=["\']finalPrice["\']/i', $html, $m)
        || preg_match('/data-price-type=["\']finalPrice["\'][^>]*data-price-amount=["\']([\d.]+)["\']/i', $html, $m)) {
        $p = casa_parse_price_string($m[1]);
        if ($p !== null) {
            // The visible currency label next to a Magento price is usually the word "lei", not the
            // ISO code "RON" - both mean the same Romanian leu, so normalize either to RON.
            $currency = null;
            if (preg_match('/class=["\']currency["\']\s*>\s*([^<]+?)\s*</i', $html, $c)) {
                $curText = mb_strtolower(trim($c[1]));
                if ($curText === 'lei' || $curText === 'ron') $currency = 'RON';
            }
            return ['price' => $p, 'currency' => $currency, 'source' => 'magento-final-price'];
        }
    }

    if (preg_match('/itemprop=["\']price["\'][^>]*content=["\']([^"\']+)["\']/i', $html, $m)
        || preg_match('/content=["\']([^"\']+)["\'][^>]*itemprop=["\']price["\']/i', $html, $m)) {
        $p = casa_parse_price_string($m[1]);
        if ($p !== null) {
            $currency = null;
            if (preg_match('/itemprop=["\']priceCurrency["\'][^>]*content=["\']([A-Za-z]{3})["\']/i', $html, $c)) {
                $currency = strtoupper($c[1]);
            }
            return ['price' => $p, 'currency' => $currency, 'source' => 'microdata'];
        }
    }

    // Shops with no structured data at all (evalight.ro) still push the product to Google
    // Analytics: dataLayer "view_item" with items[].price / currency, i.e. the price on screen.
    if (preg_match('/[\'"]item_id[\'"]\s*:[^}]*?[\'"]price[\'"]\s*:\s*[\'"]?([\d.,]+)[\'"]?(?:\s*,\s*[\'"]currency[\'"]\s*:\s*[\'"]([A-Za-z]{3})[\'"])?/s', $html, $m)) {
        $p = casa_parse_price_string($m[1]);
        if ($p !== null) return ['price' => $p, 'currency' => isset($m[2]) && $m[2] !== '' ? strtoupper($m[2]) : null, 'source' => 'datalayer'];
    }

    if (preg_match('/(\d[\d.,]{1,12})\s*(?:lei|ron)\b/i', strip_tags($html), $m)) {
        $p = casa_parse_price_string($m[1]);
        if ($p !== null) return ['price' => $p, 'currency' => 'RON', 'source' => 'text'];
    }

    return null;
}

// Pret/mp pentru produse vandute la bax/pachet/cutie, cand pagina nu-l da in date structurate.
// Mai intai gaseste suprafata unui bax (tabel "mp / bax" pe grosimea din titlu, sau text de tip
// "m2/pachet: 1,44", "Pachet 1.44m²", "2,16 mp / bax"); fara ea produsul nu se vinde la pachet.
// Apoi: daca pagina scrie explicit pretul pe mp ("Preț m² 113,88 RON", "45 lei/mp") acela e pretul/mp,
// altfel pretul de pe pagina se imparte la suprafata baxului.
// Intoarce pretul/mp sau null cand pagina nu vinde la bax.
function casa_detect_unit_price(string $html, float $price): ?float
{
    $text = html_entity_decode(strip_tags(preg_replace('#<(script|style)\b.*?</\1>#is', ' ', $html)), ENT_QUOTES | ENT_HTML5, 'UTF-8');
    $text = preg_replace('/\s+/u', ' ', $text);
    $sqm = '(?:m²|m2|mp)';

    $area = null;

    // Tabel cu o coloana "mp / bax" (sau pachet/cutie): randul cu grosimea produsului (din titlu).
    if (preg_match('/<title[^>]*>(.*?)<\/title>/is', $html, $t) && preg_match('/(\d{2,3})\s*mm/i', html_entity_decode($t[1]), $th)) {
        $thickness = $th[1];
        $dom = new DOMDocument();
        if (@$dom->loadHTML('<?xml encoding="UTF-8">' . $html)) {
            foreach ($dom->getElementsByTagName('table') as $table) {
                $col = null;
                foreach ($table->getElementsByTagName('tr') as $tr) {
                    $cells = [];
                    foreach ($tr->childNodes as $c) {
                        if ($c instanceof DOMElement && in_array(strtolower($c->tagName), ['td', 'th'], true)) $cells[] = trim(preg_replace('/\s+/u', ' ', $c->textContent));
                    }
                    if ($col === null) {
                        foreach ($cells as $i => $label) {
                            if (preg_match('/' . $sqm . '\s*\/\s*(?:bax|pachet|cutie)/iu', $label)) { $col = $i; break; }
                        }
                        continue;
                    }
                    if (isset($cells[0], $cells[$col]) && $cells[0] === $thickness && is_numeric(str_replace(',', '.', $cells[$col]))) {
                        $area = (float)str_replace(',', '.', $cells[$col]);
                        break 2;
                    }
                }
            }
        }
    }

    if ($area === null) {
        $num = '(\d+(?:[.,]\d+)?)';
        if (preg_match('/' . $sqm . '\s*\/\s*(?:pachet|bax|cutie)\s*:?\s*' . $num . '/iu', $text, $m)
            || preg_match('/(?:pachet|bax|cutie)\s*' . $num . '\s*' . $sqm . '/iu', $text, $m)
            || preg_match('/' . $num . '\s*' . $sqm . '\s*\/\s*(?:pachet|bax|cutie)/iu', $text, $m)) {
            $area = (float)str_replace(',', '.', $m[1]);
        }
    }

    // Fara suprafata de bax nu e un produs vandut la pachet (un pret/mp secundar de pe pagina, ca la
    // oglinzile de la Dedeman, nu conteaza).
    if ($area === null || $area <= 0 || $area == 1.0 || $area >= 100) return null;

    if (preg_match('/pre[tț]\s*' . $sqm . '\s*:?\s*(\d[\d.,]*)\s*(?:lei|ron)/iu', $text, $m)
        || preg_match('/(\d[\d.,]*)\s*(?:lei|ron)\s*\/\s*' . $sqm . '(?![\w²])/iu', $text, $m)) {
        $p = casa_parse_price_string($m[1]);
        if ($p !== null) return round($p, 2);
    }

    return round($price / $area, 2);
}

// Fetches a product's URL, extracts the price, and records one row in casa_price_history -
// the single step both entry points (manual check button, daily cron) run per product.
function casa_check_product_price(mysqli $mysqli, int $productId, string $url): array
{
    $fetched = casa_fetch_page($url);

    $price = null;
    $unitPrice = null;
    $currency = null;
    $ok = 0;
    $error = null;

    if (!$fetched['ok']) {
        $error = mb_substr($fetched['error'], 0, 255);
    } else {
        $extracted = casa_extract_price($fetched['html']);
        if ($extracted === null) {
            $error = 'Prețul nu a putut fi găsit în pagină';
        } else {
            $price = $extracted['price'];
            $unitPrice = $extracted['unit_price'] ?? null;
            if ($unitPrice === null) $unitPrice = casa_detect_unit_price($fetched['html'], (float)$price);
            if ($unitPrice !== null && $price > 0) {
                // Produsele vandute la cutie se urmaresc pe pret/mp. Intrarile vechi (pret pe cutie,
                // fara unit_price) se rescaleaza o singura data cu acelasi factor (suprafata cutiei),
                // iar unit_price devine marcajul "price e deja per mp".
                $factor = $unitPrice / $price;
                $rescale = $mysqli->prepare('UPDATE casa_price_history SET price = ROUND(price * ?, 2), unit_price = ROUND(price * ?, 2) WHERE product_id = ? AND unit_price IS NULL');
                $rescale->bind_param('ddi', $factor, $factor, $productId);
                $rescale->execute();
                $price = $unitPrice;
            }
            $currency = $extracted['currency'] ?: 'RON';
            $ok = 1;
        }
    }

    // O verificare esuata (blocata de site, URL mort, pret negasit etc.) nu mai lasa o intrare in
    // istoric - istoricul de pret arata doar preturi reale, nu si incercari nereusite.
    if ($ok === 1) {
        // Cel mult o intrare pe zi per produs: daca produsul a mai fost citit cu succes azi,
        // actualizam acea intrare cu noua valoare in loc sa adaugam alta - istoricul arata un
        // singur pret pe zi, nu unul per verificare.
        $todayStmt = $mysqli->prepare('SELECT id FROM casa_price_history WHERE product_id = ? AND DATE(checked_at) = CURDATE() LIMIT 1');
        $todayStmt->bind_param('i', $productId);
        $todayStmt->execute();
        $todayRow = $todayStmt->get_result()->fetch_assoc();

        if ($todayRow) {
            $update = $mysqli->prepare('UPDATE casa_price_history SET price = ?, unit_price = ?, currency = ?, checked_at = NOW() WHERE id = ?');
            $update->bind_param('ddsi', $price, $unitPrice, $currency, $todayRow['id']);
            $update->execute();
        } else {
            $insert = $mysqli->prepare('INSERT INTO casa_price_history (product_id, price, unit_price, currency, ok, error) VALUES (?, ?, ?, ?, 1, NULL)');
            $insert->bind_param('idds', $productId, $price, $unitPrice, $currency);
            $insert->execute();
        }
    }

    return ['id' => $productId, 'ok' => (bool)$ok, 'price' => $price, 'unit_price' => $unitPrice, 'currency' => $currency, 'error' => $error];
}
