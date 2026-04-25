/*
 * Copyright 2026 The Lilly Edtior contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef GOLDEN_SNAPSHOT_SIGNAL_H
#define GOLDEN_SNAPSHOT_SIGNAL_H

#include <signal.h>
#include <stdbool.h>

static volatile sig_atomic_t golden_snapshot_pending = 0;

static void golden_snapshot_sigusr1(int sig) {
	(void)sig;
	golden_snapshot_pending = 1;
}

static inline void golden_snapshot_install_handler(void) {
	signal(SIGUSR1, golden_snapshot_sigusr1);
}

static inline bool golden_snapshot_check_and_clear(void) {
	if (golden_snapshot_pending) {
		golden_snapshot_pending = 0;
		return true;
	}
	return false;
}

#endif
