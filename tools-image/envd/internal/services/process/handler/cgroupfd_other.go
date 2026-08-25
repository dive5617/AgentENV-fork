//go:build !linux

package handler

import "syscall"

func applyCgroupFD(_ *syscall.SysProcAttr, _ int, _ bool) {}
