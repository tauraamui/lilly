#!/usr/bin/env -S v run

import build
import strconv
import math

const app_name = "lilly"

mut context := build.context(
	default: "run"
)

// BUILD TASKS
context.task(name: "build", depends: ["_generate-git-hash"], run: |self| system("v ./src -o lilly"))
context.task(name: "build-prod", depends: ["_generate-git-hash"], run: |self| system("v ./src -o ${app_name}"))
context.task(name: "run", depends: ["_generate-git-hash"], run: |self| system("v -g run ./src ."))
context.task(name: "run-with-gap", depends: ["_generate-git-hash"], run: |self| system("v -g run ./src -ugb ."))
context.task(name: "run-debug-log", depends: ["_generate-git-hash"], run: |self| system("v -g run ./src --log-level debug ."))
context.task(name: "run-gui", depends: ["_generate-git-hash"], run: |self| system("v -g -d gui run ./src ."))
context.task(name: "compile-make", run: |self| system("v -prod -skip-running make.vsh"))

// TEST TASKS
context.task(name: "test", run: |self| system("v -g test ./src"))
context.task(name: "verbose-test", run: |self| system("v -g -stats test ./src"))

// EXPERIMENTS
context.task(
	name: "linux-clipboard",
	help: "runs experiment to test linux C code clipboard integration"
	run: fn (self build.Task) ! {
		system("v -g run ./experiment/clipboard/x11.c.v")
	}
)

context.task(
	name: "emoji-grid",
	help: "runs experiment to test emoji grid rendering"
	depends: ["_copy-emoji-grid-code"]
	run: fn (self build.Task) ! {
		system("v -g run ./src/emoji_grid.v")
		rm("./src/emoji_grid.v")!
	}
)

context.task(
	name: "immediate-grid",
	help: "runs experiment to test immediate grid rendering"
	depends: ["_copy-immediate-grid-code"]
	run: fn (self build.Task) ! {
		system("v -g run ./src/immediate_grid.v")
		rm("./src/immediate_grid.v")!
	}
)

// UTIL TASKS
context.task(
	name: "ansi-colour-codes",
	help: "displays ansi colour code chart"
	run: fn (self build.Task) ! {
		print("\n   +  ")
		for i := 0; i < 36; i++ {
			print("${i:2} ")
		}

		print("\n\n ${0:3}  ")
		for i := 0; i < 16; i++ {
			print("\033[48;5;${i}m  \033[m ")
		}

		for i := 0; i < 7; i++ {
			real_i := (i * 36) + 16
			print("\n\n ${real_i:3}  ")
			for j := 0; j < 36; j++ {
				print("\033[48;5;${real_i + j}m  \033[m ")
			}
		}
		println("")
	}
)
context.task(
	name: "ansi-to-rgb",
	help: "prompts for single ansi colour code and outputs the RGB components"
	run: fn (self build.Task) ! {
		ansi_num_to_convert := input("ANSI colour to convert to RGB: ")
		c := strconv.atoi(ansi_num_to_convert) or { panic("invalid num: ${err}") }

		if !(c >= 16 && c <= 231) {
			println("${c} -> is outside the 6x6x6 colour cube (16-231).")
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

		println("${c} -> RGB(${rr}, ${gg}, ${bb})")
	}
)

context.task(
	name: "rgb-to-ansi",
	help: "prompts three times for rgb values and produces single ansi colour code"
	run: fn (self build.Task) ! {
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

		rr_num_to_convert := input("R: ")
		rr := strconv.atoi(rr_num_to_convert) or { panic("invalid num for R: ${err}") }
		gg_num_to_convert := input("G: ")
		gg := strconv.atoi(gg_num_to_convert) or { panic("invalid num for G: ${err}") }
		bb_num_to_convert := input("B: ")
		bb := strconv.atoi(bb_num_to_convert) or { panic("invalid num for B: ${err}") }

		r := find_nearest_level(levels, rr)
		g := find_nearest_level(levels, gg)
		b := find_nearest_level(levels, bb)
		println("RGB(${rr}, ${gg}, ${bb}) -> ${16 + (36 * r) + (6 * g) + b}")
	}
)
context.task(name: "git-prune", run: |self| system("git remote prune origin"))
// NOTE(tauraamui) [27/05/2025]: unsure whether this util should really live here
//                               since it's only really for me as it's unlikely
//                               anyone else will be using radical but oh well?'
context.task(name: "rad-push", run: |self| system("git push rad master"))
context.task(
	name: "apply-license-header",
	help: "executes addlicense tool to insert license headers into files without one",
	run: |self| system("addlicense -v -c \"The Lilly Edtior contributors\" -y \"2025\" ./src/*")
)
context.task(
	name: "install-license-tool",
	help: "REQUIRES GO: installs a tool used to insert the license header into source files",
	run: |self| system("go install github.com/google/addlicense@latest")
)

// ARTIFACTS
context.artifact(
	name: "_generate-git-hash",
	help: "generate .githash to contain latest commit of current branch to embed in builds",
	run: |self| system("git log -n 1 --pretty=format:\"%h\" | tee ./src/.githash")
)
context.artifact(
	name: "_copy-emoji-grid-code",
	help: "internal tool, do not run this directly"
	run: |self| cp("./experiment/tui_render/emoji_grid.v", "./src/emoji_grid.v")!
)
context.artifact(
	name: "_copy-immediate-grid-code",
	help: "internal tool, do not run this directly"
	run: |self| cp("./experiment/tui_render/immediate_grid.v", "./src/immediate_grid.v")!
)

context.run()

