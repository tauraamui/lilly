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

module telemetry

import json

pub enum EventKind as u8 {
	launch
	session_end
}

pub struct Event {
pub:
	kind    EventKind
	version string
	os      string
	arch    string
}

pub interface Provider {
	send_event(event Event) !
	post(payload string) !
}

pub struct NoOpProvider {}

pub fn (p NoOpProvider) send_event(event Event) ! {}

pub fn (p NoOpProvider) post(payload string) ! {}

struct EventPayload {
	kind    string
	version string
	os      string
	arch    string
}

pub fn encode_event(event Event) string {
	return json.encode(EventPayload{
		kind:    event.kind.str()
		version: event.version
		os:      event.os
		arch:    event.arch
	})
}
