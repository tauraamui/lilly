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

struct Config {
	program     []string // program path and args
	input_spec  string
	output_dir  string
	compare_dir string // if non-empty, compare captured frames against this golden dir
}

fn parse_args(args []string) !Config {
	mut program := []string{}
	mut input_spec := ''
	mut output_dir := 'xpty_frames'
	mut compare_dir := ''

	mut i := 0
	for i < args.len {
		if args[i] == '--compare' {
			i++
			if i >= args.len {
				return error('--compare requires a directory argument')
			}
			compare_dir = args[i]
		} else if args[i] == '--output-dir' {
			i++
			if i >= args.len {
				return error('--output-dir requires a directory argument')
			}
			output_dir = args[i]
		} else if program.len == 0 {
			program = args[i].split(' ').filter(it.len > 0)
		} else if input_spec.len == 0 {
			input_spec = args[i]
		} else {
			return error('unexpected argument: ${args[i]}')
		}
		i++
	}

	if program.len == 0 || input_spec.len == 0 {
		return error('missing required arguments')
	}

	return Config{
		program:     program
		input_spec:  input_spec
		output_dir:  output_dir
		compare_dir: compare_dir
	}
}

fn print_usage() {
	eprintln('usage: xpty [options] <program> <input-sequence>')
	eprintln('')
	eprintln('  Runs <program> inside a pseudo-terminal, sends <input-sequence>')
	eprintln('  keystroke by keystroke, and captures each rendered frame to disk.')
	eprintln('')
	eprintln('  Options:')
	eprintln('    --output-dir <dir>   Directory to save captured frames (default: xpty_frames)')
	eprintln('    --compare <dir>      Compare captured frames against golden frames in <dir>')
	eprintln('')
	eprintln('  Special tokens in <input-sequence>:')
	eprintln('    <enter>  -> carriage return')
	eprintln('    <esc>    -> escape (0x1b)')
	eprintln('    <tab>    -> tab')
	eprintln('    <space>  -> space')
	eprintln('    <bs>     -> backspace')
	eprintln('    <up> <down> <left> <right> -> arrow keys')
	eprintln('    <wait:NNN> -> pause NNN milliseconds before next key')
	eprintln('    <snapshot> -> capture a golden frame at this point')
	eprintln('')
	eprintln('  Examples:')
	eprintln("    xpty ./lilly '<wait:2000>;ffedi<enter><wait:1000>}}}}}' ")
	eprintln("    xpty --compare testdata/xpty/scroll-scenario ./lilly '<wait:2000>;ffedi<enter><wait:1000>}}}}}' ")
}

fn main() {
	config := parse_args(os.args[1..]) or {
		eprintln('xpty: ${err}')
		eprintln('')
		print_usage()
		exit(1)
	}

	cols := u16(120)
	rows := u16(40)

	os.mkdir_all(config.output_dir) or {
		eprintln('failed to create output directory: ${err}')
		exit(1)
	}

	eprintln('xpty: starting "${config.program.join(' ')}" in ${cols}x${rows} pty')
	eprintln('xpty: input sequence: ${config.input_spec}')
	eprintln('xpty: frames will be saved to ${config.output_dir}/')
	if config.compare_dir.len > 0 {
		eprintln('xpty: will compare against golden frames in ${config.compare_dir}/')
	}

	// Tell lilly to dump golden frames into the output directory.
	// This requires lilly to be built with -d golden_frames.
	golden_capture_dir := os.real_path(config.output_dir)
	master_fd, child_pid := spawn_in_pty(config.program, cols, rows, golden_capture_dir) or {
		eprintln('xpty: failed to spawn: ${err}')
		exit(1)
	}

	// Allow the program to initialize and render its first frame.
	eprintln('xpty: waiting for program to initialize...')
	time.sleep(1500 * time.millisecond)

	// Drain any initial output (startup rendering).
	drain_pty(master_fd, 200)

	// Parse and send input tokens one at a time.
	tokens := parse_input(config.input_spec)
	eprintln('xpty: parsed ${tokens.len} input tokens')

	mut frame_num := 0
	for i, token in tokens {
		match token {
			InputToken {
				bytes := token.bytes
				eprintln('xpty: [${i + 1}/${tokens.len}] sending: ${token.label}')
				write_to_fd(master_fd, bytes)

				// Give the program time to process the input and render.
				time.sleep(150 * time.millisecond)
				drain_pty(master_fd, 100)
			}
			WaitToken {
				eprintln('xpty: [${i + 1}/${tokens.len}] waiting ${token.ms}ms')
				time.sleep(token.ms * time.millisecond)
				drain_pty(master_fd, 100)
			}
			SnapshotToken {
				eprintln('xpty: [${i + 1}/${tokens.len}] snapshot ${frame_num}')
				// Send SIGUSR1 to tell lilly to capture a golden frame on next view().
				C.kill(child_pid, C.SIGUSR1)
				// Wait for lilly to process the signal and write the frame.
				time.sleep(500 * time.millisecond)
				drain_pty(master_fd, 100)
				frame_num++
			}
		}
	}

	// Final drain.
	time.sleep(500 * time.millisecond)
	drain_pty(master_fd, 200)

	eprintln('xpty: done — ${frame_num} snapshots captured in ${config.output_dir}/')

	// Send quit signal to the child.
	C.kill(child_pid, C.SIGTERM)
	time.sleep(200 * time.millisecond)
	C.kill(child_pid, C.SIGKILL)

	C.close(master_fd)

	// If comparison was requested, run it now.
	if config.compare_dir.len > 0 {
		exit(compare_frames(config.output_dir, config.compare_dir))
	}
}

