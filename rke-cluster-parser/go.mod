module github.com/nikkelma/rke-rke2-migration/rke-cluster-parser

go 1.15

require (
	github.com/rancher/rke v1.2.8
	github.com/spf13/cobra v1.1.3
	gopkg.in/yaml.v2 v2.4.0
)

replace k8s.io/client-go => k8s.io/client-go v0.20.0
