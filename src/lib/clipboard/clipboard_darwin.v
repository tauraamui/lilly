module clipboard

import clipboard as stdlib_clipboard
import os

fn new_clipboard() Clipboard {
	return StdLibClipboard{ ref: stdlib_clipboard.new() }
}

