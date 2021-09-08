#!/bin/bash

function log() {
  echo "$(date +'%Y-%m-%d %H:%M:%S %z') INFO  - $*"
}

function fatal() {
  echo "$(date +'%Y-%m-%d %H:%M:%S %z') ERROR - $*"
  exit 1
}

function visible_sleep() {
  for (( i=0; i<$1; i++ )); do
    echo -n .
    sleep 1
  done
}

usage () {
  echo "\
RKE to RKE2 migration: initial cluster-level process and first controlplane

Usage: ${0} <options>

Required flags:
  --rancher-local-kubeconfig FILE - file location of kubeconfig for the 'local' cluster in Rancher
                                      NOTE: must provide access to 'cluster.management.cattle.io'
                                      objects, usually provided by admin-level Rancher access
  --target-cluster-id CLUSTER-ID  - ID of cluster (usually c-xxxxx) in Rancher server that is being
                                      migrated
  --nodes-ssh-user USERNAME       - username for RKE to use for SSH-ing into all nodes


Optional flags:
  --nodes-ssh-key KEY_FILE        - private key for RKE to use for SSHing into all nodes
                                      (default: ~/.ssh/id_rsa)
  --migration-aio-ip IP           - IP of node that will remain an all-in-one node, while all others
                                      will be moved to a worker node - use if auto-detection of IP /
                                      node name fails
  --allow-root-ssh                - if nodes-ssh-user is set to \"root\", confirms root is accessible
                                      accessible over SSH (some RHEL-like OSes disallow root login
                                      through SSH by default)
  --insecure-import, -i           - indicate the host doesn't trust the connection to the Rancher
                                      server, use 'curl --insecure' for import instead of
                                      'kubectl apply'
"
  exit 1
}

main() {
  getopt --test
  getopt_test=$?
  if (( getopt_test != 4 )) ; then
    fatal "getopt binary doesn't support long mode; script cannot run, exiting"
  fi

  opts_short=i
  opts_long=rancher-local-kubeconfig:,target-cluster-id:,nodes-ssh-user:,nodes-ssh-key:,migration-aio-ip:,allow-root-ssh,insecure-import

  if ! parsed_opts=$(getopt --options "${opts_short}" --longoptions "${opts_long}" --name "$0" -- "$@") ; then
      usage
  fi

  eval set -- "${parsed_opts}"

  rancher_local_kubeconfig=
  target_cluster_id=
  nodes_ssh_user=
  nodes_ssh_key="~/.ssh/id_rsa"
  migration_aio_ip=
  allow_root_ssh="false"
  insecure_import="false"

  while true; do
    case "$1" in
    --rancher-local-kubeconfig)
      rancher_local_kubeconfig="$2"
      shift 2
      ;;
    --target-cluster-id)
      target_cluster_id="$2"
      shift 2
      ;;
    --nodes-ssh-user)
      nodes_ssh_user="$2"
      shift 2
      ;;
    --nodes-ssh-key)
      nodes_ssh_key="$2"
      shift 2
      ;;
    --migration-aio-ip)
      migration_aio_ip="$2"
      shift 2
      ;;
    --allow-root-ssh)
      allow_root_ssh="true"
      shift
      ;;
    --insecure-import,-i)
      insecure_import="true"
      shift 1
      ;;
    --)
      shift
      break
      ;;
    *)
      # ideally this case should never happen, as getopt should have thrown an
      # error; just in case, handle the bad case and print usage
      echo "Unexpected option: $1"
      usage
      ;;
    esac
  done

  if [ -z "${rancher_local_kubeconfig}" ]; then
    fatal "Missing required flag 'rancher-local-kubeconfig' - exiting"
  fi

  if [ -z "${target_cluster_id}" ]; then
    fatal "Missing required flag 'target-cluster-id' - exiting"
  fi

  if [ -z "${nodes_ssh_user}" ]; then
    fatal "Missing required flag 'node-ssh-user' - exiting"
  elif [ "${nodes_ssh_user}" == "root" ] && [ "${allow_root_ssh}" != "true" ]; then
    fatal "root user could be possibly inaccessible over SSH; confirm root is accessible over SSH with --allow-root-ssh"
  fi

