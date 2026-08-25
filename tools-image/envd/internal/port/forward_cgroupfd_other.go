//go:build !linux

package port

import "syscall"

func applyCgroupFD(_ *syscall.SysProcAttr, _ int, _ bool) {}
