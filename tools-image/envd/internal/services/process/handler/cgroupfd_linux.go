//go:build linux

package handler

import "syscall"

func applyCgroupFD(attr *syscall.SysProcAttr, fd int, use bool) {
	attr.CgroupFD = fd
	attr.UseCgroupFD = use
}
