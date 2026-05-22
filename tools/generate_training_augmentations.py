from __future__ import annotations

import argparse
import hashlib
import json
import random
import re
import unicodedata
from dataclasses import dataclass
from difflib import SequenceMatcher
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps


IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}

FOLDER_OVERRIDES = {
    "Ayan (god of music)": "ayan",
    "Drummers' Return": "drummer's_return",
    "Ijo (Africa Dances)": "ijo(african_dances)",
    "Ola (I/4)": "ola(1_4)",
    "The Adanma Masquerade": "the_adanma_masqeurade",
}

@dataclass(frozen=True)
class Variant:
    mode: str
    angle: float
    scale: float
    tx: float
    ty: float
    perspective_x: float
    perspective_y: float
    crop: float
    brightness: float = 1.0
    contrast: float = 1.0
    color: float = 1.0
    sharpness: float = 1.0
    obstruction: float = 0.0
    blur: float = 0.0


VARIANTS = [
    Variant("original", 0, 1.00, 0.00, 0.00, 0.00, 0.00, 1.00),
    Variant("screenshot", 0, 0.96, 0.00, 0.00, 0.01, 0.01, 1.00, contrast=0.96, sharpness=0.92),
    Variant("darker", 0, 1.02, 0.00, 0.00, 0.00, 0.00, 1.00, brightness=0.72, contrast=1.08),
    Variant("brighter", 0, 1.02, 0.00, 0.00, 0.00, 0.00, 1.00, brightness=1.26, contrast=0.96),
    Variant("low_light", -2, 1.04, 0.02, -0.02, 0.02, 0.00, 1.00, brightness=0.58, contrast=1.14),
    Variant("bright_room", 2, 1.04, -0.02, 0.02, -0.02, 0.00, 1.00, brightness=1.38, contrast=0.92),
    Variant("scene", -22, 0.84, -0.12, -0.08, -0.14, 0.04, 1.00),
    Variant("scene", -15, 0.92, 0.10, -0.10, 0.10, -0.03, 1.00),
    Variant("scene", -8, 1.04, -0.08, 0.08, -0.08, 0.06, 1.00),
    Variant("scene", 8, 0.88, 0.13, 0.03, 0.14, 0.02, 1.00),
    Variant("scene", 18, 1.08, -0.10, -0.04, -0.10, -0.06, 1.00),
    Variant("scene", 24, 0.95, 0.05, 0.11, 0.12, -0.08, 1.00),
    Variant("far", -4, 0.72, -0.10, 0.06, -0.06, 0.02, 1.00, sharpness=0.96),
    Variant("far", 5, 0.78, 0.12, -0.04, 0.08, -0.03, 1.00, brightness=0.92),
    Variant("far", 0, 0.68, 0.00, 0.10, 0.00, 0.00, 1.00, brightness=1.10),
    Variant("upright", 0, 0.92, -0.12, 0.00, 0.00, 0.00, 1.00),
    Variant("upright", 0, 1.08, 0.12, 0.00, 0.00, 0.00, 0.88),
    Variant("upright", 0, 1.22, 0.00, -0.12, 0.00, 0.00, 0.76),
    Variant("upright", 0, 1.32, 0.00, 0.12, 0.00, 0.00, 0.68),
    Variant("upright", 0, 1.45, -0.14, 0.12, 0.00, 0.00, 0.58),
    Variant("crop", -4, 1.10, 0.00, 0.00, -0.03, 0.02, 0.90),
    Variant("crop", 5, 1.18, -0.06, 0.04, 0.04, -0.03, 0.84),
    Variant("crop", -9, 1.26, 0.07, -0.06, -0.06, 0.05, 0.78),
    Variant("crop", 11, 1.34, -0.10, -0.08, 0.08, -0.05, 0.72),
    Variant("crop", 0, 1.45, 0.11, 0.08, 0.00, 0.00, 0.66),
    Variant("zoom", -3, 1.54, -0.09, 0.07, -0.03, 0.04, 0.60),
    Variant("zoom", 4, 1.68, 0.08, -0.08, 0.04, -0.04, 0.54),
    Variant("zoom", 0, 1.82, 0.00, 0.00, 0.02, 0.02, 0.48),
    Variant("zoom_dark", -5, 1.58, -0.11, 0.08, -0.02, 0.03, 0.58, brightness=0.70, contrast=1.10),
    Variant("zoom_bright", 5, 1.62, 0.10, -0.08, 0.03, -0.03, 0.56, brightness=1.22, contrast=0.98),
    Variant("close", -2, 1.92, -0.16, 0.00, -0.02, 0.02, 0.44, sharpness=1.08),
    Variant("close", 3, 2.05, 0.16, 0.00, 0.02, -0.02, 0.40, brightness=0.95, sharpness=1.08),
    Variant("close", 0, 2.16, 0.00, -0.14, 0.00, 0.00, 0.36, brightness=1.08),
    Variant("close", 0, 2.28, 0.00, 0.14, 0.00, 0.00, 0.34, contrast=1.08),
    Variant("obstructed", -6, 1.12, -0.06, 0.03, -0.04, 0.02, 0.86, obstruction=0.10),
    Variant("obstructed", 7, 1.18, 0.06, -0.03, 0.04, -0.02, 0.82, obstruction=0.12, brightness=0.88),
    Variant("obstructed", 0, 1.32, -0.10, -0.08, 0.00, 0.00, 0.70, obstruction=0.14, brightness=1.12),
    Variant("obstructed", 4, 1.48, 0.10, 0.08, 0.03, 0.00, 0.62, obstruction=0.16),
    Variant("soft", -3, 1.06, 0.04, 0.04, -0.02, 0.02, 0.92, brightness=0.90, contrast=0.92, blur=0.35),
    Variant("soft", 3, 1.12, -0.04, -0.04, 0.02, -0.02, 0.88, brightness=1.14, contrast=0.94, blur=0.25),
]


