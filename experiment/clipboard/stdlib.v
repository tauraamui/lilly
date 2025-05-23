import clipboard

fn main() {
	mut s_clip := clipboard.new()
	defer { s_clip.destroy() }
	s_clip.copy("Some example text for stdlib clipboard copy!")
}

