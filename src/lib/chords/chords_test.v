module chords

fn test_chord_generates_single_op_from_single_direction_with_no_repeat_amount() {
	mut chord := Chord{}
	ops := chord.expand_ops(Op{ kind: .movement, direction: .down })
	assert ops == [Op{ kind: .movement, direction: .down }]
}
