# Cloom Logs

Stream or stop streaming `os_log` output from the Cloom app to a temporary log file for debugging.

## How to use

- `/logs` or `/logs on` — Start streaming logs to `/tmp/cloom-logs/cloom.log`
- `/logs off` — Stop streaming and show a summary of the last log entries
- `/logs read` — Read the current log file contents (tail)
- `/logs clear` — Clear the log file

## Implementation

Run the log streaming script:

```bash
.claude/skills/logs/logs.sh <on|off|read|clear>
```

## After running

- **on**: Confirm logs are streaming and remind the user to reproduce the issue
- **off**: Show the last 20 lines of the log file, then stop the stream
- **read**: Show the last 50 lines of the log file and analyze for errors/warnings
- **clear**: Confirm the log file was cleared
