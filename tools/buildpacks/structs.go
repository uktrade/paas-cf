package main

type Buildpack struct {
	Name         string       `yaml:"name"`
	RepoName     string       `yaml:"repo_name"`
	Stack        string       `yaml:"stack"`
	Version      string       `yaml:"version"`
	Sha          string       `yaml:"sha"`
	Filename     string       `yaml:"filename"`
	Url          string       `yaml:"url"`
	Dependencies []Dependency `yaml:"dependencies"`
}

type Buildpacks struct {
	Buildpacks []Buildpack `yaml:"buildpacks"`
}

type DefaultVersion struct {
	Name    string `yaml:"name"`
	Version string `yaml:"version"`
}

type Dependency struct {
	Name    string   `yaml:"name"`
	Version string   `yaml:"version"`
	Stacks  []string `yaml:"cf_stacks"`
}

type Manifest struct {
	DefaultVersions []DefaultVersion `yaml:"default_versions"`
	Dependencies    []Dependency     `yaml:"dependencies"`
}

type Changes struct {
	Removals  []Dependency
	Additions []Dependency
}

type Difference struct {
	Present bool
	Dep     string
}
