package main

import (
	"flag"
	"fmt"
	"io/ioutil"
	"log"

	yaml "gopkg.in/yaml.v2"
)

func getUniqueDepStrings(dependancies []Dependency) (result []string) {
	thisisamap := map[string]string{}
	for _, dependancy := range dependancies {
		thisisamap[fmt.Sprintf("%s %s", dependancy.Name, dependancy.Version)] = ""
	}

	for key := range thisisamap {
		result = append(result, key)
	}
	return result
}

func getUniqueDepMap(dependancies []Dependency) map[string]bool {
	thisisamap := map[string]bool{}
	for _, dependancy := range dependancies {
		thisisamap[fmt.Sprintf("%s %s", dependancy.Name, dependancy.Version)] = true
	}
	return thisisamap
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
		fmt.Errorf("oldFileData cannot be read from %s: %v", oldFilePath, err)
	}
	newFileData, err := ioutil.ReadFile(*newFilePath)
	if err != nil {
		fmt.Errorf("newFileData cannot be read from %s: %v", newFilePath, err)
	}
	oldBuildpacks := Buildpacks{}
	err = yaml.Unmarshal(oldFileData, &oldBuildpacks)

	newBuildpacks := Buildpacks{}
	err = yaml.Unmarshal(newFileData, &newBuildpacks)

	for idx, newBuildpack := range newBuildpacks.Buildpacks {
		oldBuildpack := oldBuildpacks.Buildpacks[idx]

		oldDependenciesString := getUniqueDepStrings(oldBuildpack.Dependencies)
		newDependenciesMap := getUniqueDepMap(newBuildpack.Dependencies)
		oldDependenciesMap := getUniqueDepMap(oldBuildpack.Dependencies)
		newDependenciesString := getUniqueDepStrings(newBuildpack.Dependencies)

		added := []string{}
		differences := []Difference{}
		for _, x := range oldDependenciesString {
			if _, ok := newDependenciesMap[x]; !ok {
				added = append(added, x)
				differences = append(differences, Difference{
					Dep:     x,
					Present: false,
				})

			}
		}
		for _, x := range newDependenciesString {
			if _, ok := oldDependenciesMap[x]; !ok {
				added = append(added, x)
				differences = append(differences, Difference{
					Dep:     x,
					Present: true,
				})

			}
		}

		fmt.Printf("%s:\n", newBuildpack.Name)
		for _, difference := range differences {
			if !difference.Present {
				fmt.Printf("[- %s]", difference.Dep)
			}
			if difference.Present {
				fmt.Printf("[+ %s]", difference.Dep)
			}
		}
		fmt.Println()

		// }
	}
}
