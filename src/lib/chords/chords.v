module chords

import strconv

pub enum Kind as u8 {
	nop
	mode
	move
	delete
}

pub enum Direction as u8 {
	left
	up
	right
	down
	word
	word_end
	inside_word
}

pub enum Mode as u8 {
	insert
}

pub struct Op {
pub:
	kind      Kind
	direction Direction
	mode      Mode
	repeat    int
}

pub struct Chord {
mut:
	pending_motion        string
	pending_repeat_amount string
}

pub fn (chord Chord) pending_repeat_amount() string { return chord.pending_repeat_amount }

pub fn (mut chord Chord) reset() { chord.pending_repeat_amount = "" }

pub fn (mut chord Chord) append_to_repeat_amount(n string) {
	chord.pending_repeat_amount = "${chord.pending_repeat_amount}${n}"
}

pub fn (mut chord Chord) c() Op {
	chord.pending_motion = "c"
	return Op{ kind: .nop }
}

pub fn (mut chord Chord) i() Op {
	if chord.pending_motion.len == 0 {
		return Op{ kind: .mode, mode: .insert }
	}
	op := Op{ kind: .nop }
	if chord.pending_motion == "ci" { chord.pending_motion = ""; return op }
	chord.pending_motion = "${chord.pending_motion}i"
	return op
}

pub fn (mut chord Chord) h() Op {
	return chord.create_op(.move, .left)
}

pub fn (mut chord Chord) l() Op {
	return chord.create_op(.move, .right)
}

pub fn (mut chord Chord) j() Op {
	return chord.create_op(.move, .down)
}

pub fn (mut chord Chord) k() Op {
	return chord.create_op(.move, .up)
}

pub fn (mut chord Chord) e() Op {
	return chord.create_op(.move, .word_end)
}

fn (mut chord Chord) create_op(kind Kind, direction Direction) Op {
	defer { chord.pending_motion = ""; chord.pending_repeat_amount = "" }
	count := strconv.atoi(chord.pending_repeat_amount) or { 1 }
	return Op{ kind: kind, direction: direction, repeat: count }
}

pub fn (mut chord Chord) w() Op {
	if chord.pending_motion == "c" { return chord.create_op(.delete, .word) }
	if chord.pending_motion == "ci" { return chord.create_op(.delete, .inside_word) }
	return chord.create_op(.move, .word)
}

