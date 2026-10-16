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

// fuzz drives a lilly binary, as shipped, with random keystrokes on random
// and mutated files, and reports every run that crashes or hangs it. It needs
// nothing built into lilly, so it tests the exact release artifact on each
// platform: through openpty on Linux and macOS, and ConPTY on Windows.
//
// Each failure is saved with the steps that caused it, the files it was
// given and lilly's log, and replays with --replay.
module main

import os
import rand
import time

const usage = 'usage: fuzz [options] -- <program> [args...]

  Fuzzes <program> (a lilly binary, or e.g. `qemu-aarch64 ./lilly`) in a
  pseudo terminal, and exits 1 if any run crashed or hung it.

  Options:
    --duration <d>       how long to keep starting runs, e.g. 90s, 10m, 1h (default 5m)
    --runs <n>           stop after n runs instead
    --steps <n>          steps per run, on average (default 600)
    --seed <n>           seed for the whole session, to repeat one (default: from the clock)
    --corpus <dir>       files to open and mutate, repeatable (default testdata/syntax, testdata/fakefiles)
    --out <dir>          where failures and the summary go (default fuzz_out)
    --timeout-scale <f>  multiply every timeout, for slow targets such as qemu-user (default 1)
    --replay <dir>       rerun one saved failure instead of fuzzing'

struct Config {
mut:
	program       []string
	duration      time.Duration = 5 * time.minute
	runs          int
	steps         int = 600
	seed          u64
	corpus        []string
	out           string = 'fuzz_out'
	timeout_scale f64    = 1.0
	replay        string
}

fn parse_args(args []string) !Config {
	mut c := Config{
		seed: u64(time.now().unix_nano())
	}
	mut i := 0
	for i < args.len {
		arg := args[i]
		if arg == '--' {
			c.program = args[i + 1..].clone()
			break
		}
		if i + 1 >= args.len {
			return error('${arg} needs a value')
		}
		value := args[i + 1]
		match arg {
			'--duration' { c.duration = parse_duration(value)! }
			'--runs' { c.runs = value.int() }
			'--steps' { c.steps = value.int() }
			'--seed' { c.seed = value.u64() }
			'--corpus' { c.corpus << value }
			'--out' { c.out = value }
			'--timeout-scale' { c.timeout_scale = value.f64() }
			'--replay' { c.replay = value }
			else { return error('unknown option ${arg}') }
		}
		i += 2
	}
	if c.program.len == 0 {
		return error('no program given after --')
	}
	if c.corpus.len == 0 {
		c.corpus = ['testdata/syntax', 'testdata/fakefiles']
	}
	// the child starts in each run's own directory, so paths given relative
	// to here must be made absolute first
	c.program = c.program.map(if os.exists(it) { os.real_path(it) } else { it })
	c.out = os.abs_path(c.out)
	c.corpus = c.corpus.map(os.abs_path(it))
	return c
}

fn parse_duration(s string) !time.Duration {
	if s.len < 2 {
		return error('bad duration ${s}')
	}
	n := s[..s.len - 1].i64()
	return match s[s.len - 1] {
		`s` { n * time.second }
		`m` { n * time.minute }
		`h` { n * time.hour }
		else { error('bad duration ${s}, give e.g. 90s, 10m or 1h') }
	}
}

// splitmix64, so neighbouring run indexes still get unrelated seeds
fn run_seed(session u64, index int) u64 {
	mut z := session + u64(index + 1) * 0x9e3779b97f4a7c15
	z = (z ^ (z >> 30)) * 0xbf58476d1ce4e5b9
	z = (z ^ (z >> 27)) * 0x94d049bb133111eb
	return z ^ (z >> 31)
}

fn main() {
	c := parse_args(os.args[1..]) or {
		eprintln('fuzz: ${err}\n')
		eprintln(usage)
		exit(2)
	}
	if c.replay != '' {
		exit(replay(c))
	}
	exit(fuzz(c))
}

fn fuzz(c Config) int {
	corpus := load_corpus(c.corpus)
	println('fuzz: ${c.program.join(' ')}')
	println('fuzz: session seed ${c.seed}, ${corpus.len} corpus files, ${os.user_os()}')
	deadline := time.now().add(c.duration)
	mut tally := map[string]int{}
	mut failures := []string{}
	mut index := 0
	for {
		if c.runs > 0 && index >= c.runs {
			break
		}
		if c.runs == 0 && time.now() > deadline {
			break
		}
		seed := run_seed(c.seed, index)
		mut g := Gen{
			rng: rand.new_default(seed_: [u32(seed), u32(seed >> 32)])
		}
		setup := g.setup(corpus)
		steps := g.steps(c.steps / 2 + g.n(c.steps))
		result := execute(c, setup, steps)
		tally[result.verdict.str()]++
		println('fuzz: run ${index} seed ${seed}: ${result.verdict} ${result.detail}')
		if result.verdict.is_failure() || result.verdict == .stuck {
			dir := save_failure(c, seed, setup, steps, result) or {
				eprintln('fuzz: could not save failure: ${err}')
				''
			}
			if result.verdict.is_failure() {
				failures << '${result.verdict} ${result.detail} -> ${dir}'
			}
		}
		index++
	}
	summary := 'fuzz: ${index} runs, ${tally}, session seed ${c.seed}\n' +
		failures.map('  ${it}\n').join('')
	println(summary)
	os.mkdir_all(c.out) or {}
	os.write_file(os.join_path(c.out, 'summary.txt'), summary) or {}
	return if failures.len > 0 { 1 } else { 0 }
}
