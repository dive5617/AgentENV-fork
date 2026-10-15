//go:build !linux

package cgroups

// Cgroup2Manager is a non-functional stub on non-Linux development hosts.
type Cgroup2Manager struct{}

var _ Manager = (*Cgroup2Manager)(nil)

// Cgroup2Config describes a process cgroup on platforms that cannot create it.
type Cgroup2Config struct {
	Path       string
	Properties map[string]string
}

// cgroup2Config retains caller configuration so cross-platform code can compile.
type cgroup2Config struct {
	rootPath     string
	processTypes map[ProcessType]Cgroup2Config
}

// Cgroup2ManagerOption configures the non-Linux manager stub.
type Cgroup2ManagerOption func(*cgroup2Config)

// WithCgroup2RootSysFSPath records the requested cgroup root on non-Linux hosts.
func WithCgroup2RootSysFSPath(path string) Cgroup2ManagerOption {
	return func(config *cgroup2Config) {
		config.rootPath = path
	}
}

// WithCgroup2ProcessType records a requested process cgroup on non-Linux hosts.
func WithCgroup2ProcessType(processType ProcessType, path string, properties map[string]string) Cgroup2ManagerOption {
	return func(config *cgroup2Config) {
		if config.processTypes == nil {
			config.processTypes = make(map[ProcessType]Cgroup2Config)
		}
		config.processTypes[processType] = Cgroup2Config{Path: path, Properties: properties}
	}
}

// NewCgroup2Manager returns a no-op manager for non-Linux development hosts.
func NewCgroup2Manager(_ ...Cgroup2ManagerOption) (*Cgroup2Manager, error) {
	return &Cgroup2Manager{}, nil
}

// GetFileDescriptor reports that cgroup file descriptors are unavailable.
func (c Cgroup2Manager) GetFileDescriptor(ProcessType) (int, bool) {
	return 0, false
}

// Close is a no-op because the non-Linux manager owns no file descriptors.
func (c Cgroup2Manager) Close() error {
	return nil
}
