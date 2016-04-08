package acceptance_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	. "github.com/onsi/gomega/gexec"

	"github.com/cloudfoundry-incubator/cf-test-helpers/cf"
	"github.com/cloudfoundry-incubator/cf-test-helpers/helpers"
)

var _ = Describe("Connection reliability", func() {
    appName := "connection-reliability"

	It("should start testing successfully", func() {
		Expect(cf.Cf(
			"push", appName,
			"-b", config.GoBuildpackName,
			"-p", "../../example_apps/pollingServer",
			"-d", config.AppsDomain,
			"-c", "./bin/src; sleep 1; echo 'done'",
		).Wait(CF_PUSH_TIMEOUT)).To(Exit(0))

		response := helpers.CurlApp(appName, "/start")
		Expect(response).To(Equal("Started"))
	})

	It("should end testing and indicate that no connections failed", func() {
		response := helpers.CurlApp(appName, "/stop")
		Expect(response).To(Equal("OK"))
	})
})
