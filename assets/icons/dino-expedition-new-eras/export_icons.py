"""Export generated icons at the requested size and centered 85% framing."""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent

def export(source, destination):
    image = Image.open(source).convert("RGBA")
    # Ignore nearly invisible pixels when measuring the visible silhouette.
    bounds = image.getchannel("A").point(lambda value: 255 if value > 8 else 0).getbbox()
    if not bounds:
        raise ValueError(f"Empty icon: {source}")
    left, top, right, bottom = bounds
    bounds = (max(0, left - 3), max(0, top - 3),
              min(image.width, right + 3), min(image.height, bottom + 3))
    subject = image.crop(bounds)
    subject.thumbnail((435, 435), Image.Resampling.LANCZOS)
    result = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    result.alpha_composite(subject, ((512 - subject.width) // 2, (512 - subject.height) // 2))
    result.save(destination, optimize=True)

if __name__ == "__main__":
    sources = json.loads((ROOT / "sources.json").read_text())
    for entry in sources:
        export(entry["source"], ROOT / f'{entry["key"]}.png')
    print(f"Exported {len(sources)} icons at 512×512 with centered framing.")
