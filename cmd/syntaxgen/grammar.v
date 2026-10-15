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

import kdlv
import os

// Grammar is one language's grammar file, loaded and checked
struct Grammar {
	// id names the generated code: lex_<id>_*, Lang.<id>
	id         string
	name       string
	extensions []string
	// words maps each word to its dotted scope
	words map[string]string
mut:
	contexts []Context
	// embeds are the other grammars embedded in this one, each with its
	// contexts copied in after this grammar's own
	embeds []Embed
}

// Embed is another grammar embedded until an escape pattern matches, e.g. the
// code in a Markdown fence. Its contexts are copied in from `root` on, each
// copy matching the escape before running the embedded grammar's own context.
struct Embed {
	lang   string
	escape string
	// scope is what the escape matches
	scope string
	root  int
}

// Copy marks a context as a copy of an embedded grammar's context
struct Copy {
	// embed indexes the grammar's embeds
	embed int
	// source is the context's index in the embedded grammar
	source      int
	source_name string
}

// Context is a named set of rules, with includes already resolved
struct Context {
	name        string
	scope       string
	pops_at_eol bool
	copy        ?Copy
mut:
	rules []Rule
	// includes lists the contexts whose rules go where each `include`
	// stood, by index into rules
	includes []Include
}

struct Include {
	at   int
	name string
}

struct Rule {
	pattern string
	// scope is the dotted scope of what the rule matches. Empty means the
	// scope of the context the rule matched in.
	scope string
	// words makes the rule match only text found in the grammar's word lists,
	// taking the scope the word list gives it
	words  bool
	op     string
	target string
	// embed names the grammar a rule embeds, until `escape` matches; the rule
	// pushes the root of that grammar's copied contexts
	embed  string
	escape string
mut:
	embed_root int
}

fn load_grammar(path string) !Grammar {
	src := os.read_file(path)!
	id := os.file_name(path).all_before_last('.')
	if !is_ident(id) {
		return error('${path}: the file name has to be a lower case V identifier')
	}
	return parse_grammar(id, src) or { return error('${path}: ${err}') }
}

fn parse_grammar(id string, src string) !Grammar {
	doc := kdlv.parse(src)!
	mut name := ''
	mut extensions := []string{}
	mut words := map[string]string{}
	mut contexts := []Context{}
	for node in doc.nodes {
		match node.name {
			'name' {
				name = string_arg(node, 0)!
			}
			'extensions' {
				extensions = string_args(node)!
			}
			'words' {
				args := string_args(node)!
				if args.len < 2 {
					return error('words needs a scope and at least one word')
				}
				scope := check_scope(args[0])!
				for word in args[1..] {
					if word in words && words[word] != scope {
						return error('word "${word}" is in both ${words[word]} and ${scope}')
					}
					words[word] = scope
				}
			}
			'context' {
				contexts << parse_context(node)!
			}
			else {
				return error('unknown top level node "${node.name}"')
			}
		}
	}
	if name.len == 0 {
		return error('missing name')
	}
	if contexts.len == 0 || contexts[0].name != 'main' {
		return error('the first context must be "main"')
	}
	if contexts.len > 255 {
		return error('too many contexts (${contexts.len}), the limit is 255')
	}
	for i, ctx in contexts {
		if contexts[..i].any(it.name == ctx.name) {
			return error('context "${ctx.name}" is defined twice')
		}
	}
	mut g := Grammar{
		id:         id
		name:       name
		extensions: extensions
		words:      words
		contexts:   contexts
	}
	g.resolve_includes()!
	g.check_targets()!
	return g
}

fn parse_context(node &kdlv.Node) !Context {
	name := string_arg(node, 0)!
	if !is_ident(name) {
		return error('bad context name "${name}": use lower case letters, digits and _')
	}
	check_props(node, ['scope', 'pop_at_eol'])!
	mut ctx := Context{
		name:        name
		scope:       check_scope(string_prop(node, 'scope')!)!
		pops_at_eol: bool_prop(node, 'pop_at_eol')!
	}
	for child in node.children {
		match child.name {
			'rule' {
				ctx.rules << parse_rule(child) or {
					return error('context "${name}" rule ${ctx.rules.len + 1}: ${err}')
				}
			}
			'include' {
				ctx.includes << Include{
					at:   ctx.rules.len
					name: string_arg(child, 0)!
				}
			}
			else {
				return error('context "${name}": unknown node "${child.name}"')
			}
		}
	}
	return ctx
}

