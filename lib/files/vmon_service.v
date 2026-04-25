module files

import os
import sync
import tauraamui.bobatea as tea
import vmon

const default_watch_flags = u32(vmon.WatchFlag.recursive) | u32(vmon.WatchFlag.follow_symlinks)

pub type AppSendFn = fn (tea.Msg)

pub struct VmonWatchEventMsg {
pub:
	watch_id      vmon.WatchID
	action        vmon.Action
	root_path     string
	file_path     string
	old_file_path string
}

pub fn (msg VmonWatchEventMsg) absolute_path() string {
	if msg.file_path.len == 0 {
		return msg.root_path
	}
	return os.join_path(msg.root_path, msg.file_path)
}

@[heap]
pub struct VmonService {
pub:
	root_path string
	flags     u32
mut:
	watch_id vmon.WatchID
	send_fn  AppSendFn = unsafe { nil }
	running  bool
	mu       sync.Mutex
}

@[params]
pub struct VmonServiceOptions {
	flags ?u32
}

pub fn VmonService.new(path string, send AppSendFn, opts VmonServiceOptions) !&VmonService {
	if path.len == 0 {
		return error('vmon service requires a non-empty path')
	}
	if isnil(send) {
		return error('vmon service requires a valid send callback')
	}
	abs_path := os.real_path(path)
	if !os.is_dir(abs_path) {
		return error('vmon service requires a directory to watch: ${abs_path}')
	}
	flags := opts.flags or { default_watch_flags }
	mut svc := &VmonService{
		root_path: abs_path
		flags:     flags
		send_fn:   send
		running:   true
	}
	svc.watch_id = vmon.watch(abs_path, watch_callback, flags, svc) or {
		svc.running = false
		unsafe { free(svc) }
		return err
	}
	return svc
}

pub fn (mut svc VmonService) stop() {
	svc.mu.@lock()
	if !svc.running {
		svc.mu.unlock()
		return
	}
	svc.running = false
	wid := svc.watch_id
	svc.watch_id = 0
	svc.mu.unlock()
	if wid != 0 {
		vmon.unwatch(wid)
	}
}

pub fn (mut svc VmonService) free() {
	svc.stop()
}

fn watch_callback(watch_id vmon.WatchID, action vmon.Action, root_path string, file_path string, old_file_path string, user_data voidptr) {
	if isnil(user_data) {
		return
	}
	mut svc := unsafe { &VmonService(user_data) }
	svc.handle_event(watch_id, action, root_path, file_path, old_file_path)
}

fn (mut svc VmonService) handle_event(watch_id vmon.WatchID, action vmon.Action, root_path string, file_path string, old_file_path string) {
	svc.mu.@lock()
	running := svc.running
	send := svc.send_fn
	svc.mu.unlock()
	if !running || isnil(send) {
		return
	}
	send(tea.Msg(VmonWatchEventMsg{
		watch_id:      watch_id
		action:        action
		root_path:     root_path
		file_path:     file_path
		old_file_path: old_file_path
	}))
}
