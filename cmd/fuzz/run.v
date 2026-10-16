// Copyright 2026 The Lilly Editor contributors
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
import time
import lib.pty

const start_cols = u16(120)
const start_rows = u16(40)

// how much of the end of lilly's output a failure keeps
const tail_size = 65536

// first frame after starting; the release builds draw it well within a second
const startup_timeout = 15 * time.second

// for a frame after a resize. Generous: a run is never failed for being slow,
// only for having stopped
const probe_timeout = 10 * time.second

const quit_timeout = 5 * time.second

enum Verdict {
	ok
	stuck   // alive and redrawing, but would not quit on :qa; a hang on Windows, see Runner.quit
	startup // never drew a first frame
	crash   // died from a signal or exception, exited non-zero, or logged a panic
	hang    // stopped redrawing, or stopped reading its input
}

fn (v Verdict) is_failure() bool {
	return v in [.startup, .crash, .hang]
}

enum Launch {
	file      // lilly <file>
	directory // lilly .
	nothing   // lilly
}

struct Setup {
	launch Launch
	target string
	files  []CorpusFile
}

struct Result {
	verdict Verdict
	detail  string
	tail    []u8
	log     string
	stacks  string
}

fn (mut g Gen) setup(corpus []CorpusFile) Setup {
	mut files := []CorpusFile{}
	mut names := map[string]bool{}
	for _ in 0 .. 1 + g.n(5) {
		f := g.file(corpus)
		// a name that is unsafe or already taken is renumbered, never dropped
		mut name := os.file_name(f.name).replace_each(['\\', '_', ':', '_'])
		if name == '' || name in names {
			name = '${files.len}_${name}'
		}
		names[name] = true
		files << CorpusFile{
			name: name
			data: f.data
		}
	}
	roll := g.n(10)
	launch := match roll {
		0 { Launch.directory }
		1 { Launch.nothing }
		else { Launch.file }
	}
	return Setup{
		launch: launch
		target: files[0].name
		files:  files
	}
}

struct Runner {
	scale f64
mut:
	p    &pty.Process
	tail []u8
}

fn (r Runner) timeout(base time.Duration) time.Duration {
	return time.Duration(i64(f64(base) * r.scale))
}

fn (mut r Runner) collect() int {
	data := r.p.read()
	if data.len == 0 {
		return 0
	}
	// answer cursor position queries as a terminal would. Unanswered, lilly
	// takes the next keys typed for the answer, which is a startup bug of its
	// own rather than anything the keys exercise
	for _ in 0 .. data.bytestr().count('\x1b[6n') {
		r.p.write('\x1b[1;1R'.bytes()) or {}
	}
	r.tail << data
	if r.tail.len > tail_size {
		r.tail = r.tail[r.tail.len - tail_size..].clone()
	}
	return data.len
}

// wait_output waits for anything at all to be drawn, and fails once the
// timeout passes or lilly exits without drawing
fn (mut r Runner) wait_output(timeout time.Duration) bool {
	deadline := time.now().add(r.timeout(timeout))
	for time.now() < deadline {
		if r.collect() > 0 {
			return true
		}
		if _ := r.p.exited() {
			return false
		}
		time.sleep(10 * time.millisecond)
	}
	return false
}

// settle reads until lilly has drawn nothing for a moment, so output already
// on its way cannot pass for the answer to a probe
fn (mut r Runner) settle() {
	deadline := time.now().add(r.timeout(2 * time.second))
	mut quiet_since := time.now()
	for time.now() < deadline && time.since(quiet_since) < 150 * time.millisecond {
		if r.collect() > 0 {
			quiet_since = time.now()
		}
		time.sleep(10 * time.millisecond)
	}
}

// probe checks lilly's event loop is still turning, whatever state the keys
// left it in: a resize redraws every screen, dialog and mode alike, so a
// resize that draws nothing means lilly is wedged. Resized and back, so the
// steps that follow see the size they were generated for.
fn (mut r Runner) probe(cols u16, rows u16) bool {
	r.settle()
	r.p.resize(if cols > 2 { cols - 1 } else { cols + 1 }, rows)
	if !r.wait_output(probe_timeout) {
		return false
	}
	r.settle()
	r.p.resize(cols, rows)
	return r.wait_output(probe_timeout)
}

// ended judges an exit: a clean one, from :q on the last editor say, is fine
fn (r Runner) ended(s pty.ExitStatus, when string) Result {
	if !s.crashed() && s.code == 0 {
		return Result{
			verdict: .ok
			detail:  'quit ${when}'
		}
	}
	return Result{
		verdict: .crash
		detail:  '${s} ${when}'
	}
}

fn (mut r Runner) gone_or(verdict Verdict, detail string) Result {
	if s := r.p.exited() {
		return r.ended(s, detail)
	}
	return Result{
		verdict: verdict
		detail:  detail
	}
}

