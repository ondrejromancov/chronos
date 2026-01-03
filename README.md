# Cronos

A lightweight macOS menu bar app for scheduling bash commands.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
[![GitHub release](https://img.shields.io/github/v/release/ondrejromancov/chronos)](https://github.com/ondrejromancov/chronos/releases)

## Features

- **Menu bar app** — lives in your menu bar, not the Dock
- **Schedule commands** — run any bash command daily or weekly
- **Live log streaming** — watch stdout/stderr as jobs run
- **Log history** — browse all past runs with duration and exit codes
- **Failure notifications** — get notified when jobs fail
- **Keyboard navigation** — arrow keys, Enter, Escape
- **Search** — filter jobs by name or command
- **Launch at login** — starts automatically with your Mac

## Installation

1. Download the latest DMG from [Releases](https://github.com/ondrejromancov/chronos/releases)
2. Open the DMG and drag Cronos to your Applications folder
3. **Important:** Right-click the app and select "Open" (required for unsigned apps)

> **Note:** Cronos is not notarized by Apple. On first launch, you may need to go to System Settings > Privacy & Security and click "Open Anyway".

### Build from Source

```bash
git clone https://github.com/ondrejromancov/chronos.git
cd chronos
xcodebuild -project Cronos.xcodeproj -scheme Cronos -configuration Release
```

## Usage

Click the clock icon in the menu bar to open the job list.

### Managing Jobs

- **Add a job** — click `+` to create a new scheduled command
- **View details** — click any job to expand its detail panel
- **Run now** — trigger a job immediately
- **Enable/disable** — toggle jobs without deleting them
- **Edit/delete** — modify or remove existing jobs

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| ↑/↓ | Navigate between jobs |
| Enter | Expand/collapse job details |
| Escape | Clear search or close panel |

### Logs

Each job shows a preview of the last log line. Click "Logs" to open the full log history:

- View all past runs (newest first)
- See duration, exit code, and timestamp for each run
- Switch between stdout and stderr tabs
- Live streaming while jobs run

### Storage

Jobs and logs are stored locally:

```
~/.cronos/
├── jobs.json          # Job configurations
└── logs/              # Per-run log files
    ├── {runId}.stdout
    └── {runId}.stderr
```

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

## Uninstalling

1. Quit Cronos from the menu bar
2. Delete Cronos.app from Applications
3. Remove data: `rm -rf ~/.cronos`

## License

MIT
