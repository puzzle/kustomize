// Copyright 2019 The Kubernetes Authors.
// SPDX-License-Identifier: Apache-2.0

package builtinconfig

import (
	"reflect"
	"testing"

	"sigs.k8s.io/kustomize/api/internal/loadertest"
	"sigs.k8s.io/kustomize/api/resid"
	"sigs.k8s.io/kustomize/api/types"
)

func TestLoadDefaultConfigsFromFiles(t *testing.T) {
	ldr := loadertest.NewFakeLoader("/app")
	ldr.AddFile("/app/config.yaml", []byte(`
namePrefix:
- path: nameprefix/path
  kind: SomeKind
`))
	emptycfg := &TransformerConfig{}
	tcfg, err := loadDefaultConfig(emptycfg, ldr, []string{"/app/config.yaml"})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	expected := &TransformerConfig{
		NamePrefix: []types.FieldSpecConfig{{
			FieldSpec: types.FieldSpec{
				Gvk:  resid.Gvk{Kind: "SomeKind"},
				Path: "nameprefix/path",
			},
		}},
	}
	if !reflect.DeepEqual(tcfg, expected) {
		t.Fatalf("expected %v\n but got %v\n", expected, tcfg)
	}
}

func TestMakeTransformerConfig(t *testing.T) {

	ldr := loadertest.NewFakeLoader("/app")
	ldr.AddFile("/app/mycrdonly.yaml", []byte(`
namePrefix:
- path: metadata/name
  behavior: remove
- path: metadata/name
  kind: APIService
  group: apiregistration.k8s.io
  behavior: replace
  skip: false
- path: metadata/name
  group: storage.k8s.io
  kind: StorageClass
  behavior: replace
  skip: false
  behavior: add
- path: metadata/name
  kind: Namespace
  skip: true
- path: metadata/name
  kind: MyCRD
  behavior: add
`))
	tcfg, err := MakeTransformerConfig(ldr, []string{"/app/mycrdonly.yaml"})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	expected := &TransformerConfig{
		NamePrefix: []types.FieldSpecConfig{
			{
				FieldSpec: types.FieldSpec{
					Gvk:                resid.Gvk{Kind: "Namespace"},
					Path:               "metadata/name",
					SkipTransformation: true,
				},
			},
			{
				FieldSpec: types.FieldSpec{
					Gvk:                resid.Gvk{Kind: "StorageClass", Group: "storage.k8s.io"},
					Path:               "metadata/name",
					SkipTransformation: false,
				},
			},
			{
				FieldSpec: types.FieldSpec{
					Gvk:                resid.Gvk{Kind: "CustomResourceDefinition"},
					Path:               "metadata/name",
					SkipTransformation: true,
				},
			},
			{
				FieldSpec: types.FieldSpec{
					Gvk:                resid.Gvk{Kind: "APIService", Group: "apiregistration.k8s.io"},
					Path:               "metadata/name",
					SkipTransformation: false,
				},
			},
			{
				FieldSpec: types.FieldSpec{
					Gvk:  resid.Gvk{Kind: "MyCRD"},
					Path: "metadata/name",
				},
			},
		},
	}
	if !reflect.DeepEqual(tcfg.NamePrefixFieldSpecs(), expected.NamePrefixFieldSpecs()) {
		t.Fatalf("expected %v\n but got %v\n", expected.NamePrefixFieldSpecs(), tcfg.NamePrefixFieldSpecs())
	}
}
