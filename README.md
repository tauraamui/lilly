<div align="center">
  <img src="docs/lilly-banner.png" width="445.4" alt="Lilly">
  <img src="https://github.com/tauraamui/lilly/assets/3159648/270286b3-67a6-48ca-9b9c-4566f605ec66" width="100%" height="25px">
</div>

## A VIM-Like editor for your terminal (<a href="https://discord.gg/N4UG2TfDfd">chat on Discord</a>)

> [!IMPORTANT]
> Lilly is in a pre-alpha state, and only suitable for use by developers.
> This editor is technically usable, it is the exclusive editor used to work on itself,
> however many features are missing, and there is no guarantee of stable features or a lack of bugs.
> Features, bug fixes and issues are welcome.

![Screenshot 2023-11-17 20 07 13](https://github.com/tauraamui/lilly/assets/3159648/12e893ce-0120-4eb4-9d54-71b1a076832c)

![Screenshot 2023-12-01 21 01 45](https://github.com/tauraamui/lilly/assets/3159648/e9023db2-0214-49e1-baad-9a75aa22d291)

An editor designed as a batteries included experience, eliminating the need for plugins. So, basically Helix but for VIM
motions. The end vision is a one to one replacement/equivalent functionality for all VIM features, macros, motions, and more.

## Milestone 1: A pre-alpha release

### Targets:

- [ ] Gap buffer to replace string array
- [x] Within line visual mode (kind of)
- [ ] Fix found search result highlighting
- [ ] Horizontal scrolling
- [ ] Splits (horizontal + vertical)
- [ ] Goto def
- [x] List of active but not open buffers
- [x] Search/Find files
- [ ] Workspace wide search (ripgrep + roll your own)

## How to build (requires the V compiler https://vlang.io)

#### Build lilly by executing
	./make.vsh build-prod

#### or run with no binary build with
	./make.vsh run

You can see what other tasks are available to run with `./make.vsh --tasks`

(you can compile make.vsh into a binary to make executing tasks as fast as possible, use `v -prod -skip-running make.vsh`)

### Not convinced?

Not a problem, Neovim/VIM are fantastic existing projects and are freely available for you to use today.

### misc + extra information

### radicle.xyz remote

The Lilly project is also hosted by (approx minimum 20 seeds) on the decentralised peer-to-peer git host network "Radicle".
If you would like to contribute using that instead of Github then please clone with:
`rad clone rad:zENt7TUiNcnJSf9H371PZ66XdgxE` and then submit a patch in the usual git way but using the rad toolchain (see https://radicle.xyz/guides/user#working-with-patches)

Feel free to also raise issues here, I will hopefully remember to check the inbox frequently.


### memleak checks

On macOS we get this output from running:

`leaks --atExit -- ./lilly .`

```
lilly(53176) MallocStackLogging: could not tag MSL-related memory as no_footprint, so those pages will be included in process footprint - (null)
lilly(53176) MallocStackLogging: recording malloc and VM allocation stacks using lite mode
Process 53176 is not debuggable. Due to security restrictions, leaks can only show or save contents of readonly memory of restricted processes.

Process:         lilly [53176]
Path:            /Users/USER/*/lilly
Load Address:    0x10294c000
Identifier:      lilly
Version:         0
Code Type:       ARM64
Platform:        macOS
Parent Process:  leaks [53172]

Date/Time:       2024-12-05 11:07:02.409 +0000
Launch Time:     2024-12-05 11:06:46.429 +0000
OS Version:      macOS 13.2.1 (22D68)
Report Version:  7
Analysis Tool:   /usr/bin/leaks

Physical footprint:         4513K
Physical footprint (peak):  4529K
Idle exit: untracked
----

leaks Report Version: 4.0, multi-line stacks
Process 53176: 226 nodes malloced for 22 KB
Process 53176: 0 leaks for 0 total leaked bytes.
```

Look at that. 0 memory leaks.

(experimental GUI render target)

![Screenshot 2023-12-13 21 10 40](https://github.com/tauraamui/lilly/assets/3159648/17ec7286-ecc2-4e68-addd-9c503afd45ee)