#  mkdir migration
#  cd migration
#  export rancher_local_kubeconfig=./rancher_kube_config.yaml
#  export target_cluster_id="c-88rkd"
#  export nodes_ssh_user="ec2-user"
#  export nodes_ssh_key="/home/ec2-user/.ssh/id_rsa"
#  export migration_aio_ip="18.253.203.135"
#  vi ./rancher_kube_config.yaml

  log "Kube config for Rancher 'local' cluster: ${rancher_local_kubeconfig}"
  log "ID of Rancher cluster being migrated:    ${target_cluster_id}"
#  log "Name of this node, as seen in k8s Node:  ${node_name}"
  log "User used for RKE's SSH access to nodes: ${nodes_ssh_user}"
  log "Key used for RKE's SSH access to nodes:  ${nodes_ssh_key}"

  if [ -n "${migration_aio_ip}" ]; then
  log "IP of node that will remain an AIO node: ${migration_aio_ip}"
  fi

  # ---
  log "installing all tools to $(pwd)/bin;
to use these tools from your shell, run
export PATH=\"$(pwd)/bin:\${PATH}\""

  PATH="$(pwd)/bin:${PATH}"

  # ---
  log "create working and temp directory"
  mkdir -p tmp bin rke rke2
  ls -alh

  pushd tmp || {
    fatal "failed to change to ./tmp; exiting"
  }

  # ---
  log "install kubectl"

  curl -LO "https://dl.k8s.io/release/v1.20.7/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 kubectl ../bin/kubectl
  sudo ln ../bin/kubectl /usr/sbin/kubectl
  rm kubectl

  kubectl version --client

  # ---
  log "install rke CLI"

  curl -LO https://github.com/rancher/rke/releases/download/v1.2.8/rke_linux-amd64
  sudo install -o root -g root -m 0755 rke_linux-amd64 ../bin/rke
  sudo ln ../bin/rke /usr/sbin/rke
  rm rke_linux-amd64

  rke --version

  # ---
  log "install cluster parser (https://github.com/nikkelma/rke-rke2-migration/tree/main/rke-cluster-parser)"

  curl -LO https://github.com/nikkelma/rke-rke2-migration/releases/download/parser-v0.1.0/parser-linux-amd64
  sudo install -o root -g root -m 0755 parser-linux-amd64 ../bin/rke-cluster-parser
  sudo ln ../bin/rke-cluster-parser /usr/sbin/rke-cluster-parser
  rm parser-linux-amd64

  # ---
  popd || {
    fatal "failed to change to .. from ./tmp; exiting"
  }

  # ---
  if [ -z "${migration_aio_ip}" ]; then
    log "use IP of local node when AIO IP not provided as CLI flag"
    migration_aio_ip="$(ip route get 1.1.1.1 | awk '{print $NF; exit}')"
  fi

  # ---
  log "pre-pull jq docker image"

  sudo docker pull stedolan/jq

  # ---
  log "fetch kube config of target migration cluster"

  sudo kubectl --kubeconfig \
    "$(docker inspect kubelet --format '{{ range .Mounts }}{{ if eq .Destination "/etc/kubernetes" }}{{ .Source }}{{ end }}{{ end }}')/ssl/kubecfg-kube-node.yaml" \
    get configmap -n kube-system full-cluster-state -o json \
    | \
    docker run --rm -i stedolan/jq -r '.data."full-cluster-state"' \
    | \
    docker run --rm -i stedolan/jq -r '.currentState.certificatesBundle."kube-admin".config' \
    | \
    sed -e "/^[[:space:]]*server:/ s_:.*_: \"https://127.0.0.1:6443\"_" > ./rke/kube_config_mig-cluster.yaml

  sudo chown "$USER" ./rke/kube_config_mig-cluster.yaml

  # ---
  log "fetch RKE config from Rancher server cluster"

  kubectl --kubeconfig "${rancher_local_kubeconfig}" \
    get cluster.management.cattle.io "${target_cluster_id}" -o json \
    | \
    docker run --rm -i stedolan/jq -r .status.appliedSpec.rancherKubernetesEngineConfig \
      > ./rke/mig-cluster.json

  # ---
  log "edit RKE config to allow successful CLI calls"

  cp ./rke/mig-cluster.json ./rke/mig-cluster.json.orig

  docker run --rm -i stedolan/jq -r \
    "( .nodes[].user |= \"${nodes_ssh_user}\" ) | ( .nodes[].sshKeyPath |= \"${nodes_ssh_key}\" )" \
    < ./rke/mig-cluster.json \
    > ./rke/mig-cluster-edited.json

  mv ./rke/mig-cluster-edited.json ./rke/mig-cluster.json

  docker run --rm -i stedolan/jq -r \
    "( .nodes[] | select( .address != \"${migration_aio_ip}\" and .internalAddress != \"${migration_aio_ip}\" ) | .role ) |= [\"worker\"]" \
    < ./rke/mig-cluster.json \
    > ./rke/mig-cluster-edited.json

  mv ./rke/mig-cluster-edited.json ./rke/mig-cluster.json

  # ---
  log "convert RKE config from JSON to YAML"

  rke-cluster-parser to-yaml -o ./rke/mig-cluster.yaml ./rke/mig-cluster.json

  # ---
  # determine names and IPs of nodes in etcd vs. worker roles

  migration_aio_node_name="$(docker run --rm -i stedolan/jq -r \
    ".nodes[] | select( .address == \"${migration_aio_ip}\" or .internalAddress == \"${migration_aio_ip}\" ) | .hostnameOverride" \
    < ./rke/mig-cluster.json)"

  migration_worker_node_names="$(kubectl --kubeconfig ./rke/kube_config_mig-cluster.yaml \
    get nodes -o jsonpath='{range .items[?(@.metadata.name != "'"${migration_aio_node_name}"'")]}{.metadata.name}{'"'"'\n'"'"'}{end}')"

  readarray -t migration_worker_node_names_arr <<< "${migration_worker_node_names}"

  migration_worker_node_ips_arr=()
  for cur_node_name in "${migration_worker_node_names_arr[@]}"; do
    cur_node_ip="$(docker run --rm -i stedolan/jq -r \
    ".nodes[] | select( .hostnameOverride == \"${cur_node_name}\" ) | .address" \
    < ./rke/mig-cluster.json)"

    migration_worker_node_ips_arr+=("${cur_node_ip}")
  done

  # ---
  log "fetch RKE state from local cluster"

  kubectl --kubeconfig ./rke/kube_config_mig-cluster.yaml \
    get configmap -n kube-system full-cluster-state -o json \
    | \
    docker run --rm -i stedolan/jq -r .data.\"full-cluster-state\" \
      > ./rke/mig-cluster.rkestate

  # ---
  log "edit RKE state to match RKE config"

  cp ./rke/mig-cluster.rkestate ./rke/mig-cluster.rkestate.orig

  docker run --rm -i stedolan/jq -r \
    "( .currentState.rkeConfig.nodes[].user |= \"${nodes_ssh_user}\" ) | ( .currentState.rkeConfig.nodes[].sshKeyPath |= \"${nodes_ssh_key}\" )" \
    < ./rke/mig-cluster.rkestate \
    > ./rke/mig-cluster-edited.rkestate

  mv ./rke/mig-cluster-edited.rkestate ./rke/mig-cluster.rkestate

  # ---
  log "delete Custom cluster agents"

  kubectl --kubeconfig ./rke/kube_config_mig-cluster.yaml \
    delete daemonset -n cattle-system cattle-node-agent

  kubectl --kubeconfig ./rke/kube_config_mig-cluster.yaml \
    delete deployment -n cattle-system cattle-cluster-agent

  kubectl --kubeconfig ./rke/kube_config_mig-cluster.yaml \
    delete deployment -n fleet-system fleet-agent

  log "waiting for agents to spin down"

  for node_ip in "${migration_worker_node_ips_arr[@]}"; do
    docker_ids="$(ssh -n -i "${nodes_ssh_key}" -o StrictHostKeyChecking=no \
      "${nodes_ssh_user}"@"${node_ip}" \
      "sh -c \"docker ps -a --format '{{ .ID }} {{ .Image }}' | grep -i rancher-agent\"")"

    while read -ra container_meta; do
      container_id="${container_meta[0]}"

      ssh -n -i "${nodes_ssh_key}" -o StrictHostKeyChecking=no \
        "${nodes_ssh_user}"@"${node_ip}" \
        docker stop "${container_id}"

    done <<< "${docker_ids}"
  done

  active_cattle_pods="$(kubectl --kubeconfig \
    ./rke/kube_config_mig-cluster.yaml \
    get pods -n cattle-system -o jsonpath='{.items[*].metadata.name}')"

  until [ -z "${active_cattle_pods}" ]; do
    visible_sleep 5
    active_cattle_pods="$(kubectl --kubeconfig \
      ./rke/kube_config_mig-cluster.yaml \
      get pods -n cattle-system -o jsonpath='{.items[*].metadata.name}')"
  done

  active_fleet_pods="$(kubectl --kubeconfig \
    ./rke/kube_config_mig-cluster.yaml \
    get pods -n fleet-system -o jsonpath='{.items[*].metadata.name}')"

  until [ -z "${active_fleet_pods}" ]; do
    visible_sleep 5
    active_fleet_pods="$(kubectl --kubeconfig \
      ./rke/kube_config_mig-cluster.yaml \
      get pods -n fleet-system -o jsonpath='{.items[*].metadata.name}')"
  done
  echo

  log "rancher agents fully terminated"

  # ---
  log "run rke up to move to a 1 AIO, 2 worker cluster"

  rke up --config ./rke/mig-cluster.yaml

  # ---
  log "update RKE state configmap for migration agent"
  kubectl \
    create configmap -n kube-system full-cluster-state \
    --from-file=full-cluster-state=./rke/mig-cluster.rkestate \
    --dry-run=client -o yaml \
    > ./tmp/full-cluster-state.yaml

  kubectl --kubeconfig ./rke/kube_config_mig-cluster.yaml \
    replace -f ./tmp/full-cluster-state.yaml

  # ---
  log "take new etcd snapshot for migration"

  etcd_snapshot_name="rke2-migration-$(date +'%Y-%m-%d_%H-%M-%S')"

  rke etcd snapshot-save \
    --config ./rke/mig-cluster.yaml \
    --name "${etcd_snapshot_name}"

  for node_ip in "${migration_worker_node_ips_arr[@]}"; do
    sudo scp -i "${nodes_ssh_key}" -o StrictHostKeyChecking=no \
      "/opt/rke/etcd-snapshots/${etcd_snapshot_name}.zip" "${nodes_ssh_user}"@"${node_ip}":'~'/"${etcd_snapshot_name}.zip"

    ssh -n -i "${nodes_ssh_key}" -o StrictHostKeyChecking=no \
      "${nodes_ssh_user}"@"${node_ip}" sudo mkdir -p "/opt/rke/etcd-snapshots"

    ssh -n -i "${nodes_ssh_key}" -o StrictHostKeyChecking=no \
      "${nodes_ssh_user}"@"${node_ip}" sudo cp '~'/"${etcd_snapshot_name}.zip" "/opt/rke/etcd-snapshots/${etcd_snapshot_name}.zip"
  done

  # ---
  log "run migration agent"

  cat <<EOF > ./tmp/migration-agent.yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: migration-agent
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: migration-agent
rules:
  - apiGroups:
    - "*"
    resources:
    - "*"
    verbs:
    - "*"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: migration-agent
