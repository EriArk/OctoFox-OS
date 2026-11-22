#!/bin/bash
set -eu
export SDL_VIDEO_MINIMIZE_ON_FOCUS_LOSS=0
export QT_QPA_PLATFORM=xcb
export ENABLE_GAMESCOPE_WSI=1
unset DISPLAY WAYLAND_DISPLAY SESSION_MANAGER
eval "$(/usr/libexec/armada/device-env)"
args=(--backend drm --expose-wayland --force-windows-fullscreen)
if [ -n "${ARMADA_PRIMARY_CONNECTOR:-}" ]; then
    args+=(--prefer-output "$ARMADA_PRIMARY_CONNECTOR")
fi
# Give applications and games a handheld-sized desktop. Gamescope still drives
# the physical panel at its native resolution, including portrait-mounted LCDs.
# Use the display defaults when docked or when the preferred mode is unknown.
external=false
for output in /sys/class/drm/card*-{HDMI,DP}-*/status; do
    if [[ -r "$output" && $(<"$output") == connected ]]; then external=true; break; fi
done
case "${ARMADA_PRIMARY_CONNECTOR:-}" in
    DSI-*|eDP-*)
        for panel in /sys/class/drm/card*-"$ARMADA_PRIMARY_CONNECTOR"/modes; do
            if ! $external && [[ -r "$panel" ]] && read -r mode < "$panel" && [[ "$mode" =~ ^([0-9]{3,4})x([0-9]{3,4})$ ]]; then
                width=${BASH_REMATCH[1]}; height=${BASH_REMATCH[2]}
                if [[ "${ARMADA_PANEL_ORIENTATION:-}" == right || "${ARMADA_PANEL_ORIENTATION:-}" == left ]]; then
                    tmp=$width; width=$height; height=$tmp
                fi
                if (( height > 800 && width >= height )); then
                    args+=(-w "$(( (width * 720 / height + 1) / 2 * 2 ))" -h 720)
                fi
            fi
            break
        done ;;
esac
if [ -n "${ARMADA_PANEL_ORIENTATION:-}" ]; then
    args+=(--force-orientation "$ARMADA_PANEL_ORIENTATION")
fi
if [ -n "${ARMADA_PANEL_TYPE:-}" ]; then
    args+=(--force-panel-type "$ARMADA_PANEL_TYPE")
fi
gamescope=/usr/bin/gamescope
# A root-installed capture fix is valid only for the reviewed system baseline.
# An OS update or changed artifact returns to the system compositor automatically.
capture_fix=/var/opt/traineros/system/gamescope
if [ -x "$capture_fix/gamescope" ] && [ -r "$capture_fix/SHA256SUMS" ] &&
   sha256sum --status -c "$capture_fix/SHA256SUMS"; then
    gamescope="$capture_fix/gamescope"
fi
exec "$gamescope" "${args[@]}" -- /usr/bin/python3 /var/opt/traineros/session/client.py
