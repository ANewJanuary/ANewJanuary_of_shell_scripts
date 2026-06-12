#!/usr/bin/env bash
# disable_keyboard.sh
#
# Disables the internal laptop keyboard and touchpad via evdev EVIOCGRAB.
# Works on Wayland (niri, GNOME, KDE, …) — no X11/xinput needed.
# External keyboards and mice are NOT affected.
#
# Usage:
#   chmod +x disable_keyboard.sh
#   ./disable_keyboard.sh
#
# Unlock: press  Ctrl + Space + Enter  on the internal laptop keyboard.
#
# Depends: python3-evdev  (sudo dnf install python3-evdev)

set -euo pipefail

# ── Dependency check ────────────────────────────────────────────────────────

if ! python3 -c "import evdev" &>/dev/null; then
    echo "python3-evdev is not installed."
    echo "Installing now…"
    if command -v dnf &>/dev/null; then
        sudo dnf install -y python3-evdev
    elif command -v pip3 &>/dev/null; then
        pip3 install --user evdev
    else
        echo "ERROR: Cannot install evdev automatically." >&2
        echo "Please run:  sudo dnf install python3-evdev" >&2
        exit 1
    fi
fi

# ── Banner ───────────────────────────────────────────────────────────────────

echo "========================================="
echo "  Internal Keyboard + Touchpad Lock"
echo "  Unlock combo: Ctrl + Space + Enter"
echo "  (on the internal keyboard)"
echo "========================================="
echo ""

# ── Run embedded Python (as root) ───────────────────────────────────────────
# EVIOCGRAB requires root (or 'input' group membership + rw on /dev/input/*).
# Remove 'sudo' below if you've added yourself to the input group.


exec sudo python3 - << 'PYEOF'

#!/usr/bin/env python3
"""
Grabs the internal laptop keyboard AND touchpad at the kernel evdev level,
making them invisible to Wayland/niri until Ctrl+Space+Enter is pressed
on the internal keyboard.
"""

import sys
import evdev
from evdev import ecodes


# ---------------------------------------------------------------------------
# Device detection
# ---------------------------------------------------------------------------

# Internal keyboards are typically on i8042/serio; touchpads on i2c or pnp.
# USB/BT devices have "usb-..." or "bluetooth-..." in phys — we skip those.
INTERNAL_PHYS_HINTS = ("isa", "i8042", "serio", "pnp", "i2c")

INTERNAL_KEYBOARD_NAME_HINTS = (
    "AT Translated Set 2 keyboard",
    "laptop keyboard",
    "internal keyboard",
)

TOUCHPAD_NAME_HINTS = (
    "touchpad",
    "trackpad",
    "glidepoint",
    "synaptics",
    "elan",
    "alps",
    "focaltech",
)


def phys_is_internal(dev):
    phys = (dev.phys or "").lower()
    return any(h in phys for h in INTERNAL_PHYS_HINTS)


def looks_like_internal_keyboard(dev):
    name = (dev.name or "").lower()
    caps = dev.capabilities()
    has_many_keys = ecodes.EV_KEY in caps and len(caps[ecodes.EV_KEY]) > 10
    if not has_many_keys:
        return False
    if phys_is_internal(dev):
        return True
    return any(h in name for h in INTERNAL_KEYBOARD_NAME_HINTS)


def looks_like_touchpad(dev):
    name = (dev.name or "").lower()
    if ecodes.EV_ABS not in dev.capabilities():
        return False
    if any(h in name for h in TOUCHPAD_NAME_HINTS):
        return True
    # ABS device on an internal bus that isn't a touchscreen
    if phys_is_internal(dev) and "touchscreen" not in name and "screen" not in name:
        return True
    return False


def find_internal_devices():
    """Return (keyboard_or_None, [touchpads])."""
    kb_candidates = []
    tp_candidates = []

    for path in evdev.list_devices():
        try:
            d = evdev.InputDevice(path)
        except (OSError, PermissionError):
            continue

        if looks_like_internal_keyboard(d):
            kb_candidates.append(d)
        elif looks_like_touchpad(d):
            tp_candidates.append(d)
        else:
            d.close()

    # Pick the best keyboard (prefer i8042)
    keyboard = None
    if kb_candidates:
        for d in kb_candidates:
            if "i8042" in (d.phys or ""):
                keyboard = d
                for o in kb_candidates:
                    if o is not d:
                        o.close()
                break
        if keyboard is None:
            keyboard = kb_candidates[0]
            for d in kb_candidates[1:]:
                d.close()

    return keyboard, tp_candidates


# ---------------------------------------------------------------------------
# Unlock combo: Ctrl + Space + Enter (all held, then Enter released)
# ---------------------------------------------------------------------------

CTRL_KEYS = {ecodes.KEY_LEFTCTRL, ecodes.KEY_RIGHTCTRL}
SPACE_KEY  = ecodes.KEY_SPACE
ENTER_KEY  = ecodes.KEY_ENTER


def wait_for_unlock(keyboard):
    held = set()
    print("  Press Ctrl+Space+Enter on the INTERNAL keyboard to unlock.")
    print("  (The combo keys are suppressed while locked.)")

    for event in keyboard.read_loop():
        if event.type != ecodes.EV_KEY:
            continue
        code, value = event.code, event.value  # value: 1=down 0=up 2=hold

        if value == 1:
            held.add(code)
        elif value == 0:
            held.discard(code)

        if (value == 0 and code == ENTER_KEY
                and bool(held & CTRL_KEYS)
                and SPACE_KEY in held):
            return


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def grab_all(devices):
    grabbed = []
    for d in devices:
        try:
            d.grab()
            grabbed.append(d)
        except OSError as e:
            print(f"  WARNING: could not grab {d.name!r} ({d.path}): {e}",
                  file=sys.stderr)
    return grabbed


def ungrab_all(devices):
    for d in devices:
        try:
            d.ungrab()
        except OSError:
            pass
        try:
            d.close()
        except OSError:
            pass


def main():
    print("Scanning for internal devices…")
    keyboard, touchpads = find_internal_devices()

    if keyboard is None:
        print(
            "ERROR: Could not find an internal keyboard.\n"
            "Run 'sudo libinput list-devices' to inspect devices,\n"
            "then edit the *_HINTS constants near the top of this script.",
            file=sys.stderr,
        )
        sys.exit(1)

    print(f"  Keyboard : {keyboard.name!r}  ({keyboard.path}, phys={keyboard.phys})")
    if touchpads:
        for tp in touchpads:
            print(f"  Touchpad : {tp.name!r}  ({tp.path}, phys={tp.phys})")
    else:
        print("  Touchpad : none detected")
    print()

    grabbed = grab_all([keyboard] + touchpads)

    if keyboard not in grabbed:
        print("ERROR: Failed to grab the keyboard — cannot continue.", file=sys.stderr)
        ungrab_all(grabbed)
        sys.exit(1)

    disabled = ["keyboard"] + (["touchpad"] if touchpads else [])
    print(f"✓ Internal {' and '.join(disabled)} DISABLED.")
    print()

    try:
        wait_for_unlock(keyboard)
    finally:
        ungrab_all(grabbed)

    print()
    print(f"✓ Internal {' and '.join(disabled)} RE-ENABLED.")


main()
PYEOF
