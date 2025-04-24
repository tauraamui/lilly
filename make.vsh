#!/usr/bin/env -S v run

import build

const app_name = "lilly"

mut context := build.context(
	default: "run"
)

context.task(name: "build", run: |self| system("v ./src -o lilly"))
context.task(name: "build-prod", run: |self| system("v ./src -o ${app_name}"))
context.task(name: "run", run: |self| system("v -g run ./src ."))
context.task(name: "run-with-gap", run: |self| system("v -g run ./src -ugb ."))
context.task(name: "run-debug-log", run: |self| system("v -g run ./src --log-level debug ."))
context.task(name: "run-gui", run: |self| system("v -g -d gui run ./src ."))

context.task(name: "test", run: |self| system("v -g test ./src"))

context.task(name: "git-prune", run: |self| system("git remote prune origin"))

context.task(
	name: "apply-license-header",
	help: "executes addlicense tool to insert license headers into files without one",
	run: |self| system("addlicense -c \"The Lilly Edtior contributors\" -y \"2025\" ./src/*")
)
context.task(
	name: "install-license-tool",
	help: "REQUIRES GO: installs a tool used to insert the license header into source files",
	run: |self| system("go install github.com/google/addlicense@latest")
)

context.run()

