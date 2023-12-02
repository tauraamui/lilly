module clipboard

import clipboard as stdlib_clipboard

fn new_clipboard() Clipboard {
	return StdLibClipboard{ ref: stdlib_clipboard.new() }
}

