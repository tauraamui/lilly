module chords

import strconv

pub enum Kind as u8 {
	movement
}

pub enum Direction as u8 {
	up
	down
}

pub struct Op {
pub:
	kind      Kind
	direction Direction
}

pub struct Chord {
mut:
	pending_repeat_amount string
}

pub fn (chord Chord) pending_repeat_amount() string { return chord.pending_repeat_amount }

pub fn (mut chord Chord) reset() { chord.pending_repeat_amount = "" }

pub fn (mut chord Chord) append_to_repeat_amount(n string) {
	chord.pending_repeat_amount = "${chord.pending_repeat_amount}${n}"
}

pub fn (mut chord Chord) expand_ops(op Op) []Op {
	defer { chord.pending_repeat_amount = "" }
	mut ops := []Op{}
	if chord.pending_repeat_amount.len == 0 { ops << op; return ops }
	count := strconv.atoi(chord.pending_repeat_amount) or { 1 }
	if count - 1 <= 1 { return ops }
	for _ in 0..count {
		ops << op
	}
	return ops
}

