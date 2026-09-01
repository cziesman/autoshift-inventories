# Overview

A Kubernetes **Job is a one-time workload**. When a Job object is created, Openshift starts a pod to execute its container. When the container exits successfully, the Job is considered complete.

For autoshift, the lifecycle would be:

```text
You / Argo CD
      │
      │ creates Job
      ▼
┌──────────────────────┐
│ Openshift Job        │
│ autoshift-bootstrap  │
└──────────┬───────────┘
           │ creates
           ▼
┌──────────────────────┐
│ Pod                  │
│                      │
│ ose-cli image        │
│ bootstrap.sh         │
│                      │
│ oc apply -f -        │
└──────────┬───────────┘
           │
           │ script exits 0
           ▼
     Job: Complete
```

### What actually executes it?

The **Kubernetes Job controller**.

When you do:

```bash
oc apply -f job.yaml
```

the API server stores the Job. The Job controller sees it and creates a Pod.

You can see this with:

```bash
oc get jobs -n openshift-gitops
```

and:

```bash
oc get pods -n openshift-gitops
```

For example:

```text
NAME                  COMPLETIONS   DURATION   AGE
autoshift-bootstrap   1/1           8s         20s
```

The pod will eventually show:

```text
NAME                        READY   STATUS      RESTARTS   AGE
autoshift-bootstrap-xxxxx   0/1     Completed   0          20s
```

Then:

```bash
oc logs job/autoshift-bootstrap -n openshift-gitops
```

shows your script's output.

### What happens if the script fails?

Suppose your script does:

```bash
set -euo pipefail

oc apply -f -
```

and `oc apply` returns an error.

The container exits non-zero:

```text
Pod → Failed
```

The Job controller can then retry it according to the Job's settings.

For example:

```yaml
spec:
  backoffLimit: 3
```

means Kubernetes will allow retries before declaring the Job failed.

You can see the result with:

```bash
oc get job autoshift-bootstrap -n openshift-gitops
```

### The important difference from a Deployment

A `Deployment` is intended to keep something running:

```text
Deployment
    │
    └── Pod
         │
         └── application keeps running
```

A Job is intended to **finish**:

```text
Job
 │
 └── Pod
      │
      ├── run script
      ├── oc apply
      └── exit
             │
             ▼
          Complete
```

That's why a Job fits your bootstrap script particularly well.

### And the ConfigMap fits naturally

Your proposed arrangement would be:

```text
ConfigMap
   │
   │ mounted as /scripts/bootstrap.sh
   ▼
Job
   │
   └── Pod
        │
        ├── /scripts/bootstrap.sh
        │
        └── oc apply
                 │
                 ▼
          Argo CD Application
```

The Job doesn't need to contain the script in its YAML. It just mounts the ConfigMap:

```yaml
volumes:
  - name: script
    configMap:
      name: autoshift-bootstrap-script
```

and:

```yaml
volumeMounts:
  - name: script
    mountPath: /scripts
    readOnly: true
```

Then:

```yaml
command:
  - /bin/bash
  - /scripts/bootstrap.sh
```

### One particularly useful property for your case

A Job can be **created by Argo CD itself**.

So your Git repository could contain:

```text
bootstrap/
├── configmap.yaml
├── job.yaml
└── rbac.yaml
```

Argo CD applies those resources:

```text
Git
 │
 ▼
Argo CD
 │
 ├── ConfigMap
 ├── ServiceAccount
 ├── Role
 ├── RoleBinding
 └── Job
       │
       ▼
     Pod
       │
       └── oc apply Application
```

That makes the bootstrap operation GitOps-managed rather than requiring you to manually run `oc`.

There is one **important wrinkle** with that design, though: your Job creates an Argo CD `Application`, which then manages other resources. We should design the Job/Argo ownership and cleanup carefully so that Argo CD doesn't immediately delete the Job or repeatedly recreate it.
