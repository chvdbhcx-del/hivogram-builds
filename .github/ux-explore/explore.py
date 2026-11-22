#!/usr/bin/env python3
"""UX exploration of native Android Hivogram on an emulator (demo accounts, offline).

For every start screen: screenshot + UI dump, then tap every clickable element one by one
(and long-press list rows), screenshot + dump what opens, go back. Popups/menus/new screens
that open get one more level: each of their items is tapped too (within a time budget).
App data is restored from a snapshot between start screens, so toggles don't leak."""
import hashlib, json, os, re, subprocess, sys, time
import xml.etree.ElementTree as ET

PKG = 'app.hivogram.android'
ACT = PKG + '/org.telegram.ui.LaunchActivity'
OUT = os.environ.get('OUT', 'ux')
SCREENS = sys.argv[1].split(',')
BUDGET = float(os.environ.get('BUDGET_MIN', '200')) * 60
T0 = time.time()
MAX_T1 = 45
MAX_T2 = 14
log = open(os.path.join(OUT, 'log.txt'), 'a', encoding='utf-8')

def sh(cmd, timeout=40):
    try:
        return subprocess.run(cmd, shell=True, capture_output=True, timeout=timeout).stdout
    except subprocess.TimeoutExpired:
        return b''

def adb(cmd, timeout=40):
    return sh('adb ' + cmd, timeout)

def P(*a):
    s = ' '.join(str(x) for x in a)
    print(s, flush=True)
    log.write(s + '\n'); log.flush()

def dump():
    for _ in range(3):
        adb('shell rm -f /sdcard/u.xml')
        adb('shell uiautomator dump --compressed /sdcard/u.xml', 25)
        x = adb('exec-out cat /sdcard/u.xml')
        if x.startswith(b'<?xml'):
            try:
                return ET.fromstring(x.decode('utf-8', 'replace'))
            except ET.ParseError:
                pass
        time.sleep(1)
    return None

def bounds(n):
    m = re.findall(r'\d+', n.get('bounds', '[0,0][0,0]'))
    return tuple(int(v) for v in m) if len(m) == 4 else (0, 0, 0, 0)

def label(n):
    t = (n.get('text') or '').strip() or (n.get('content-desc') or '').strip()
    if not t:
        # first text among descendants
        for c in n.iter():
            t = (c.get('text') or '').strip() or (c.get('content-desc') or '').strip()
            if t:
                break
    return (t or n.get('resource-id') or n.get('class', '?').split('.')[-1])[:60]

def signature(root):
    if root is None:
        return 'none'
    parts = []
    for n in root.iter('node'):
        if n.get('package') != PKG:
            continue
        parts.append((n.get('class', ''), (n.get('text') or '')[:30], (n.get('content-desc') or '')[:30]))
    return hashlib.md5(json.dumps(parts).encode()).hexdigest()[:10]

def texts(root):
    out = []
    if root is None:
        return out
    for n in root.iter('node'):
        for k in ('text', 'content-desc'):
            v = (n.get(k) or '').strip()
            if v and v not in out:
                out.append(v)
    return out

def in_app(root):
    if root is None:
        return False
    return any(n.get('package') == PKG for n in root.iter('node'))

def targets(root, W, H):
    if root is None:
        return []
    found = []
    parent = {c: p for p in root.iter() for c in p}
    for n in root.iter('node'):
        if n.get('package') != PKG:
            continue
        b = bounds(n)
        w, h = b[2] - b[0], b[3] - b[1]
        if w < 12 or h < 12 or b[1] < 60 or b[3] > H + 5:
            continue
        p = parent.get(n)
        list_child = p is not None and p.get('scrollable') == 'true' and w > W * 0.6
        if n.get('clickable') == 'true' or n.get('long-clickable') == 'true' or n.get('checkable') == 'true' or list_child:
            found.append((b, label(n), n.get('long-clickable') == 'true' or list_child))
    # drop exact-bounds duplicates and containers that hold another target fully with the same label
    uniq, seen = [], set()
    for b, l, lc in found:
        key = (b, l)
        if key in seen:
            continue
        seen.add(key)
        uniq.append((b, l, lc))
    return uniq

def screen_size():
    m = re.search(rb'(\d+)x(\d+)', adb('shell wm size'))
    return (int(m.group(1)), int(m.group(2))) if m else (1080, 2400)

W, H = screen_size()
shot_no = 0
INDEX = []

