// Copyright 2026 The Lilly Edtior contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

module main

import os

fn pattern_error(src string) string {
	parse_pattern(src) or { return err.msg() }
	return ''
}

fn test_pattern_parser_rejects_malformed_patterns() {
	assert pattern_error('(ab').contains('missing ")"')
	assert pattern_error('*a').contains('nothing to repeat')
	assert pattern_error('[z-a]').contains('backwards')
	assert pattern_error('[\\W]').contains("can't go inside []")
	assert pattern_error('a{3,1}').contains('max below min')
	assert pattern_error('(?=a)*').contains("can't repeat")
	assert pattern_error('ab)').contains('unexpected')
}

fn test_pattern_parser_builds_classes_from_escapes_and_ranges() {
	node := parse_pattern('[a-c\\d_]')!
	assert node.kind == .class
	assert node.ranges == [Range{`a`, `c`}, Range{`0`, `9`}, Range{`_`, `_`}]
	assert parse_pattern('.')!.is_any()
	assert parse_pattern('\\S')!.negated
	// an escaped metacharacter is a literal
	assert parse_pattern('\\*')!.ranges == [Range{`*`, `*`}]
}

fn test_pattern_parser_rejects_escapes_it_does_not_know() {
	assert pattern_error('\\n').contains('unknown escape "\\n"')
	assert pattern_error('a\\b').contains('unknown escape "\\b"')
	assert pattern_error('[\\r]').contains('unknown escape "\\r"')
	assert pattern_error('\\1').contains('unknown escape "\\1"')
	assert pattern_error('[a-\\z]').contains("can't end a range")
	// the escapes it knows, and escaped punctuation, still parse
	for src in ['\\w\\W\\d\\D\\s\\S\\h\\H\\t', '\\.\\(\\]', '[\\w\\-]', '[!-\\/]'] {
		assert pattern_error(src) == '', src
	}
}

fn first_conds(src string) []string {
	f := first_of(parse_pattern(src) or { panic(err) })
	if f.any || f.nullable {
		return ['any']
	}
	return f.classes.map(class_cond(it, 'c'))
}

fn test_first_set_is_what_a_match_can_start_with() {
	assert first_conds('//.*') == ['c == `/`']
	assert first_conds('c?"') == ['c == `c`', 'c == `"`']
	assert first_conds('[A-Z]\\w*') == ['c >= `A` && c <= `Z`']
	assert first_conds('^\\s*#') == ['c == ` ` || c == rune(9)', 'c == `#`']
	// nothing to filter on when a pattern can match without consuming
	assert first_conds('(?=x)') == ['any']
	assert first_conds('a*') == ['any']
	assert first_conds('.x') == ['any']
}

fn test_conditions_bracket_mixed_and_or() {
	assert or_join(['a', 'b && c']) == 'a || (b && c)'
	assert and_join(['a', 'b || c']) == 'a && (b || c)'
	assert and_join(['a']) == 'a'
}

fn grammar_error(src string) string {
	parse_grammar('test', src) or { return err.msg() }
	return ''
}

fn test_grammar_errors_say_what_is_wrong() {
	assert grammar_error('name "T"\ncontext "other" {}').contains('first context must be "main"')
	assert grammar_error('context "main" {}').contains('missing name')
	assert grammar_error('name "T"\ncontext "main" {\nrule "a" push="nowhere"\n}').contains('unknown context "nowhere"')
	assert grammar_error('name "T"\ncontext "main" {\ninclude "main"\n}').contains('includes itself')
	assert grammar_error('name "T"\nwords "keyword" if\nwords "literal" if\ncontext "main" {}').contains('is in both')
	assert grammar_error('name "T"\ncontext "main" {\nrule "a" scope="Bad"\n}').contains('bad scope')
	assert grammar_error('name "T"\ncontext "main" {\nrule "a" push="main" pop=#true\n}').contains('only push, set or pop')
	assert grammar_error('name "T"\ncontext "Main" {}').contains('bad context name')
}

