# Alma Academy - Istio Practice Labs

Learn Istio by doing. Every lab starts from a realistic, pre-built cluster state,
asks you to produce an **outcome**, and is graded by a script that tests real
behaviour (traffic splits, rejected requests), not just whether YAML was accepted.

## Quick start (GitHub Codespaces)

1. Open this repo in a Codespace (4-core machine recommended).
2. Wait for the terminal to print `Environment ready`. The first start creates a
   `kind` cluster and installs Istio (a few minutes).
3. Run:

```bash
lab list          # see all labs
lab start 1       # build the starting state and read the task
lab check 1       # grade your work
lab hint 1        # one hint at a time
lab solution 1    # explained solution (try first!)
```

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
- Pinned versions in `versions.env` should be confirmed against the Istio release the
  current ICA exam is based on before you publish.

## Roadmap (suggested next labs)
Traffic: gateway ingress, mirroring, fault injection, timeouts/retries, circuit breaking, ServiceEntry.
Security: STRICT mTLS, AuthorizationPolicy, JWT.
Troubleshooting: broken-by-design clusters diagnosed with `istioctl analyze` / `proxy-config`.
Install/upgrade: Helm install, canary upgrade, ambient enrolment.
Then: timed mini-exams and a full mock exam built from these labs.
