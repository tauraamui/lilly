import src.lib.clipboardv3.x11

fn main() {
	mut s_clip := x11.new_clipboard()
	s_clip.set_text("Some example text for stdlib clipboard copy!")
}