fn test_includes_splice_rules_in_where_they_stand() {
	g := parse_grammar('test', 'name "T"
context "main" {
	rule "a"
	include "other"
	rule "c"
}
context "other" {
	rule "b"
}')!
	assert g.contexts[0].rules.map(it.pattern) == ['a', 'b', 'c']
}

fn test_generator_rejects_a_rule_that_matches_nothing_and_does_nothing() {
	g := parse_grammar('test', 'name "T"\ncontext "main" {\nrule "x*"\n}')!
	generate(g, '', {}) or {
		assert err.msg().contains('can match nothing')
		return
	}
	assert false, 'expected an error'
}

fn test_a_rule_pops_through_only_when_it_pops() {
	g := parse_grammar('test', 'name "T"
context "main" {
	rule "f" push="f"
}
context "f" {
	rule "x" pop=#true through=#true
}')!
	assert g.contexts[1].rules[0].op == 'pop_through'
	assert grammar_error('name "T"\ncontext "main" {\nrule "a" through=#true\n}').contains('only a rule that pops')
	assert grammar_error('name "T"\ncontext "main" {\nrule "a" push="main" through=#true\n}').contains('only a rule that pops')
}

fn test_each_rule_declares_its_match_in_a_block_of_its_own() {
	// a rule that can't be guarded by its first rune, then one that can,
	// each with an `e` of its own
	g := parse_grammar('test', 'name "T"
context "main" {
	rule "a" push="f"
}
context "f" {
	rule "(?=b)" pop=#true
	rule "c"
}')!
	code := generate(g, '', {})!
	assert code.code.contains('fn lex_test_ctx_f(')
	f := code.code.all_after('fn lex_test_ctx_f(').all_before('\n}\n')
	assert f.contains('\t{\n\t\te := ')
	assert f.contains('\tif c == `c` {\n\t\te := ')
}

// embedded is a grammar to embed: two contexts, one pushing the other
const embedded = 'name "E"
context "main" {
	rule "a" push="s"
	rule "w" words=#true
}
context "s" {
	rule "b" pop=#true
}'

fn host_grammar(src string) !Grammar {
	e := parse_grammar('emb', embedded)!
	mut g := parse_grammar('host', src)!
	g.link_embeds([e, g])!
	return g
}

fn embed_error(src string) string {
	host_grammar(src) or { return err.msg() }
	return ''
}

fn test_an_embedding_rule_needs_an_escape_and_does_nothing_else() {
	assert grammar_error('name "T"\ncontext "main" {\nrule "a" embed="emb"\n}').contains('needs an escape')
	assert grammar_error('name "T"\ncontext "main" {\nrule "a" escape="b"\n}').contains('only a rule that embeds')
	assert grammar_error('name "T"\ncontext "main" {\nrule "a" embed="emb" escape="b" pop=#true\n}').contains("can't also push")
	// the target is its copy's root, which only exists once linked
	g := parse_grammar('host', 'name "T"\ncontext "main" {\nrule "a" embed="emb" escape="b"\n}')!
	assert g.contexts[0].rules[0].op == 'push'
}

fn test_linking_rejects_embeds_it_cant_make() {
	assert embed_error('name "T"\ncontext "main" {\nrule "a" embed="nope" escape="b"\n}').contains('unknown grammar "nope"')
	assert embed_error('name "T"\ncontext "main" {\nrule "a" embed="host" escape="b"\n}').contains("can't embed itself")
	assert embed_error('name "T"\ncontext "main" {\nrule "a" embed="emb" escape="b*"\n}').contains('can match nothing')
	e := parse_grammar('emb', embedded)!
	g := parse_grammar('host', 'name "T"\ncontext "main" {\nrule "a" embed="emb" escape="b"\n}')!
	mut outer := parse_grammar('outer', 'name "O"\ncontext "main" {\nrule "a" embed="host" escape="b"\n}')!
	outer.link_embeds([e, g, outer]) or {
		assert err.msg().contains('which embeds grammars itself')
		return
	}
	assert false, 'expected an error'
}

fn test_linking_copies_the_embedded_contexts_once_per_escape() {
	g := host_grammar('name "T"
context "main" {
	rule "x" embed="emb" escape="y"
	rule "z" push="other"
}
context "other" {
	rule "x" embed="emb" escape="y"
	rule "q" embed="emb" escape="q"
}')!
	// the root is named after the embedded grammar; its other contexts keep
	// their names
	assert g.contexts.map(it.name) == ['main', 'other', 'emb', 's', 'emb', 's']
	assert g.contexts[0].rules[0].embed_root == 2
	assert g.contexts[1].rules[0].embed_root == 2
	assert g.contexts[1].rules[1].embed_root == 4
	assert g.embeds.map(it.root) == [2, 4]
	copy := g.contexts[3].copy or { panic('not a copy') }
	assert copy.embed == 0 && copy.source == 1 && copy.source_name == 's'
}

fn test_a_copy_escapes_then_runs_the_embedded_context_with_its_targets_moved() {
	g := host_grammar('name "T"\ncontext "main" {\nrule "x" embed="emb" escape="^y"\nrule "u" embed="emb" escape="y"\n}')!
	code := generate(g, '', {
		'emb': [false, false]
	})!.code
	assert code.contains('1 { lex_host_ctx_e0_emb(r, i) }')
	assert code.contains('2 { lex_host_ctx_e0_s(r, i) }')
	assert code.contains('3 { lex_host_ctx_e1_emb(r, i) }')
	root := code.all_after('fn lex_host_ctx_e0_emb(').all_before('\n}\n')
	assert root.contains('if i == 0 && r[i] == `y` {')
	assert root.contains('op: .escape\n\t\t\t\ttarget: 1\n')
	assert root.contains('m := lex_emb_ctx_main(r, i)')
	assert root.contains('target: m.target + 1')
	// an escape only at the start of a line can't be inside plain text
	assert !root.contains('m.end < 0')
	// one anywhere stops plain text short of where it could start
	mid := code.all_after('fn lex_host_ctx_e1_emb(').all_before('\n}\n')
	assert mid.contains('if r[i] == `y` {')
	assert mid.contains('for j < m.next && !(r[j] == `y`) {')
	// a context function taking emit is called with it
	with_emit := generate(g, '', {
		'emb': [true, false]
	})!.code
	assert with_emit.contains('fn lex_host_ctx_e0_emb(r []rune, i int, emit bool) Match {')
	assert with_emit.contains('m := lex_emb_ctx_main(r, i, emit)')
	assert with_emit.contains('fn lex_host_step(ctx u8, r []rune, i int, emit bool) Match {')
	// and the grammar embedded has to be generated first
	generate(g, '', {}) or {
		assert err.msg().contains('has to be generated first')
		return
	}
	assert false, 'expected an error'
}

fn firsts_of(patterns []string) []First {
	return patterns.map(first_of(parse_pattern(it) or { panic(err) }))
}

fn test_a_first_rune_table_gives_each_guarded_rule_a_bit() {
	// a rule starting with any rune can't be guarded, so it has no bit
	table := first_rune_table(firsts_of(['//.*', '.y', '[a-z_]\\w*', '"', '[^"]+', 'é']))
	assert table.bits == [u64(1), 0, 2, 4, 8, 16]
	assert table.mask_type == 'u32'
	assert table.ascii[`/`] == 1 | 8
	assert table.ascii[`q`] == 2 | 8
	assert table.ascii[`_`] == 2 | 8
	assert table.ascii[`"`] == 4
	assert table.ascii[`7`] == 8
	// a negated class and a class past ASCII are tested for wider runes
	assert table.wide == [4, 5]
}

fn test_a_context_with_few_guarded_rules_or_too_many_has_no_table() {
	assert first_rune_table(firsts_of(['a', '.c', 'd'])).bits.len == 0
	mut many := []string{}
	for k in 0 .. 65 {
		many << 'x${k}'
	}
	assert first_rune_table(firsts_of(many)).bits.len == 0
	assert first_rune_table(firsts_of(many[..40])).mask_type == 'u64'
}

fn test_a_context_with_a_table_tests_bits() {
	g := parse_grammar('test', 'name "T"
context "main" {
	rule "^#.*" scope="comment"
	rule "a+" scope="keyword"
	rule "b" scope="string"
	rule "[^a-z ]" scope="operator"
}')!
	code := generate(g, '', {})!.code
	assert code.contains('const lex_test_first_main = [u32(')
	main_fn := code.all_after('fn lex_test_ctx_main(').all_before('\n}\n')
	assert main_fn.contains('f := if c < 128 { lex_test_first_main[c] } else { lex_test_first_wide_main(c) }')
	assert main_fn.contains('if i == 0 && f & 1 != 0 {')
	assert main_fn.contains('if f & 2 != 0 {')
	assert main_fn.contains('if f & 8 != 0 {')
	// plain text stops where a rule other than the line start one could start
	assert main_fn.contains('if (if x < 128 { lex_test_first_main[x] } else { lex_test_first_wide_main(x) }) & 14 != 0 {')
	wide := code.all_after('fn lex_test_first_wide_main(').all_before('\n}\n')
	assert wide.contains('f |= 8')
	assert !wide.contains('f |= 2')
}

fn test_skip_classes_are_deduplicated_without_a_table() {
	g := parse_grammar('test', 'name "T"
context "main" {
	rule "ab" scope="keyword"
	rule "ac" scope="string"
}')!
	code := generate(g, '', {})!.code
	main_fn := code.all_after('fn lex_test_ctx_main(').all_before('\n}\n')
	assert main_fn.contains('\t\tif x == `a` {')
}

fn test_a_context_defined_twice_is_an_error() {
	assert grammar_error('name "T"\ncontext "main" {}\ncontext "s" {}\ncontext "s" {}').contains('context "s" is defined twice')
}

fn test_scopes_are_read_from_the_scope_enum() {
	scopes := read_scopes(os.read_file(os.join_path(@VMODROOT, 'lib', 'syntax', 'scope.v'))!)!
	assert scopes.first() == 'none'
	assert 'keyword_control' in scopes
	assert 'storage_type_definition' in scopes
	assert scopes.all(!it.contains('/') && !it.contains(' '))
	assert read_scopes('module syntax') or { []string{} } == []string{}
}

fn test_a_scope_the_enum_does_not_have_is_an_error() {
	known := ['none', 'keyword', 'keyword_control', 'string']
	g := parse_grammar('test', 'name "T"
words "keyword.control" if
context "main" {
	rule "a" scope="keyword"
}
context "s" scope="string" {
	rule "b" pop=#true
}')!
	g.check_scopes(known)!
	scope_error := fn [known] (src string) string {
		g := parse_grammar('test', src) or { return err.msg() }
		g.check_scopes(known) or { return err.msg() }
		return ''
	}
	assert scope_error('name "T"\ncontext "main" {\nrule "a" scope="keywrod"\n}').contains('rule "a": unknown scope "keywrod"')
	assert scope_error('name "T"\ncontext "main" scope="strings" {}').contains('context "main": unknown scope "strings"')
	assert scope_error('name "T"\nwords "keyword.flow" if\ncontext "main" {}').contains('word "if": unknown scope "keyword.flow"')
}

fn test_properties_that_are_misspelt_mistyped_or_empty_are_errors() {
	rule := fn (props string) string {
		return grammar_error('name "T"\ncontext "main" {\nrule "a" ${props}\n}\ncontext "s" {}')
	}
	assert rule('pop="true"').contains('pop needs #true or #false')
	assert rule('push="s" through=1').contains('through needs #true or #false')
	assert rule('set=42').contains('set needs a string')
	assert rule('set=""').contains("set can't be empty")
	assert rule('push=""').contains("push can't be empty")
	assert rule('scope=""').contains("scope can't be empty")
	assert rule('pusj="s"').contains('unknown property "pusj"')
	assert grammar_error('name "T"\ncontext "main" pop_at_eol="yes" {}').contains('pop_at_eol needs #true or #false')
	assert grammar_error('name "T"\ncontext "main" scop="string" {}').contains('unknown property "scop"')
	// well formed ones still parse, #false included
	assert rule('push="s" scope="keyword"') == ''
	assert rule('pop=#false') == ''
}
