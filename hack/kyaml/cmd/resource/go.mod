module sigs.k8s.io/kustomize/cmd/resource

go 1.12

require (
	github.com/pkg/errors v0.8.1
	github.com/spf13/cobra v0.0.5
	golang.org/x/net v0.0.0-20191004110552-13f9640d40b9 // indirect
	k8s.io/apimachinery v0.0.0-20190913080033-27d36303b655
	k8s.io/client-go v0.0.0-20190918160344-1fbdaa4c8d90
	sigs.k8s.io/controller-runtime v0.4.0
	sigs.k8s.io/kustomize/kstatus v0.0.0
	sigs.k8s.io/kustomize/kyaml v0.0.0
)

replace (
	sigs.k8s.io/kustomize/kstatus => ../../../kstatus/
	sigs.k8s.io/kustomize/kyaml => ../../kyaml
)