subjects:
- kind: ServiceAccount
  name: migration-agent
  namespace: kube-system
roleRef:
  kind: ClusterRole
  name: migration-agent
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: migration-agent-etcd
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: migration-agent-etcd
  template:
    metadata:
      labels:
        name: migration-agent-etcd
    spec:
      hostNetwork: true
      hostPID: true
      serviceAccountName: migration-agent
      tolerations:
      - operator: Exists
        effect: NoSchedule
      - operator: Exists
        effect: NoExecute
      containers:
      - name: migration-agent
        image: rancher/migration-agent:v0.1.0-rc8
        imagePullPolicy: Always
        securityContext:
          privileged: true
        command:
          - "sh"
          - "-c"
          - "migration-agent --snapshot /opt/rke/etcd-snapshots/${etcd_snapshot_name}.zip && sleep 9223372036854775807"
        volumeMounts:
        - name: var-lib-rancher
          mountPath: /var/lib/rancher
        - name: etc-kubernetes-ssl
          mountPath: /etc/kubernetes/ssl
        - name: etc-rancher
          mountPath: /etc/rancher
        - name: opt-rke-etcd-snapshots
          mountPath: /opt/rke/etcd-snapshots
      terminationGracePeriodSeconds: 30
      volumes:
      - name: var-lib-rancher
        hostPath:
          path: /var/lib/rancher
      - name: etc-kubernetes-ssl
        hostPath:
          path: /etc/kubernetes/ssl
      - name: etc-rancher
        hostPath:
          path: /etc/rancher
      - name: opt-rke-etcd-snapshots
        hostPath:
          path: /opt/rke/etcd-snapshots
