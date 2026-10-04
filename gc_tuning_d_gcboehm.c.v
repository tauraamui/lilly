// Copyright 2026 The Lilly Edtior contributors
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

module main

import os

fn C.GC_set_free_space_divisor(usize)

fn C.GC_gcollect_and_unmap()

// gc_free_space_divisor is how much of the heap Boehm aims to keep free: the
// heap is grown until free space is roughly 1/divisor of it. Boehm's default
// is 3, which makes it prefer growing the heap over collecting.
//
// That default suits a batch program that exits. An editor renders
// continuously for hours, and because Boehm never returns the growth to the
// OS, every burst of render garbage becomes a permanent step up in resident
// memory. Opening the file picker at 200x50 was a clear example: it added
// only ~0.6MiB of live data, but took the heap from 4.3MiB to 8.9MiB with
// 5.5MiB of that sitting free inside the heap, and resident memory followed
// the reservation rather than the live set and stayed there after the dialog
// closed.
//
// Asking for a sixth free rather than a third trades a few more collections
// for a much smaller footprint. Peak RSS over identical scripted sessions at
// 200x50, sampled from outside the process:
//
//	open the file picker, close it   ~16MiB -> ~11MiB
//	open a 5MiB file and scroll      ~46MiB -> ~36MiB
//
// Both rendered exactly the same number of frames in the same wall-clock time,
// and collections only went from 2 to 11 on the first case, so the extra
// collector work does not come out of the frame budget. Values above 6 were
// measured too and bought almost nothing, so this stops where the curve
// flattens.
//
// Boehm's global unmapping options are still deliberately not set here:
// GC_UNMAP_THRESHOLD made no reliable difference, and
// GC_FORCE_UNMAP_ON_GCOLLECT swung between better and considerably worse
// across repeats of the same scenario. Unmapping is instead asked for by hand
// at the one moment it is known to be worth doing - see
// release_free_heap_to_os.
const gc_free_space_divisor = usize(6)

// tune_gc_for_interactive_use applies the above. An explicit
// GC_FREE_SPACE_DIVISOR in the environment takes precedence, since Boehm has
// already read it by this point and overriding it would make the variable
// silently useless for experimentation.
fn tune_gc_for_interactive_use() {
	if _ := os.getenv_opt('GC_FREE_SPACE_DIVISOR') {
		return
	}
	C.GC_set_free_space_divisor(gc_free_space_divisor)
}

// release_free_heap_to_os collects and then hands as much of the free heap
// back to the operating system as Boehm is willing to part with.
//
// Boehm unmaps free blocks only during a collection, and only once a block has
// stayed free across GC_unmap_threshold (7) consecutive collections. An editor
// that has just closed a file then does the worst possible thing for that
// heuristic: it goes idle. With nothing being allocated there are no further
// collections, the blocks never age, and the heap keeps a megabyte per file
// visited for the rest of the session - which is what the process shows as
// resident memory, however small the live set is.
//
// So this is for callers that have just released something big and know it:
// it bypasses the ageing heuristic for one collection. Measured over a
// scripted session that opens four 1MiB files through the picker, resident
// memory at the end fell from ~19.6MiB to ~12-16MiB, with 3.5-8.2MiB returned.
//
// Deliberately not wired into the collector's own cycle. It is a full
// stop-the-world collection plus mmap churn, which is far too expensive to pay
// per frame or per collection, and only pays at all when a lot has just died.
fn release_free_heap_to_os() {
	C.GC_gcollect_and_unmap()
}
