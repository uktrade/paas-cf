package main

import (
	"flag"
	"fmt"
	"io/ioutil"
	"log"

	yaml "gopkg.in/yaml.v2"
)

func stringifyDependencies(input []Dependency) (result []string) {
	for _, dependency := range input {
		result = append(result, fmt.Sprintf("%s %s", dependency.Name, dependency.Version))
	}
	return result
}

func keys(input map[string]bool) (result []string) {
	for key := range input {
		result = append(result, key)
	}
	return result
}

func toSet(dependencies []string) map[string]bool {
	dependencySet := map[string]bool{}
	for _, dependency := range dependencies {
		dependencySet[dependency] = true
	}
	return dependencySet
}

func difference(as, bs []string) (differences []string) {
	uniqueAs := keys(toSet(as))
	bsSet := toSet(bs)
	for _, x := range uniqueAs {
		if _, ok := bsSet[x]; !ok {
			differences = append(differences, x)
		}
	}
	return differences
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

		oldDependencies := stringifyDependencies(oldBuildpack.Dependencies)
		newDependencies := stringifyDependencies(newBuildpack.Dependencies)
		removals := difference(oldDependencies, newDependencies)
		additions := difference(newDependencies, oldDependencies)

		fmt.Printf("%s (%s):\n", newBuildpack.Name, newBuildpack.Stack)
		fmt.Print("Removed: ")
		for _, removal := range removals {
			fmt.Printf("%s, ", removal)
		}
		fmt.Println()
		fmt.Print("Added: ")
		for _, addition := range additions {
			fmt.Printf("%s, ", addition)
		}
		fmt.Println()
		fmt.Println()
	}
}