EOF

  kubectl --kubeconfig ./rke/kube_config_mig-cluster.yaml \
    apply -f ./tmp/migration-agent.yaml

  log "give migration agent time to complete"
  visible_sleep 10
  echo

  # ---
  log "install RKE2"

  curl -sfL https://get.rke2.io | sudo sh -c 'INSTALL_RKE2_VERSION=v1.20.7+rke2r2 sh -'
  export PATH="${PATH}:/var/lib/rancher/rke2/bin"

  curl -sfL https://get.rke2.io | sudo sh -c 'INSTALL_RKE2_VERSION=v1.21.4+rke2r2 sh -'
  export PATH="${PATH}:/var/lib/rancher/rke2/bin"

  # ---
  log "edit Rancher Cluster API object to become Imported cluster"

  kubectl --kubeconfig "${rancher_local_kubeconfig}" \
    patch cluster.management.cattle.io/${target_cluster_id} \
    --type json \
    --patch '[{"op":"remove","path": "/spec/rancherKubernetesEngineConfig"},{"op":"replace","path":"/status/driver","value": ""}]'

  # ---
  log "stop docker"

  sudo systemctl disable docker
  sudo systemctl stop docker
  sudo systemctl disable docker.socket
  sudo systemctl stop docker.socket

  # ---
  log "start RKE2"
  sudo systemctl enable rke2-server
  sudo systemctl start rke2-server

  # ---
  log "wait for RKE2 kubeconfig"

  until [ -f "/etc/rancher/rke2/rke2.yaml" ]; do
    visible_sleep 5
  done
  visible_sleep 3
  echo

  sudo cp /etc/rancher/rke2/rke2.yaml ./rke2/kube_config.yaml
  sudo chown "${USER}" ./rke2/kube_config.yaml

  # ---
  log "install rke2 on non-AIO hosts, switch from docker to RKE2"
  node_token="$(sudo cat /var/lib/rancher/rke2/server/node-token)"

  cat <<EOF > "./tmp/install-attach-rke2.yaml"
