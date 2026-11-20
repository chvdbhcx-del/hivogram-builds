#!/usr/bin/env bash
# release-all.sh: keeps ONE release «Hivogram — все версии» (tag v<date>, marked Latest: apps and links
# find it as /releases/latest) holding the newest
# file of every version: WEBA (Windows), APK (Android), UNI (Unigram), Rust (Hivogram Lite), plus the сайт link.
# Every app still publishes its own release (hivogram-v…, lite-v…, unigram-v…): installed apps update from those.
# Of those only the newest per app is kept, older ones are deleted. Needs GH_TOKEN, GH_REPO; UPDATE_SIGNING_KEY optional.
set -euo pipefail
# A new tag each time, v<year>.<monthday>.<hourmin>: GitHub lists it above the app releases (unigram-v…, lite-v…,
# hivogram-v…), and no app updater takes it for its own.
TAG="v$(date -u +%Y.%-m%d.%-H%M)"
OLD_RE='^(hivogram-latest|hivogram-all-[0-9.]+|all-v[0-9.]+|v[0-9]{4}\.[0-9.]+)$'
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
gh api "repos/$GH_REPO/releases?per_page=100" > "$work/releases.json"

# plan.tsv: <label> <source tag> <source asset> <new name>   (newest release that has that file)
python3 - "$work/releases.json" > "$work/plan.tsv" <<'PY'
import json, re, sys
rs = [r for r in json.load(open(sys.argv[1])) if not r["draft"]]
rs.sort(key=lambda r: r.get("published_at") or "", reverse=True)
def pick(label, prefix, pattern, name):
    for r in rs:
        m = re.match(re.escape(prefix) + r"v([0-9.]+)-build\.(\d+)$", r["tag_name"])
        if not m: continue
        for a in r["assets"]:
            if re.search(pattern, a["name"]):
                print("\t".join([label, r["tag_name"], a["name"], name.format(v=m.group(1), b=m.group(2))]))
                return
pick("WEBA", "hivogram-", r"-windows-x64-setup\.exe$", "Hivogram-WEBA-{v}-build.{b}-setup.exe")
pick("APK",  "hivogram-", r"-android\.apk$",            "Hivogram-APK-{v}-build.{b}.apk")
pick("UNI",  "unigram-",  r"-setup\.exe$",              "Hivogram-UNI-{v}-build.{b}-setup.exe")
pick("UNI",  "unigram-",  r"\.msixbundle$",             "Hivogram-UNI-{v}-build.{b}-x64.msixbundle")
pick("UNI",  "unigram-",  r"\.cer$",                    "Hivogram-UNI.cer")
pick("Rust", "lite-",     r"-setup\.exe$",              "Hivogram-Rust-{v}-build.{b}-setup.exe")
PY
cat "$work/plan.tsv"

