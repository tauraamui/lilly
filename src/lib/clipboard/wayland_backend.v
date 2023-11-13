module clipboard

import os

[heap]
struct WaylandClipboard {
mut:
	content string
}

fn (mut wclipboard WaylandClipboard) copy(text string) bool {
	mut cmd := os.Command{
		path: "echo '${text}' | wl-copy"
	}
	defer { cmd.close() or { } }
	cmd.start() or { return false }
	return cmd.exit_code == 0
}

fn (wclipboard WaylandClipboard) paste() []string {
	mut cmd := os.Command{
		path: "wl-paste"
	}
	defer { cmd.close() or { } }
	cmd.start() or { panic(err) }

	mut out := []string{}
	for {
		out << cmd.read_line()
		if cmd.eof { break }
	}

	if cmd.exit_code == 0 { return out }

	return []
}

