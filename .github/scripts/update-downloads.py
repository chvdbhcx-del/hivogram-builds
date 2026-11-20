#!/usr/bin/env python3
"""Rewrites the downloads table in README.md (between the downloads markers) from this repo's releases.

Each row is the newest release that has that file, so a build where one target failed still leaves
the other rows on the newest working file. Usage: update-downloads.py <releases.json> <README.md>
"""
import json, re, sys

releases_path, readme_path = sys.argv[1], sys.argv[2]
releases = [r for r in json.load(open(releases_path)) if not r.get("draft")]
releases.sort(key=lambda r: r.get("published_at") or "", reverse=True)

def newest(tag_prefix, asset_re):
    for r in releases:
        if not r["tag_name"].startswith(tag_prefix):
            continue
        for a in r.get("assets", []):
            if re.search(asset_re, a["name"]):
                return r, a
    return None, None

def build_of(r):
    m = re.search(r"-v([0-9.]+)-build\.(\d+)$", r["tag_name"])
    return f"{m.group(1)}, сборка {m.group(2)}" if m else r["tag_name"]

def date_of(r):
    d = (r.get("published_at") or "")[:10]
    return f"{d[8:10]}.{d[5:7]}.{d[0:4]}" if d else ""

rows = []
def row(label, what, tag_prefix, asset_re, extra=None):
    r, a = newest(tag_prefix, asset_re)
    if not r:
        rows.append(f"| **{label}** | {what} | пока нет сборки | | |")
        return
    link = f"[Скачать]({a['browser_download_url']})"
    if extra:
        _, e = newest(tag_prefix, extra[1])
        if e:
            link += f" · [{extra[0]}]({e['browser_download_url']})"
    rows.append(f"| **{label}** | {what} | {link} | {build_of(r)} | {date_of(r)} |")

row("WEBA", "Windows 10/11, основная версия", "hivogram-v", r"-windows-x64-setup\.exe$")
row("APK", "Android 7+", "hivogram-v", r"-android\.apk$")
rows.append("| **сайт** | iPhone и браузер | [Открыть](https://hivogram.pages.dev) | всегда свежий | |")
row("UNI", "Windows 10/11, версия на Unigram", "unigram-v", r"\.msixbundle$", ("сертификат", r"\.cer$"))
row("Rust", "Windows, лёгкая версия для слабых ПК", "lite-v", r"-setup\.exe$")

table = "\n".join([
    "| | Что | Файл | Версия | Дата |",
    "|---|---|---|---|---|",
    *rows,
])
readme = open(readme_path, encoding="utf-8").read()
start, end = "<!-- downloads:start -->", "<!-- downloads:end -->"
if start not in readme or end not in readme:
    sys.exit("README.md has no downloads markers")
new = re.sub(re.escape(start) + r".*?" + re.escape(end), lambda _: f"{start}\n{table}\n{end}", readme, flags=re.S)
open(readme_path, "w", encoding="utf-8").write(new)
print(table)
