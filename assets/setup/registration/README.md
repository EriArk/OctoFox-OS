# Public registration QR codes

Static PNGs, generated locally with Python `qrcode` 8.2, error correction M,
12 pixels per module and a four-module white quiet zone. No runtime dependency,
remote QR service, personal information or authorization token. Keep black on
white even in the dark theme; scale with nearest-neighbour filtering.

Verified official destinations on 10 November 2026:

- `social.png`: https://fluxer.com/login — Fluxer uses this entry for account creation too; [official instructions](https://fluxer.com/help/create-account).
- `achievements.png`: https://retroachievements.org/createaccount.php
- `scraper.png`: https://www.screenscraper.fr/membreinscription.php

Each PNG was decoded with ZXing-C++ and compared with its exact URL. The displayed
URL lives in FirstRunServicePanel.qml; update it together with the corresponding
QR if the provider changes its registration route. Registration on a phone does
not sign the handheld in automatically.
