#!/usr/bin/env python3
"""Render a Markdown doc to a styled standalone HTML and (via headless Chrome) a PDF.

Usage:  python3 render-doc-pdf.py <input.md> [output_basename]
Outputs <basename>.html and <basename>.pdf next to the input (or at output_basename).

Deps: `markdown` (pip). PDF step uses Google Chrome --headless --print-to-pdf;
if Chrome isn't found it stops after the HTML (which is still useful).
"""
import sys, os, re, html, subprocess, shutil

try:
    import markdown
except ImportError:
    sys.exit("Need the `markdown` package: pip install markdown")

CHROME_CANDIDATES = [
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    shutil.which("google-chrome") or "",
    shutil.which("chromium") or "",
]

CSS = """
@page { size: A4; margin: 18mm 16mm; }
:root { --ink:#1a1f29; --muted:#5b6673; --line:#d9dee6; --accent:#3b5bdb; --soft:#f4f6fb; }
* { box-sizing: border-box; }
body { font-family: -apple-system, "Segoe UI", Helvetica, Arial, sans-serif; color:#1a1f29;
       line-height:1.55; max-width: 860px; margin: 0 auto; padding: 24px 28px; font-size: 14px; }
h1 { font-size: 26px; line-height:1.2; margin: 0 0 4px; letter-spacing:-0.01em; }
h2 { font-size: 19px; margin: 30px 0 10px; padding-bottom:6px; border-bottom:2px solid #3b5bdb; }
h3 { font-size: 15.5px; margin: 22px 0 8px; color:#27324a; }
p, li { font-size: 14px; }
a { color:#3b5bdb; text-decoration: none; }
code { font-family: "SF Mono", ui-monospace, Menlo, monospace; font-size: 12.5px;
       background:#f4f6fb; padding:1px 5px; border-radius:4px; }
pre { background:#f4f6fb; padding:12px 14px; border-radius:8px; overflow:auto; border:1px solid #e3e8f0; }
pre code { background:none; padding:0; }
table { border-collapse: collapse; width:100%; margin: 12px 0 18px; font-size: 12.5px; }
th, td { border:1px solid #d9dee6; padding:7px 9px; text-align:left; vertical-align:top; }
th { background:#eef2fb; font-weight:600; }
tr:nth-child(even) td { background:#fafbfe; }
blockquote { margin:12px 0; padding:8px 14px; border-left:3px solid #3b5bdb; background:#f4f6fb; color:#3a4656; }
hr { border:none; border-top:1px solid #d9dee6; margin:26px 0; }
strong { color:#101521; }
.docmeta { color:#5b6673; font-size:13px; margin-bottom:18px; }
"""
# (defensive: remove any stray non-ascii that slipped into the CSS literal)
CSS = re.sub(r"[^\x00-\x7f]", "", CSS)


def split_frontmatter(text):
    # Require a YAML fence delimited by lines that are exactly `---`.
    m = re.match(r"^---\s*\n(.*?)\n---\s*\n(.*)$", text, re.DOTALL)
    if not m:
        return {}, text
    meta = {}
    for line in m.group(1).splitlines():
        if ":" in line:
            k, v = line.split(":", 1)
            meta[k.strip()] = v.strip().strip('"')
    return meta, m.group(2)


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    src = sys.argv[1]
    base = sys.argv[2] if len(sys.argv) > 2 else os.path.splitext(src)[0]
    html_path, pdf_path = base + ".html", base + ".pdf"

    with open(src, encoding="utf-8") as f:
        raw = f.read()
    meta, body = split_frontmatter(raw)

    html_body = markdown.markdown(
        body, extensions=["tables", "fenced_code", "toc", "sane_lists", "attr_list"]
    )
    title = html.escape(meta.get("title", os.path.basename(base)))
    header = f"<h1>{title}</h1>"
    if meta.get("subtitle"):
        header += f'<div class="docmeta">{html.escape(meta["subtitle"])}</div>'
    doc = f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<title>{title}</title><style>{CSS}</style></head><body>{header}{html_body}</body></html>"""

    with open(html_path, "w", encoding="utf-8") as f:
        f.write(doc)
    print(f"HTML  -> {html_path}")

    chrome = next((c for c in CHROME_CANDIDATES if c and os.path.exists(c)), None)
    if not chrome:
        print("Chrome not found; skipped PDF. Open the HTML and print to PDF manually.")
        return
    subprocess.run(
        [chrome, "--headless", "--disable-gpu", "--no-pdf-header-footer",
         f"--print-to-pdf={pdf_path}", "file://" + os.path.abspath(html_path)],
        check=True, capture_output=True,
    )
    print(f"PDF   -> {pdf_path}")


if __name__ == "__main__":
    main()