fn parse_rule(node &kdlv.Node) !Rule {
	pattern := string_arg(node, 0)!
	check_props(node, ['scope', 'push', 'set', 'pop', 'through', 'words', 'embed', 'escape'])!
	mut op := ''
	mut target := ''
	push := string_prop(node, 'push')!
	if push.len > 0 {
		op, target = 'push', push
	}
	set := string_prop(node, 'set')!
	if set.len > 0 {
		if op.len > 0 {
			return error('a rule can only push, set or pop')
		}
		op, target = 'set', set
	}
	if bool_prop(node, 'pop')! {
		if op.len > 0 {
			return error('a rule can only push, set or pop')
		}
		op = 'pop'
	}
	embed := string_prop(node, 'embed')!
	escape := string_prop(node, 'escape')!
	if embed.len > 0 {
		if op.len > 0 {
			return error("a rule that embeds a grammar can't also push, set or pop")
		}
		if escape.len == 0 {
			return error('a rule that embeds a grammar needs an escape')
		}
		op = 'push'
	}
	if embed.len == 0 && escape.len > 0 {
		return error('only a rule that embeds a grammar has an escape')
	}
	if bool_prop(node, 'through')! {
		if op != 'pop' {
			return error('only a rule that pops can pop through')
		}
		op = 'pop_through'
	}
	words := bool_prop(node, 'words')!
	scope := check_scope(string_prop(node, 'scope')!)!
	if words && scope.len > 0 {
		return error('a words rule takes its scope from the word lists')
	}
	return Rule{
		pattern: pattern
		scope:   scope
		words:   words
		op:      op
		target:  target
		embed:   embed
		escape:  escape
	}
}

// resolve_includes splices each included context's rules in where the
// include stood, recursively
fn (mut g Grammar) resolve_includes() ! {
	mut resolved := [][]Rule{len: g.contexts.len}
	for i in 0 .. g.contexts.len {
		resolved[i] = g.flatten(i, []string{})!
	}
	for i in 0 .. g.contexts.len {
		g.contexts[i].rules = resolved[i]
		g.contexts[i].includes = []
	}
}

fn (g Grammar) flatten(index int, seen []string) ![]Rule {
	ctx := g.contexts[index]
	if ctx.name in seen {
		return error('context "${ctx.name}" includes itself')
	}
	mut out := []Rule{}
	mut next := 0
	for inc in ctx.includes {
		out << ctx.rules[next..inc.at]
		next = inc.at
		included := g.context_index(inc.name) or {
			return error('context "${ctx.name}" includes unknown context "${inc.name}"')
		}
		mut inner_seen := seen.clone()
		inner_seen << ctx.name
		out << g.flatten(included, inner_seen)!
	}
	out << ctx.rules[next..]
	return out
}

fn (g Grammar) check_targets() ! {
	for ctx in g.contexts {
		for rule in ctx.rules {
			if rule.embed.len == 0 && rule.target.len > 0 && g.context_index(rule.target) == none {
				return error('context "${ctx.name}": rule "${rule.pattern}" goes to unknown context "${rule.target}"')
			}
		}
	}
}

// check_scopes makes sure every scope the grammar names is one of `known`,
// the names in lib/syntax/scope.v, so a typo is reported against the grammar
// rather than as an unknown enum value in the generated code
fn (g Grammar) check_scopes(known []string) ! {
	for word, scope in g.words {
		check_known_scope(scope, known) or { return error('word "${word}": ${err}') }
	}
	for ctx in g.contexts {
		check_known_scope(ctx.scope, known) or { return error('context "${ctx.name}": ${err}') }
		for rule in ctx.rules {
			check_known_scope(rule.scope, known) or {
				return error('context "${ctx.name}": rule "${rule.pattern}": ${err}')
			}
		}
	}
}

fn check_known_scope(scope string, known []string) ! {
	if scope.len > 0 && scope_ident(scope) !in known {
		return error('unknown scope "${scope}", see lib/syntax/scope.v')
	}
}

// read_scopes returns the names of the Scope enum in scope.v's source
fn read_scopes(src string) ![]string {
	body := src.find_between('pub enum Scope as u8 {', '}')
	mut names := []string{}
	for line in body.split_into_lines() {
		name := line.trim_space()
		if name.len > 0 && !name.starts_with('//') {
			names << name
		}
	}
	if names.len == 0 {
		return error("can't find the Scope enum")
	}
	return names
}

