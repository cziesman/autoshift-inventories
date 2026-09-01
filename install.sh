#!/bin/sh

export APP_NAME="autoshift"
# Running a fork? Set this to your fork. It becomes both the source of the chart and the
# repository every generated Application clones for policies.
export REPO_URL="https://github.com/auto-shift/autoshiftv2.git"
export TARGET_REVISION="main"
export VALUES_FILE="values/global.yaml"
export VALUES_FILE_2="values/clustersets/hub.yaml"
export VALUES_FILE_3="values/clustersets/managed.yaml"
export ARGO_PROJECT="default"
export GITOPS_NAMESPACE="openshift-gitops"
cat << EOF | oc apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $APP_NAME
  namespace: $GITOPS_NAMESPACE
spec:
  destination:
    namespace: $GITOPS_NAMESPACE
    server: https://kubernetes.default.svc
  source:
    path: autoshift
    repoURL: $REPO_URL
    targetRevision: $TARGET_REVISION
    helm:
      valueFiles:
        - $VALUES_FILE
        - $VALUES_FILE_2
        - $VALUES_FILE_3
      # Injected by Argo CD from this Application's own source, so the repository and revision
      # are declared once. Substitution works in parameters, not in a `values:` block.
      # The backslashes keep the shell from expanding these before oc sees them; in a plain
      # manifest file, write them as $ARGOCD_APP_SOURCE_REPO_URL with no backslash.
      parameters:
        - name: autoshiftGitRepo
          value: \$ARGOCD_APP_SOURCE_REPO_URL
        - name: autoshiftGitBranchTag
          value: \$ARGOCD_APP_SOURCE_TARGET_REVISION
  sources: []
  project: $ARGO_PROJECT
  syncPolicy:
    automated:
      prune: false
      selfHeal: true
EOF
