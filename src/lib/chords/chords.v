module chords

import strconv

pub enum Kind as u8 {
	movement
	deletion
}

pub enum Direction as u8 {
	up
	down
	word
	word_end
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

pub fn (mut chord Chord) j() []Op {
	op := chords.Op{ kind: .movement, direction: .down }
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

pub fn (mut chord Chord) k() []Op {
	op := chords.Op{ kind: .movement, direction: .up }
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

pub fn (mut chord Chord) e() []Op {
	op := chords.Op{ kind: .movement, direction: .word_end }
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

pub fn (mut chord Chord) w() []Op {
	op := chords.Op{ kind: .movement, direction: .word }
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

