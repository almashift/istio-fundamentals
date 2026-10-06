# Alma Academy - Istio Practice Labs

Learn Istio by doing. Every lab starts from a realistic, pre-built cluster state,
asks you to produce an **outcome**, and is graded by a script that tests real
behaviour (traffic splits, rejected requests), not just whether YAML was accepted.

## Quick start (GitHub Codespaces)

1. Open this repo in a Codespace. The **smallest machine (2-core / 8 GB / 32 GB)** is all you need.
2. Wait for the terminal to print `Environment ready`. The first start creates a
   `kind` cluster and installs Istio (a few minutes).
3. Run:

```bash
lab list          # see all labs
lab start 1       # build the starting state and read the task
lab check 1       # grade your work
lab hint 1        # one hint at a time
lab solution 1    # explained solution (try first!)
lab budget        # CPU requested vs the 2-core budget
```

## Built for the smallest Codespace
The whole stack is sized to fit GitHub's smallest machine (2 vCPU, 8 GB RAM, 32 GB storage):

- **CPU is the tight resource.** A single-node `kind` cluster already requests roughly 1 core
  for Kubernetes itself. Istio's defaults (istiod 500m CPU / 2Gi; 100m CPU per sidecar) would
  crowd a 2-core node and leave pods `Pending`, so `setup/istio-install.sh` lowers them
  (istiod 100m / 256Mi, sidecars 10m / 48Mi).
- **CPU budget guard.** `lab budget` shows total CPU requested versus the budget in
  `versions.env` (`CPU_BUDGET_M=1700` of 2000m). `lab verify` (and CI) fails if a lab pushes the
  cluster over it. Keep lab manifests small: give your own pods `requests: {cpu: 10m, memory: 16Mi}`.
- **Free quota.** 120 free core-hours/month is about 60 hours of use on a 2-core machine.
  Stop the Codespace when you finish (it also auto-stops after an idle period).
- **Storage.** Images are kept small; avoid adding large images to labs.
- **One lab at a time.** `lab start` rebuilds only that lab's namespace; delete finished
  namespaces (`kubectl delete ns lab01`) if you start running low on resources.
- **Ambient mode is heavier** (a ztunnel and CNI agent on every node) and has not been slimmed
  or tested on 2 cores yet. Treat it as experimental on this machine size.

CI runs on a larger GitHub runner, so it cannot prove real 2-core performance. The CPU
budget check is the guard; still, try new labs on an actual 2-core Codespace before publishing.

## Run locally instead
Requires Docker. Either open the folder in VS Code with the *Dev Containers*
extension, or run `bash setup/install-tools.sh && bash setup/ensure-cluster.sh`
on a Linux machine with Docker installed.

## Layout

```
.devcontainer/      Codespaces / Dev Container definition
setup/              install-tools, kind config, Istio install, ensure-cluster
bin/lab, bin/lib.sh the practice runner and shared check helpers
versions.env        pinned Istio / Kubernetes / kind versions (one place to bump)
labs/NN-name/       one folder per lab (see below)
labs/_template/     copy this to start a new lab
.github/workflows/  CI that proves every lab is solvable and not pre-solved
```

## Anatomy of a lab

| File | Purpose |
|---|---|
| `meta.env` | title, domain, sidecar/ambient mode, estimated minutes |
| `init.sh` | builds the starting state (idempotent) |
| `task.md` | scenario + outcome-based task shown to the learner |
| `check.sh` | grades behaviour; exits non-zero on failure |
| `hints/1..3.md` | graduated hints: nudge, pointer, skeleton |
| `solution/` | `apply.sh` + manifests + `explanation.md` (why, wrong answers, production note) |

## Authoring rules (the "learn by practice" standard)
1. **Write `check.sh` first.** If you can't script the verification, the task is too vague.
2. Test **behaviour on the wire**, and add anti-cheat checks (e.g. replicas unchanged).
3. Starting state must **fail** the checker; the solution must **pass**. CI enforces this (`lab verify`).
4. Hints should nudge, never hand over the answer until hint 3.
5. Every solution explains common wrong answers and one production caveat.
6. Pin versions in `versions.env`; bump them in one commit and let CI tell you what broke.

## Switching to ambient mode
Set `ISTIO_MODE=ambient`, then `lab reset-cluster`. Labs declare which modes they
support in `meta.env`; `lab start` warns on a mismatch.

## Status of this scaffold
- Lab 01 (weighted routing) is the reference lab.
- Ambient install path and the Gateway API CRD step are scaffolded but not yet exercised by a lab.
- Resource sizing for 2 vCPU / 8 GB is based on default `kind` and Istio requests; measure it on a real small Codespace.
- Pinned versions in `versions.env` should be confirmed against the Istio release the
  current ICA exam is based on before you publish.

## Roadmap (suggested next labs)
Traffic: gateway ingress, mirroring, fault injection, timeouts/retries, circuit breaking, ServiceEntry.
Security: STRICT mTLS, AuthorizationPolicy, JWT.
Troubleshooting: broken-by-design clusters diagnosed with `istioctl analyze` / `proxy-config`.
Install/upgrade: Helm install, canary upgrade, ambient enrolment.
Then: timed mini-exams and a full mock exam built from these labs.

## Troubleshooting

**`Permission denied` when running `lab` or a script.** The execute bit was lost (common when
unzipping or committing from Windows). The setup now repairs this automatically, but if you
are committing the repo yourself, record the bit in git once:

```bash
git add --chmod=+x bin/lab bin/lib.sh setup/*.sh labs/*/*.sh labs/*/solution/*.sh
git commit -m "Make scripts executable"
```

**`bad interpreter` / `\r` errors.** Line endings were converted to Windows style. The included
`.gitattributes` forces LF; run `git add --renormalize .` after adding it.

You can also always run the CLI without the execute bit: `bash bin/lab list`.
