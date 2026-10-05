"""本批验收拼版；不修改运行图片。"""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
FONT = ImageFont.truetype(str(ROOT / "godot/assets/fonts/NotoSansSC.ttf"), 22)


def tile(canvas, path, box):
    with Image.open(path) as source:
        thumb = source.convert("RGBA").convert("RGB")
        thumb.thumbnail((box[2], box[3]), Image.Resampling.LANCZOS)
        canvas.paste(thumb, (box[0] + (box[2] - thumb.width) // 2,
                            box[1] + (box[3] - thumb.height) // 2))


def comparisons(pack):
    units = json.loads((ROOT / f"godot/assets/redrawn/prompts-{pack}.json").read_text())["units"]
    selected = [u for u in units if u.get("selected")]
    for page, start in enumerate(range(0, len(selected), 4), 1):
        canvas = Image.new("RGB", (1280, 1080), "#20232b")
        draw = ImageDraw.Draw(canvas)
        for i, unit in enumerate(selected[start:start + 4]):
            x, y = (i % 2) * 640, (i // 2) * 540
            draw.text((x + 12, y + 8), f'{unit["name"]} · 原版 / 重绘', font=FONT, fill="#eee7d7")
            tile(canvas, ROOT / unit["reference"], (x + 6, y + 42, 310, 486))
            tile(canvas, ROOT / unit["output"], (x + 322, y + 42, 310, 486))
        canvas.save(OUT / f"review/{pack}-comparison-{page:02d}.jpg", quality=94)
    print(f"COMPARISONS {pack} units={len(selected)} pages={page}")


def screenshots(pack, category):
    paths = sorted((OUT / f"final-shots/{pack}").glob(f"*{category}*.png"))
    for page, start in enumerate(range(0, len(paths), 4), 1):
        canvas = Image.new("RGB", (1280, 864), "#20232b")
        draw = ImageDraw.Draw(canvas)
        for i, path in enumerate(paths[start:start + 4]):
            x, y = (i % 2) * 640, (i // 2) * 432
            draw.text((x + 8, y + 4), path.stem, font=FONT, fill="#eee7d7")
            tile(canvas, path, (x, y + 32, 640, 400))
        canvas.save(OUT / f"review/{pack}-{category}-{page:02d}.jpg", quality=94)
    print(f"SCREENSHOTS {pack} category={category} count={len(paths)}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("pack", choices=["wave5", "wave6", "wave7", "wave8"])
    parser.add_argument("--screens", choices=["deck", "battle", "portraits", "formation"])
    args = parser.parse_args()
    (OUT / "review").mkdir(exist_ok=True)
    if args.screens:
        screenshots(args.pack, args.screens)
    else:
        comparisons(args.pack)
