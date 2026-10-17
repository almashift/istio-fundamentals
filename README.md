# AlmaShift - Istio Practice Labs

Learn Istio by doing. Every lab starts from a realistic, pre-built cluster state,
asks you to produce an **outcome**, and is graded by a script that tests real
behaviour (traffic splits, rejected requests), not just whether YAML was accepted.

These are the labs of **Istio Fundamentals**, the free course at
[learn.almashift.com](https://learn.almashift.com/lms/courses/istio-fundamentals).
Everything runs in your browser.

## Option A: Killercoda (one click per lab)

Each lab's lesson has a **▶ Start in your browser** link, and all labs are listed at
[killercoda.com/almashift](https://killercoda.com/almashift). Sign in with a free Killercoda
account and click **Start**: about a minute later you have a fresh cluster with Istio,
the MeshMart store and your task.

## Option B: GitHub Codespaces (one environment for every lab)

1. Fork this repository to your **personal GitHub account**.
2. In your fork, select **Code > Codespaces > Create codespace on master**. Choose the smallest machine (2-core / 8 GB / 32 GB).
3. Wait for the terminal to print `Environment ready`. The first start creates a
   Kubernetes cluster and installs Istio (takes a few minutes).
4. In the Codespace's terminal:

```bash
lab list          # see all labs
lab start 1       # build the starting state and read the task
lab check         # grade your work
lab hint          # one hint at a time
lab solution      # explained solution (try first!)
```

Codespaces usage is billed to the account that owns the Codespace (usually the account that
created it), not automatically to the original repository owner. With a personal fork, your
Codespace is normally billed to your account; check your GitHub billing settings and stop the
Codespace when you finish. Usage beyond your included allowance may be charged to you.
