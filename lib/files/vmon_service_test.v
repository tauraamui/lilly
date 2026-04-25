module files

import os
import time
import tauraamui.bobatea as tea
import vmon

const event_wait = 150 * time.millisecond

fn prepare_temp_dir(suffix string) string {
	dir := os.join_path(os.temp_dir(), 'lilly_vmon_service_${suffix}_${time.now().unix_micro()}')
	os.rmdir_all(dir) or {}
	os.mkdir_all(dir) or { panic(err) }
	return dir
}

fn test_vmon_service_emits_events() {
	temp_dir := prepare_temp_dir('events')
	defer {
		os.rmdir_all(temp_dir) or {}
	}

	shared events := []VmonWatchEventMsg{}
	send := fn [mut events] (msg tea.Msg) {
		match msg {
			VmonWatchEventMsg {
				lock events {
					events << msg
				}
			}
			else {}
		}
	}

	mut svc := VmonService.new(temp_dir, send, VmonServiceOptions{}) or { panic(err) }
	defer {
		svc.free()
	}

	time.sleep(event_wait)

	file_a := os.join_path(temp_dir, 'file.txt')
	os.write_file(file_a, 'hello world') or { panic(err) }
	time.sleep(event_wait)

	file_b := os.join_path(temp_dir, 'renamed.txt')
	os.mv(file_a, file_b) or { panic(err) }
	time.sleep(event_wait)

	svc.stop()
	time.sleep(event_wait)

	lock events {
		assert events.len > 0
		assert events.any(it.action == vmon.Action.create && it.absolute_path() == file_a)
		assert events.any(it.action == vmon.Action.move && it.absolute_path() == file_b
			&& it.old_file_path == 'file.txt')
	}
}

fn test_vmon_service_stop_stops_watching() {
	temp_dir := prepare_temp_dir('stop')
	defer {
		os.rmdir_all(temp_dir) or {}
	}

	shared events := []VmonWatchEventMsg{}
	send := fn [mut events] (msg tea.Msg) {
		match msg {
			VmonWatchEventMsg {
				lock events {
					events << msg
				}
			}
			else {}
		}
	}

	mut svc := VmonService.new(temp_dir, send, VmonServiceOptions{}) or { panic(err) }
	defer {
		svc.free()
	}

	time.sleep(event_wait)

	svc.stop()
	svc.stop()
	assert !svc.running
	assert svc.watch_id == 0

	after_stop_file := os.join_path(temp_dir, 'after_stop.txt')
	os.write_file(after_stop_file, 'data') or { panic(err) }
	time.sleep(event_wait)

	lock events {
		assert events.len == 0
	}
}
