module chords

import strconv

pub enum Kind as u8 {
	nop
	mode
	movement
	deletion
}

pub enum Direction as u8 {
	up
	down
	word
	word_end
}

pub enum Mode as u8 {
	insert
}

pub struct Op {
pub:
	kind      Kind
	direction Direction
	mode      Mode
	repeat    int // TODO(tauraamui): use this field instead of returning a list of ops
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
		chord.pending_motion = ""
		chord.pending_repeat_amount = ""
		return Op{ kind: .mode, mode: .insert }
	}
	chord.pending_motion = "${chord.pending_motion}i"
	return Op{ kind: .nop }
}

pub fn (mut chord Chord) j() Op {
	defer { chord.pending_motion = ""; chord.pending_repeat_amount = "" }
	count := strconv.atoi(chord.pending_repeat_amount) or { 1 }
	return Op{ kind: .movement, direction: .down, repeat: count }
}

pub fn (mut chord Chord) k() Op {
	defer { chord.pending_motion = ""; chord.pending_repeat_amount = "" }
	count := strconv.atoi(chord.pending_repeat_amount) or { 1 }
	return Op{ kind: .movement, direction: .up, repeat: count }
}

pub fn (mut chord Chord) e() Op {
	defer { chord.pending_motion = ""; chord.pending_repeat_amount = "" }
	count := strconv.atoi(chord.pending_repeat_amount) or { 1 }
	return Op{ kind: .movement, direction: .word_end, repeat: count }
}

pub fn (mut chord Chord) w() Op {
	defer { chord.pending_motion = ""; chord.pending_repeat_amount = "" }
	count := strconv.atoi(chord.pending_repeat_amount) or { 1 }
	return Op{ kind: .movement, direction: .word, repeat: count }
}

