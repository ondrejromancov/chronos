import {
  Action,
  ActionPanel,
  Alert,
  Color,
  confirmAlert,
  Icon,
  List,
  showToast,
  Toast,
  open,
} from "@raycast/api";
import { usePromise } from "@raycast/utils";
import { useState, useCallback } from "react";
import {
  loadJobs,
  toggleJob,
  deleteJob,
  isCronosInstalled,
  createRun,
  completeRun,
  writeLogContent,
  updateJobLastRun,
} from "./lib/cronos";
import {
  Job,
  getScheduleDisplayString,
  getNextRunDate,
  getEffectiveCommand,
} from "./lib/types";
import JobLogsView from "./job-logs";
import CreateJob from "./create-job";

export default function ListJobs() {
  const [searchText, setSearchText] = useState("");
  const [runningJobs, setRunningJobs] = useState<Set<string>>(new Set());

  const {
    data: jobs,
    isLoading,
    revalidate,
  } = usePromise(async () => {
    const installed = await isCronosInstalled();
    if (!installed) {
      throw new Error(
        "Cronos is not installed. Please install the Cronos app first.",
      );
    }
    return loadJobs();
  });

  const filteredJobs = jobs?.filter((job) => {
    if (!searchText) return true;
    const query = searchText.toLowerCase();
    return (
      job.name.toLowerCase().includes(query) ||
      job.command.toLowerCase().includes(query) ||
      (job.claudePrompt ?? "").toLowerCase().includes(query)
    );
  });

  const handleToggle = useCallback(
    async (job: Job) => {
      try {
        await toggleJob(job.id);
        await showToast({
          style: Toast.Style.Success,
          title: job.isEnabled ? "Job Disabled" : "Job Enabled",
          message: job.name,
        });
        revalidate();
      } catch (error) {
        await showToast({
          style: Toast.Style.Failure,
          title: "Failed to toggle job",
          message: String(error),
        });
      }
    },
    [revalidate],
  );

  const handleDelete = useCallback(
    async (job: Job) => {
      const confirmed = await confirmAlert({
        title: "Delete Job",
        message: `Are you sure you want to delete "${job.name}"? This will also delete all log history.`,
        primaryAction: {
          title: "Delete",
          style: Alert.ActionStyle.Destructive,
        },
      });

      if (confirmed) {
        try {
          await deleteJob(job.id);
          await showToast({
            style: Toast.Style.Success,
            title: "Job Deleted",
            message: job.name,
          });
          revalidate();
        } catch (error) {
          await showToast({
            style: Toast.Style.Failure,
            title: "Failed to delete job",
            message: String(error),
          });
        }
      }
    },
    [revalidate],
  );

  const handleRunNow = useCallback(
    async (job: Job) => {
      if (runningJobs.has(job.id)) {
        await showToast({
          style: Toast.Style.Animated,
          title: "Job Already Running",
          message: job.name,
        });
        return;
      }

      setRunningJobs((prev) => new Set(prev).add(job.id));

      const toast = await showToast({
        style: Toast.Style.Animated,
        title: "Running Job",
        message: job.name,
      });

      try {
        // Create a run record
        const run = await createRun(job.id);

        // Execute the command
        const command = getEffectiveCommand(job);
        const { execSync } = await import("child_process");

        let stdout = "";
        let stderr = "";
        let exitCode = 0;
        let success = true;

        try {
          const result = execSync(command, {
            cwd: job.workingDirectory.replace(/^~/, process.env.HOME || ""),
            encoding: "utf-8",
            shell: "/bin/zsh",
            maxBuffer: 10 * 1024 * 1024, // 10MB
            timeout: 5 * 60 * 1000, // 5 minutes
          });
          stdout = result;
        } catch (error: unknown) {
          const execError = error as {
            status?: number;
            stdout?: string;
            stderr?: string;
          };
          exitCode = execError.status ?? 1;
          stdout = execError.stdout ?? "";
          stderr = execError.stderr ?? "";
          success = false;
        }

        // Write log files
        await writeLogContent(run.id, stdout, stderr);

        // Complete the run
        await completeRun(run.id, exitCode, success);

        // Update job's lastRun info
        await updateJobLastRun(job.id, success);

        if (success) {
          toast.style = Toast.Style.Success;
          toast.title = "Job Completed";
          toast.message = job.name;
        } else {
          toast.style = Toast.Style.Failure;
          toast.title = "Job Failed";
          toast.message = `${job.name} (exit code: ${exitCode})`;
        }

        revalidate();
      } catch (error) {
        toast.style = Toast.Style.Failure;
        toast.title = "Failed to run job";
        toast.message = String(error);
      } finally {
        setRunningJobs((prev) => {
          const next = new Set(prev);
          next.delete(job.id);
          return next;
        });
      }
    },
    [runningJobs, revalidate],
  );

  const getStatusIcon = (job: Job): { source: Icon; tintColor: Color } => {
    if (runningJobs.has(job.id)) {
      return { source: Icon.CircleProgress, tintColor: Color.Blue };
    }
    if (!job.isEnabled) {
      return { source: Icon.CircleDisabled, tintColor: Color.SecondaryText };
    }
    if (job.lastRunSuccessful === false) {
      return { source: Icon.XMarkCircle, tintColor: Color.Red };
    }
    if (job.lastRunSuccessful === true) {
      return { source: Icon.CheckCircle, tintColor: Color.Green };
    }
    return { source: Icon.Circle, tintColor: Color.SecondaryText };
  };

  const getAccessories = (job: Job): List.Item.Accessory[] => {
    const accessories: List.Item.Accessory[] = [];

    // Schedule
    accessories.push({
      text: getScheduleDisplayString(job.schedule),
      icon: Icon.Clock,
    });

    // Next run
    if (job.isEnabled) {
      const nextRun = getNextRunDate(job.schedule);
      const now = new Date();
      const diffMs = nextRun.getTime() - now.getTime();
      const diffMins = Math.round(diffMs / 60000);

      let nextRunText: string;
      if (diffMins < 60) {
        nextRunText = `in ${diffMins}m`;
      } else if (diffMins < 1440) {
        nextRunText = `in ${Math.round(diffMins / 60)}h`;
      } else {
        nextRunText = `in ${Math.round(diffMins / 1440)}d`;
      }

      accessories.push({
        text: nextRunText,
        icon: Icon.Calendar,
      });
    }

    // Job type
    accessories.push({
      tag: job.jobType === "claude" ? "Claude" : "Custom",
    });

    return accessories;
  };

  return (
    <List
      isLoading={isLoading}
      searchText={searchText}
      onSearchTextChange={setSearchText}
      searchBarPlaceholder="Search jobs..."
    >
      {filteredJobs?.length === 0 && !isLoading ? (
        <List.EmptyView
          title="No Jobs Found"
          description={
            searchText
              ? "Try a different search term"
              : "Create a job to get started"
          }
          actions={
            <ActionPanel>
              <Action.Push
                title="Create Job"
                icon={Icon.Plus}
                target={<CreateJob />}
              />
              <Action
                title="Open Cronos"
                icon={Icon.AppWindow}
                onAction={() => open("cronos://")}
              />
            </ActionPanel>
          }
        />
      ) : (
        filteredJobs?.map((job) => (
          <List.Item
            key={job.id}
            title={job.name}
            subtitle={
              job.jobType === "claude"
                ? job.claudePrompt?.slice(0, 50)
                : job.command.slice(0, 50)
            }
            icon={getStatusIcon(job)}
            accessories={getAccessories(job)}
            actions={
              <ActionPanel>
                <ActionPanel.Section>
                  <Action
                    title="Run Now"
                    icon={Icon.Play}
                    shortcut={{ modifiers: ["cmd"], key: "r" }}
                    onAction={() => handleRunNow(job)}
                  />
                  <Action.Push
                    title="View Logs"
                    icon={Icon.Document}
                    shortcut={{ modifiers: ["cmd"], key: "l" }}
                    target={<JobLogsView job={job} />}
                  />
                </ActionPanel.Section>
                <ActionPanel.Section>
                  <Action
                    title={job.isEnabled ? "Disable Job" : "Enable Job"}
                    icon={job.isEnabled ? Icon.Pause : Icon.Play}
                    shortcut={{ modifiers: ["cmd"], key: "e" }}
                    onAction={() => handleToggle(job)}
                  />
                  <Action.Push
                    title="Create Job"
                    icon={Icon.Plus}
                    target={<CreateJob />}
                  />
                </ActionPanel.Section>
                <ActionPanel.Section>
                  <Action
                    title="Delete Job"
                    icon={Icon.Trash}
                    style={Action.Style.Destructive}
                    shortcut={{ modifiers: ["cmd"], key: "backspace" }}
                    onAction={() => handleDelete(job)}
                  />
                </ActionPanel.Section>
                <ActionPanel.Section>
                  <Action
                    title="Open Cronos"
                    icon={Icon.AppWindow}
                    onAction={() => open("cronos://")}
                  />
                  <Action
                    title="Refresh"
                    icon={Icon.ArrowClockwise}
                    shortcut={{ modifiers: ["cmd"], key: "shift+r" }}
                    onAction={revalidate}
                  />
                </ActionPanel.Section>
              </ActionPanel>
            }
          />
        ))
      )}
    </List>
  );
}
