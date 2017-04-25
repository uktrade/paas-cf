package acceptance_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	. "github.com/onsi/gomega/gexec"

	"github.com/cloudfoundry-incubator/cf-test-helpers/cf"
	"github.com/cloudfoundry-incubator/cf-test-helpers/generator"
	"github.com/cloudfoundry-incubator/cf-test-helpers/helpers"
)

var _ = FDescribe("request and response body sizes", func() {
	BeforeEach(func() {
		appName := generator.PrefixedRandomName("CATS-APP-")
		Expect(cf.Cf(
			"push", appName,
			"-b", config.GoBuildpackName,
			"-p", "../../example-apps/echo_request_body",
			"-d", config.AppsDomain,
			"-c", "./bin/debug_app; sleep 1; echo 'done'",
		).Wait(CF_PUSH_TIMEOUT)).To(Exit(0))
	})

	for sizekB := 1; sizekB <= 200; sizekB += 10 {
		Context(fmt.Sprintf("request body of %d kB", size), func() {
			It(fmt.Sprintf("should have response body of %d kB", size), func() {
				reqBody := make([]byte, sizekB*1000)
				for i, _ := range reqBody {
					reqBody[i] = byte('1')
				}

				curlArgs := []string{"-f", "-d", reqBody}
				respBody := helpers.CurlApp(appName, "/", curlArgs)
				Expect(respBody).To(Equal(reqBody))
			})
		})
	}
})
