
# PancakeLinux

A Debian-derived Linux distribution powered by runit, featuring its own package management ecosystem and custom system tools.

## Features

- Debian Stable foundation
- runit init system
- Custom package management frontend (`pkgmngr`)
- Custom driver management tool (`drvmngr`)
- Custom system installer (`sys-inst`)

## Project Status

Early development. Features and components are subject to change.

## Architecture

| Component | Technology |
|---|---|
| Base | Debian Stable |
| Init | runit |
| Bootloader | GRUB |
| Live environment | CLI |
| Architecture | amd64 |

