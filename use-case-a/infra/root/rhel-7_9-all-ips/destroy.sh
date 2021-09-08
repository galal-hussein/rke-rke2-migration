#!/bin/bash

export TZ="America/New_York"

function log() {
  echo "$(date +'%Y-%m-%d %H:%M:%S %z') INFO  - $*"
}

function fatal() {
  echo "$(date +'%Y-%m-%d %H:%M:%S %z') ERROR - $*"
  exit 1
}

function cleanup() {
  log "removing plans directory"
  rm -rf ./plans
}

trap cleanup EXIT

mkdir -p ./plans ./state

log "---"
log "destroy nodes..."
# shellcheck disable=SC2015
{
  log "---"
  log "nodes init"
  terraform \
    -chdir=./nodes \
    init \
    -input=false
} && {
  log "---"
  log "nodes plan"
  terraform \
    -chdir=./nodes \
    plan \
    -destroy \
    -input=false \
    -var-file=../nodes.tfvars \
    -state=../state/nodes.tfstate \
    -out=../plans/nodes.zip
} && {
  log "---"
  log "nodes apply"
  terraform \
    -chdir=./nodes \
    apply \
    -input=false \
    -state=../state/nodes.tfstate \
    ../plans/nodes.zip
} || {
  fatal "nodes module failed"
}

log "---"
log "destroy rancher-cluster..."
# shellcheck disable=SC2015
{
  log "---"
  log "rancher-cluster init"
  terraform \
    -chdir=./rancher-cluster \
    init \
    -input=false
} && {
  log "---"
  log "rancher-cluster plan"
  terraform \
    -chdir=./rancher-cluster \
    plan \
    -destroy \
    -input=false \
    -var-file=../cluster.tfvars \
    -state=../state/rancher-cluster.tfstate \
    -out=../plans/rancher-cluster.zip
} && {
  log "---"
  log "rancher-cluster apply"
  terraform \
    -chdir=./rancher-cluster \
    apply \
    -input=false \
    -state=../state/rancher-cluster.tfstate \
    ../plans/rancher-cluster.zip
} || {
  fatal "rancher-cluster module failed"
}

log "---"
log "destroy network..."
# shellcheck disable=SC2015
{
  log "---"
  log "network init"
  terraform \
    -chdir=./network \
    init \
    -input=false
} && {
  log "---"
  log "network plan"
  terraform \
    -chdir=./network \
    plan \
    -destroy \
    -input=false \
    -var-file=../network.tfvars \
    -state=../state/network.tfstate \
    -out=../plans/network.zip
} && {
  log "---"
  log "network apply"
  terraform \
    -chdir=./network \
    apply \
    -input=false \
    -state=../state/network.tfstate \
    ../plans/network.zip
} || {
  fatal "network module failed"
}

log "---"
log "destroy base..."
# shellcheck disable=SC2015
{
  log "---"
  log "base init"
  terraform \
    -chdir=./base \
    init \
    -input=false
} && {
  log "---"
  log "base plan"
  terraform \
    -chdir=./base \
    plan \
    -destroy \
    -input=false \
    -state=../state/base.tfstate \
    -out=../plans/base.zip
} && {
  log "---"
  log "base apply"
  terraform \
    -chdir=./base \
    apply \
    -input=false \
    -state=../state/base.tfstate \
    ../plans/base.zip
} || {
  fatal "base module failed"
}

log "finished destruction successfully"
