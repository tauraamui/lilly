module nanoid

import rand

fn test_simple_generation() {
	rand.seed([u32(22), 59])
	assert simple() == 'k6xdi7ljafxso8iinbb-m'
}

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

