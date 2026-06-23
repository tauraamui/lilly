module nanoid

import rand
import crypto.rand as crand

const alpha_set = [
	u8(`-`), `_`, `0`, `1`, `2`, `3`, `4`, `5`, `6`, `7`, `8`, `9`,
	`a`, `b`, `c`, `d`, `e`, `f`, `g`, `h`, `i`, `j`, `k`, `l`, `m`,
	`n`, `o`, `p`, `q`, `r`, `s`, `t`, `u`, `v`, `w`, `x`, `y`, `z`
]

pub fn generate(size int) string {
	return custom(alpha_set, size)
}

pub fn simple() string {
	return generate(21)
}

pub fn safe_generate(size int) ?string {
	return safe_custom(alpha_set, size)
}

pub fn safe_simple() ?string {
	return safe_generate(21)
}

pub fn custom(alphas []u8, size int) string {
	alpha_size := alphas.len - 1
	return custom_with(alphas, size, fn [alpha_size] () !int {
		return rand.int_in_range(0, alpha_size)
	})
}

fn custom_with(alphas []u8, size int, next_int fn () !int) string {
	mut id := []u8{ len: size }
	for i in 0..size {
		random_num := next_int() or { 0 }
		id[i] = alphas[random_num]
	}
	return id.bytestr()
}

pub fn safe_custom(alphas []u8, size int) ?string {
	return safe_custom_with(alphas, size, fn () !u8 {
		b := crand.bytes(1)!
		return b[0]
	})
}

fn safe_custom_with(alphas []u8, size int, next_byte fn () !u8) ?string {
	alpha_size := alphas.len
	if alpha_size == 0 || alpha_size > 256 {
		return none
	}

	limit := 256 - (256 % alpha_size) // to make max/limit be evenly devisable by 256
	mut rand_buf := []u8{ len: size }

	for i in 0..size {
		mut b := u8(0)
		for {
			b = next_byte() or { return none }
			if b < limit {
				break
			}
		}
		rand_buf[i] = alphas[b % u8(alpha_size)]
	}

	return rand_buf.bytestr()
}


