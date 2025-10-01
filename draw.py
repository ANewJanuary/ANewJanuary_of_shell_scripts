#!/usr/bin/env python3
import evdev
from evdev import ecodes, InputDevice, UInput, list_devices
import time
import sys
from select import select
import errno

# The main function that will directly grab absolute inputs.
def create_absolute_mapper(device_path=None):
    # Get the name of touchpad device.
    if not device_path:
        devices = [InputDevice(path) for path in list_devices()]
        touchpad = None
        
        # Check if the present touchpads report absolute positions in
        # the fist place.
        for device in devices:
            if "touchpad" in device.name.lower():
                caps = device.capabilities()
                if ecodes.EV_ABS in caps:
                    touchpad = device
                    break
        
        if not touchpad:
            print("No suitable touchpad found with absolute capabilities")
            print("Available devices:")
            for device in devices:
                print(f"  {device.path}: {device.name}")
            return None
    else:
        try:
            touchpad = InputDevice(device_path)
        except:
            print(f"Could not open device: {device_path}")
            return None
    
    print(f"Using touchpad: {touchpad.name}")
    
    # Get touchpad size
    caps = touchpad.capabilities()
    abs_caps = caps.get(ecodes.EV_ABS, [])
    
    x_min, x_max, y_min, y_max = 0, 1000, 0, 1000
    found_x = found_y = False
    
    # Try to automatically configure the cordinates of the touchpad.
    for abs_code, abs_info in abs_caps:
        if abs_code in [ecodes.ABS_X, ecodes.ABS_MT_POSITION_X]:
            x_min, x_max = abs_info.min, abs_info.max
            found_x = True
            print(f"X range: {x_min} to {x_max}")
        elif abs_code in [ecodes.ABS_Y, ecodes.ABS_MT_POSITION_Y]:
            y_min, y_max = abs_info.min, abs_info.max
            found_y = True
            print(f"Y range: {y_min} to {y_max}")
    
    if not found_x or not found_y:
        print("Could not find X and Y coordinate ranges")
        return None
    
    # Screen dimensions, change them for your screen
    screen_width = 1920
    screen_height = 1080
    
    print(f"Mapping to screen: {screen_width}x{screen_height}")
    
    # Create virtual absolute input device
    capabilities = {
        ecodes.EV_KEY: [
            ecodes.BTN_LEFT, 
            ecodes.BTN_RIGHT, 
            ecodes.BTN_MIDDLE,
            ecodes.BTN_TOUCH,
        ],
        ecodes.EV_ABS: [
            (ecodes.ABS_X, evdev.AbsInfo(
                value=0, min=0, max=screen_width, 
                fuzz=0, flat=0, resolution=100
            )),
            (ecodes.ABS_Y, evdev.AbsInfo(
                value=0, min=0, max=screen_height, 
                fuzz=0, flat=0, resolution=100
            )),
        ],
        ecodes.EV_REL: [ecodes.REL_WHEEL, ecodes.REL_HWHEEL],
    }
    
    # Create the virtual device
    # The vendors, product and version numbers are just random
    ui = UInput(
        events=capabilities,
        name="virtual-absolute-touchpad",
        vendor=0x1234,
        product=0x5678,
        version=0x111
    )
    
    # Open keyboard devices for monitoring
    keyboard_devices = []
    for device_path in list_devices():
        try:
            device = InputDevice(device_path)
            caps = device.capabilities()
            if ecodes.EV_KEY in caps:
                key_caps = caps[ecodes.EV_KEY]
                # Look for devices that have control keys 
                if ecodes.KEY_LEFTCTRL in key_caps or ecodes.KEY_A in key_caps:
                    keyboard_devices.append(device)
                    print(f"Monitoring keyboard: {device.name}")
        except:
            continue
    
    if not keyboard_devices:
        print("Warning: No keyboard devices found for monitoring!")
    
    print("\n✓ Virtual absolute device created!")
    print("→ Press LEFT CONTROL to TOGGLE absolute positioning mode")
    print("→ In absolute mode: Touch = draw after 50ms delay")
    print("→ Lift finger = stop drawing")
    print("→ Press Ctrl+C in terminal to exit script\n")
    
    # State tracking
    ctrl_toggle = False
    absolute_mode_active = False
    ctrl_was_pressed = False
    
    # Touch tracking
    finger_down = False
    last_touch_time = 0
    mouse_press_scheduled = False

    # (adjust if you find bugs or weird behaviour, like if lines are
    # drawn between the points where you lift your finger and press
    # down again.
    MOUSE_PRESS_DELAY = 0.05  # 50 milliseconds
    
    # Smoothing variables
    # I do this because on my machine, there wasn't a smooth diagonal,
    # it was sort of jittery, so I smoothed it out. Remove if you
    # don't need it.
    last_x, last_y = screen_width // 2, screen_height // 2
    smoothed_x, smoothed_y = last_x, last_y
    SMOOTHING_FACTOR = 0.4
    
    try:
        # Uncomment the following lines to grab the touchpad. This
        # makes it so that only this script has access to touchpad
        # inputs, meaning no accidental gestures while drawing. I
        # disabled it, because it was interfering with gesture that I
        # needed.

        # touchpad.grab()
        # print("Touchpad grabbed for exclusive access")
        
        # Set devices to non-blocking mode
        touchpad.fd  # Ensure fd is accessed
        for kb in keyboard_devices:
            kb.fd  # Ensure fd is accessed
        
        # Main event loop
        while True:
            current_time = time.time()
            
            # Check all devices for events
            all_devices = [touchpad] + keyboard_devices
            r, w, x = select(all_devices, [], [], 0.01)  # 10ms timeout

            # Timeout is to avoid jitter and unexpected behaviour
            
            # Process devices that have data
            for device in r:
                try:
                    # Read all available events from this device
                    events = device.read()
                    for event in events:
                        # Handle keyboard events
                        if device in keyboard_devices:
                            if event.type == ecodes.EV_KEY:
                                # LEFT CONTROL - Toggle absolute mode
                                if event.code == ecodes.KEY_LEFTCTRL:
                                    if event.value == 1 and not ctrl_was_pressed:  # Pressed
                                        ctrl_toggle = not ctrl_toggle
                                        absolute_mode_active = ctrl_toggle
                                        ctrl_was_pressed = True
                                        
                                        if absolute_mode_active:
                                            print("→ Absolute mode ENABLED (Touch to draw)")
                                            # Reset touch state when entering absolute mode
                                            finger_down = False
                                            mouse_press_scheduled = False
                                        else:
                                            print("→ Absolute mode DISABLED")
                                            # Release mouse button when leaving absolute mode
                                            ui.write(ecodes.EV_KEY, ecodes.BTN_LEFT, 0)
                                            ui.syn()
                                    
                                    elif event.value == 0:  # Released
                                        ctrl_was_pressed = False
                        
                        # Handle touchpad events
                        elif device == touchpad:
                            if event.type == ecodes.EV_ABS:
                                # Detect finger touch using tracking ID
                                if event.code == ecodes.ABS_MT_TRACKING_ID:
                                    if event.value != -1:  # Finger touched down
                                        if not finger_down and absolute_mode_active:
                                            finger_down = True
                                            last_touch_time = current_time
                                            mouse_press_scheduled = True
                                            print("→ Finger detected - mouse press in 50ms")
                                    else:  # Finger lifted (value == -1)
                                        if finger_down:
                                            finger_down = False
                                            mouse_press_scheduled = False
                                            # Release mouse button immediately
                                            ui.write(ecodes.EV_KEY, ecodes.BTN_LEFT, 0)
                                            ui.syn()
                                            print("→ Finger lifted - mouse released")
                                
                                # Detect finger via position events (fallback)
                                # You can comment this out if you
                                # like, but in my experience, I can't
                                # ever tell which will work on
                                # what machine, so just keep it 

                                elif event.code in [ecodes.ABS_MT_POSITION_X, ecodes.ABS_MT_POSITION_Y]:
                                    if not finger_down and absolute_mode_active:
                                        finger_down = True
                                        last_touch_time = current_time
                                        mouse_press_scheduled = True
                                        print("→ Finger detected via position - mouse press in 50ms")
                                
                                # Handle coordinate updates
                                if absolute_mode_active and finger_down:
                                    if event.code in [ecodes.ABS_X, ecodes.ABS_MT_POSITION_X]:
                                        # Convert to screen coordinates
                                        normalized_x = (event.value - x_min) / (x_max - x_min)
                                        target_x = int(normalized_x * screen_width)
                                        target_x = max(0, min(screen_width, target_x))
                                        
                                        # Apply smoothing
                                        smoothed_x = int(SMOOTHING_FACTOR * target_x + (1 - SMOOTHING_FACTOR) * smoothed_x)
                                        ui.write(ecodes.EV_ABS, ecodes.ABS_X, smoothed_x)
                                        last_x = target_x
                                        
                                    elif event.code in [ecodes.ABS_Y, ecodes.ABS_MT_POSITION_Y]:
                                        # Convert to screen coordinates
                                        normalized_y = (event.value - y_min) / (y_max - y_min)
                                        target_y = int(normalized_y * screen_height)
                                        target_y = max(0, min(screen_height, target_y))
                                        
                                        # Apply smoothing
                                        smoothed_y = int(SMOOTHING_FACTOR * target_y + (1 - SMOOTHING_FACTOR) * smoothed_y)
                                        ui.write(ecodes.EV_ABS, ecodes.ABS_Y, smoothed_y)
                                        last_y = target_y
                                    
                                    ui.syn()
                                
                                elif not absolute_mode_active:
                                    # Relative mode handling
                                    if event.code in [ecodes.ABS_X, ecodes.ABS_MT_POSITION_X]:
                                        delta_x = event.value - last_x
                                        if abs(delta_x) > 2:
                                            rel_x = delta_x // 15
                                            ui.write(ecodes.EV_REL, ecodes.REL_X, rel_x)
                                            last_x = event.value
                                            
                                    elif event.code in [ecodes.ABS_Y, ecodes.ABS_MT_POSITION_Y]:
                                        delta_y = event.value - last_y
                                        if abs(delta_y) > 2:
                                            rel_y = delta_y // 15
                                            ui.write(ecodes.EV_REL, ecodes.REL_Y, rel_y)
                                            last_y = event.value
                                    
                                    ui.syn()
                            
                            elif event.type == ecodes.EV_KEY:
                                # Handle touchpad button events (only in relative mode)
                                if not absolute_mode_active:
                                    if event.code in [ecodes.BTN_LEFT, ecodes.BTN_RIGHT, ecodes.BTN_MIDDLE, ecodes.BTN_TOUCH]:
                                        ui.write(ecodes.EV_KEY, event.code, event.value)
                                        ui.syn()
                            
                            elif event.type == ecodes.EV_SYN:
                                ui.syn()
                
                except BlockingIOError:
                    # No data available, continue to next device
                    continue
                except OSError as e:
                    if e.errno == errno.EAGAIN:
                        # Resource temporarily unavailable, continue
                        continue
                    else:
                        # Other error, re-raise
                        raise
            
            # Handle delayed mouse press
            if absolute_mode_active and finger_down and mouse_press_scheduled:
                time_since_touch = current_time - last_touch_time
                if time_since_touch >= MOUSE_PRESS_DELAY:
                    ui.write(ecodes.EV_KEY, ecodes.BTN_LEFT, 1)
                    ui.syn()
                    mouse_press_scheduled = False
                    print("→ Mouse button pressed (drawing)")
            
            # Small sleep to prevent CPU spinning at 100%
            time.sleep(0.001)
                
    except KeyboardInterrupt:
        print("\nExiting...")
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
    finally:
        # Clean up - make sure to release mouse button
        ui.write(ecodes.EV_KEY, ecodes.BTN_LEFT, 0)
        ui.syn()
        
        touchpad.ungrab()
        ui.close()
        print("Touchpad returned to normal mode")

if __name__ == "__main__":
    device_path = None
    if len(sys.argv) > 1:
        device_path = sys.argv[1]
    
    create_absolute_mapper(device_path)
