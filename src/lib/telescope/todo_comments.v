module telescope

import os

fn exec_rg(execute fn (cmd string) os.Result, pattern string) os.Result {
	return execute("rg '${pattern}'")
}
