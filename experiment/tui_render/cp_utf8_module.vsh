#!/usr/bin/env -S v

working_dir := getwd()
utf8_module_path := join_path(working_dir, 'src', 'lib', 'utf8')
tui_render_experiment_path := join_path(working_dir, 'experiment', 'tui_render')
experiment_lib_dest_path := join_path(tui_render_experiment_path, 'lib', 'utf8')
cp_all(utf8_module_path, experiment_lib_dest_path, true) or {
	println('unable to cp ${utf8_module_path} to ${experiment_lib_dest_path} -> ${err}')
}
