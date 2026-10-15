// Uploads release assets to the draft release for a tag on git.catkin.dev,
// creating that release first if nothing has yet.
//
//   node .forgejo/scripts/publish-release.mjs <tag> <file>...
//
// Every job that produces a binary calls this independently -- the Linux and
// Windows jobs in the CI image, and the macOS jobs on the self-hosted Mac
// runner -- so there is no single job that owns the release. Whichever arrives first
// creates it; the rest find it and attach to it. Re-running a job replaces its
// asset rather than failing on the duplicate name.
//
// Node rather than a shell script, because it is present everywhere this runs
// (the CI image is node:22-trixie, and the Mac runner needs it for
// actions/checkout anyway) and its built-in fetch avoids depending on jq.
//
// Environment:
//   FORGE_TOKEN  access token with write:repository on the repo (required)
//   FORGE_URL    defaults to https://git.catkin.dev
//   FORGE_REPO   defaults to tauraamui/lilly
import { execFileSync } from 'node:child_process'
import { readFile } from 'node:fs/promises'
import { basename } from 'node:path'

const [tag, ...files] = process.argv.slice(2)
if (!tag || files.length === 0) {
	console.error('usage: publish-release.mjs <tag> <file>...')
	process.exit(2)
}
const token = process.env.FORGE_TOKEN
if (!token) {
	console.error('FORGE_TOKEN is not set')
	process.exit(2)
}
const api = `${process.env.FORGE_URL || 'https://git.catkin.dev'}/api/v1/repos/${process.env.FORGE_REPO || 'tauraamui/lilly'}`

async function call(method, path, body) {
	const res = await fetch(`${api}${path}`, {
		method,
		headers: {
			Authorization: `token ${token}`,
			Accept: 'application/json',
			...(body && !(body instanceof FormData) ? { 'Content-Type': 'application/json' } : {}),
		},
		body: body instanceof FormData ? body : body && JSON.stringify(body),
	})
	return res
}

async function must(res, what) {
	if (res.ok) {
		return res.status === 204 ? null : res.json()
	}
	throw new Error(`${what}: HTTP ${res.status} ${await res.text()}`)
}

// The by-tag endpoint does not return drafts, so page through the list, which
// does for a token that can write to the repo.
async function find_release() {
	for (let page = 1; ; page++) {
		const releases = await must(await call('GET', `/releases?limit=50&page=${page}`), 'list releases')
		const found = releases.find((r) => r.tag_name === tag)
		if (found || releases.length === 0) {
			return found
		}
	}
}

function git(...args) {
	return execFileSync('git', args, { encoding: 'utf8' }).trim()
}

// The previous tag by version order, matching the changelog the GitHub
// mirror's releases used before releases moved here. Needs the full history, so the
// calling job checks out with fetch-depth: 0.
function changelog() {
	try {
		const previous = git('tag', '--sort=-version:refname').split('\n').find((t) => t && t !== tag)
		const range = previous ? `${previous}..${tag}` : tag
		return `## Changes\n\n${git('log', '--pretty=format:- %s (%h)', range)}\n`
	} catch (err) {
		console.warn(`could not generate a changelog: ${err.message}`)
		return ''
	}
}

async function get_or_create_release() {
	const existing = await find_release()
	if (existing) {
		return existing
	}
	const res = await call('POST', '/releases', {
		tag_name: tag,
		name: tag,
		body: changelog(),
		draft: true,
		prerelease: /alpha|beta|rc/.test(tag),
	})
	// another job created it between our lookup and this request
	if (res.status === 409) {
		const raced = await find_release()
		if (raced) {
			return raced
		}
	}
	return must(res, 'create release')
}

const release = await get_or_create_release()
console.log(`release ${release.name} (id ${release.id}, draft: ${release.draft})`)

for (const file of files) {
	const name = basename(file)
	for (const asset of release.assets || []) {
		if (asset.name === name) {
			await must(await call('DELETE', `/releases/${release.id}/assets/${asset.id}`), `delete old ${name}`)
			console.log(`  replaced existing ${name}`)
		}
	}
	const form = new FormData()
	form.append('attachment', new Blob([await readFile(file)]), name)
	await must(await call('POST', `/releases/${release.id}/assets?name=${encodeURIComponent(name)}`, form), `upload ${name}`)
	console.log(`  uploaded ${name}`)
}