want=$(cut -f4 "$work/plan.tsv" | LC_ALL=C sort | tr '\n' ' ')
have=$(python3 -c "
import json,sys,re
for r in json.load(open('$work/releases.json')):
    if r['tag_name']=='hivogram-latest' or re.match(r'^(hivogram-all-|all-v|v[0-9]{4}\.)', r['tag_name']):
        print(' '.join(sorted(a['name'] for a in r['assets'] if not a['name'].startswith('SHA256SUMS')))); break
" | tr -d '\n')
if [ "${want% }" = "${have}" ] && [ "${FORCE:-false}" != true ]; then
  echo "Общий релиз уже свежий"
else
  mkdir "$work/out"
  while IFS=$'\t' read -r label src asset name; do
    gh release download "$src" --pattern "$asset" --dir "$work/dl" --clobber
    mv "$work/dl/$asset" "$work/out/$name"
  done < "$work/plan.tsv"
  (cd "$work/out" && sha256sum * > SHA256SUMS.txt && "$here/sign-sums.sh" SHA256SUMS.txt "$TAG")

  line() { grep -P "^$1\t" "$work/plan.tsv" | head -n1 | cut -f4; }
  ver() { sed -E 's/^Hivogram-[A-Za-z]+-([0-9.]+)-build\.([0-9]+).*/\1, сборка \2/' <<<"$1"; }
  {
    echo "Все версии Hivogram в одном месте. Ключи Telegram вшиты, вводить ничего не надо. Дальше каждая версия обновляется сама."
    echo
    w=$(line WEBA); [ -n "$w" ] && echo "- **WEBA** ($(ver "$w")): \`$w\` — Windows 10/11, основная версия. Если SmartScreen ругается: «Подробнее» → «Выполнить в любом случае»."
    a=$(line APK);  [ -n "$a" ] && echo "- **APK** ($(ver "$a")): \`$a\` — Android 7+."
    echo "- **сайт**: https://hivogram.pages.dev — iPhone и браузер. В Safari → «Поделиться» → «На экран „Домой“»."
    u=$(grep -P "^UNI\t" "$work/plan.tsv" | cut -f4 | grep -E 'setup\.exe$' || true)
    m=$(grep -P "^UNI\t" "$work/plan.tsv" | cut -f4 | grep -E 'msixbundle$' || true)
    if [ -n "$u" ]; then echo "- **UNI** ($(ver "$u")): \`$u\` — Windows 10/11, версия на Unigram, ставится в один клик."
    elif [ -n "$m" ]; then echo "- **UNI** ($(ver "$m")): \`$m\` — Windows 10/11, версия на Unigram. Сначала один раз поставь \`Hivogram-UNI.cer\`: «Установить сертификат» → «Локальный компьютер» → «Доверенные лица», потом двойной клик по \`.msixbundle\`."; fi
    r=$(line Rust); [ -n "$r" ] && echo "- **Rust** ($(ver "$r")): \`$r\` — Hivogram Lite, лёгкая версия для слабых ПК."
  } > "$work/notes.md"
  cat "$work/notes.md"

  # Made anew each time it changes, so it stays on top of the list; then the previous one is deleted.
  gh release create "$TAG" "$work"/out/* --title "Hivogram — все версии" --notes-file "$work/notes.md" --latest \
    --target "$(gh api "repos/$GH_REPO" --jq .default_branch)"
  # the previous shared release goes
  for old in $(gh api "repos/$GH_REPO/releases?per_page=100" --jq '.[].tag_name' | grep -E "$OLD_RE" | grep -vx "$TAG"); do
    gh release delete "$old" --yes --cleanup-tag
  done
fi

# Only the newest release of each app stays (installed apps update from it), plus any release a file of the shared
# one still comes from (e.g. the APK when the newest build's Android job failed); older builds go.
python3 - "$work/releases.json" "$work/plan.tsv" > "$work/old.txt" <<'PY'
import json, re, sys
rs = [r for r in json.load(open(sys.argv[1])) if not r["draft"]]
used = {l.split("\t")[1] for l in open(sys.argv[2]) if l.strip()}  # still the source of a file in the shared one
rs.sort(key=lambda r: r.get("published_at") or "", reverse=True)
seen = set()
for r in rs:
    m = re.match(r"(hivogram|lite|unigram)-v[0-9.]+-build\.\d+$", r["tag_name"])
    if not m: continue
    if m.group(1) in seen and r["tag_name"] not in used: print(r["tag_name"])
    seen.add(m.group(1))
PY
while read -r old; do [ -n "$old" ] && { echo "Удаляю старую сборку $old"; gh release delete "$old" --yes --cleanup-tag; }; done < "$work/old.txt"
# The app releases must never hold «Latest»: that is the shared one.
cur=$(gh api "repos/$GH_REPO/releases?per_page=100" --jq '.[].tag_name' | grep -E "$OLD_RE" | head -n1)
[ -n "$cur" ] && gh release edit "$cur" --latest >/dev/null
