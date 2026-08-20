<?php
require_once __DIR__ . '/../../includes/admin_common.php';
ucp_admin_require_level5();

$flash = null;
$flashErr = false;

// bbClean: -1 while rented, 0 dirty, 1 cleaning in progress, 2 clean - mirrors /bbc [id] clean in bare.pwn
$bbCleanOptions = [-1 => 'Rented (-1)', 0 => 'Dirty (0)', 1 => 'Cleaning (1)', 2 => 'Clean (2)'];

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST' && !ucp_csrf_verify()) {
    $flash = "Security check failed (invalid or expired form). Please try again.";
    $flashErr = true;
} elseif (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    $id = (int)($_POST['id'] ?? 0);
    if ($id > 0) {
        $text       = trim($_POST['bbText'] ?? '');
        $textColor  = trim($_POST['bbTextColor'] ?? '#FFFFFFFF');
        $textBkg    = trim($_POST['bbTextBackground'] ?? '#000000FF');
        $fontSize   = max(1, (int)($_POST['bbFontSize'] ?? 30));
        $rented     = isset($_POST['bbRented']) ? 1 : 0;
        $rentLeft   = max(0, (int)($_POST['bbRentLeft'] ?? 0));
        $rentPrice  = max(0, (int)($_POST['bbRentPrice24H'] ?? 0));
        $clean      = (int)($_POST['bbClean'] ?? 2);
        $price      = max(0, (int)($_POST['bbPrice'] ?? 0));
        $bank       = (int)($_POST['bbBank'] ?? 0);
        $forSale    = isset($_POST['bbIsForSale']) ? 1 : 0;
        $ownerRaw   = trim($_POST['owner_id'] ?? '');

        // #RRGGBB or #RRGGBBAA only - matches Billboard_ParseColor in bare.pwn
        if (!preg_match('/^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$/', $textColor)) $textColor = '#FFFFFFFF';
        if (!preg_match('/^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$/', $textBkg))   $textBkg   = '#000000FF';
        if (!in_array($clean, [-1, 0, 1, 2], true)) $clean = 2;

        if (strcasecmp($ownerRaw, 'none') === 0 || $ownerRaw === '') {
            $ownerId = 0; $ownerName = '';
        } else {
            $ownerId = (int)$ownerRaw;
            $ownerName = ucp_username_by_id($mysqli, $ownerId);
            if ($ownerName === null) {
                $flash = "Player ID $ownerRaw not found."; $flashErr = true;
            }
        }

        if (!$flashErr) {
            $stmt = $mysqli->prepare("UPDATE `billboards` SET `bbText`=?, `bbTextColor`=?, `bbTextBackground`=?, `bbFontSize`=?, `bbRented`=?, `bbRentLeft`=?, `bbRentPrice24H`=?, `bbClean`=?, `bbPrice`=?, `bbBank`=?, `bbIsForSale`=?, `bbOwnerId`=?, `bbOwner`=? WHERE `bbID`=?");
            $stmt->bind_param('sssiiiiiiiiisi', $text, $textColor, $textBkg, $fontSize, $rented, $rentLeft, $rentPrice, $clean, $price, $bank, $forSale, $ownerId, $ownerName, $id);
            $stmt->execute();
            $stmt->close();
            $flash = "Billboard #$id updated.";
        }
    }
}

try {
    $billboards = $mysqli->query("SELECT * FROM `billboards` ORDER BY `bbID` ASC")->fetch_all(MYSQLI_ASSOC);
} catch (mysqli_sql_exception $e) {
    $billboards = null; // table doesn't exist yet - the gamemode creates it on startup
}

$adminActive = 'billboards';
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia LosSantos | RPG — Billboards</title>
<link rel="icon" type="image/png" href="<?= UCP_BASE ?>/assets/img/favicon.ico">
<link rel="stylesheet" href="<?= UCP_BASE ?>/assets/css/style.css?v=<?= filemtime(__DIR__ . '/../assets/css/style.css') ?>">
</head>
<body>

<?php include __DIR__ . '/../../includes/header.php'; ?>
<?php include __DIR__ . '/../../includes/admin_section_nav.php'; ?>