// normalise_git_hash replaces the 7-char git commit hash in version strings
// like "alpha-v0.0.0 (#abcdef1)" with a fixed placeholder, so that frames
// captured on one commit can be verified against a different commit.
fn normalise_git_hash(text string) string {
	mut result := text
	mut i := 0
	for {
		idx := result.index_after('(#', i) or { break }
		hash_start := idx + 2
		hash_end := hash_start + 7
		if hash_end < result.len && result[hash_end] == `)` {
			result = result[..hash_start] + 'GITHASH' + result[hash_end..]
		}
		i = idx + 2
	}
	return result
}

// compare_frames compares captured .txt golden frames (produced by lilly with
// -d golden_frames and LILLY_GOLDEN_DIR) against committed golden .txt frames.
// Returns 0 if all frames match, 1 if there are differences.
fn compare_frames(captured_dir string, golden_dir string) int {
	eprintln('')
	eprintln('xpty: comparing captured frames against golden frames in ${golden_dir}/')

	golden_files := os.glob(os.join_path(golden_dir, 'frame_*.txt')) or {
		eprintln('xpty: ERROR: failed to list golden frames: ${err}')
		return 1
	}

	if golden_files.len == 0 {
		eprintln('xpty: ERROR: no golden frames found in ${golden_dir}/')
		eprintln('xpty: hint: run xpty-capture first, review the .txt frames, then copy them to ${golden_dir}/')
		return 1
	}

	captured_files := os.glob(os.join_path(captured_dir, 'frame_*.txt')) or {
		eprintln('xpty: ERROR: failed to list captured frames: ${err}')
		eprintln('xpty: hint: ensure lilly was built with -d golden_frames')
		return 1
	}

	if captured_files.len == 0 {
		eprintln('xpty: ERROR: no captured .txt frames found in ${captured_dir}/')
		eprintln('xpty: hint: ensure lilly was built with -d golden_frames')
		return 1
	}

	if captured_files.len != golden_files.len {
		eprintln('xpty: FAIL: frame count mismatch — captured ${captured_files.len}, golden ${golden_files.len}')
	}

	// Compare all golden frames that exist.
	mut failures := 0
	mut compared := 0
	for golden_path in golden_files {
		name := os.file_name(golden_path)
		captured_path := os.join_path(captured_dir, name)

		if !os.exists(captured_path) {
			eprintln('xpty: FAIL: ${name} — no matching captured frame')
			failures++
			continue
		}

		captured_text := os.read_file(captured_path) or {
			eprintln('xpty: FAIL: ${name} — could not read captured frame: ${err}')
			failures++
			continue
		}

		golden_text := os.read_file(golden_path) or {
			eprintln('xpty: FAIL: ${name} — could not read golden frame: ${err}')
			failures++
			continue
		}

		if normalise_git_hash(captured_text) == normalise_git_hash(golden_text) {
			eprintln('xpty: OK: ${name}')
		} else {
			eprintln('xpty: FAIL: ${name} — content differs')
			// Show the first differing line for debugging.
			captured_lines := captured_text.split('\n')
			golden_lines := golden_text.split('\n')
			min_lines := if captured_lines.len < golden_lines.len {
				captured_lines.len
			} else {
				golden_lines.len
			}
			for j := 0; j < min_lines; j++ {
				if captured_lines[j] != golden_lines[j] {
					eprintln('xpty:        first difference at line ${j + 1}:')
					eprintln('xpty:          golden:   "${golden_lines[j]}"')
					eprintln('xpty:          captured: "${captured_lines[j]}"')
					break
				}
			}
			if captured_lines.len != golden_lines.len {
				eprintln('xpty:        line count: captured ${captured_lines.len}, golden ${golden_lines.len}')
			}
			failures++
		}
		compared++
	}

	eprintln('')
	if failures > 0 {
		eprintln('xpty: FAILED — ${failures}/${compared} frames differ')
		return 1
	}
	eprintln('xpty: PASSED — all ${compared} frames match')
	return 0
}
