# Cronos

A lightweight macOS menu bar app for scheduling bash commands.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)

## Features

- **Menu bar app** — lives in your menu bar, not the Dock
- **Schedule commands** — run any bash command daily or weekly
- **View logs** — see stdout/stderr from past runs
- **Run now** — manually trigger jobs anytime
- **Launch at login** — starts automatically with your Mac

## Installation

1. Clone the repo
2. Open `Cronos.xcodeproj` in Xcode
3. Build and run (⌘R)

## Usage

Click the clock icon in the menu bar to:

- **Add a job** — click `+` to create a new scheduled command
- **View job details** — click any job to see details and actions
- **Run now** — trigger a job immediately
- **View logs** — see output from the last run
- **Enable/disable** — toggle jobs without deleting them

Jobs are stored in `~/.cronos/jobs.json` and logs in `~/.cronos/logs/`.

## Example

Schedule a Claude CLI command to run daily:

```
Name: Daily Summary
Command: claude -p "summarize today's git commits"
Working Directory: ~/projects/myapp
Schedule: Daily at 9:00
```

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15+ to build

## License

MIT