<main>
  <h1>📢 Billboards</h1>
  <p style="color:var(--muted)">Edit billboards directly. Changes are saved immediately to the database. Creating/repositioning billboards is still done in-game with <code>/billboardcreate</code> and <code>/bbc</code> (admin level 6+).</p>

  <?php include __DIR__ . '/../../includes/admin_nav.php'; ?>

  <?php if ($flash): ?>
    <div class="flash <?= $flashErr ? 'err' : 'ok' ?>"><?= ucp_escape($flash) ?></div>
  <?php endif; ?>

  <?php if ($billboards === null): ?>
  <div class="card">
    <p style="color:var(--muted)">The <code>billboards</code> table doesn't exist yet. It's created automatically by the gamemode on startup - run the server once, then reload this page.</p>
  </div>
  <?php else: ?>
  <div class="card">
    <div style="overflow-x:auto">
    <table class="edittable">
      <tr>
        <th>ID</th><th>Text</th><th>Text color</th><th>Bkg color</th><th>Font size</th>
        <th class="chk">Rented</th><th>Rent left (paydays)</th><th>24h rent price</th><th>Clean</th>
        <th>Price</th><th>Bank</th><th class="chk">For sale</th><th>Owner (player ID / none)</th><th></th>
      </tr>
      <?php foreach ($billboards as $bb): $fid = 'bb-' . (int)$bb['bbID']; ?>
      <tr>
          <td>#<?= (int)$bb['bbID'] ?></td>
          <td><input form="<?= $fid ?>" type="text" name="bbText" maxlength="127" value="<?= ucp_escape($bb['bbText']) ?>" style="width:160px"></td>
          <td><input form="<?= $fid ?>" type="text" name="bbTextColor" maxlength="9" value="<?= ucp_escape($bb['bbTextColor']) ?>" style="width:90px"></td>
          <td><input form="<?= $fid ?>" type="text" name="bbTextBackground" maxlength="9" value="<?= ucp_escape($bb['bbTextBackground']) ?>" style="width:90px"></td>
          <td><input form="<?= $fid ?>" type="number" name="bbFontSize" min="1" value="<?= (int)$bb['bbFontSize'] ?>" style="width:70px"></td>
          <td class="chk"><input form="<?= $fid ?>" type="checkbox" name="bbRented" <?= $bb['bbRented'] ? 'checked' : '' ?>></td>
          <td><input form="<?= $fid ?>" type="number" name="bbRentLeft" min="0" value="<?= (int)$bb['bbRentLeft'] ?>" style="width:70px"></td>
          <td><input form="<?= $fid ?>" type="number" name="bbRentPrice24H" min="0" value="<?= (int)$bb['bbRentPrice24H'] ?>"></td>
          <td>
            <select form="<?= $fid ?>" name="bbClean">
              <?php foreach ($bbCleanOptions as $val => $label): ?>
                <option value="<?= $val ?>" <?= (int)$bb['bbClean'] === $val ? 'selected' : '' ?>><?= $label ?></option>
              <?php endforeach; ?>
            </select>
          </td>
          <td><input form="<?= $fid ?>" type="number" name="bbPrice" min="0" value="<?= (int)$bb['bbPrice'] ?>"></td>
          <td><input form="<?= $fid ?>" type="number" name="bbBank" value="<?= (int)$bb['bbBank'] ?>"></td>
          <td class="chk"><input form="<?= $fid ?>" type="checkbox" name="bbIsForSale" <?= $bb['bbIsForSale'] ? 'checked' : '' ?>></td>
          <td><input form="<?= $fid ?>" type="text" name="owner_id" value="<?= (int)$bb['bbOwnerId'] > 0 ? (int)$bb['bbOwnerId'] : 'none' ?>" placeholder="none" style="width:70px"></td>
          <td>
            <form id="<?= $fid ?>" method="post">
              <?= ucp_csrf_field() ?>
              <input type="hidden" name="id" value="<?= (int)$bb['bbID'] ?>">
              <button type="submit" class="save-btn">Save</button>
            </form>
          </td>
      </tr>
      <?php endforeach; ?>
    </table>
    </div>
  </div>
  <?php endif; ?>
</main>

<?php include __DIR__ . '/../../includes/footer.php'; ?>

</body>
</html>
