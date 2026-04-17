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

import net.http

pub struct HttpProvider {
	endpoint string
}

pub fn HttpProvider.new(endpoint string) HttpProvider {
	return HttpProvider{
		endpoint: endpoint
	}
}

pub fn (p HttpProvider) send_event(event Event) ! {
	payload := encode_event(event)
	p.post(payload)!
}

pub fn (p HttpProvider) post(payload string) ! {
	http.post_json(p.endpoint, payload)!
}
