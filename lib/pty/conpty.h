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

// ConPTY, the Windows pseudo console. The three entry points are looked up
// at run time rather than linked: they exist from Windows 10 1809 on, and
// mingw only declares them when _WIN32_WINNT is raised before windows.h,
// which V has already included by the time this header is.

#include <windows.h>

#ifndef PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE
#define PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE 0x00020016
#endif

typedef HRESULT (WINAPI *lilly_create_pc_fn)(COORD, HANDLE, HANDLE, DWORD, void **);
typedef HRESULT (WINAPI *lilly_resize_pc_fn)(void *, COORD);
typedef void (WINAPI *lilly_close_pc_fn)(void *);

typedef struct lilly_conpty {
	void *hpc;
	HANDLE in_write; // our end of the child's input
	HANDLE out_read; // our end of what the child draws
	HANDLE process;
} lilly_conpty;

static FARPROC lilly_conpty_proc(const char *name) {
	return GetProcAddress(GetModuleHandleW(L"kernel32.dll"), name);
}

// The input pipe is given a megabyte of buffer: an anonymous pipe cannot be
// made non-blocking, and a child that stops reading must fail a liveness
// check before it can fill the pipe and wedge the caller's WriteFile.
static int lilly_conpty_spawn(lilly_conpty *p, wchar_t *cmdline, short cols, short rows) {
	lilly_create_pc_fn create = (lilly_create_pc_fn)lilly_conpty_proc("CreatePseudoConsole");
	if (!create) {
		return -1;
	}
	HANDLE in_read = NULL;
	HANDLE out_write = NULL;
	if (!CreatePipe(&in_read, &p->in_write, NULL, 1 << 20)) {
		return -2;
	}
	if (!CreatePipe(&p->out_read, &out_write, NULL, 1 << 20)) {
		return -3;
	}
	COORD size = {cols, rows};
	if (create(size, in_read, out_write, 0, &p->hpc) != S_OK) {
		return -4;
	}
	// the pseudo console holds its own references to these
	CloseHandle(in_read);
	CloseHandle(out_write);

	SIZE_T attr_size = 0;
	InitializeProcThreadAttributeList(NULL, 1, 0, &attr_size);
	STARTUPINFOEXW si;
	ZeroMemory(&si, sizeof(si));
	si.StartupInfo.cb = sizeof(si);
	// without this a caller whose own stdio is redirected, as it is over ssh,
	// hands those handles to the child in place of the pseudo console's
	si.StartupInfo.dwFlags = STARTF_USESTDHANDLES;
	si.StartupInfo.hStdInput = INVALID_HANDLE_VALUE;
	si.StartupInfo.hStdOutput = INVALID_HANDLE_VALUE;
	si.StartupInfo.hStdError = INVALID_HANDLE_VALUE;
	si.lpAttributeList = (LPPROC_THREAD_ATTRIBUTE_LIST)HeapAlloc(GetProcessHeap(), 0, attr_size);
	if (!si.lpAttributeList) {
		return -5;
	}
	if (!InitializeProcThreadAttributeList(si.lpAttributeList, 1, 0, &attr_size)
		|| !UpdateProcThreadAttribute(si.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE,
			p->hpc, sizeof(p->hpc), NULL, NULL)) {
		HeapFree(GetProcessHeap(), 0, si.lpAttributeList);
		return -6;
	}
	PROCESS_INFORMATION pi;
	ZeroMemory(&pi, sizeof(pi));
	BOOL ok = CreateProcessW(NULL, cmdline, NULL, NULL, FALSE, EXTENDED_STARTUPINFO_PRESENT, NULL,
		NULL, &si.StartupInfo, &pi);
	DeleteProcThreadAttributeList(si.lpAttributeList);
	HeapFree(GetProcessHeap(), 0, si.lpAttributeList);
	if (!ok) {
		return -7;
	}
	CloseHandle(pi.hThread);
	p->process = pi.hProcess;
	return 0;
}

// reads whatever is waiting without blocking: 0 when there is nothing
static int lilly_conpty_read(lilly_conpty *p, unsigned char *buf, int len) {
	DWORD avail = 0;
	if (!PeekNamedPipe(p->out_read, NULL, 0, NULL, &avail, NULL) || avail == 0) {
		return 0;
	}
	DWORD n = 0;
	if (!ReadFile(p->out_read, buf, avail < (DWORD)len ? avail : (DWORD)len, &n, NULL)) {
		return 0;
	}
	return (int)n;
}

static int lilly_conpty_write(lilly_conpty *p, unsigned char *buf, int len) {
	DWORD n = 0;
	if (!WriteFile(p->in_write, buf, (DWORD)len, &n, NULL)) {
		return -1;
	}
	return (int)n;
}

static void lilly_conpty_resize(lilly_conpty *p, short cols, short rows) {
	lilly_resize_pc_fn resize = (lilly_resize_pc_fn)lilly_conpty_proc("ResizePseudoConsole");
	COORD size = {cols, rows};
	if (resize) {
		resize(p->hpc, size);
	}
}

// 1 and the exit code once the child has exited, 0 while it runs
static int lilly_conpty_poll(lilly_conpty *p, int *code) {
	if (WaitForSingleObject(p->process, 0) != WAIT_OBJECT_0) {
		return 0;
	}
	DWORD exit_code = 0;
	GetExitCodeProcess(p->process, &exit_code);
	*code = (int)exit_code;
	return 1;
}

// Our end of the output pipe is closed before the pseudo console: before
// Windows 11 24H2, ClosePseudoConsole blocks until that pipe is drained.
static void lilly_conpty_close(lilly_conpty *p, int terminate) {
	if (terminate) {
		TerminateProcess(p->process, 1);
		WaitForSingleObject(p->process, 5000);
	}
	CloseHandle(p->in_write);
	CloseHandle(p->out_read);
	lilly_close_pc_fn close_pc = (lilly_close_pc_fn)lilly_conpty_proc("ClosePseudoConsole");
	if (close_pc) {
		close_pc(p->hpc);
	}
	CloseHandle(p->process);
}
