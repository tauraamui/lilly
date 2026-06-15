module main

import time
import bobatea as tea
import lib.petal.theme

struct MessageLabel {
	contents string
	ccolor   tea.Color
}

enum DisplayMessageType {
	normal
	warning
	error
}

fn (t DisplayMessageType) color(ttheme theme.Theme) tea.Color {
	return match t {
		.normal { ttheme.petal_green }
		.warning { ttheme.status_orange }
		.error { ttheme.petal_red }
	}
}

struct DisplayMessageMsg {
	contents string
	m_type   DisplayMessageType
}

fn display_message(m_type DisplayMessageType, contents string) tea.Cmd {
	return fn [m_type, contents] () tea.Msg {
		return DisplayMessageMsg{
			contents: contents
			m_type:   m_type
		}
	}
}

fn emit_focused() tea.Msg {
	return tea.FocusedMsg{}
}

fn display_error_message(contents string) tea.Cmd {
	return tea.sequence(display_message(.error, contents), hide_message_after(6 * time.second))
}

struct HideMessageMsg {
	time time.Time
}

fn hide_message() tea.Msg {
	return HideMessageMsg{}
}

fn hide_message_after(duration time.Duration) tea.Cmd {
	return tea.tick(duration, fn (t time.Time) tea.Msg {
		return HideMessageMsg{
			time: t
		}
	})
}

fn execute_command(cmd string) tea.Cmd {
	match cmd {
		'qa' {
			return tea.quit
		}
		else {
			return display_error_message('unrecognised command: ${cmd}')
		}
	}

	return tea.noop_cmd
}

struct QueryGitBranchMsg {}

fn query_git_branch() tea.Msg {
	return QueryGitBranchMsg{}
}

struct GitBranchQueryResultMsg {
	branch_name string
}

fn git_branch_query_result(branch_name string) tea.Cmd {
	return fn [branch_name] () tea.Msg {
		return GitBranchQueryResultMsg{
			branch_name: branch_name
		}
	}
}