// quit leaves whatever mode lilly is in and asks it to quit, a few times
fn (mut r Runner) quit() Result {
	for _ in 0 .. 3 {
		// a key at a time: bytes that arrive together reach lilly as one
		// multi-rune key, which no binding matches
		for key in ['\x1b', '\x1b', ':', 'q', 'a', '\r'] {
			r.p.write(key.bytes()) or { return r.gone_or(.hang, 'stopped reading input at quit') }
			time.sleep(100 * time.millisecond)
		}
		deadline := time.now().add(r.timeout(quit_timeout))
		for time.now() < deadline {
			r.collect()
			if s := r.p.exited() {
				return r.ended(s, 'on :qa')
			}
			time.sleep(20 * time.millisecond)
		}
	}
	if !r.probe(start_cols, start_rows) {
		return r.gone_or(.hang, 'stopped redrawing at quit')
	}
	// ConPTY repaints by itself on a resize, so on Windows a probe passes even
	// for a wedged lilly, and refusing :qa is the only sign of a hang there
	$if windows {
		return Result{
			verdict: .hang
			detail:  'still running after :qa'
		}
	}
	return Result{
		verdict: .stuck
		detail:  'still running after :qa'
	}
}

fn (mut r Runner) drive(steps []Step) Result {
	if !r.wait_output(startup_timeout) {
		return r.gone_or(.startup, 'no first frame within ${r.timeout(startup_timeout).str()}')
	}
	// let startup finish its terminal queries before the first key
	r.settle()
	mut cols, mut rows := start_cols, start_rows
	for i, step in steps {
		if step.delay_ms > 0 {
			time.sleep(step.delay_ms * time.millisecond)
		}
		r.collect()
		if s := r.p.exited() {
			return r.ended(s, 'at step ${i}')
		}
		match step.kind {
			.keys {
				r.p.write(step.bytes) or {
					return r.gone_or(.hang, 'stopped reading input at step ${i}')
				}
			}
			.resize {
				cols, rows = step.cols, step.rows
				r.p.resize(cols, rows)
			}
			.probe {
				if !r.probe(cols, rows) {
					return r.gone_or(.hang, 'stopped redrawing at step ${i}')
				}
			}
		}
	}
	if !r.probe(cols, rows) {
		return r.gone_or(.hang, 'stopped redrawing after the last step')
	}
	return r.quit()
}

// execute runs lilly once, in a fresh home with nothing but the setup's files
fn execute(c Config, setup Setup, steps []Step) Result {
	work := os.join_path(c.out, 'work')
	os.rmdir_all(work) or {}
	files_dir := os.join_path(work, 'files')
	state_dir := os.join_path(work, 'state')
	os.mkdir_all(files_dir) or {
		return Result{
			verdict: .startup
			detail:  'cannot create ${files_dir}: ${err}'
		}
	}
	for f in setup.files {
		os.write_file_array(os.join_path(files_dir, f.name), f.data) or {}
	}
	// lilly's panics go to its log under the state directory
	home := os.join_path(work, 'home')
	os.mkdir_all(home) or {}
	os.setenv('HOME', home, true)
	os.setenv('USERPROFILE', home, true)
	os.setenv('XDG_CONFIG_HOME', os.join_path(home, '.config'), true)
	os.setenv('XDG_STATE_HOME', state_dir, true)
	os.setenv('TERM', 'xterm-256color', true)
	// so lilly skips its truecolor query, which nothing here answers
	os.setenv('COLORTERM', 'truecolor', true)
	os.unsetenv('LILLY_THEME')

	mut argv := c.program.clone()
	match setup.launch {
		.file { argv << setup.target }
		.directory { argv << '.' }
		.nothing {}
	}
	back := os.getwd()
	os.chdir(files_dir) or {}
	defer {
		os.chdir(back) or {}
	}
	mut p := pty.spawn(argv, start_cols, start_rows) or {
		return Result{
			verdict: .startup
			detail:  err.msg()
		}
	}
	mut r := Runner{
		scale: c.timeout_scale
		p:     p
	}
	mut result := r.drive(steps)
	// where a lilly that stopped is stuck, read while it is still there to read
	stacks := if result.verdict in [.hang, .stuck] && p.exited() == none {
		p.stacks()
	} else {
		''
	}
	p.kill()

	log := os.read_file(os.join_path(state_dir, 'lilly', 'lilly.log')) or { '' }
	if result.verdict == .ok && log.contains('V panic') {
		result = Result{
			verdict: .crash
			detail:  'panic in lilly.log'
		}
	}
	return Result{
		...result
		tail:   r.tail
		log:    log
		stacks: stacks
	}
}
