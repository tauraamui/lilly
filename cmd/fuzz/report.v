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

import encoding.hex
import os

// A saved failure is a directory of plain files, so it can be read as well as
// replayed:
//
//   info.txt    what happened, where, and how to replay it
//   setup.txt   how lilly was started
//   steps.txt   every step, one per line: keys <delay> <hex>,
//               resize <delay> <cols> <rows>, or probe <delay>
//   files/      the files lilly was given, before it edited any of them
//   screen.bin  the last of what lilly drew; `cat` it in a terminal
//   lilly.log   lilly's own log, with any panic and its backtrace
//   stacks.txt  for a hang, where each of lilly's threads was: sample's
//               report on macOS, gdb's and the kernel's on Linux

fn save_failure(c Config, seed u64, setup Setup, steps []Step, result Result) !string {
	dir := os.join_path(c.out, 'failures', '${result.verdict}-${seed}')
	os.rmdir_all(dir) or {}
	files_dir := os.join_path(dir, 'files')
	os.mkdir_all(files_dir)!
	for f in setup.files {
		os.write_file_array(os.join_path(files_dir, f.name), f.data)!
	}
	os.write_file(os.join_path(dir, 'setup.txt'), 'launch ${setup.launch}\ntarget ${setup.target}\n')!
	os.write_file(os.join_path(dir, 'steps.txt'), steps.map(encode_step(it)).join('\n') + '\n')!
	os.write_file_array(os.join_path(dir, 'screen.bin'), result.tail)!
	os.write_file(os.join_path(dir, 'lilly.log'), result.log)!
	if result.stacks != '' {
		os.write_file(os.join_path(dir, 'stacks.txt'), result.stacks)!
	}
	os.write_file(os.join_path(dir, 'info.txt'), 'verdict: ${result.verdict}
detail:  ${result.detail}
program: ${c.program.join(' ')}
os:      ${os.user_os()} (${os.uname().machine})
seed:    ${seed} (session ${c.seed})
replay:  fuzz --replay ${dir} -- ${c.program.join(' ')}
')!
	return dir
}

fn encode_step(s Step) string {
	return match s.kind {
		.keys { 'keys ${s.delay_ms} ${hex.encode(s.bytes)}' }
		.resize { 'resize ${s.delay_ms} ${s.cols} ${s.rows}' }
		.probe { 'probe ${s.delay_ms}' }
	}
}

fn decode_step(line string) !Step {
	f := line.fields()
	if f.len < 2 {
		return error('bad step: ${line}')
	}
	delay := f[1].int()
	return match f[0] {
		'keys' {
			Step{
				kind:     .keys
				delay_ms: delay
				bytes:    hex.decode(if f.len > 2 { f[2] } else { '' })!
			}
		}
		'resize' {
			if f.len < 4 {
				return error('bad step: ${line}')
			}
			Step{
				kind:     .resize
				delay_ms: delay
				cols:     u16(f[2].int())
				rows:     u16(f[3].int())
			}
		}
		'probe' {
			Step{
				kind:     .probe
				delay_ms: delay
			}
		}
		else {
			error('bad step: ${line}')
		}
	}
}

fn load_failure(dir string) !(Setup, []Step) {
	mut launch := Launch.file
	mut target := ''
	for line in os.read_lines(os.join_path(dir, 'setup.txt'))! {
		key, value := line.split_once(' ') or { continue }
		if key == 'launch' {
			launch = Launch.from(value)!
		}
		if key == 'target' {
			target = value
		}
	}
	files_dir := os.join_path(dir, 'files')
	mut files := []CorpusFile{}
	for name in os.ls(files_dir)! {
		files << CorpusFile{
			name: name
			data: os.read_bytes(os.join_path(files_dir, name))!
		}
	}
	mut steps := []Step{}
	for line in os.read_lines(os.join_path(dir, 'steps.txt'))! {
		if line.trim_space() == '' {
			continue
		}
		steps << decode_step(line)!
	}
	return Setup{
		launch: launch
		target: target
		files:  files
	}, steps
}

fn replay(c Config) int {
	setup, steps := load_failure(c.replay) or {
		eprintln('fuzz: cannot load ${c.replay}: ${err}')
		return 2
	}
	println('fuzz: replaying ${steps.len} steps from ${c.replay}')
	result := execute(c, setup, steps)
	println('fuzz: ${result.verdict} ${result.detail}')
	if result.log.contains('V panic') {
		println(result.log)
	}
	return if result.verdict.is_failure() { 1 } else { 0 }
}
