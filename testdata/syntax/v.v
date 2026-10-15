// V syntax stress file. Not meant to compile cleanly, only to lex.
module main

import os
import strings { Builder }

/*
 * Block comments in V nest:
 * /* this inner comment must not end the outer one */
 * still a comment here, the outer one closes on the next line
 */
const max_depth = 0x7F_FF
const ratio = 1_000.25e-3
const mask = 0b1010_0101
const perms = 0o755

/* single line block */ const after_comment = 1 /* trailing */ + 2

@[heap; minify]
pub struct Node[T] {
mut:
	value    T
	children []&Node[T]
pub:
	name string = 'root'
}

@[inline]
fn (n &Node[T]) depth[T]() int {
	mut best := 0
	for child in n.children {
		d := child.depth()
		if d > best {
			best = d
		}
	}
	return best + 1
}

enum Colour as u8 {
	red   = 1
	green
	blue
}

interface Shape {
	area() f64
mut:
	scale(factor f64)
}

type Token = Ident | Number | string

fn interpolation_cases(name string, items []int) string {
	plain := 'hello ${name}'
	nested_braces := 'map: ${{'a': 1, 'b': {'deep': 2}['deep']}}'
	call_in_interp := "len=${items.filter(fn (x int) bool { return x > 0 }).len}"
	string_in_interp := 'outer ${'inner ${name} done'} outer again'
	format_spec := '${ratio:8.3f} | ${max_depth:x} | ${name:-10s}|'
	escaped := 'not interp: \${name} and quote \' and tab \t and \u00e9'
	dollar_alone := 'cost: $5 and ${items[0] + items[1]}'
	return plain + nested_braces + call_in_interp + string_in_interp + format_spec + escaped +
		dollar_alone
}

fn raw_and_c_strings() {
	raw := r'C:\path\no\escapes\${not_interp}'
	raw_double := r"regex \d+\s*\w+"
	cstr := c'hello from C\n'
	cstr_double := c"also C"
	multi := '
line one of a multi-line literal
	line two with ${interpolation_cases('x', [1, 2])}
line three '
	println(raw + raw_double + multi)
	_ = cstr
	_ = cstr_double
}

fn runes() {
	a := `a`
	newline := `\n`
	backtick := `\``
	unicode := `é`
	println('${a}${newline}${backtick}${unicode}')
}

fn compile_time() {
	$if linux {
		println('on linux')
	} $else $if macos {
		println('on mac')
	}
	$for field in Node[int].fields {
		println(field.name)
	}
	println(@FN + ' in ' + @MOD + ' at ' + @LINE)
	path := $embed_file('v.v')
	_ = path
}

fn control_flow(x ?int) !int {
	val := x or { return error('none given') }
	result := match val {
		0 { 'zero' }
		1...9 { 'small' }
		else { 'big' }
	}
	defer {
		eprintln('leaving with ${result}')
	}
	shared counter := 0
	lock counter {
		counter++
	}
	rlock counter {
		println(counter)
	}
	t := spawn fn () int {
		return 42
	}()
	if val is int && val !in [1, 2, 3] {
		unsafe {
			goto end
		}
	}
	end:
	return t.wait()
}

fn main() {
	mut sb := Builder{}
	sb.write_string(interpolation_cases('lilly', [1, -2, 3]))
	println(sb.str())
	raw_and_c_strings()
	runes()
	compile_time()
	n := control_flow(none) or { -1 }
	assert n == -1, 'expected fallback'
	println(os.args)
}
