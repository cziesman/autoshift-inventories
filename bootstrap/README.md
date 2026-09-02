# Overview

A Kubernetes Job is used to bootstrap AutoShift. A **Job is a one-time workload**. 

When a Job object is created, Openshift starts a pod to execute its container. When the container exits successfully, the Job is considered complete.

For AutoShift, the lifecycle is:

```text
    Admin
      │
      │ create Job
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

When the following command is executed:

```bash
oc apply -f job.yaml
```

the API server stores the Job. The Job controller sees it and creates a Pod.

This can be viewed with:

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

shows the script's output.

### What happens if the script fails?

If `oc apply` returns an error, then the container exits non-zero:

```text
Pod → Failed
```

The result can be viewed using the following:

```bash
oc get job autoshift-bootstrap -n openshift-gitops
```
