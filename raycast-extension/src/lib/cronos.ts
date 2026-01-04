import { homedir } from "os";
import { readFile, writeFile, mkdir, access, stat } from "fs/promises";
import { constants } from "fs";
import { join } from "path";
import { Job, LogRun } from "./types";
import { randomUUID } from "crypto";

// Cronos directory paths
const CRONOS_DIR = join(homedir(), ".cronos");
const JOBS_FILE = join(CRONOS_DIR, "jobs.json");
const LOGS_DIR = join(CRONOS_DIR, "logs");
const RUNS_DIR = join(LOGS_DIR, "runs");
const LOGS_INDEX_FILE = join(LOGS_DIR, "index.json");

// Check if Cronos directory exists
export async function isCronosInstalled(): Promise<boolean> {
  try {
    await access(CRONOS_DIR, constants.R_OK);
    return true;
  } catch {
    return false;
  }
}

// Ensure all required directories exist
async function ensureDirectoriesExist(): Promise<void> {
  await mkdir(CRONOS_DIR, { recursive: true });
  await mkdir(LOGS_DIR, { recursive: true });
  await mkdir(RUNS_DIR, { recursive: true });
}

// Get the modification time of the jobs file
export async function getJobsFileModTime(): Promise<number> {
  try {
    const stats = await stat(JOBS_FILE);
    return stats.mtimeMs;
  } catch {
    return 0;
  }
}

// Load all jobs from disk
export async function loadJobs(): Promise<Job[]> {
  try {
    const data = await readFile(JOBS_FILE, "utf-8");
    return JSON.parse(data) as Job[];
  } catch {
    return [];
  }
}

// Save all jobs to disk
export async function saveJobs(jobs: Job[]): Promise<void> {
  await ensureDirectoriesExist();
  const data = JSON.stringify(jobs, null, 2);
  await writeFile(JOBS_FILE, data, "utf-8");
}

// Add a new job
export async function addJob(job: Omit<Job, "id">): Promise<Job> {
  const jobs = await loadJobs();
  const newJob: Job = {
    ...job,
    id: randomUUID(),
  };
  jobs.push(newJob);
  await saveJobs(jobs);
  return newJob;
}

// Update an existing job
export async function updateJob(job: Job): Promise<void> {
  const jobs = await loadJobs();
  const index = jobs.findIndex((j) => j.id === job.id);
  if (index >= 0) {
    jobs[index] = job;
    await saveJobs(jobs);
  }
}

// Delete a job
export async function deleteJob(jobId: string): Promise<void> {
  const jobs = await loadJobs();
  const filteredJobs = jobs.filter((j) => j.id !== jobId);
  await saveJobs(filteredJobs);

  // Also delete associated log runs
  await deleteRunsForJob(jobId);
}

// Toggle job enabled status
export async function toggleJob(jobId: string): Promise<Job | undefined> {
  const jobs = await loadJobs();
  const job = jobs.find((j) => j.id === jobId);
  if (job) {
    job.isEnabled = !job.isEnabled;
    await saveJobs(jobs);
    return job;
  }
  return undefined;
}

// Load all log runs from the index
export async function loadLogsIndex(): Promise<LogRun[]> {
  try {
    const data = await readFile(LOGS_INDEX_FILE, "utf-8");
    return JSON.parse(data) as LogRun[];
  } catch {
    return [];
  }
}

// Save all log runs to the index
async function saveLogsIndex(runs: LogRun[]): Promise<void> {
  await ensureDirectoriesExist();
  const data = JSON.stringify(runs, null, 2);
  await writeFile(LOGS_INDEX_FILE, data, "utf-8");
}

// Get log runs for a specific job (newest first)
export async function getRunsForJob(jobId: string): Promise<LogRun[]> {
  const runs = await loadLogsIndex();
  return runs
    .filter((r) => r.jobId === jobId)
    .sort(
      (a, b) =>
        new Date(b.startedAt).getTime() - new Date(a.startedAt).getTime(),
    );
}

// Create a new run entry (called before executing a job)
export async function createRun(jobId: string): Promise<LogRun> {
  const runs = await loadLogsIndex();
  const run: LogRun = {
    id: randomUUID(),
    jobId,
    startedAt: new Date().toISOString(),
  };
  runs.push(run);
  await saveLogsIndex(runs);
  return run;
}

// Complete a run (called after job execution finishes)
export async function completeRun(
  runId: string,
  exitCode: number,
  success: boolean,
): Promise<void> {
  const runs = await loadLogsIndex();
  const run = runs.find((r) => r.id === runId);
  if (run) {
    run.endedAt = new Date().toISOString();
    run.exitCode = exitCode;
    run.success = success;
    await saveLogsIndex(runs);
  }
}

// Update job's lastRun info after execution
export async function updateJobLastRun(
  jobId: string,
  success: boolean,
): Promise<void> {
  const jobs = await loadJobs();
  const job = jobs.find((j) => j.id === jobId);
  if (job) {
    job.lastRun = new Date().toISOString();
    job.lastRunSuccessful = success;
    await saveJobs(jobs);
  }
}

// Get log file paths for a run
function getLogFilePaths(runId: string): { stdout: string; stderr: string } {
  return {
    stdout: join(RUNS_DIR, `${runId}.stdout`),
    stderr: join(RUNS_DIR, `${runId}.stderr`),
  };
}

// Read log content for a specific run
export async function readLogContent(
  runId: string,
): Promise<{ stdout: string; stderr: string }> {
  const paths = getLogFilePaths(runId);
  let stdout = "";
  let stderr = "";

  try {
    stdout = await readFile(paths.stdout, "utf-8");
  } catch {
    // File might not exist
  }

  try {
    stderr = await readFile(paths.stderr, "utf-8");
  } catch {
    // File might not exist
  }

  return { stdout, stderr };
}

// Write log content for a run (used when running jobs from Raycast)
export async function writeLogContent(
  runId: string,
  stdout: string,
  stderr: string,
): Promise<void> {
  await ensureDirectoriesExist();
  const paths = getLogFilePaths(runId);
  await writeFile(paths.stdout, stdout, "utf-8");
  await writeFile(paths.stderr, stderr, "utf-8");
}

// Delete all runs for a job
async function deleteRunsForJob(jobId: string): Promise<void> {
  const runs = await loadLogsIndex();
  const jobRuns = runs.filter((r) => r.jobId === jobId);

  // Delete log files
  for (const run of jobRuns) {
    const paths = getLogFilePaths(run.id);
    try {
      const { unlink } = await import("fs/promises");
      await unlink(paths.stdout);
    } catch {
      // Ignore
    }
    try {
      const { unlink } = await import("fs/promises");
      await unlink(paths.stderr);
    } catch {
      // Ignore
    }
  }

  // Remove from index
  const filteredRuns = runs.filter((r) => r.jobId !== jobId);
  await saveLogsIndex(filteredRuns);
}

// Export paths for external use
export const PATHS = {
  CRONOS_DIR,
  JOBS_FILE,
  LOGS_DIR,
  RUNS_DIR,
  LOGS_INDEX_FILE,
};
