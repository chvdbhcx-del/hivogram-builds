#!/usr/bin/env bash
# release-all.sh: keeps ONE release «Hivogram — все версии» (tag v<date>, marked Latest: apps and links
# find it as /releases/latest) holding the newest
# file of every version: WEBA (Windows), APK (Android), Native (native Android), UNI (Unigram), Rust (Hivogram Lite),
# plus the сайт link. Every app still publishes its own release (hivogram-v…, lite-v…, unigram-v…, android-v…):
# installed apps update from those. Of those only the newest per app is kept (native Android: the last 3), older
# ones are deleted. Needs GH_TOKEN, GH_REPO; UPDATE_SIGNING_KEY (required: unsigned, nothing is published).
set -euo pipefail
# A new tag each time, v<year>.<monthday>.<hourmin>: GitHub lists it above the app releases (unigram-v…, lite-v…,
# hivogram-v…), and no app updater takes it for its own.
TAG="v$(date -u +%Y.%-m%d.%-H%M)"
OLD_RE='^(hivogram-latest|hivogram-all-[0-9.]+|all-v[0-9.]+|v[0-9]{4}\.[0-9.]+)$'
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)

# The certificate the Unigram msixbundle is signed with since Unigram build 9 (Hivogram-Unigram.cer of
# unigram-v13.2.9-build.9, CN=D89C87B4-2758-402A-8F40-3571D00882AB, valid 2026-11-22..2029-11-22): SHA-256 of its DER.
# A new certificate means a new value here. The old one (sha256 3e4bd1c3…, valid to 2027-04-16) is refused.
UNI_CERT_SHA256=4d0f5afd939b55bf2d22f5f36b5d531dfa001889673c8886a8bdb9b81310d88c
UNI_OLD_CERT_RE='^3e4bd1'
die() { echo "::error::$*"; exit 1; }
# cert_ok <what> <sha256 of a certificate's DER>: only the current Unigram certificate passes
cert_ok() {
  [ "$2" = "$UNI_CERT_SHA256" ] && return 0
  [[ "$2" =~ $UNI_OLD_CERT_RE ]] && die "$1: signed with the OLD Unigram certificate ($2), refused"
  die "$1: unknown certificate $2 (expected $UNI_CERT_SHA256)"
}
# verify_from_release <source tag> <asset> <downloaded file>: the file's SHA-256 must be the one in that release's
# SHA256SUMS.txt, a .cer must be the current certificate and a .msixbundle must be signed with it.
verify_from_release() {
  local src=$1 asset=$2 file=$3 sums="$work/sums/$1/SHA256SUMS.txt" want got fp d c n=0
  if [ ! -f "$sums" ]; then
    gh release download "$src" --pattern SHA256SUMS.txt --dir "$work/sums/$src" --clobber \
      || die "$src has no SHA256SUMS.txt: $asset cannot be checked, not re-signing it"
  fi
  # lines are "<sha256> <name>" or "<sha256> *<name>" (sha256sum -b)
  want=$(awk -v n="$asset" '{f=$2; sub(/^\*/, "", f); if (f == n) { print tolower($1); exit }}' "$sums" | tr -d '\r')
  [ -n "$want" ] || die "$asset is not listed in SHA256SUMS.txt of $src"
  got=$(sha256sum "$file" | cut -d' ' -f1)
  [ "$got" = "$want" ] || die "$asset from $src: SHA-256 $got, but its SHA256SUMS.txt says $want"
  case "$asset" in
    *.cer)
      fp=$({ openssl x509 -inform DER -in "$file" -outform DER 2>/dev/null || openssl x509 -in "$file" -outform DER; } | sha256sum | cut -d' ' -f1) \
        || die "$asset from $src is not a certificate"
      cert_ok "$asset from $src" "$fp" ;;
    *.msixbundle)
      # AppxSignature.p7x = "PKCX" + PKCS#7 (DER) with the signer's certificate
      d=$(mktemp -d)
      unzip -p "$file" AppxSignature.p7x > "$d/sig.p7x" || die "$asset from $src has no AppxSignature.p7x (unsigned?)"
      [ "$(head -c 4 "$d/sig.p7x")" = PKCX ] || die "$asset from $src: AppxSignature.p7x is not a signature"
      tail -c +5 "$d/sig.p7x" | openssl pkcs7 -inform DER -print_certs > "$d/certs.pem" || die "$asset from $src: unreadable signature"
      awk -v d="$d" '/-----BEGIN CERTIFICATE-----/ { n++ } n { print > (d "/c" n ".pem") }' "$d/certs.pem"
      for c in "$d"/c*.pem; do
        [ -f "$c" ] || continue
        n=$((n + 1))
        cert_ok "$asset from $src" "$(openssl x509 -in "$c" -outform DER | sha256sum | cut -d' ' -f1)"
      done
      [ "$n" -gt 0 ] || die "$asset from $src: no certificate in its signature"
      rm -rf "$d" ;;
  esac
  echo "checked $asset from $src: SHA-256 matches its SHA256SUMS.txt"
}
gh api "repos/$GH_REPO/releases?per_page=100" > "$work/releases.json"

# plan.tsv: <label> <source tag> <source asset> <new name>   (newest release that has that file)
python3 - "$work/releases.json" > "$work/plan.tsv" <<'PY'
import json, re, sys
rs = [r for r in json.load(open(sys.argv[1])) if not r["draft"] and not r.get("prerelease")]
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
pick("Native", "android-", r"\.apk$",                  "Hivogram-Native-{v}-build.{b}.apk")
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
    # Files uploaded from the PC (Unigram) carry no signature of their own, yet are re-signed below: check them first
    if [ "$label" = UNI ] || [ "$label" = Native ]; then verify_from_release "$src" "$asset" "$work/dl/$asset"; fi
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
    n=$(line Native); [ -n "$n" ] && echo "- **Native** ($(ver "$n")): \`$n\` — Android 7+, нативный Hivogram (форк Telegram для Android). Ставится рядом с APK, это другое приложение."
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
rs = [r for r in json.load(open(sys.argv[1])) if not r["draft"] and not r.get("prerelease")]
used = {l.split("\t")[1] for l in open(sys.argv[2]) if l.strip()}  # still the source of a file in the shared one
rs.sort(key=lambda r: r.get("published_at") or "", reverse=True)
seen = {}
KEEP = {"android": 3}  # native Android (android-v…): the last 3 builds, every other app only its newest
for r in rs:
    m = re.match(r"(hivogram|lite|unigram|android)-v[0-9.]+-build\.\d+$", r["tag_name"])
    if not m: continue
    app = m.group(1)
    if seen.get(app, 0) >= KEEP.get(app, 1) and r["tag_name"] not in used: print(r["tag_name"])
    seen[app] = seen.get(app, 0) + 1
PY
while read -r old; do [ -n "$old" ] && { echo "Удаляю старую сборку $old"; gh release delete "$old" --yes --cleanup-tag; }; done < "$work/old.txt"
# The app releases must never hold «Latest»: that is the shared one.
cur=$(gh api "repos/$GH_REPO/releases?per_page=100" --jq '.[].tag_name' | grep -E "$OLD_RE" | head -n1)
[ -n "$cur" ] && gh release edit "$cur" --latest >/dev/null
