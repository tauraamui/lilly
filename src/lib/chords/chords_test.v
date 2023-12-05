module chords

fn test_chord_generates_single_op_from_directions_with_no_repeat_amount() {
	mut chord := Chord{}
	assert chord.h() == Op{ kind: .move, direction: .left, repeat: 1 }
	assert chord.j() == Op{ kind: .move, direction: .down, repeat: 1 }
	assert chord.k() == Op{ kind: .move, direction: .up, repeat: 1 }
	assert chord.l() == Op{ kind: .move, direction: .right, repeat: 1 }
	assert chord.w() == Op{ kind: .move, direction: .word, repeat: 1 }
	assert chord.e() == Op{ kind: .move, direction: .word_end, repeat: 1 }
}

fn test_chord_generates_single_op_from_invoking_i_alone() {
	mut chord := Chord{}
	assert chord.i() == Op{ kind: .mode, mode: .insert }
}

fn test_chord_generates_single_nop_op_from_invoking_c_alone() {
	mut chord := Chord{}
	assert chord.c() == Op{ kind: .nop }
}

fn test_chord_generates_single_deletion_op_from_invoking_c_and_w() {
	mut chord := Chord{}
	assert chord.c() == Op{ kind: .nop }
	assert chord.w() == Op{ kind: .delete, direction: .word, repeat: 1 }
}

fn test_chord_generates_single_deletion_op_from_invoking_c_i_and_w() {
	mut chord := Chord{}
	assert chord.c() == Op{ kind: .nop }
	assert chord.i() == Op{ kind: .nop }
	assert chord.w() == Op{ kind: .delete, direction: .inside_word, repeat: 1 }
}

fn test_chord_generates_single_nop_op_from_invoking_c_i_and_i_again() {
	mut chord := Chord{}
	assert chord.c() == Op{ kind: .nop }
	assert chord.i() == Op{ kind: .nop }
	assert chord.i() == Op{ kind: .nop }
}
