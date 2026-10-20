"""Bundles preview.html with the engine and captioned plan into one page.

Usage: python3 build_preview.py <outDir>   (run captions.py first)
"""

import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
out = Path(sys.argv[1])
page = (HERE / "preview.html").read_text()
page = page.replace("/*ENGINE*/", (HERE / "engine.js").read_text())
page = page.replace("/*DAYS*/", (out / "days.captioned.json").read_text())
(out / "preview.html").write_text(page)
print("wrote", out / "preview.html")