def shot(tag, root, extra=None):
    global shot_no
    shot_no += 1
    name = '%04d-%s' % (shot_no, re.sub(r'[^\w.-]+', '_', tag)[:80])
    png = adb('exec-out screencap -p', 30)
    with open(os.path.join(OUT, name + '.png'), 'wb') as f:
        f.write(png)
    if root is not None:
        ET.ElementTree(root).write(os.path.join(OUT, name + '.xml'), encoding='utf-8')
    INDEX.append(dict(file=name, tag=tag, texts=texts(root)[:80], **(extra or {})))
    with open(os.path.join(OUT, 'index.json'), 'w', encoding='utf-8') as f:
        json.dump(INDEX, f, ensure_ascii=False, indent=1)
    return name

def restore_data():
    adb('shell am force-stop ' + PKG)
    adb('shell "rm -rf /data/data/%s/* && tar -xf /data/local/tmp/hv.tar -C /data/data/%s && chown -R $(stat -c %%u /data/data/%s):$(stat -c %%u /data/data/%s) /data/data/%s && restorecon -R /data/data/%s"' % ((PKG,) * 6), 120)

def launch(screen):
    adb('shell am force-stop ' + PKG)
    adb('shell am start -W -n %s --ez hivogram_demo true --es hivogram_screen %s' % (ACT, screen), 30)
    time.sleep(7)

def tap(b, long=False):
    x, y = (b[0] + b[2]) // 2, (b[1] + b[3]) // 2
    if long:
        adb('shell input swipe %d %d %d %d 900' % (x, y, x, y))
    else:
        adb('shell input tap %d %d' % (x, y))

def back_to(base_sig, screen, steps=()):
    """Return to the state with base_sig: back once, else relaunch and replay steps."""
    r = dump()
    if signature(r) == base_sig:
        return True
    adb('shell input keyevent 4'); time.sleep(1.2)
    r = dump()
    if signature(r) == base_sig:
        return True
    launch(screen)
    for b, lc in steps:
        tap(b, lc); time.sleep(1.6)
    return signature(dump()) == base_sig

def explore(screen):
    restore_data()
    launch(screen)
    base = dump()
    base_sig = signature(base)
    shot(f'{screen}__base', base, dict(screen=screen, level=0))
    # what's below the fold
    adb('shell input swipe %d %d %d %d 300' % (W // 2, H * 3 // 4, W // 2, H // 4)); time.sleep(1.5)
    sc = dump()
    if signature(sc) != base_sig:
        shot(f'{screen}__scrolled', sc, dict(screen=screen, level=0))
        adb('shell input swipe %d %d %d %d 300' % (W // 2, H // 4, W // 2, H * 3 // 4)); time.sleep(1.5)
    tg = targets(base, W, H)
    P(f'== {screen}: {len(tg)} targets, sig {base_sig}')
    long_done = 0
    acts = [(b, l, False) for b, l, lc in tg][:MAX_T1]
    acts += [(b, l, True) for b, l, lc in tg if lc][:3]
    for b, l, lc in acts:
        if time.time() - T0 > BUDGET:
            P('budget over'); return
        if not back_to(base_sig, screen):
            restore_data(); launch(screen); base_sig = signature(dump())
        tap(b, lc); time.sleep(1.8)
        r = dump()
        kind = 'long' if lc else 'tap'
        if not in_app(r):
            shot(f'{screen}__{kind}_{l}__LEFT_APP', r, dict(screen=screen, level=1, target=l, kind=kind, left_app=True))
            adb('shell input keyevent 4'); time.sleep(1)
            continue
        sig = signature(r)
        changed = sig != base_sig
        shot(f'{screen}__{kind}_{l}' + ('' if changed else '__nochange'), r,
             dict(screen=screen, level=1, target=l, kind=kind, changed=changed))
        if not changed or time.time() - T0 > BUDGET * 0.85:
            continue
        # level 2: what's inside what opened
        sub = [t for t in targets(r, W, H) if (t[0], t[1]) not in {(x[0], x[1]) for x in tg}][:MAX_T2]
        for b2, l2, _ in sub:
            if time.time() - T0 > BUDGET * 0.85:
                break
            if not back_to(sig, screen, [(b, lc)]):
                break
            tap(b2); time.sleep(1.8)
            r2 = dump()
            if not in_app(r2):
                shot(f'{screen}__{l}__{l2}__LEFT_APP', r2, dict(screen=screen, level=2, target=f'{l} > {l2}', left_app=True))
                adb('shell input keyevent 4'); time.sleep(1); continue
            ch2 = signature(r2) != sig
            shot(f'{screen}__{l}__{l2}' + ('' if ch2 else '__nochange'), r2,
                 dict(screen=screen, level=2, target=f'{l} > {l2}', changed=ch2))
        back_to(base_sig, screen)

for s in SCREENS:
    try:
        explore(s)
    except Exception as e:
        P('ERROR', s, repr(e))
P('done in %.0f min, %d shots' % ((time.time() - T0) / 60, shot_no))
