// Cronos data types - must match Swift models exactly

export type JobType = "claude" | "customCommand";

export interface DailySchedule {
  daily: {
    hour: number;
    minute: number;
  };
}

export interface WeeklySchedule {
  weekly: {
    weekday: number; // 1=Sunday, 7=Saturday
    hour: number;
    minute: number;
  };
}

export type Schedule = DailySchedule | WeeklySchedule;

export interface Job {
  id: string; // UUID
  name: string;
  command: string;
  workingDirectory: string;
  schedule: Schedule;
  isEnabled: boolean;
  lastRun?: string; // ISO 8601 date string
  lastRunSuccessful?: boolean;
  jobType: JobType;
  claudePrompt?: string;
  contextDirectory?: string;
}

export interface LogRun {
  id: string; // UUID
  jobId: string;
  startedAt: string; // ISO 8601 date string
  endedAt?: string;
  exitCode?: number;
  success?: boolean;
}

// Helper type guards
export function isDailySchedule(schedule: Schedule): schedule is DailySchedule {
  return "daily" in schedule;
}

export function isWeeklySchedule(
  schedule: Schedule,
): schedule is WeeklySchedule {
  return "weekly" in schedule;
}

// Helper functions
export function getScheduleDisplayString(schedule: Schedule): string {
  if (isDailySchedule(schedule)) {
    const { hour, minute } = schedule.daily;
    const timeString = `${hour}:${minute.toString().padStart(2, "0")}`;
    return `Daily at ${timeString}`;
  } else {
    const { weekday, hour, minute } = schedule.weekly;
    const days = [
      "",
      "Sunday",
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
    ];
    const dayName = weekday >= 1 && weekday <= 7 ? days[weekday] : "Unknown";
    const timeString = `${hour}:${minute.toString().padStart(2, "0")}`;
    return `${dayName} at ${timeString}`;
  }
}

export function getNextRunDate(
  schedule: Schedule,
  after: Date = new Date(),
): Date {
  const now = after;

  if (isDailySchedule(schedule)) {
    const { hour, minute } = schedule.daily;
    const nextRun = new Date(now);
    nextRun.setHours(hour, minute, 0, 0);

    // If the time has already passed today, schedule for tomorrow
    if (nextRun <= now) {
      nextRun.setDate(nextRun.getDate() + 1);
    }

    return nextRun;
  } else {
    const { weekday, hour, minute } = schedule.weekly;
    const nextRun = new Date(now);
    nextRun.setHours(hour, minute, 0, 0);

    // Get current day of week (0=Sunday, 6=Saturday)
    const currentDay = nextRun.getDay();
    // Convert to Cronos format (1=Sunday, 7=Saturday)
    const targetDay = weekday - 1; // Convert back to JS format

    let daysUntilTarget = targetDay - currentDay;
    if (daysUntilTarget < 0) {
      daysUntilTarget += 7;
    } else if (daysUntilTarget === 0 && nextRun <= now) {
      daysUntilTarget = 7;
    }

    nextRun.setDate(nextRun.getDate() + daysUntilTarget);
    return nextRun;
  }
}

export function getEffectiveCommand(job: Job): string {
  if (job.jobType === "claude") {
    const prompt = job.claudePrompt ?? "";
    const escapedPrompt = prompt.replace(/'/g, "'\\''");
    let cmd = `claude -p '${escapedPrompt}'`;
    if (job.contextDirectory && job.contextDirectory.length > 0) {
      const escapedDir = job.contextDirectory.replace(/'/g, "'\\''");
      cmd += ` '${escapedDir}'`;
    }
    return cmd;
  }
  return job.command;
}

export function formatDuration(seconds: number): string {
  if (seconds < 1) {
    return "<1s";
  } else if (seconds < 60) {
    return `${Math.floor(seconds)}s`;
  } else if (seconds < 3600) {
    const minutes = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${minutes}m ${secs}s`;
  } else {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    return `${hours}h ${minutes}m`;
  }
}
