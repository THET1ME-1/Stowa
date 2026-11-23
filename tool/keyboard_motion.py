#!/usr/bin/env python3
"""Как строка ввода едет за клавиатурой — по записи экрана телефона.

Запуск: python3 tool/keyboard_motion.py запись.mp4 [--mic white|cyan]

На каждом кадре записи печатает верх клавиатуры, середину кнопки микрофона строки, зазор между
ними и шаг строки от прошлого кадра. Плавный выезд — шаги растут и падают одной горкой, зазор
почти не меняется (Telegram 23.11.2026: шаги 25, 191, 176, 118, 70, 34, 14; зазор ±10 точек).
Дёрганый — шаги пилой и зазор скачет (Stowa 0.1.3 в тот же день: 65, 123, 189, 58, 85, 54;
зазор от 112 до 189 точек).

--mic white — белый круг микрофона Stowa, --mic cyan — голубой круг Telegram. Клавиатура
ищется по фону Gboard тёмной темы (36, 48, 54); у другой клавиатуры поправить KEYBOARD.
Кадры режет ffmpeg во временную папку, нужны numpy и Pillow.
"""

import argparse
import glob
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

KEYBOARD = np.array([36, 48, 54])


def keyboard_top(frame):
    """Первая строка, с которой 30 строк подряд почти целиком цвета клавиатуры."""
    height = frame.shape[0]
    band = frame[:, int(frame.shape[1] * 0.11):int(frame.shape[1] * 0.88)]
    match = (np.abs(band - KEYBOARD).max(axis=2) <= 6).mean(axis=1) > 0.9
    for row in range(height // 3, height - 30):
        if match[row:row + 30].all():
            return row
    return height


def mic_center(frame, top, mic):
    """Середина круга микрофона у правого края, выше клавиатуры."""
    width = frame.shape[1]
    start = frame.shape[0] // 3
    area = frame[start:top, int(width * 0.83):int(width * 0.99)]
    if mic == 'white':
        hit = area.min(axis=2) >= 235
    else:
        red, green, blue = area[..., 0], area[..., 1], area[..., 2]
        hit = (red >= 100) & (red <= 165) & (green >= 190) & (blue >= 200)
    rows = np.nonzero(hit)[0]
    return start + rows.mean() if rows.size > 800 else float('nan')


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('video')
    parser.add_argument('--mic', choices=['white', 'cyan'], default='white')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory() as folder:
        subprocess.run(['ffmpeg', '-v', 'error', '-i', args.video, '-vsync', '0', f'{folder}/%04d.png'], check=True)
        previous = None
        for index, path in enumerate(sorted(glob.glob(f'{folder}/*.png'))):
            frame = np.asarray(Image.open(path).convert('RGB')).astype(int)
            top = keyboard_top(frame)
            mic = mic_center(frame, top, args.mic)
            step = '' if previous is None or np.isnan(mic) else f'{mic - previous:+7.1f}'
            print(f'{index:4d}  клавиатура {top:5d}  строка {mic:7.1f}  зазор {top - mic:7.1f}  шаг {step}')
            previous = mic
    return 0


if __name__ == '__main__':
    sys.exit(main())
