package handler

import (
	"testing"

	"github.com/stretchr/testify/assert"

	rpc "github.com/e2b-dev/infra/packages/envd/internal/services/spec/process"
)

// TestCommandForExecution verifies that the opt-in policy changes only the SDK wrapper shape.
func TestCommandForExecution(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name              string
		disableLoginShell bool
		process           *rpc.ProcessConfig
		wantArgs          []string
	}{
		{
			name:              "agentenv strips SDK login shell flag",
			disableLoginShell: true,
			process:           &rpc.ProcessConfig{Cmd: "/bin/bash", Args: []string{"-l", "-c", "cargo --version"}},
			wantArgs:          []string{"-c", "cargo --version"},
		},
		{
			name:              "default envd behavior is unchanged",
			disableLoginShell: false,
			process:           &rpc.ProcessConfig{Cmd: "/bin/bash", Args: []string{"-l", "-c", "cargo --version"}},
			wantArgs:          []string{"-l", "-c", "cargo --version"},
		},
		{
			name:              "explicit long login option is unchanged",
			disableLoginShell: true,
			process:           &rpc.ProcessConfig{Cmd: "/bin/bash", Args: []string{"--login", "-c", "cargo --version"}},
			wantArgs:          []string{"--login", "-c", "cargo --version"},
		},
		{
			name:              "other commands are unchanged",
			disableLoginShell: true,
			process:           &rpc.ProcessConfig{Cmd: "/bin/sh", Args: []string{"-l", "-c", "cargo --version"}},
			wantArgs:          []string{"-l", "-c", "cargo --version"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			originalArgs := append([]string(nil), tt.process.GetArgs()...)
			cmd, args := commandForExecution(tt.process, tt.disableLoginShell)

			assert.Equal(t, tt.process.GetCmd(), cmd)
			assert.Equal(t, tt.wantArgs, args)
			assert.Equal(t, originalArgs, tt.process.GetArgs())
		})
	}
}
