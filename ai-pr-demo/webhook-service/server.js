const express = require("express");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawn } = require("child_process");

const PORT = process.env.PORT || 4000;
// Path to a local clone of this repository that the `claude` CLI will operate
// on: read the Terraform code, edit it, commit, push, and open a PR. It must
// already have git remotes + credentials (SSH key or PAT) configured so
// Claude Code can push and use `gh`/the GitHub API without prompting.
const REPO_ROOT = process.env.REPO_ROOT || path.resolve(__dirname, "..", "..");
// Optional shared secret. If set, requests must send it as
// `x-webhook-secret`. Turbonomic's webhook workflow can send a custom header
// via Basic Authentication or an extra header field - see the demo README.
const WEBHOOK_SECRET = process.env.WEBHOOK_SECRET || "";
const CLAUDE_TIMEOUT_MS = Number(process.env.CLAUDE_TIMEOUT_MS || 5 * 60 * 1000);

const app = express();
app.use(express.json({ limit: "2mb" }));

app.post("/webhook", (req, res) => {
  if (WEBHOOK_SECRET && req.get("x-webhook-secret") !== WEBHOOK_SECRET) {
    return res.status(401).send("unauthorized");
  }

  const payload = req.body;
  console.log(`[webhook] received Turbonomic action payload:\n${JSON.stringify(payload, null, 2)}`);

  const payloadPath = path.join(os.tmpdir(), `turbonomic-action-${Date.now()}.json`);
  fs.writeFileSync(payloadPath, JSON.stringify(payload, null, 2));

  const prompt = buildPrompt(payloadPath);
  runClaude(prompt)
    .then((output) => {
      console.log("[claude] finished:\n", output);
    })
    .catch((err) => {
      console.error("[claude] failed:", err);
    });

  // Acknowledge the webhook immediately; Claude Code keeps running in the
  // background and will push a branch + open a PR when it's done.
  res.status(202).json({ status: "accepted" });
});

function buildPrompt(payloadPath) {
  return `You are the automated Terraform-update assistant in a Turbonomic optimization workflow.

A Turbonomic optimization action was just triggered. The raw action payload
(Turbonomic ActionApiDTO JSON) is saved at: ${payloadPath}

Do the following:
1. Read that JSON file and identify: the target entity, its current
   configuration, and the recommended new configuration (e.g. a new
   instance/machine type).
2. In this repository, find the Terraform resource that manages that entity.
   Start by looking in ai-pr-demo/terraform/main.tf.
3. Update the Terraform code so the resource's configuration matches the
   recommended value. Do not touch unrelated files.
4. Create a new git branch named turbonomic-action-<a short id or timestamp>.
5. Commit the change with a descriptive commit message referencing the
   Turbonomic action (entity, old value, new value, reason).
6. Push the branch to the 'origin' remote.
7. Open a GitHub pull request from that branch. In the PR description,
   explain what Turbonomic recommended, why, and exactly what changed in the
   Terraform code. Do not merge the pull request.

If you cannot confidently determine the correct Terraform resource or value
from the payload, stop and explain why instead of guessing.`;
}

function runClaude(prompt) {
  return new Promise((resolve, reject) => {
    const child = spawn(
      "claude",
      ["-p", prompt, "--permission-mode", "bypassPermissions"],
      { cwd: REPO_ROOT }
    );

    let stdout = "";
    let stderr = "";
    const timer = setTimeout(() => {
      child.kill("SIGTERM");
      reject(new Error(`claude CLI timed out after ${CLAUDE_TIMEOUT_MS}ms`));
    }, CLAUDE_TIMEOUT_MS);

    child.stdout.on("data", (d) => (stdout += d.toString()));
    child.stderr.on("data", (d) => (stderr += d.toString()));
    child.on("error", (err) => {
      clearTimeout(timer);
      reject(err);
    });
    child.on("close", (code) => {
      clearTimeout(timer);
      if (code === 0) resolve(stdout);
      else reject(new Error(`claude CLI exited with code ${code}\n${stderr}`));
    });
  });
}

app.listen(PORT, () => {
  console.log(`Turbonomic AI->PR webhook service listening on :${PORT}`);
  console.log(`Operating on repo: ${REPO_ROOT}`);
});
