#!/usr/bin/env python3
"""Rewrites the downloads table in README.md (between the downloads markers) from this repo's releases.

Links point at the files of the shared release v<date> (see release-all.sh). Usage: update-downloads.py <releases.json> <README.md>
"""
import json, re, sys

releases_path, readme_path = sys.argv[1], sys.argv[2]
releases = [r for r in json.load(open(releases_path)) if not r.get("draft") and not r.get("prerelease")]
releases.sort(key=lambda r: r.get("published_at") or "", reverse=True)

# the one release with every version (.github/scripts/release-all.sh)
shared = next((r for r in releases if r["tag_name"] == "hivogram-latest" or re.match(r"^(hivogram-all-|all-v|v[0-9]{4}\.)", r["tag_name"])), None)

def newest(_prefix, asset_re):
    for a in (shared or {}).get("assets", []):
        if re.search(asset_re, a["name"]):
            # /releases/latest/download/… survives the shared release being re-made under a new tag
            a = dict(a, browser_download_url=re.sub(r"/releases/download/[^/]+/", "/releases/latest/download/", a["browser_download_url"]))
            return a, a
    return None, None

def build_of(a):
    m = re.search(r"-([0-9.]+)-build\.(\d+)", a["name"])
    return f"{m.group(1)}, сборка {m.group(2)}" if m else ""

def date_of(a):
    d = (a.get("updated_at") or a.get("created_at") or "")[:10]
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

row("WEBA", "Windows 10/11, основная версия", "", r"^Hivogram-WEBA-.*-setup\.exe$")
row("APK", "Android 7+", "", r"^Hivogram-APK-.*\.apk$")
if newest("", r"^Hivogram-Native-.*\.apk$")[0]:
    row("Native", "Android 7+, нативный Hivogram", "", r"^Hivogram-Native-.*\.apk$")
rows.append("| **сайт** | iPhone и браузер | [Открыть](https://hivogram.pages.dev) | всегда свежий | |")
if newest("", r"^Hivogram-UNI-.*-setup\.exe$")[0]:
    row("UNI", "Windows 10/11, версия на Unigram", "", r"^Hivogram-UNI-.*-setup\.exe$")
else:
    row("UNI", "Windows 10/11, версия на Unigram", "", r"^Hivogram-UNI-.*\.msixbundle$", ("сертификат", r"^Hivogram-UNI\.cer$"))
row("Rust", "Windows, лёгкая версия для слабых ПК", "", r"^Hivogram-Rust-.*-setup\.exe$")

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
