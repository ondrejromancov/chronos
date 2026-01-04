import { Action, ActionPanel, Color, Detail, Icon, List } from "@raycast/api";
import { usePromise } from "@raycast/utils";
import { getRunsForJob, readLogContent } from "./lib/cronos";
import { Job, LogRun, formatDuration } from "./lib/types";

interface JobLogsViewProps {
  job: Job;
}

export default function JobLogsView({ job }: JobLogsViewProps) {
  const { data: runs, isLoading } = usePromise(async () => {
    return getRunsForJob(job.id);
  });

  const getStatusIcon = (run: LogRun): { source: Icon; tintColor: Color } => {
    if (!run.endedAt) {
      return { source: Icon.CircleProgress, tintColor: Color.Blue };
    }
    if (run.success) {
      return { source: Icon.CheckCircle, tintColor: Color.Green };
    }
    return { source: Icon.XMarkCircle, tintColor: Color.Red };
  };

  const formatDate = (dateString: string): string => {
    const date = new Date(dateString);
    return date.toLocaleString();
  };

  const getDuration = (run: LogRun): string => {
    if (!run.endedAt) {
      return "Running...";
    }
    const start = new Date(run.startedAt).getTime();
    const end = new Date(run.endedAt).getTime();
    const seconds = (end - start) / 1000;
    return formatDuration(seconds);
  };

  return (
    <List
      isLoading={isLoading}
      navigationTitle={`Logs: ${job.name}`}
      searchBarPlaceholder="Search runs..."
    >
      {runs?.length === 0 && !isLoading ? (
        <List.EmptyView
          title="No Runs Found"
          description="This job hasn't been executed yet"
          icon={Icon.Document}
        />
      ) : (
        runs?.map((run) => (
          <List.Item
            key={run.id}
            title={formatDate(run.startedAt)}
            subtitle={getDuration(run)}
            icon={getStatusIcon(run)}
            accessories={[
              run.exitCode !== undefined
                ? { text: `Exit: ${run.exitCode}` }
                : {},
              {
                tag: run.success
                  ? "Success"
                  : run.endedAt
                    ? "Failed"
                    : "Running",
              },
            ]}
            actions={
              <ActionPanel>
                <Action.Push
                  title="View Output"
                  icon={Icon.Eye}
                  target={<RunDetailView run={run} jobName={job.name} />}
                />
                <Action.CopyToClipboard
                  title="Copy Run Id"
                  content={run.id}
                  shortcut={{ modifiers: ["cmd"], key: "c" }}
                />
              </ActionPanel>
            }
          />
        ))
      )}
    </List>
  );
}

interface RunDetailViewProps {
  run: LogRun;
  jobName: string;
}

function RunDetailView({ run, jobName }: RunDetailViewProps) {
  const { data: logContent, isLoading } = usePromise(async () => {
    return readLogContent(run.id);
  });

  const formatDate = (dateString: string): string => {
    const date = new Date(dateString);
    return date.toLocaleString();
  };

  const getDuration = (): string => {
    if (!run.endedAt) {
      return "Running...";
    }
    const start = new Date(run.startedAt).getTime();
    const end = new Date(run.endedAt).getTime();
    const seconds = (end - start) / 1000;
    return formatDuration(seconds);
  };

  const markdown = `
# Run Details

**Job:** ${jobName}
**Started:** ${formatDate(run.startedAt)}
**Ended:** ${run.endedAt ? formatDate(run.endedAt) : "Still running..."}
**Duration:** ${getDuration()}
**Exit Code:** ${run.exitCode ?? "N/A"}
**Status:** ${run.success ? "Success" : run.endedAt ? "Failed" : "Running"}

---

## Standard Output

\`\`\`
${logContent?.stdout || "(empty)"}
\`\`\`

${logContent?.stderr ? `## Standard Error\n\n\`\`\`\n${logContent.stderr}\n\`\`\`` : ""}
`;

  return (
    <Detail
      isLoading={isLoading}
      markdown={markdown}
      navigationTitle={`Run: ${formatDate(run.startedAt)}`}
      actions={
        <ActionPanel>
          {logContent?.stdout && (
            <Action.CopyToClipboard
              title="Copy Stdout"
              content={logContent.stdout}
              shortcut={{ modifiers: ["cmd"], key: "c" }}
            />
          )}
          {logContent?.stderr && (
            <Action.CopyToClipboard
              title="Copy Stderr"
              content={logContent.stderr}
              shortcut={{ modifiers: ["cmd", "shift"], key: "c" }}
            />
          )}
        </ActionPanel>
      }
    />
  );
}
