#!/usr/bin/env python3
"""Render CHARTER.md → ProjectOptimizer-Charter.generated.pdf via Chrome headless.

Run after editing CHARTER.md: `python3 render_pdf.py`
Output filename uses `.generated.pdf` to signal it is a derived artifact —
do not edit the PDF directly; CHARTER.md is the source of truth.
"""

import os
import subprocess
import sys
from pathlib import Path

import markdown

HERE = Path(__file__).parent
MD_PATH = HERE / "CHARTER.md"
HTML_PATH = HERE / "_charter.html"
PDF_PATH = HERE / "ProjectOptimizer-Charter.generated.pdf"

CSS = """
@page { size: letter; margin: 0.75in 0.85in; }
html { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
body {
  font-family: -apple-system, "Helvetica Neue", Helvetica, Arial, sans-serif;
  font-size: 10.5pt;
  line-height: 1.45;
  color: #1d1f21;
  max-width: 100%;
}
h1 {
  font-size: 22pt;
  border-bottom: 2px solid #1d1f21;
  padding-bottom: 0.25rem;
  margin-top: 0;
}
h2 {
  font-size: 15pt;
  margin-top: 1.6em;
  padding-top: 0.3em;
  border-top: 1px solid #d0d4d8;
}
h3 {
  font-size: 12pt;
  margin-top: 1.2em;
  color: #2a3441;
}
h4 { font-size: 11pt; margin-top: 1em; }
p, li { margin: 0.4em 0; }
ul, ol { padding-left: 1.4em; margin: 0.5em 0; }
li { margin: 0.25em 0; }
strong { color: #0b1320; }
code {
  font-family: "SF Mono", Menlo, Consolas, monospace;
  font-size: 9.5pt;
  background: #f3f4f6;
  border: 1px solid #e2e4e8;
  border-radius: 3px;
  padding: 0.05em 0.35em;
}
pre {
  background: #f7f8fa;
  border: 1px solid #e2e4e8;
  border-radius: 6px;
  padding: 0.9em 1em;
  overflow: auto;
  page-break-inside: avoid;
}
pre code {
  background: transparent;
  border: 0;
  padding: 0;
  font-size: 9pt;
  line-height: 1.4;
}
table {
  border-collapse: collapse;
  width: 100%;
  margin: 0.8em 0;
  font-size: 9.5pt;
  page-break-inside: avoid;
}
th, td {
  border: 1px solid #d0d4d8;
  padding: 0.45em 0.55em;
  text-align: left;
  vertical-align: top;
}
th {
  background: #f2f4f7;
  font-weight: 600;
}
tr:nth-child(2n) td { background: #fafbfc; }
blockquote {
  border-left: 3px solid #c2c8d0;
  padding-left: 1em;
  color: #4a5260;
  margin: 0.8em 0;
}
hr { border: 0; border-top: 1px solid #d8dbe0; margin: 1.4em 0; }
a { color: #1f4d8a; text-decoration: none; }
em { color: #2a3441; }
.callout {
  background: #fff7e6;
  border-left: 3px solid #d99b2e;
  padding: 0.6em 0.9em;
  margin: 0.8em 0;
  border-radius: 0 4px 4px 0;
}
@media print {
  h2, h3, h4 { page-break-after: avoid; }
  table, pre { page-break-inside: avoid; }
  tr { page-break-inside: avoid; }
}
"""


def main() -> int:
    md_text = MD_PATH.read_text(encoding="utf-8")
    html_body = markdown.markdown(
        md_text,
        extensions=["tables", "fenced_code", "sane_lists", "toc"],
        output_format="html5",
    )

    html = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>ProjectOptimizer Charter</title>
<style>{CSS}</style>
</head>
<body>
{html_body}
</body>
</html>
"""
    HTML_PATH.write_text(html, encoding="utf-8")

    chrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    if not Path(chrome).exists():
        print(f"Chrome not found at {chrome}", file=sys.stderr)
        return 1

    file_url = f"file://{HTML_PATH.resolve()}"
    cmd = [
        chrome,
        "--headless=new",
        "--disable-gpu",
        "--no-sandbox",
        "--no-pdf-header-footer",
        f"--print-to-pdf={PDF_PATH}",
        "--print-to-pdf-no-header",
        "--virtual-time-budget=2000",
        file_url,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    if result.returncode != 0:
        print("Chrome stderr:", result.stderr, file=sys.stderr)
        return result.returncode

    if not PDF_PATH.exists():
        print("PDF not produced", file=sys.stderr)
        return 2

    size_kb = PDF_PATH.stat().st_size // 1024
    print(f"Wrote {PDF_PATH.name} ({size_kb} KB)")

    try:
        HTML_PATH.unlink()
    except OSError:
        pass

    return 0


if __name__ == "__main__":
    sys.exit(main())
