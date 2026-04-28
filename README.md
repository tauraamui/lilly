<div align="center">
  <img src="https://github.com/user-attachments/assets/1948c77f-81cd-4d4b-a6a3-0c36b6936fa1" width="445.4" alt="Lilly">
  <img src="https://github.com/tauraamui/lilly/assets/3159648/270286b3-67a6-48ca-9b9c-4566f605ec66" width="100%" height="25px">
</div>

## A VIM-Like editor for your terminal (<a href="https://discord.gg/N4UG2TfDfd">chat on Discord</a>)

> **Note:** The canonical home of this project is now [git.catkin.dev/tauraamui/lilly](https://git.catkin.dev/tauraamui/lilly).
> The [GitHub repository](https://github.com/tauraamui/lilly) is a **read-only mirror** — please open issues and pull requests on Catkin.

<img width="1400" height="826" alt="screenshot-2026-04-01_12-23-26" src="https://github.com/user-attachments/assets/add7e429-f308-4025-809c-ff4510f6e67f" />
<img width="1404" height="821" alt="screenshot-2026-04-01_12-23-44" src="https://github.com/user-attachments/assets/62f82f83-0d1d-444b-930d-f36e41114dcd" />
<img width="1381" height="822" alt="screenshot-2026-04-01_12-24-33" src="https://github.com/user-attachments/assets/047e5ea4-0062-499f-9026-29f98a47f4a3" />


An editor designed as a batteries included experience, eliminating the need for plugins. So, basically Helix but for VIM
motions. The end vision is a one to one replacement/equivalent functionality for all VIM features, macros, motions, and more.

## How to build (requires the V compiler https://vlang.io)

#### Install Bobatea (TUI library)
	v install

#### Build lilly by executing
	./make.vsh build

#### or run with no binary build with
	./make.vsh run-d (for dark mode)
	./make.vsh run-l (for light mode)

You can see what other tasks are available to run with `./make.vsh --tasks`

(you can compile make.vsh into a binary to make executing tasks as fast as possible, use `./make.vsh compile-make` or `v -prod -skip-running make.vsh`)

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
