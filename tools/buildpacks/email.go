package main

import (
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"strings"

	yaml "gopkg.in/yaml.v2"
)

func toSet(input []string) map[string]bool {
	set := map[string]bool{}
	for _, item := range input {
		set[item] = true
	}
	return set
}

func difference(as, bs []string) (differences []string) {
	asSet := toSet(as)
	bsSet := toSet(bs)
	for aKey := range asSet {
		if _, ok := bsSet[aKey]; !ok {
			differences = append(differences, aKey)
		}
	}
	return differences
}

func dependencyVersionsByName(dependencies []Dependency) (dependencyVersionsByName map[string][]string) {
	dependencyVersionsByName = map[string][]string{}
	for _, dependency := range dependencies {
		dependencyVersionsByName[dependency.Name] = append(dependencyVersionsByName[dependency.Name], dependency.Version)
	}
	return dependencyVersionsByName
}

func main() {
	var (
		oldFilePath = flag.String("old", "", "Old file")
		newFilePath = flag.String("new", "", "New file")
	)
	flag.Parse()

	if *oldFilePath == "" {
		flag.Usage()
		log.Fatal("oldfile must be set")
	}
	if *newFilePath == "" {
		flag.Usage()
		log.Fatal("newfile must be set")
	}

	oldFileData, err := ioutil.ReadFile(*oldFilePath)
	if err != nil {
		log.Fatalf("oldFileData cannot be read from %s: %v", *oldFilePath, err)
	}
	newFileData, err := ioutil.ReadFile(*newFilePath)
	if err != nil {
		log.Fatalf("newFileData cannot be read from %s: %v", *newFilePath, err)
	}
	oldBuildpacks := Buildpacks{}
	err = yaml.Unmarshal(oldFileData, &oldBuildpacks)

	newBuildpacks := Buildpacks{}
	err = yaml.Unmarshal(newFileData, &newBuildpacks)

	for idx, newBuildpack := range newBuildpacks.Buildpacks {
		oldBuildpack := oldBuildpacks.Buildpacks[idx]

		oldDependenciesByName := dependencyVersionsByName(oldBuildpack.Dependencies)
		newDependenciesByName := dependencyVersionsByName(newBuildpack.Dependencies)

		additionsByName := map[string][]string{}
		removalsByName := map[string][]string{}
		for name, versions := range oldDependenciesByName {
			removalsByName[name] = difference(versions, newDependenciesByName[name])
		}
		for name, versions := range newDependenciesByName {
			additionsByName[name] = difference(versions, oldDependenciesByName[name])
		}

		// TODO build a struct and yaml marshal it instead of printing
		fmt.Printf("%s (%s):\n", newBuildpack.Name, newBuildpack.Stack)
		fmt.Printf("  old: %s\n", oldBuildpack.Version)
		fmt.Printf("  new: %s\n", newBuildpack.Version)
		if len(additionsByName)+len(removalsByName) == 0 {
			fmt.Printf(
				"  # TODO - check these manually - https://github.com/cloudfoundry/%s/releases/\n",
				newBuildpack.RepoName,
			)
			fmt.Println("  added_dependencies: {}")
			fmt.Println("  removed_dependencies: {}")
			fmt.Println()
		} else {
			fmt.Printf("  added_dependencies:\n")
			for name, additions := range additionsByName {
				if len(additions) != 0 {
					fmt.Printf("    %s: %s\n", name, strings.Join(additions, ", "))
				}
			}
			fmt.Printf("  removed_dependencies:\n")
			for name, removals := range removalsByName {
				if len(removals) != 0 {
					fmt.Printf("    %s: %s\n", name, strings.Join(removals, ", "))
				}
			}
			fmt.Println()
		}
	}
}
