# Claude Code Guidance

`AGENTS.md` is the canonical repository guide for every coding agent, including Claude Code. Read it before acting.

<!-- Claude Code inlines the canonical rules from AGENTS.md here. -->
@AGENTS.md

## Herdr

Herdr orchestration is optional. If `HERDR_ENV` is not `1` or no Herdr session is active, ignore the herdr workflow and execute the task directly. If an orchestrator prompted this pane, execute the assigned task and do not delegate further. Orchestrators follow the discovery, self-contained dispatch, monitoring, and concurrency rules in [AGENTS.md](AGENTS.md#optional-herdr-orchestration).
