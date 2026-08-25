//go:build linux

package port

import "syscall"

func applyCgroupFD(attr *syscall.SysProcAttr, fd int, use bool) {
	attr.CgroupFD = fd
	attr.UseCgroupFD = use
}
