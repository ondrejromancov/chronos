import {
  Action,
  ActionPanel,
  Form,
  showToast,
  Toast,
  useNavigation,
  Icon,
} from "@raycast/api";
import { useState } from "react";
import { addJob } from "./lib/cronos";
import { Job, JobType, Schedule } from "./lib/types";
import { homedir } from "os";

type ScheduleType = "daily" | "weekly";

const WEEKDAYS = [
  { value: "1", title: "Sunday" },
  { value: "2", title: "Monday" },
  { value: "3", title: "Tuesday" },
  { value: "4", title: "Wednesday" },
  { value: "5", title: "Thursday" },
  { value: "6", title: "Friday" },
  { value: "7", title: "Saturday" },
];

const HOURS = Array.from({ length: 24 }, (_, i) => ({
  value: String(i),
  title: `${i}:00`,
}));

const MINUTES = Array.from({ length: 60 }, (_, i) => ({
  value: String(i),
  title: i.toString().padStart(2, "0"),
}));

export default function CreateJob() {
  const { pop } = useNavigation();

  const [jobType, setJobType] = useState<JobType>("claude");
  const [scheduleType, setScheduleType] = useState<ScheduleType>("daily");
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Form errors
  const [nameError, setNameError] = useState<string>();
  const [promptError, setPromptError] = useState<string>();
  const [commandError, setCommandError] = useState<string>();

  async function handleSubmit(values: {
    name: string;
    jobType: string;
    claudePrompt?: string;
    contextDirectory?: string[];
    command?: string;
    workingDirectory: string[];
    scheduleType: string;
    hour: string;
    minute: string;
    weekday?: string;
  }) {
    // Validate
    if (!values.name.trim()) {
      setNameError("Name is required");
      return;
    }

    if (values.jobType === "claude" && !values.claudePrompt?.trim()) {
      setPromptError("Prompt is required for Claude jobs");
      return;
    }

    if (values.jobType === "customCommand" && !values.command?.trim()) {
      setCommandError("Command is required for custom jobs");
      return;
    }

    setIsSubmitting(true);

    try {
      // Build schedule
      const hour = parseInt(values.hour, 10);
      const minute = parseInt(values.minute, 10);
      let schedule: Schedule;

      if (values.scheduleType === "daily") {
        schedule = { daily: { hour, minute } };
      } else {
        const weekday = parseInt(values.weekday || "2", 10);
        schedule = { weekly: { weekday, hour, minute } };
      }

      // Build job
      const jobData: Omit<Job, "id"> = {
        name: values.name.trim(),
        command: values.command?.trim() || "",
        workingDirectory: values.workingDirectory?.[0] || homedir(),
        schedule,
        isEnabled: true,
        jobType: values.jobType as JobType,
        claudePrompt: values.claudePrompt?.trim(),
        contextDirectory: values.contextDirectory?.[0],
      };

      await addJob(jobData);

      await showToast({
        style: Toast.Style.Success,
        title: "Job Created",
        message: values.name,
      });

      pop();
    } catch (error) {
      await showToast({
        style: Toast.Style.Failure,
        title: "Failed to create job",
        message: String(error),
      });
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <Form
      isLoading={isSubmitting}
      actions={
        <ActionPanel>
          <Action.SubmitForm
            title="Create Job"
            icon={Icon.Plus}
            onSubmit={handleSubmit}
          />
        </ActionPanel>
      }
    >
      <Form.TextField
        id="name"
        title="Name"
        placeholder="My Scheduled Job"
        error={nameError}
        onChange={() => setNameError(undefined)}
      />

      <Form.Dropdown
        id="jobType"
        title="Job Type"
        value={jobType}
        onChange={(v) => setJobType(v as JobType)}
      >
        <Form.Dropdown.Item value="claude" title="Claude" icon={Icon.Stars} />
        <Form.Dropdown.Item
          value="customCommand"
          title="Custom Command"
          icon={Icon.Terminal}
        />
      </Form.Dropdown>

      <Form.Separator />

      {jobType === "claude" ? (
        <>
          <Form.TextArea
            id="claudePrompt"
            title="Prompt"
            placeholder="Enter the prompt for Claude..."
            error={promptError}
            onChange={() => setPromptError(undefined)}
          />
          <Form.FilePicker
            id="contextDirectory"
            title="Context Directory"
            allowMultipleSelection={false}
            canChooseDirectories={true}
            canChooseFiles={false}
            info="Optional directory to provide as context to Claude"
          />
        </>
      ) : (
        <Form.TextArea
          id="command"
          title="Command"
          placeholder="echo 'Hello, World!'"
          error={commandError}
          onChange={() => setCommandError(undefined)}
        />
      )}

      <Form.FilePicker
        id="workingDirectory"
        title="Working Directory"
        allowMultipleSelection={false}
        canChooseDirectories={true}
        canChooseFiles={false}
        defaultValue={[homedir()]}
      />

      <Form.Separator />

      <Form.Dropdown
        id="scheduleType"
        title="Schedule"
        value={scheduleType}
        onChange={(v) => setScheduleType(v as ScheduleType)}
      >
        <Form.Dropdown.Item value="daily" title="Daily" icon={Icon.Calendar} />
        <Form.Dropdown.Item
          value="weekly"
          title="Weekly"
          icon={Icon.Calendar}
        />
      </Form.Dropdown>

      {scheduleType === "weekly" && (
        <Form.Dropdown id="weekday" title="Day" defaultValue="2">
          {WEEKDAYS.map((day) => (
            <Form.Dropdown.Item
              key={day.value}
              value={day.value}
              title={day.title}
            />
          ))}
        </Form.Dropdown>
      )}

      <Form.Dropdown id="hour" title="Hour" defaultValue="9">
        {HOURS.map((h) => (
          <Form.Dropdown.Item key={h.value} value={h.value} title={h.title} />
        ))}
      </Form.Dropdown>

      <Form.Dropdown id="minute" title="Minute" defaultValue="0">
        {MINUTES.map((m) => (
          <Form.Dropdown.Item key={m.value} value={m.value} title={m.title} />
        ))}
      </Form.Dropdown>
    </Form>
  );
}
