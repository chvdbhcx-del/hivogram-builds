#!/usr/bin/env python3
"""Build README screenshot grids: every desktop shot and every phone shot
lands at exactly the same pixel size, captions baked in, so GitHub can't
stretch columns by caption length.

    python3 docs/make-grids.py /path/to/Nunito-SemiBold.ttf [grid-name ...]

A variable Nunito works too (SemiBold is picked). Grid names limit the run.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'screens')
FONT = sys.argv[1]

PHONE = (540, 1169)      # all phone tiles
DESK = (1440, 900)       # all desktop tiles
GAP = 40
PILL_BG = (40, 42, 46, 255)
PILL_FG = (240, 240, 242, 255)

GRIDS = {
    'grid-desktop-main': ('desk', 2, [
        ('desktop-inbox', '«Входящие»'),
        ('desktop-broadcasts', 'Рассылки'),
        ('desktop-call', 'Звонок на другой аккаунт'),
        ('desktop-settings', 'Настройки'),
    ]),
    'grid-phone-main': ('phone', 4, [
        ('android-chats', 'Android: чаты'),
        ('android-inbox', 'Android: «Входящие»'),
        ('iphone-allchats', 'iPhone: все чаты'),
        ('iphone-chat', 'iPhone: чат'),
    ]),
    'grid-phone-calls': ('phone', 4, [
        ('call-other', 'На другой аккаунт'),
        ('call-incoming', 'Входящий'),
        ('call-talking', 'Разговор'),
        ('call-bar', 'Полоска звонка'),
    ]),
    'grid-desktop-status': ('desk', 2, [
        ('desktop-status-list', 'Список по статусам'),
        ('desktop-status-sort', 'Сортировка и вид'),
        ('desktop-status-menu', 'Статус и метки чата'),
        ('desktop-status-editor', 'Редактор статусов'),
    ]),
    'grid-desktop-unigram': ('desk', 2, [
        ('unigram/1-list', 'Список по важности, группы'),
        ('unigram/2-status-menu', 'Статус и метки чата'),
        ('unigram/3-sort', 'Сортировка и вид'),
        ('unigram/4-editor', 'Редактор статусов'),
        ('unigram/5-words', 'Вид «Со словом»'),
        ('unigram/6-profile', 'Звонки из профиля'),
    ]),
    'grid-desktop-lite': ('desk', 2, [
        ('lite/lite-allchats', '«Все чаты» по всем аккаунтам'),
        ('lite/lite-status-menu', 'Статус и метки чата'),
        ('lite/lite-calls', '«Звонки» всех аккаунтов'),
        ('lite/lite-broadcasts', 'Рассылки'),
        ('lite/lite-chat-poll', 'Опрос, стикер, эмодзи'),
        ('lite/lite-group-call', 'Голосовой чат'),
    ]),
    'grid-phone-native': ('phone', 4, [
        ('native/chats', 'Чаты всех аккаунтов'),
        ('native/statuses', 'Статусы и метки'),
        ('native/calls', 'Звонки'),
        ('native/templates', 'Шаблоны через «/»'),
    ]),
    'grid-phone-status': ('phone', 4, [
        ('iphone-status-list', 'Список'),
        ('iphone-status-sort', 'Сортировка'),
        ('iphone-status-menu', 'Статус чата'),
        ('iphone-status-editor', 'Редактор'),
    ]),
}


def rounded(img, r):
    mask = Image.new('L', img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, img.width - 1, img.height - 1), r, fill=255)
    out = img.convert('RGBA')
    out.putalpha(mask)
    return out


def build(name, kind, cols, items):
    tw, th = PHONE if kind == 'phone' else DESK
    fsize = 44 if kind == 'phone' else 52
    font = ImageFont.truetype(FONT, fsize)
    try:
        font.set_variation_by_name('SemiBold')
    except (OSError, ValueError):
        pass  # a static SemiBold file
    pill_h = int(fsize * 1.9)
    cell_h = th + 20 + pill_h
    rows = (len(items) + cols - 1) // cols
    W = cols * tw + (cols - 1) * GAP
    H = rows * cell_h + (rows - 1) * GAP
    canvas = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(canvas)
    for i, (src, caption) in enumerate(items):
        x = (i % cols) * (tw + GAP)
        y = (i // cols) * (cell_h + GAP)
        shot = Image.open(os.path.join(ROOT, src + '.png')).convert('RGB')
        assert shot.width * th == shot.height * tw or abs(shot.width / shot.height - tw / th) < 0.003, src
        shot = shot.resize((tw, th), Image.LANCZOS)
        canvas.alpha_composite(rounded(shot, 36 if kind == 'phone' else 20), (x, y))
        tw_txt = d.textlength(caption, font=font)
        pw = int(tw_txt + fsize * 1.4)
        px = x + (tw - pw) // 2
        py = y + th + 20
        d.rounded_rectangle((px, py, px + pw, py + pill_h), pill_h // 2, fill=PILL_BG)
        # vertical centring by the glyph box, not the ascent
        bb = d.textbbox((0, 0), caption, font=font, anchor='ls')
        cy = py + pill_h / 2 - (bb[1] + bb[3]) / 2
        d.text((x + tw / 2 - tw_txt / 2, cy), caption, font=font, fill=PILL_FG, anchor='ls')
    out = os.path.join(ROOT, name + '.png')
    canvas.save(out, optimize=True)
    print(name, canvas.size, os.path.getsize(out) // 1024, 'KB')


ONLY = set(sys.argv[2:])
for n, (k, c, it) in GRIDS.items():
    if not ONLY or n in ONLY:
        build(n, k, c, it)
