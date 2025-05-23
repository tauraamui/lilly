import src.lib.clipboardv3.x11

fn main() {
	mut s_clip := x11.new_clipboard()
	defer {
		s_clip.shutdown_with_persistence()
	}
	s_clip.set_text("Some example text for stdlib clipboard copy!")
}

