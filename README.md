# AlmaShift - Istio Practice Labs

Learn Istio by doing. Every lab starts from a realistic, pre-built cluster state,
asks you to produce an **outcome**, and is graded by a script that tests real
behaviour (traffic splits, rejected requests), not just whether YAML was accepted.

## Quick start (GitHub Codespaces)

1. Fork this repository to your **personal GitHub account**.
2. In your fork, select **Code > Codespaces > Create codespace on master**. Choose the smallest machine (2-core / 8 GB / 32 GB).
3. Wait for the terminal to print `Environment ready`. The first start creates a
   `kind` cluster and installs Istio (takes a few minutes).
4. Run inside the vscode terminal window inside the codespaces:

```bash
lab list          # see all labs
lab start 1       # build the starting state and read the task
lab check         # grade your work
lab hint          # one hint at a time
lab solution      # explained solution (try first!)
lab budget        # CPU requested vs the 2-core budget
```

Codespaces usage is billed to the account that owns the Codespace (usually the account that
created it), not automatically to the original repository owner. With a personal fork, your
Codespace is normally billed to your account; check your GitHub billing settings and stop the
Codespace when you finish. Usage beyond your included allowance may be charged to you.

## Run locally with a Dev Container

This uses the same development container configuration as Codespaces, but runs on your own
computer. You need Docker Desktop (running) and Visual Studio Code with the
[Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers).

1. Clone your fork and open its folder in VS Code.
2. Open the Command Palette (`Ctrl+Shift+P` / `Cmd+Shift+P`) and select **Dev Containers: Reopen in Container**.
3. Wait for the container setup to finish and for the terminal to print `Environment ready`.
   The first start installs the tools, creates a local `kind` cluster, and installs Istio.
4. In the VS Code terminal, use the lab commands from the Codespaces quick start above.

The cluster and containers run locally on your computer, so this does not use GitHub Codespaces compute. Docker and the Kubernetes cluster still use local disk, memory, and CPU.
