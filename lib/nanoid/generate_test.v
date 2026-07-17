module nanoid

import rand

fn test_simple_generation() {
	rand.seed([u32(22), 59])
	assert simple() == 'k6xdi7ljafxso8iinbb-m'
}

fn test_simple_generation_from_seed() {
	assert simple_with_seed('~/src/project/file.v') == 'xuegdsoaelebpmo_6vynr'
	assert simple_with_seed('/home/user/document/notes.txt') == 'rl_4efe3q63jp-jyw8_nw'
	assert simple_with_seed('/tmp/misc/xxfeiwjfiewfiwe.backup') == '83hucvhu8dr6hj3v3pm9l'
}

// NOTE(tauraamui) [2026-06-23]: the assertions of these tests passing relies on the stdlib's internal
// RNG functionality remaining the same. if in future they inexplicably fail after a compiler update
// we can just remove the seed setting tests entirely.
fn test_generate_generation() {
	rand.seed([u32(93), 152])
	assert generate(4) == 'a321'
	assert generate(8) == '_rn2x_ue'
	assert generate(16) == 'eskc6wy86ai1adri'
}

fn test_custom_generation() {
	custom_alpha_set := [u8(`*`), `+`, `|`, `~`, `2`, `v`, `p`]

	rand.seed([u32(93), 152])

	assert custom(custom_alpha_set, 4) == '|v*v'
	assert custom(custom_alpha_set, 8) == '2+~~+**|'
	assert custom(custom_alpha_set, 16) == '+|+|~2v~+~+v*2**'
}

fn test_custom_generation_with() {
	mut idx := 0
	custom_alpha_set := [u8(`*`), `+`, `|`, `~`, `2`, `v`, `p`]
	ints := [6, 4, 2, 3, 1, 5, 0]

	next := fn [mut idx, ints] () !int {
		i := ints[idx]
		idx += 1
		return i
	}

	assert custom_with(custom_alpha_set, ints.len, next) == 'p2|~+v*'
}

fn test_safe_custom_generation_is_deterministic_given_static_source() {
	mut idx := 0
	bytes := [u8(0), 1, 2, 3, 4, 5, 6, 7, 8, 9]

	next := fn [mut idx, bytes] () !u8 {
		b := bytes[idx]
		idx += 1
		return b
	}

	hash_output := safe_custom_with([u8(`a`), `b`, `c`, `d`, `e`, `f`, `g`, `h`, `i`, `j`], bytes.len, next) or {
		assert false, 'should not fail'
		return
	}

	assert hash_output == 'abcdefghij'
}