def title_slug(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode("ascii")
    normalized = normalized.lower().replace("&", "and")
    normalized = re.sub(r"\s+", "_", normalized.strip())
    normalized = re.sub(r"[^a-z0-9_()']+", "_", normalized)
    normalized = re.sub(r"_+", "_", normalized).strip("_")
    normalized = normalized.replace("_(", "(").replace(")_", ")")
    return normalized


def match_key(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", title_slug(value))


def find_training_folder(title: str, folders: list[Path]) -> Path:
    by_name = {folder.name: folder for folder in folders}
    override = FOLDER_OVERRIDES.get(title)
    if override:
        if override not in by_name:
            raise ValueError(f"Override for {title!r} points to missing folder: {override!r}")
        return by_name[override]

    exact = title_slug(title)
    if exact in by_name:
        return by_name[exact]

    key = match_key(title)
    scored = sorted(
        (
            (SequenceMatcher(None, key, match_key(folder.name)).ratio(), folder)
            for folder in folders
        ),
        reverse=True,
        key=lambda item: item[0],
    )
    if scored and scored[0][0] >= 0.82:
        return scored[0][1]

    raise ValueError(f"No matching training folder for artwork title: {title!r}")


def image_to_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        image = ImageOps.exif_transpose(image)
        return image.convert("RGBA")


def perspective_coefficients(width: int, height: int, px: float, py: float) -> tuple[float, ...]:
    x_offset = width * abs(px)
    y_offset = height * abs(py)

    if px >= 0:
        target = [
            (x_offset, y_offset),
            (width - x_offset * 0.25, 0),
            (width - x_offset * 0.25, height),
            (x_offset, height - y_offset),
        ]
    else:
        target = [
            (x_offset * 0.25, 0),
            (width - x_offset, y_offset),
            (width - x_offset, height - y_offset),
            (x_offset * 0.25, height),
        ]

    if py < 0:
        target = [
            (target[0][0], y_offset),
            (target[1][0], y_offset),
            (target[2][0], height),
            (target[3][0], height),
        ]

    source = [(0, 0), (width, 0), (width, height), (0, height)]
    matrix = []
    for (x, y), (u, v) in zip(target, source):
        matrix.append([x, y, 1, 0, 0, 0, -u * x, -u * y])
        matrix.append([0, 0, 0, x, y, 1, -v * x, -v * y])

    values = [coord for point in source for coord in point]

    # Gaussian elimination for the 8 perspective coefficients.
    for column in range(8):
        pivot = max(range(column, 8), key=lambda row: abs(matrix[row][column]))
        matrix[column], matrix[pivot] = matrix[pivot], matrix[column]
        values[column], values[pivot] = values[pivot], values[column]

        pivot_value = matrix[column][column]
        if abs(pivot_value) < 1e-12:
            continue

        for idx in range(column, 8):
            matrix[column][idx] /= pivot_value
        values[column] /= pivot_value

        for row in range(8):
            if row == column:
                continue
            factor = matrix[row][column]
            for idx in range(column, 8):
                matrix[row][idx] -= factor * matrix[column][idx]
            values[row] -= factor * values[column]

    return tuple(values)


def make_background(image: Image.Image) -> Image.Image:
    width, height = image.size
    red, green, blue = image.convert("RGB").resize((1, 1), Image.Resampling.BICUBIC).getpixel((0, 0))
    matte = (int(red * 0.75), int(green * 0.75), int(blue * 0.75), 255)
    return Image.new("RGBA", (width, height), matte)


def crop_source(image: Image.Image, variant: Variant, rng: random.Random) -> Image.Image:
    if variant.mode == "scene" or variant.crop >= 0.995:
        return image

    width, height = image.size
    crop_width = max(16, int(width * variant.crop))
    crop_height = max(16, int(height * variant.crop))

    jitter_x = rng.uniform(-0.035, 0.035) * width
    jitter_y = rng.uniform(-0.035, 0.035) * height
    center_x = width / 2 + variant.tx * width * 0.55 + jitter_x
    center_y = height / 2 + variant.ty * height * 0.55 + jitter_y

    left = int(max(0, min(width - crop_width, center_x - crop_width / 2)))
    top = int(max(0, min(height - crop_height, center_y - crop_height / 2)))
    cropped = image.crop((left, top, left + crop_width, top + crop_height))
    return cropped.resize((width, height), Image.Resampling.LANCZOS)


def alpha_composite_clipped(canvas: Image.Image, subject: Image.Image, x: int, y: int) -> None:
    canvas_width, canvas_height = canvas.size
    left = max(0, x)
    top = max(0, y)
    right = min(canvas_width, x + subject.width)
    bottom = min(canvas_height, y + subject.height)

    if left >= right or top >= bottom:
        return

    source_left = left - x
    source_top = top - y
    source = subject.crop((source_left, source_top, source_left + right - left, source_top + bottom - top))
    canvas.alpha_composite(source, (left, top))


def apply_lighting(image: Image.Image, variant: Variant) -> Image.Image:
    result = ImageEnhance.Brightness(image).enhance(variant.brightness)
    result = ImageEnhance.Contrast(result).enhance(variant.contrast)
    result = ImageEnhance.Color(result).enhance(variant.color)
    result = ImageEnhance.Sharpness(result).enhance(variant.sharpness)
    if variant.blur > 0:
        result = result.filter(ImageFilter.GaussianBlur(radius=variant.blur))
    return result


def add_partial_obstruction(image: Image.Image, strength: float, rng: random.Random) -> Image.Image:
    if strength <= 0:
        return image

    width, height = image.size
    overlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    side = rng.choice(["left", "right", "top", "bottom"])
    color_base = rng.randint(18, 54)
    alpha = rng.randint(92, 138)
    fill = (color_base, color_base, color_base, alpha)

    if side in {"left", "right"}:
        block_width = int(width * rng.uniform(strength * 0.65, strength * 1.25))
        block_height = int(height * rng.uniform(0.26, 0.58))
        top = int(height * rng.uniform(0.04, 0.68))
        if side == "left":
            box = (-int(block_width * 0.25), top, block_width, top + block_height)
        else:
            box = (width - block_width, top, width + int(block_width * 0.25), top + block_height)
    else:
        block_width = int(width * rng.uniform(0.28, 0.68))
        block_height = int(height * rng.uniform(strength * 0.65, strength * 1.25))
        left = int(width * rng.uniform(0.04, 0.68))
        if side == "top":
            box = (left, -int(block_height * 0.25), left + block_width, block_height)
        else:
            box = (left, height - block_height, left + block_width, height + int(block_height * 0.25))

    draw.rounded_rectangle(box, radius=max(4, int(min(width, height) * 0.025)), fill=fill)
    overlay = overlay.filter(ImageFilter.GaussianBlur(radius=max(1.0, min(width, height) * 0.006)))
    return Image.alpha_composite(image.convert("RGBA"), overlay).convert("RGB")


def augment(image: Image.Image, variant: Variant, seed: int) -> Image.Image:
    rng = random.Random(seed)
    width, height = image.size
    canvas = make_background(image)
    base = crop_source(image, variant, rng)

    scale_jitter = 1 + rng.uniform(-0.025, 0.025)
    scaled_width = max(8, int(width * variant.scale * scale_jitter))
    scaled_height = max(8, int(height * variant.scale * scale_jitter))
    subject = base.resize((scaled_width, scaled_height), Image.Resampling.LANCZOS)

    coeffs = perspective_coefficients(
        scaled_width,
        scaled_height,
        variant.perspective_x + rng.uniform(-0.012, 0.012),
        variant.perspective_y + rng.uniform(-0.012, 0.012),
    )
    subject = subject.transform(
        (scaled_width, scaled_height),
        Image.Transform.PERSPECTIVE,
        coeffs,
        Image.Resampling.BICUBIC,
    )

    angle = variant.angle + rng.uniform(-1.5, 1.5)
    subject = subject.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)

    x = int((width - subject.width) / 2 + width * (variant.tx + rng.uniform(-0.015, 0.015)))
    y = int((height - subject.height) / 2 + height * (variant.ty + rng.uniform(-0.015, 0.015)))
    alpha_composite_clipped(canvas, subject, x, y)

    result = canvas.convert("RGB")
    result = apply_lighting(result, variant)
    result = add_partial_obstruction(result, variant.obstruction, rng)
    return result


def stable_seed(folder_name: str, variant_index: int) -> int:
    digest = hashlib.sha256(f"{folder_name}:{variant_index}".encode("utf-8")).digest()
    return int.from_bytes(digest[:4], "big")


def load_artworks(repo_root: Path) -> list[dict]:
    metadata_path = repo_root / "assets" / "data" / "artworks.json"
    return json.loads(metadata_path.read_text(encoding="utf-8"))


def existing_training_images(folder: Path) -> list[Path]:
    return [
        path
        for path in folder.iterdir()
        if path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate augmented artwork training images.")
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--variants", type=int, default=len(VARIANTS))
    parser.add_argument("--quality", type=int, default=92)
    parser.add_argument("--force", action="store_true", help="Overwrite existing aug_XX.jpg files.")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    repo_root = args.repo_root.resolve()
    training_root = repo_root / "assets" / "training"
    folders = sorted(path for path in training_root.iterdir() if path.is_dir())
    artworks = load_artworks(repo_root)

    if args.variants < 1 or args.variants > len(VARIANTS):
        raise ValueError(f"Variants must be between 1 and {len(VARIANTS)}.")

    if len(artworks) != 50:
        raise ValueError(f"Expected 50 artworks in metadata, found {len(artworks)}.")
    if len(folders) != 50:
        raise ValueError(f"Expected 50 training folders, found {len(folders)}.")

    mapping: list[tuple[dict, Path]] = []
    used_folders: set[Path] = set()
    for artwork in artworks:
        folder = find_training_folder(artwork["title"], folders)
        if folder in used_folders:
            raise ValueError(f"Training folder matched more than once: {folder}")
        source = repo_root / artwork["image"]
        if not source.exists():
            raise FileNotFoundError(source)
        mapping.append((artwork, folder))
        used_folders.add(folder)

    if len(used_folders) != len(folders):
        missing = sorted(folder.name for folder in set(folders) - used_folders)
        raise ValueError(f"Training folders without metadata match: {missing}")

    print(f"Mapped {len(mapping)} artwork images to {len(folders)} training folders.")

    if args.dry_run:
        for artwork, folder in mapping:
            print(f"{Path(artwork['image']).name:10} -> {folder.name}")
        return 0

    total_created = 0
    for artwork, folder in mapping:
        source = repo_root / artwork["image"]
        image = image_to_rgba(source)

        for index, variant in enumerate(VARIANTS[: args.variants], start=1):
            output = folder / f"aug_{index:02d}.jpg"
            if output.exists() and not args.force:
                continue

            augmented = augment(image, variant, seed=stable_seed(folder.name, index))
            augmented.save(output, "JPEG", quality=args.quality, optimize=True, progressive=True)
            total_created += 1

        count = len(existing_training_images(folder))
        print(f"{folder.name}: {count} image files")

    print(f"Created or updated {total_created} augmented images.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
