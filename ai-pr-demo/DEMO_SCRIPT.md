# Demo script: AI-driven Terraform updates from Turbonomic actions

A recordable walkthrough of `ai-pr-demo/`, following IBM's
["Automate Terraform updates from Turbonomic actions with AI"](https://developer.ibm.com/tutorials/automating-terraform-updates-from-turbonomic-actions-with-ai/)
tutorial, with Claude Code standing in for IBM Bob Shell as the AI agent.

Runtime: ~4-6 minutes. Two variants are below:

- **Variant A (recommended for recording): supervised live agent.** You (or
  whoever is driving) ask Claude Code directly to process the action. Every
  edit, branch, commit, push, and PR creation happens as a visible,
  narratable tool call — nothing runs unattended in the background. This is
  what was validated end-to-end while building this demo.
- **Variant B: the real unattended webhook service.** Shows the
  `webhook-service/` actually receiving a POST and spawning a headless
  `claude` CLI process on its own. More faithful to the original tutorial's
  architecture, but it runs as a background daemon with full bypass
  permissions, so only do this outside of a sandboxed Claude Code session
  (e.g. on your own machine or a disposable VM), and only against a
  throwaway/demo repo.

---

## Pre-recording checklist

- [ ] Clean git state: `git status` on your working branch shows nothing
      pending.
- [ ] Have two browser tabs ready: the repo's file view (to show
      `ai-pr-demo/terraform/main.tf`) and a blank tab for the PR that will
      be created.
- [ ] Decide on an action id for this take so the branch name is unique,
      e.g. the current timestamp: `date +%s`. Variant A below uses
      `ACTION_ID` as a placeholder — swap in a real value, or ask Claude to
      pick one.
- [ ] If re-recording a previous take, close/merge the prior demo PR and
      delete its branch first so the story stays clean (optional —
      branch names won't collide as long as each take uses a new id).

---

## Variant A — supervised live agent (what to record)

### Scene 1 — the problem (30s)

Show `ai-pr-demo/terraform/main.tf` on screen.

> "This EC2 instance is managed by Terraform, with its instance type
> hardcoded as `t3.small`. Turbonomic is watching this VM and just
> recommended resizing it down to `t3.micro` because it's under-utilized —
> real savings. The problem: approving that in Turbonomic changes the
> *running* infrastructure, but this Terraform file doesn't know anything
> changed. The next `terraform apply` would silently undo the savings."

### Scene 2 — the trigger (20s)

Show `ai-pr-demo/sample-payloads/scale-action.json` on screen.

> "In production, Turbonomic's webhook would POST this JSON — the action
> type, the target VM, its current and recommended instance type, and why —
> straight to our AI agent. For this demo, I'm handing Claude Code that
> same payload directly."

### Scene 3 — the agent does the work (2-3 min, the core of the demo)

Say this to Claude Code (verbatim, on camera):

```
A Turbonomic optimization action was just triggered. The action payload is
at ai-pr-demo/sample-payloads/scale-action.json. Read it, find the matching
Terraform resource in ai-pr-demo/terraform/main.tf, update it to the
recommended instance type, then create a new branch named
turbonomic-action-<the action's uuid or a timestamp>, commit the change
with a descriptive message referencing the action, push it, and open a
GitHub pull request explaining what Turbonomic recommended and why. Base
the PR on claude/loving-bell-7v2r39 (or whatever branch currently holds
ai-pr-demo/ on GitHub). Don't merge it.
```

Narrate as Claude works through it — this mirrors exactly what happened
when this demo was built:

1. Reads the payload → identifies `exampleVirtualMachine`,
   `t3.small` → `t3.micro`.
2. Finds `aws_instance.turbonomic_managed_vm` in `main.tf` (matches by the
   `Name` tag).
3. Edits the file.
4. `git checkout -b turbonomic-action-<id>`
5. `git commit` with a message citing the action.
6. `git push`
7. Opens the PR with a description that includes the action id, the
   resize, the reason, and the diff.

> "Nothing here is scripted — Claude read the raw action JSON, matched it
> to the right Terraform resource, made the edit, and opened a PR with a
> human-readable explanation. A developer reviews this PR like any other
> change — nothing merges automatically."

### Scene 4 — the result (30s)

Switch to the browser tab, open the new PR.

> "Here's the pull request: title, description with the Turbonomic action
> details and the reasoning, and a one-line diff changing `t3.small` to
> `t3.micro`. This goes through your normal review process — merge it, and
> the next `terraform apply` keeps the optimization instead of reverting
> it."

### Scene 5 — wrap-up (15s)

> "That's the loop: Turbonomic finds the optimization, approving it changes
> the infrastructure, and this AI step keeps the Terraform code — and your
> Git history — in sync, with a human still reviewing every change."

---

## Variant B — the real webhook service (optional, off-session)

Run this only on a machine/session where you can supervise or explicitly
approve a background process invoking `claude --permission-mode
bypassPermissions`:

```bash
cd ai-pr-demo/webhook-service
npm install
REPO_ROOT=/path/to/your/clone/of/TF-Turbonomic PORT=4000 npm start
```

In another terminal:

```bash
cd ai-pr-demo
bash simulate.sh
```

Narrate the `webhook-service` logs as they print: the raw payload arriving,
then Claude Code starting up headlessly and performing the same edit →
branch → commit → push → PR sequence as Variant A, but fully unattended.

---

## Cleanup after recording

```bash
# delete the local demo branch
git branch -D turbonomic-action-<id>
# delete the remote demo branch (also closes the PR as "closed", not merged,
# unless you merge it first)
git push origin --delete turbonomic-action-<id>
```

Then close or merge the pull request in the GitHub UI. If you want the next
take to start from the same clean "before" state, make sure
`ai-pr-demo/terraform/main.tf` on your working branch still has
`instance_type = "t3.small"` — it will, as long as you never merged a demo
PR into that branch.

## If something goes wrong on camera

- **Claude can't find the matching resource:** the prompt tells it to stop
  and explain rather than guess — that's a feature, not a bug, and makes a
  good talking point about safety.
- **Branch name collision** (re-running with the same id): use a fresh
  timestamp, e.g. `date +%s`, for each take.
- **Push rejected (no GitHub access):** reconnect GitHub at
  https://claude.ai/connect-github — see the main `ai-pr-demo/README.md`
  Security notes for why this is gated at all.
