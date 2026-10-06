// graphify OpenCode plugin (V2)
// Injects a knowledge graph reminder before the first shell command when the graph exists.
//
// IMPORTANT: keep the reminder string free of backticks and $(...) constructs.
// The hook prepends `echo "<reminder>" ; <cmd>` to the shell command; backticks
// inside the double-quoted echo trigger bash command substitution, which both
// corrupts tool output and silently executes the very graphify command we are
// only suggesting. Plain words render fine in opencode's TUI.
import { existsSync } from "fs";
import { join } from "path";

export default {
  id: "graphify",
  async setup(ctx) {
    let reminded = false;

    await ctx.shell.hook("create.before", (event) => {
      if (reminded) return;
      if (!existsSync(join(ctx.location.directory, "graphify-out", "graph.json"))) return;

      // ';' not '&&' — Windows PowerShell 5.1 rejects '&&' as a statement
      // separator, breaking the first shell command of the session (#1646).
      event.command =
        'echo "[graphify] knowledge graph at graphify-out/. For focused questions, run graphify query with your question (scoped subgraph, usually much smaller than GRAPH_REPORT.md) instead of grepping raw files. Read GRAPH_REPORT.md only for broad architecture context." ; ' +
        event.command;
      reminded = true;
    });
  },
};
