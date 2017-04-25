package acceptance_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	. "github.com/onsi/gomega/gexec"

	"github.com/cloudfoundry-incubator/cf-test-helpers/cf"
	"github.com/cloudfoundry-incubator/cf-test-helpers/generator"
	"github.com/cloudfoundry-incubator/cf-test-helpers/helpers"

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
			reqBody := make([]byte, sizekB*1000)
			for i, _ := range reqBody {
				reqBody[i] = byte('1')
			}

			respBody := helpers.CurlApp(appName, "/", "-f", "-d", fmt.Sprint(reqBody))
			Expect(respBody).To(Equal(reqBody))
		}
	})
})
