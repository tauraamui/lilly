// Downloads release assets for a tag from git.catkin.dev, and checks each
// against the .sha256 the release job attached beside it, so what gets fuzzed
// is byte for byte what users download.
//
//   node .forgejo/scripts/fetch-release-assets.mjs <tag> <asset>...
//
// The assets land in the working directory, marked executable.
//
// Environment:
//   FORGE_TOKEN  optional: an access token that can read the repo. Without
//                one only published releases are found; with one, drafts too
//   FORGE_URL    defaults to https://git.catkin.dev
//   FORGE_REPO   defaults to tauraamui/lilly
import { createHash } from 'node:crypto'
import { chmod, writeFile } from 'node:fs/promises'

const [tag, ...names] = process.argv.slice(2)
if (!tag || names.length === 0) {
	console.error('usage: fetch-release-assets.mjs <tag> <asset>...')
	process.exit(2)
}
const token = process.env.FORGE_TOKEN
const api = `${process.env.FORGE_URL || 'https://git.catkin.dev'}/api/v1/repos/${process.env.FORGE_REPO || 'tauraamui/lilly'}`
const headers = token ? { Authorization: `token ${token}` } : {}

async function get(url, what) {
	const res = await fetch(url, { headers })
	if (!res.ok) {
		throw new Error(`${what}: HTTP ${res.status} ${await res.text()}`)
	}
	return res
}

// The by-tag endpoint does not return drafts, so with a token page through
// the list, which does
async function find_release() {
	if (!token) {
		return (await get(`${api}/releases/tags/${tag}`, `release ${tag}`)).json()
	}
	for (let page = 1; ; page++) {
		const releases = await (await get(`${api}/releases?limit=50&page=${page}`, 'list releases')).json()
		const found = releases.find((r) => r.tag_name === tag)
		if (found) {
			return found
		}
		if (releases.length === 0) {
			throw new Error(`no release for ${tag}`)
		}
	}
}

async function download(release, name) {
	const asset = (release.assets || []).find((a) => a.name === name)
	if (!asset) {
		throw new Error(`release ${tag} has no asset ${name}`)
	}
	return Buffer.from(await (await get(asset.browser_download_url, `download ${name}`)).arrayBuffer())
}

const release = await find_release()
console.log(`release ${release.name} (id ${release.id}, draft: ${release.draft})`)
for (const name of names) {
	const data = await download(release, name)
	const expected = (await download(release, `${name}.sha256`)).toString().split(/\s+/)[0]
	const actual = createHash('sha256').update(data).digest('hex')
	if (actual !== expected) {
		throw new Error(`${name}: sha256 ${actual} does not match the release's ${expected}`)
	}
	await writeFile(name, data)
	await chmod(name, 0o755)
	console.log(`  ${name} ${actual}`)
}