// link_embeds copies in the contexts of the grammars this one embeds, one set
// per language and escape, and points each embedding rule at its copy's root.
// The root, the copy of the embedded grammar's main, is named after it.
fn (mut g Grammar) link_embeds(grammars []Grammar) ! {
	for ci in 0 .. g.contexts.len {
		if g.contexts[ci].copy != none {
			continue
		}
		for ri in 0 .. g.contexts[ci].rules.len {
			rule := g.contexts[ci].rules[ri]
			if rule.embed.len == 0 {
				continue
			}
			g.contexts[ci].rules[ri].embed_root = g.embed_root(rule, grammars) or {
				return error('context "${g.contexts[ci].name}": ${err}')
			}
		}
	}
	if g.contexts.len > 255 {
		return error('too many contexts with the embedded grammars (${g.contexts.len}), the limit is 255')
	}
}

fn (mut g Grammar) embed_root(rule Rule, grammars []Grammar) !int {
	for e in g.embeds {
		if e.lang == rule.embed && e.escape == rule.escape && e.scope == rule.scope {
			return e.root
		}
	}
	if rule.embed == g.id {
		return error("a grammar can't embed itself")
	}
	src := grammars.filter(it.id == rule.embed)
	if src.len == 0 {
		return error('embeds unknown grammar "${rule.embed}"')
	}
	if src[0].contexts.any(it.rules.any(it.embed.len > 0)) {
		return error('embeds "${rule.embed}", which embeds grammars itself')
	}
	escape := parse_pattern(rule.escape)!
	if first_of(escape).nullable {
		return error('escape "${rule.escape}" can match nothing')
	}
	root := g.contexts.len
	for si, c in src[0].contexts {
		g.contexts << Context{
			name:        if si == 0 { src[0].id } else { c.name }
			scope:       c.scope
			pops_at_eol: c.pops_at_eol
			copy:        Copy{
				embed:       g.embeds.len
				source:      si
				source_name: c.name
			}
		}
	}
	g.embeds << Embed{
		lang:   rule.embed
		escape: rule.escape
		scope:  rule.scope
		root:   root
	}
	return root
}

fn (g Grammar) context_index(name string) ?int {
	for i, ctx in g.contexts {
		if ctx.name == name {
			return i
		}
	}
	return none
}

fn is_ident(s string) bool {
	if s.len == 0 || !(s[0] >= `a` && s[0] <= `z`) {
		return false
	}
	for c in s {
		if !((c >= `a` && c <= `z`) || (c >= `0` && c <= `9`) || c == `_`) {
			return false
		}
	}
	return true
}

fn check_scope(scope string) !string {
	for c in scope {
		if !((c >= `a` && c <= `z`) || c == `.`) {
			return error('bad scope "${scope}": use lower case words joined by dots')
		}
	}
	return scope
}

fn string_arg(node &kdlv.Node, i int) !string {
	if i >= node.arguments.len || node.arguments[i].kind != .string {
		return error('"${node.name}" needs a string argument')
	}
	return node.arguments[i].str_val
}

fn string_args(node &kdlv.Node) ![]string {
	mut out := []string{}
	for i in 0 .. node.arguments.len {
		out << string_arg(node, i)!
	}
	return out
}

// check_props makes sure a node has no properties but `allowed`, so a
// misspelt one is an error rather than ignored
fn check_props(node &kdlv.Node, allowed []string) ! {
	for p in node.properties {
		if p.name !in allowed {
			return error('unknown property "${p.name}"')
		}
	}
}

// string_prop gives a string property, or '' when it's absent. One that isn't
// a string, or is empty, is an error rather than taken as absent, so
// `set=42` or `set=""` can't quietly mean no set at all.
fn string_prop(node &kdlv.Node, name string) !string {
	value := node.get_property(name) or { return '' }
	if value.kind != .string {
		return error('${name} needs a string, like ${name}="..."')
	}
	if value.str_val.len == 0 {
		return error("${name} can't be empty")
	}
	return value.str_val
}

// bool_prop gives a boolean property, or false when it's absent. One that
// isn't a boolean is an error, so `pop="true"` can't quietly mean no pop.
fn bool_prop(node &kdlv.Node, name string) !bool {
	value := node.get_property(name) or { return false }
	if value.kind != .boolean {
		return error('${name} needs #true or #false')
	}
	return value.bool_val
}
