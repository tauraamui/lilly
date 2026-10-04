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

// Builds without the Boehm collector - `-gc none`, which the memory profiling
// task uses - have nothing to tune, and must not reference its symbols.
fn tune_gc_for_interactive_use() {}

// Nothing to collect or unmap without the Boehm collector.
fn release_free_heap_to_os() {}
