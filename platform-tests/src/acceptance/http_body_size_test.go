package acceptance_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	. "github.com/onsi/gomega/gexec"

	"github.com/cloudfoundry-incubator/cf-test-helpers/cf"
	"github.com/cloudfoundry-incubator/cf-test-helpers/generator"
	"github.com/cloudfoundry-incubator/cf-test-helpers/helpers"

	"bytes"
	"fmt"
)

var _ = FDescribe("request and response body sizes", func() {
	var appName string

	BeforeEach(func() {
		appName = generator.PrefixedRandomName("CATS-APP-")
		Expect(cf.Cf(
			"push", appName,
			"-b", config.GoBuildpackName,
			"-p", "../../example-apps/echo_request_body",
			"-d", config.AppsDomain,
			"-c", "./bin/debug_app; sleep 1; echo 'done'",
		).Wait(CF_PUSH_TIMEOUT)).To(Exit(0))
	})

	It("should serve request and response bodies of increasing sizes", func() {
		for sizekB := 1; sizekB <= 200; sizekB += 10 {
			By(fmt.Sprintf("body size of %d kB", sizekB))
			var (
				reqBody   bytes.Buffer
				sizeBytes = sizekB * 1000
			)

			reqBody.Grow(sizeBytes)
			for i := 1; i <= sizeBytes; i++ {
				reqBody.WriteString(fmt.Sprintf("%d", i%10))
			}

			respBody := helpers.CurlApp(appName, "/", "-f", "-d", reqBody.String())
			Expect(respBody).To(Equal(reqBody.String()))
		}
	})
})
