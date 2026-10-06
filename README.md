# Alma Academy - Istio Practice Labs

Learn Istio by doing. Every lab starts from a realistic, pre-built cluster state,
asks you to produce an **outcome**, and is graded by a script that tests real
behaviour (traffic splits, rejected requests), not just whether YAML was accepted.

## Quick start (GitHub Codespaces)

1. Fork this repository to your **personal GitHub account**.
2. In your fork, select **Code > Codespaces > Create codespace on main**. Choose the smallest machine (2-core / 8 GB / 32 GB).
3. Wait for the terminal to print `Environment ready`. The first start creates a
   `kind` cluster and installs Istio (takes a few minutes).
4. Run inside the vscode terminal window inside the codespaces:

```bash
lab list          # see all labs
lab start 1       # build the starting state and read the task
lab check 1       # grade your work
lab hint 1        # one hint at a time
lab solution 1    # explained solution (try first!)
lab budget        # CPU requested vs the 2-core budget
```

Codespaces usage is billed to the account that owns the Codespace (usually the account that
created it), not automatically to the original repository owner. With a personal fork, your
Codespace is normally billed to your account; check your GitHub billing settings and stop the
Codespace when you finish. Usage beyond your included allowance may be charged to you.

## Run locally instead
Requires Docker. Either open the folder in VS Code with the *Dev Containers*
extension, or run `bash setup/install-tools.sh && bash setup/ensure-cluster.sh`
on a Linux machine with Docker installed.

