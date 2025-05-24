import os
import time

fn set_content() {
	mut p := os.new_process('/usr/bin/pbcopy')
	p.set_redirect_stdio()
	p.run()

	p.stdin_write("text to copy")
	os.fd_close(p.stdio_fd[0])

	p.close()
	p.wait()
	println("ERR: ${p.err}, CODE: ${p.code}")
}

fn get_content() {
	mut out := []string{}
	mut er := []string{}
	mut rc := 0

	mut p := os.new_process('/usr/bin/pbpaste')
	p.set_redirect_stdio()
	p.run()

	for p.is_alive() {
		if data := p.pipe_read(.stderr) {
			eprintln('p.pipe_read .stderr, len: ${data.len:4} | data: `${data#[0..10]}`...')
			er << data
		}
		if data := p.pipe_read(.stdout) {
			eprintln('p.pipe_read .stdout, len: ${data.len:4} | data: `${data#[0..10]}`...')
			out << data
		}
		// avoid a busy loop, by sleeping a bit between each iteration
		time.sleep(2 * time.millisecond)
	}

	out << p.stdout_slurp()
	er << p.stderr_slurp()
	p.close()
	p.wait()

	if p.code > 0 {
		eprintln('----------------------------------------------------------')
		eprintln('COMMAND: pbcopy')
		eprintln('STDOUT:\n${out}')
		eprintln('STDERR:\n${er}')
		eprintln('----------------------------------------------------------')
		rc = 1
	}

	println("${out.join('')}, ${rc}, ${er.join('')}")
}

fn main() {
	// set_content()
	get_content()
}

