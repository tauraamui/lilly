module draw

struct Debug {
}

fn (mut debug Debug) draw(mut ctx Contextable) {
	ctx.draw_text(0, 0, "A")
}

fn (mut debug Debug) on_key_down(e Event, r mut Root) {
	if e.code == .escape { r.quit() }
}

