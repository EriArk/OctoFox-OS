# Plasma Mobile audio teardown repair — 2026-11-01

This is a bounded host compatibility patch, not a replacement audio server.
The stock immutable `/usr` files remain untouched. TrainerOS itself is unchanged.

## Source and cause

- KDE [PulseAudioQt v1.8.1](https://invent.kde.org/libraries/pulseaudio-qt/-/tree/v1.8.1),
  commit `10786fe31e640858f4f5db5366aed9c56d77bfab`.
- Installed host: Fedora 44 aarch64 `pulseaudio-qt-qt6-1.8.1-1`, Qt 6.11.2,
  Plasma Workspace/Mobile 6.7.5. Stock library SHA-256:
  `44f26f2756392f174123ab04e2f7305d23bc5187ef31ff0fea3009e78dc2a489`.
- A live Flip debugger captured `ContextPrivate::~ContextPrivate → reset →
  Sink/Port destruction → QQmlBinding → QQuickText → QFontCache →
  QThreadStorageData::get`, after application destruction in static exit handlers.
  Native KDE logout alone still reproduced SIGSEGV.
- `shutdown.patch` empties the audio models on Qt's
  [aboutToQuit](https://doc.qt.io/qt-6/qcoreapplication.html#aboutToQuit) signal,
  while GUI/thread resources are alive. It stops reconnects during teardown.
  Normal discovery, device selection, playback and volume code is unchanged.

## Build and checks

Run `bash build.sh /path/on/sd/new-build-directory` in a native aarch64 build
environment with CMake, C++20, Git, Qt6 Core/Gui/DBus/Qml/Quick/Test development
packages, pkg-config, libpulse and libpulse-mainloop-glib development packages.
ECM is pinned to `d8d80bcc61341239519392eef1360c796bf25931` (6.20.0).
No host root changes occur in the recipe. Keep sources/builds on SD.

The device build used the existing Qt 6.11.2/GCC 16.2.1 builder, `RelWithDebInfo`,
three compilation jobs. Retained artifact SHA-256:
`69b179f3a45cf18183a2d99b2bd6ccc31c3aa307b595852c29bc179c9589ee11`.
Paths/toolchain differences can change the binary hash; this is identity of the
delivered artifact, not a reproducible-binary guarantee.

`ShutdownProbe.cpp` reads real audio devices without playing audio or changing
volume. Run the built probe as the desktop user with `QT_QPA_PLATFORM=offscreen`,
its user D-Bus and PulseAudio/PipeWire runtime available. Compare
`LD_LIBRARY_PATH=/usr/lib64` against the patched `build/bin` directory. It asserts
that an actual QML-bound port is destroyed while the application is alive,
models are empty after quit, and late reconnect cannot repopulate them.
Stock failed (exit 1), patched passed (exit 0) on Odin. Upstream MapsTest: 4/4.
The real Flip logout then completed without a crash. Remote evidence and limits:
[session polish](../../../docs/evidence/session-polish-20261101/README.md).

## Installation, update and rollback

The reviewed session installer accepts `--plasma-audio-library /path/to/built.so`
alongside `--user NAME` (and `--managed` for managed installations). It validates
the stock hash and aarch64 artifact before installation, records the delivered
hash and creates only a root-owned compatibility directory plus one Plasma user
unit drop-in. The artifact is **optional and not bundled in this Git repository**;
public image/OTA packaging is not delivered by this change. Do not claim all
fresh installations have the audio patch merely because they include the helper.

`plasmashell.py` validates both hashes on each start and uses `LD_PRELOAD` only
in the launched Plasma process environment; it is not exported into the user
systemd manager or global session configuration. Directly spawned children can
inherit that environment. A changed host library or damaged/missing artifact
falls back to stock Plasma with a diagnostic, rather than blocking the desktop.
After host updates, re-evaluate the upstream fix and ABI, rerun the probe and
real logout before updating the stock hash. Do not blindly disable the guard.

On the two existing manual installations, files were deployed with first-version
backups on each SD, then `systemctl --user daemon-reload`. Managed installation
uses the existing ownership journal and refuses to remove edited files. For a
bounded manual rollback remove only the unchanged
`/etc/systemd/user/plasma-plasmashell.service.d/50-traineros-audio-teardown.conf`
installed by this change, reload the user manager, and use a fresh Plasma session.
The stock library was never replaced. Do not stop Plasma during unsaved work.

## License

The modified KDE files retain their original authors and SPDX expression:
`LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL`.
The patch is supplied under that same expression. Upstream notices and complete
license texts are retained in the fetched source tree; its
[LICENSES](https://invent.kde.org/libraries/pulseaudio-qt/-/tree/v1.8.1/LICENSES)
must accompany redistributed source/binaries with the patch and build recipe.
Original wrapper, integration and regression probe code is GPL-3.0-or-later.
Public redistribution/image acceptance remains separate.
