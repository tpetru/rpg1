<?php
// Downscales an uploaded photo in place so galleries stay fast on mobile data - a modern phone
// photo is 3-5 MB, which adds up quickly with a dozen photos per room.
//
// Requires the GD extension. If GD isn't available the original file is simply left untouched, so
// uploads keep working (just without the size saving) rather than failing outright.

const CASA_MAX_IMAGE_DIM = 1600;   // longest edge, in pixels
const CASA_JPEG_QUALITY  = 82;

// iPhone JPEGs store pixels in the sensor's native (usually landscape) layout and rely on the EXIF
// `Orientation` tag for viewers to rotate them for display. GD ignores that tag on decode and never
// writes it back out, so re-saving with imagejpeg() silently "bakes in" the wrong rotation unless we
// apply it to the pixels ourselves first. Sets $rotated=true if a transform was applied.
function casa_apply_exif_orientation($image, string $path, bool &$rotated)
{
    $rotated = false;
    if (!function_exists('exif_read_data')) return $image; // exif extension not available - skip, don't fail

    $exif = @exif_read_data($path);
    if (!$exif || empty($exif['Orientation'])) return $image;

    return casa_transform_by_orientation($image, (int)$exif['Orientation'], $rotated);
}

// Pixel transform for a given EXIF orientation value (1-8), split out from casa_apply_exif_orientation
// so it can be unit-tested without needing a real EXIF-tagged file on disk.
function casa_transform_by_orientation($image, int $orientation, bool &$rotated)
{
    $rotated = false;
    switch ($orientation) {
        case 2: // mirrored horizontally
            imageflip($image, IMG_FLIP_HORIZONTAL);
            $rotated = true;
            break;
        case 3: // upside down
            $image = imagerotate($image, 180, 0);
            $rotated = true;
            break;
        case 4: // mirrored vertically
            imageflip($image, IMG_FLIP_VERTICAL);
            $rotated = true;
            break;
        case 5: // mirrored + rotated 90 CW
            imageflip($image, IMG_FLIP_VERTICAL);
            $image = imagerotate($image, -90, 0);
            $rotated = true;
            break;
        case 6: // rotated 90 CW (most common on phones held in portrait)
            $image = imagerotate($image, -90, 0);
            $rotated = true;
            break;
        case 7: // mirrored + rotated 270 CW
            imageflip($image, IMG_FLIP_HORIZONTAL);
            $image = imagerotate($image, -90, 0);
            $rotated = true;
            break;
        case 8: // rotated 270 CW
            $image = imagerotate($image, 90, 0);
            $rotated = true;
            break;
    }
    return $image;
}

function casa_resize_image_in_place(string $path, string $ext): bool
{
    if (!extension_loaded('gd')) return false;

    $rotated = false;
    switch ($ext) {
        case 'jpg':
        case 'jpeg':
            $src = @imagecreatefromjpeg($path);
            if ($src !== false) $src = casa_apply_exif_orientation($src, $path, $rotated);
            break;
        case 'png':
            $src = @imagecreatefrompng($path);
            break;
        case 'webp':
            $src = function_exists('imagecreatefromwebp') ? @imagecreatefromwebp($path) : false;
            break;
        case 'gif':
            // Skipped on purpose: re-encoding would flatten animated GIFs to a single frame.
            return false;
        default:
            return false;
    }
    if ($src === false) return false;

    // Read dimensions from the (now correctly oriented) GD image rather than getimagesize(), since
    // a 90/270 rotation swaps width and height versus what the raw file reported.
    $width = imagesx($src);
    $height = imagesy($src);
    $longest = max($width, $height);

    if ($longest <= CASA_MAX_IMAGE_DIM) {
        if (!$rotated) { imagedestroy($src); return false; } // already small enough, nothing to fix
        // Small enough to skip the resize, but the orientation fix still needs to be written to disk.
        $ok = imagejpeg($src, $path, CASA_JPEG_QUALITY);
        imagedestroy($src);
        return $ok;
    }

    $scale = CASA_MAX_IMAGE_DIM / $longest;
    $newWidth = (int)round($width * $scale);
    $newHeight = (int)round($height * $scale);

    $dst = imagecreatetruecolor($newWidth, $newHeight);

    // Keep transparency for the formats that support it.
    if ($ext === 'png' || $ext === 'webp') {
        imagealphablending($dst, false);
        imagesavealpha($dst, true);
        $transparent = imagecolorallocatealpha($dst, 0, 0, 0, 127);
        imagefilledrectangle($dst, 0, 0, $newWidth, $newHeight, $transparent);
    }

    imagecopyresampled($dst, $src, 0, 0, 0, 0, $newWidth, $newHeight, $width, $height);

    $ok = false;
    switch ($ext) {
        case 'jpg':
        case 'jpeg':
            $ok = imagejpeg($dst, $path, CASA_JPEG_QUALITY);
            break;
        case 'png':
            $ok = imagepng($dst, $path, 6);
            break;
        case 'webp':
            $ok = function_exists('imagewebp') ? imagewebp($dst, $path, CASA_JPEG_QUALITY) : false;
            break;
    }

    imagedestroy($src);
    imagedestroy($dst);
    return $ok;
}
