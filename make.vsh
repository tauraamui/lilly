#!/usr/bin/env -S v run

import build
import strconv
import math

const app_name = 'lilly'

struct Scenario {
	name    string
	command string
	keys    string
}

const scenarios = [
	Scenario{
		name:    'single-line-file'
		command: './lilly ./testdata/fakefiles'
		keys:    '<wait:2000><snapshot>;ff<wait:1000>0001<enter><wait:1000><snapshot>:q<enter><wait:500>'
	},
	Scenario{
		name:    'multi-line-file'
		command: './lilly ./testdata/fakefiles'
		keys:    '<wait:2000><snapshot>;ff<wait:1000>0002<enter><wait:1000><snapshot>:q<enter><wait:500>'
	},
	Scenario{
		name:    'scrolling-in-multi-line-code-file'
		command: './lilly ./testdata/fakefiles'
		keys:    '<wait:2000><snapshot>;ff<wait:1000>0003<enter><wait:1000><snapshot>}}}}<snapshot>}}}<snapshot>}}}}<snapshot>:q<enter><wait:500>'
	},
]

mut context := build.context(
	default: 'run'
)

// BUILD TASKS
context.task(
	name:    'build'
	depends: ['_generate-git-hash']
	run:     |self| system('v . -o ${app_name}')
)
context.task(
	name:    'prod'
	depends: ['_generate-git-hash']
	run:     |self| system('v -prod -g . -o ${app_name}')
)
context.task(name: 'run', depends: ['_generate-git-hash'], run: |self| system('v -g run .'))
context.task(
	name:    'run-d'
	depends: ['_generate-git-hash']
	run:     |self| system('export LILLY_THEME=dark && v -g run .')
)
context.task(
	name:    'run-l'
	depends: ['_generate-git-hash']
	run:     |self| system('export LILLY_THEME=light && v -g run .')
)
context.task(name: 'compile-make', run: |self| system('v -prod -skip-running make.vsh -o make'))

// TEST TASKS
context.task(
	name:    'test'
	depends: ['_generate-git-hash']
	run:     |self| exit(system('v -g test .'))
)

context.task(
	name:    'verbose-test'
	depends: ['_generate-git-hash']
	run:     |self| exit(system('v -g -stats test .'))
)

// UTIL TASKS
context.task(name: 'format', run: |self| system('v fmt -w *.v lib/'))
context.task(name: 'verify-format', run: |self| exit(system('v fmt -inprocess -verify *.v lib/')))
context.task(name: 'git', depends: ['format'], run: |self| system('lazygit'))

context.task(
	name: 'ansi-colour-codes'
	help: 'displays ansi colour code chart'
	run:  fn (self build.Task) ! {
		print('\n   +  ')
		for i := 0; i < 36; i++ {
			print('${i:2} ')
		}

		print('\n\n ${0:3}  ')
		for i := 0; i < 16; i++ {
			print('\033[48;5;${i}m  \033[m ')
		}

		for i := 0; i < 7; i++ {
			real_i := (i * 36) + 16
			print('\n\n ${real_i:3}  ')
			for j := 0; j < 36; j++ {
				print('\033[48;5;${real_i + j}m  \033[m ')
			}
		}
		println('')
	}
)

context.task(
	name: 'ansi-color-codes'
	run:  fn [mut context] (self build.Task) ! {
		context.exec('ansi-colour-codes')
	}
)

context.task(
	name: 'ansi-to-rgb'
	help: 'prompts for single ansi colour code and outputs the RGB components'
	run:  fn (self build.Task) ! {
		ansi_num_to_convert := input('ANSI colour to convert to RGB: ')
		c := strconv.atoi(ansi_num_to_convert) or { panic('invalid num: ${err}') }

		if !(c >= 16 && c <= 231) {
			println('${c} -> is outside the 6x6x6 colour cube (16-231).')
			return
		}

		c_prime := c - 16
		r := c_prime / 36
		g := (c_prime % 36) / 6
		b := c_prime % 6

		levels := [int(0), 95, 135, 175, 215, 255]
		rr := levels[r]
		gg := levels[g]
		bb := levels[b]

		println('${c} -> RGB(${rr}, ${gg}, ${bb})')
	}
)

context.task(
	name: 'rgb-to-ansi'
	help: 'prompts three times for rgb values and produces single ansi colour code'
	run:  fn (self build.Task) ! {
		find_nearest_level := fn (levels []int, value int) int {
			mut nearest_index := 0
			mut min_diff := math.max_f64
			for i, level in levels {
				diff := math.abs(f64(value - level))
				if diff < min_diff {
					min_diff = diff
					nearest_index = i
				}
			}
			return nearest_index
		}

		levels := [int(0), 95, 135, 175, 215, 255]

		rr_num_to_convert := input('R: ')
		rr := strconv.atoi(rr_num_to_convert) or { panic('invalid num for R: ${err}') }
		gg_num_to_convert := input('G: ')
		gg := strconv.atoi(gg_num_to_convert) or { panic('invalid num for G: ${err}') }
		bb_num_to_convert := input('B: ')
		bb := strconv.atoi(bb_num_to_convert) or { panic('invalid num for B: ${err}') }

		r := find_nearest_level(levels, rr)
		g := find_nearest_level(levels, gg)
		b := find_nearest_level(levels, bb)
		println('RGB(${rr}, ${gg}, ${bb}) -> ${16 + (36 * r) + (6 * g) + b}')
	}
)

// XPTY FRAME REGRESSION TASKS
context.task(
	name:    'xpty-build'
	help:    'build lilly with golden frame support enabled'
	depends: ['_generate-git-hash']
	run:     |self| system('v -d golden_frames -g . -o lilly')
)
context.task(
	name:    'xpty-capture'
	help:    'capture golden frames for all scenarios (review output before committing)'
	depends: ['xpty-build']
	run:     fn (self build.Task) ! {
		for s in scenarios {
			eprintln('Capturing: ${s.name}')
			system("v -g run cmd/xpty/ '${s.command}' '${s.keys}' --output-dir ./xpty_frames/${s.name}")
			eprintln('')
			eprintln('Frames saved to xpty_frames/. Review, then copy:')
			eprintln('  cp xpty_frames/${s.name}/frame_*.txt testdata/xpty/${s.name}/')
		}
	}
)
context.task(
	name:    'xpty-verify'
	help:    'verify current rendering matches golden frames for all scenarios'
	depends: ['xpty-build']
	run:     fn (self build.Task) ! {
		mut failed := false
		for s in scenarios {
			eprintln('Verifying: ${s.name}')
			rc := system("v -g run cmd/xpty/ --compare testdata/xpty/${s.name} '${s.command}' '${s.keys}'")
			if rc != 0 {
				failed = true
			}
		}
		if failed {
			exit(1)
		}
	}
)

context.task(name: 'git-prune', run: |self| system('git remote prune origin'))

context.task(
	name: 'apply-license-header'
	help: 'executes addlicense tool to insert license headers into files without one'
	run:  |self| system('addlicense -v -c "The Lilly Edtior contributors" -y "2026" ./*')
)

context.task(
	name: 'install-license-tool'
	help: 'REQUIRES GO: installs a tool used to insert the license header into source files'
	run:  |self| system('go install github.com/google/addlicense@latest')
)

// ARTIFACTS
context.artifact(
	name: '_generate-git-hash'
	help: 'generate .githash to contain latest commit of current branch to embed in builds'
	run:  |self| system('git log -n 1 --pretty=format:"%h" | tee ./.githash')
)

context.run()