sudo mkdir -p /etc/rancher/rke2/
sudo cp ~/config.yaml /etc/rancher/rke2/

curl -sfL https://get.rke2.io | sudo sh -c 'INSTALL_RKE2_VERSION=v1.20.7+rke2r2 sh -'

sudo systemctl disable docker
sudo systemctl stop docker
sudo systemctl disable docker.socket
sudo systemctl stop docker.socket

sudo systemctl enable rke2-server
sudo systemctl start rke2-server
EOF

  for (( i=0; i<${#migration_worker_node_ips_arr[@]}; i++ )) ; do
    cur_name="${migration_worker_node_names_arr[i]}"
    cur_ip="${migration_worker_node_ips_arr[i]}"

    log "switch node ${cur_name} (IP ${cur_ip}) to RKE2"

    cat <<EOF > "./tmp/rke2-config_${cur_name}.yaml"
server: https://${migration_aio_ip}:9345
token: ${node_token}
node-name: ${cur_name}
EOF

    scp -i "${nodes_ssh_key}" -o StrictHostKeyChecking=no \
      "./tmp/rke2-config_${cur_name}.yaml" "${nodes_ssh_user}"@"${cur_ip}":'~'/config.yaml

    ssh -i "${nodes_ssh_key}" -o StrictHostKeyChecking=no \
      "${nodes_ssh_user}"@"${cur_ip}" \
      < ./tmp/install-attach-rke2.yaml


    log "waiting for node ${cur_name} to become Ready"
    visible_sleep 15

    until [ "$( kubectl --kubeconfig ./rke2/kube_config.yaml get node "${cur_name}" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' )" == "True" ]; do
      visible_sleep 5
    done
    echo
  done

  # ---
  log "re-import migrated cluster back into Rancher"

  rancher_server_url="$(kubectl --kubeconfig "${rancher_local_kubeconfig}" \
    get settings.management.cattle.io server-url \
    -o jsonpath='{.value}')"

  import_token="$(kubectl --kubeconfig "${rancher_local_kubeconfig}" \
    get clusterregistrationtoken.management.cattle.io \
    -n "${target_cluster_id}" -o jsonpath='{.items[].status.token}')"

  if [ "${insecure_import}" == "true" ]; then
    curl --insecure -sfL "${rancher_server_url}/v3/import/${import_token}_${target_cluster_id}.yaml" \
      | kubectl --kubeconfig ./rke2/kube_config.yaml apply -f -
  else
    kubectl --kubeconfig ./rke2/kube_config.yaml apply -f "${rancher_server_url}/v3/import/${import_token}_${target_cluster_id}.yaml"
  fi
}

main "$@"
