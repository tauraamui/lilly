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

Our project is focused on the development of a text editor that serves as a practical alternative to Vim and Neovim. The primary aim is to provide users with essential features, eliminating the need to navigate a complex ecosystem of Lua plugins. This approach is intended to be welcoming to users of all experience levels.

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

1. Install the clockwork build tool by executing this command: `v run ./install-clockwork.vsh`

2. Build lilly by executing: `clockwork build`
	or build and run with `clockwork run`

You can see what other tasks are available to run with `clockwork --tasks`

# The Rationale
### Inclusive Functionality
We have set out to create an editor that encompasses the fundamental capabilities expected by users, rendering it a compelling choice as a Vim/Neovim alternative. Our emphasis is on streamlining the editing process without the necessity of configuring numerous plugins – our core features aim to fulfill these needs.

### Simplified User Experience
The intricacies of Lua plugins can be daunting for newcomers and even pose a management challenge for seasoned users. Our editor simplifies the user experience by removing the requirement for extensive plugin management. It offers an approachable and intuitive platform, eliminating the complexities that often accompany plugin management.

### Performance Enhancement
Our editor is optimized to offer improved performance, particularly when handling extensive files. It is engineered for speed and responsiveness, designed to enhance your editing efficiency.

### VIM-Like Experience
We've crafted the editor to deliver a VIM-like experience, preserving the functionalities that VIM users appreciate. The difference lies in the absence of reliance on a multifaceted ecosystem – our editor consolidates these features within a unified framework.

Transition to our text editor to explore an alternative that is rooted in functionality, accessibility, and performance.

### Not convinced?

Not a problem, Neovim/VIM are fantastic existing projects and are freely available for you to use today.

### misc + extra information

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
