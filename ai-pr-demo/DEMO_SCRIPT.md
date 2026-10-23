# Demo script: AI-driven Terraform updates from Turbonomic actions

A recordable walkthrough of `ai-pr-demo/`, following IBM's
["Automate Terraform updates from Turbonomic actions with AI"](https://developer.ibm.com/tutorials/automating-terraform-updates-from-turbonomic-actions-with-ai/)
tutorial, with Claude Code standing in for IBM Bob Shell as the AI agent.

Runtime: ~5-7 minutes. Two variants are below:

- **Variant A (recommended for recording): supervised live agent.** The
  story starts in the Turbonomic UI with a real pending action. You then ask
  Claude Code what Turbonomic is recommending, and it pulls the live actions
  from the Turbonomic API and processes the one you pick into a pull
  request. Every query, edit, branch, commit, push, and PR creation happens
  as a visible, narratable tool call — nothing runs unattended in the
  background.
- **Variant B: the real unattended webhook service.** Shows the
  `webhook-service/` actually receiving a POST and spawning a headless
  `claude` CLI process on its own. More faithful to the original tutorial's
  architecture, but it runs as a background daemon with full bypass
  permissions, so only do this outside of a sandboxed Claude Code session
  (e.g. on your own machine or a disposable VM), and only against a
  throwaway/demo repo.

---

## Pre-recording checklist

- [ ] The Claude Code session you record in can reach Turbonomic: run
      `bash ai-pr-demo/turbo-actions.sh` once off camera and confirm it
      lists the `exampleVirtualMachine` action (`t3.nano` → `t3a.nano`).
      In a cloud session this needs the **Body parameter** network secret
      for the Turbonomic host (parameters `username` and `password`); see
      [`README.md`](./README.md#run-the-demo-live-supervised). Delete the
      `live-payloads/` folder afterwards if you used `--save`.
- [ ] The action is still **pending** in Turbonomic. Don't execute it before
      the take — once executed it leaves the pending list and Claude won't
      find it.
- [ ] `ai-pr-demo/terraform/main.tf` on `claude/loving-bell-7v2r39` still
      has `instance_type = "t3.nano"` (it will, as long as no demo PR was
      merged into that branch).
- [ ] No leftover demo PRs or `turbonomic-action-*` branches from earlier
      takes (see Cleanup below), so the new PR is the only one.
- [ ] Browser tabs ready: Turbonomic, already showing the pending actions for
      the `Steve Weaver` AWS account (or `exampleVirtualMachine` itself);
      the repo's file view of `ai-pr-demo/terraform/main.tf`; and a blank tab
      for the PR.

---

## Variant A — supervised live agent (what to record)

### Scene 1 — Turbonomic finds the optimization (30s)

In the Turbonomic UI, open the pending actions and point at the scale action
for `exampleVirtualMachine`: **t3.nano → t3a.nano**, Efficiency Improvement,
underutilized vCPU. Don't execute it.

> "Turbonomic is continuously analysing this AWS account, and it's flagged
> `exampleVirtualMachine`: its vCPU is underutilized, so it recommends
> scaling from `t3.nano` to `t3a.nano`. I could approve this right here —
> but there's a catch."

### Scene 2 — the problem (20s)

Switch to `ai-pr-demo/terraform/main.tf`.

> "This VM is managed by Terraform, with its instance type hardcoded as
> `t3.nano`. Executing the action in Turbonomic changes the *running*
> infrastructure, but this file doesn't know anything changed. The next
> `terraform apply` would quietly undo the optimization. So let's have an AI
> agent bring the code in line."

### Scene 3 — ask Claude what Turbonomic recommends (45s)

Say this to Claude Code (verbatim, on camera):

```
Check Turbonomic for any outstanding optimization actions on my AWS account
using ai-pr-demo/turbo-actions.sh, and tell me which of them map to a
resource in ai-pr-demo/terraform/main.tf.
```

Claude logs in to the Turbonomic API, lists the pending scale actions on the
`AWS-steve-demo` target (currently six, all from the `Steve Weaver`
account), and reports that only `exampleVirtualMachine` matches a Terraform
resource (`aws_instance.turbonomic_managed_vm`, by its `Name` tag).

> "That's the same action we just saw in the Turbonomic UI, pulled live from
> the API. Turbonomic has recommendations for other VMs too, but only this
> one is managed by this Terraform code, and Claude knows to leave the rest
> alone."

### Scene 4 — Claude processes the action (2-3 min, the core of the demo)

Say this to Claude Code (verbatim, on camera):

```
Process the exampleVirtualMachine action. Save its payload with
turbo-actions.sh --save, update the matching Terraform resource in
ai-pr-demo/terraform/main.tf to the recommended instance type, then create a
new branch named turbonomic-action-<the action's uuid>, commit the change
with a descriptive message referencing the action, push it, and open a
GitHub pull request against claude/loving-bell-7v2r39 explaining what
Turbonomic recommended and why. Don't merge it.
```

Narrate as Claude works through it:

1. Runs `turbo-actions.sh --save <uuid>` → the real `ActionApiDTO` lands in
   `live-payloads/action-<uuid>.json` (git-ignored, so it isn't committed).
2. Reads it → `exampleVirtualMachine`, `t3.nano` → `t3a.nano`, underutilized
   vCPU.
3. Edits `instance_type` on `aws_instance.turbonomic_managed_vm`.
4. `git checkout -b turbonomic-action-<uuid>`
5. `git commit` with a message citing the action.
6. `git push`
7. Opens the PR with a description that includes the action id, the
   resize, the reason, and the diff.

> "Nothing here is scripted. Claude took the live action from Turbonomic,
> matched it to the right Terraform resource, made the edit, and opened a PR
> with a human-readable explanation. A developer reviews this PR like any
> other change — nothing merges automatically."

### Scene 5 — the result (30s)

Switch to the browser tab, open the new PR.

> "Here's the pull request: the Turbonomic action details and reasoning in
> the description, and a one-line diff changing `t3.nano` to `t3a.nano`.
> Once it's reviewed and merged, Turbonomic's optimization and the
> Terraform code agree, and the next `terraform apply` keeps it."

### Scene 6 — wrap-up (15s)

> "That's the loop: Turbonomic finds the optimization, and this AI step
> keeps the Terraform code — and your Git history — in sync, with a human
> still reviewing every change."

Executing the action in Turbonomic is optional and best left off camera: it
really resizes instance `i-0c9d3c17d0d094067`, which is also managed by the
HCP Terraform workspace for the root `main.tf`.

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
`instance_type = "t3.nano"` — it will, as long as you never merged a demo
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
