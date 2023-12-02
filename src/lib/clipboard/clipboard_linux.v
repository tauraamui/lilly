module clipboard

import clipboard as stdlib_clipboard
import os

fn new_clipboard() Clipboard {
	// NOTE(tauraamui): temp disable wayland clipboard support
	// if os_running_wayland() {
	// 	$if !test { return WaylandClipboard{} }
	// }
	$if test { return MockClipboard{} }
	return StdLibClipboard{ ref: stdlib_clipboard.new_primary() }
}

fn os_running_wayland() bool { return os.getenv("WAYLAND_DISPLAY").len > 0 }
