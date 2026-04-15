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
