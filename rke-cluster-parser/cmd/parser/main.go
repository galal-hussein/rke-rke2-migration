package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"path/filepath"

	rkecluster "github.com/rancher/rke/cluster"
	rketypes "github.com/rancher/rke/types"
	"github.com/spf13/cobra"
	"gopkg.in/yaml.v2"
)

func main() {
	rootCmd := &cobra.Command{
		Use:   "rcp",
		Short: "rke-cluster-parser converts RKE cluster configs between JSON and YAML",
		RunE: func(cmd *cobra.Command, args []string) error {
			return cmd.Help()
		},
	}

	toJSONOpts := toJSONOptions{}

	toJSONCmd := &cobra.Command{
		Use:   "to-json cluster.yaml [-o cluster.json]",
		Short: "convert an RKE cluster config from YAML to JSON",
		RunE: func(cmd *cobra.Command, args []string) error {
			if len(args) != 1 {
				return errors.New("only expected one input file argument")
			}

			inputPath, err := filepath.Abs(args[0])
			if err != nil {
				return fmt.Errorf("parse input file path: %v", err)
			}
			toJSONOpts.InputFile = inputPath

			var src io.Reader
			var dst io.Writer

			if toJSONOpts.InputFile == "-" {
				src = os.Stdin
			} else {
				if clusterFile, err := os.Open(toJSONOpts.InputFile); err != nil {
					return fmt.Errorf("failed opening input file %s: %v", toJSONOpts.InputFile, err)
				} else {
					defer clusterFile.Close()
					src = clusterFile
				}
			}

			if toJSONOpts.OutputFile == "-" {
				dst = os.Stdout
			} else {
				outputFile, err := os.Create(toJSONOpts.OutputFile)
				if err != nil {
					return fmt.Errorf("failed opening output file %s: %v", toJSONOpts.OutputFile, err)
				}
				defer outputFile.Close()
				dst = outputFile
			}

			clusterYAML, err := ioutil.ReadAll(src)
			if err != nil {
				return fmt.Errorf("failed reading YAML contents: %v", err)
			}

			cluster, err := rkecluster.ParseConfig(string(clusterYAML))
			if err != nil {
				return fmt.Errorf("failed parsing YAML: %v", err)
			}

			clusterJSON, err := json.Marshal(cluster)
			if err != nil {
				return fmt.Errorf("failed converting cluster to JSON: %v", err)
			}

			if _, err := io.Copy(dst, bytes.NewBuffer(clusterJSON)); err != nil {
				return fmt.Errorf("failed writing to output: %v", err)
			}

			return nil
		},
	}

	toJSONCmd.Flags().StringVarP(
		&toJSONOpts.OutputFile,
		"output",
		"o",
		"-",
		"specify output file; '-' outputs to stdout",
	)

	toYAMLOpts := toYAMLOptions{}

	toYAMLCmd := &cobra.Command{
		Use:     "to-yaml cluster.json [-o cluster.]",
		Short:   "convert a cluster config from JSON to YAML",
		Example: "to-yaml cluster.json",
		RunE: func(cmd *cobra.Command, args []string) error {
			if len(args) != 1 {
				return errors.New("only expected one input file argument")
			}

			inputPath, err := filepath.Abs(args[0])
			if err != nil {
				return fmt.Errorf("parse input file path: %v", err)
			}
			toYAMLOpts.InputFile = inputPath

			var src io.Reader
			var dst io.Writer

			if toYAMLOpts.InputFile == "-" {
				src = os.Stdin
			} else {
				if clusterFile, err := os.Open(toYAMLOpts.InputFile); err != nil {
					return fmt.Errorf("failed opening input file %s: %v", toJSONOpts.InputFile, err)
				} else {
					defer clusterFile.Close()
					src = clusterFile
				}
			}

			if toYAMLOpts.OutputFile == "-" {
				dst = os.Stdout
			} else {
				outputFile, err := os.Create(toYAMLOpts.OutputFile)
				if err != nil {
					return fmt.Errorf("failed opening output file %s: %v", toYAMLOpts.OutputFile, err)
				}
				defer outputFile.Close()
				dst = outputFile
			}

			clusterJSON, err := ioutil.ReadAll(src)
			if err != nil {
				return fmt.Errorf("failed reading JSON contents: %v", err)
			}

			cluster := &rketypes.RancherKubernetesEngineConfig{}
			if err := json.Unmarshal(clusterJSON, &cluster); err != nil {
				return fmt.Errorf("failed parsing JSON: %v", err)
			}

			clusterYAML, err := yaml.Marshal(cluster)
			if err != nil {
				return fmt.Errorf("failed converting cluster to YAML: %v", err)
			}

			if _, err := io.Copy(dst, bytes.NewBuffer(clusterYAML)); err != nil {
				return fmt.Errorf("failed writing to output: %v", err)
			}

			return nil
		},
	}

	toYAMLCmd.Flags().StringVarP(
		&toYAMLOpts.OutputFile,
		"output",
		"o",
		"-",
		"specify output file; '-' outputs to stdout",
	)

	rootCmd.AddCommand(toJSONCmd, toYAMLCmd)

	if err := rootCmd.Execute(); err != nil {
		fmt.Println("error: " + err.Error())
	}
}

type toJSONOptions struct {
	InputFile  string
	OutputFile string
}

type toYAMLOptions struct {
	InputFile  string
	OutputFile string
}
