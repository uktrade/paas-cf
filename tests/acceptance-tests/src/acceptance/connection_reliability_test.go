package acceptance_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	. "github.com/onsi/gomega/gexec"

	"github.com/cloudfoundry-incubator/cf-test-helpers/cf"
	"github.com/cloudfoundry-incubator/cf-test-helpers/helpers"
	"os"
)

var _ = Describe("Connection reliability", func() {
	appName := "connection-reliability"

	It("should start testing successfully", func() {
		if os.Getenv("DISABLE_ENV_SETUP") != "" {
			Skip("Not testing start as connection reliability test is probably stopping")
		}

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
		if os.Getenv("DISABLE_ENV_TEARDOWN") != "" {
			Skip("Not testing stop as connection reliability test is probably starting")
		}
		response := helpers.CurlApp(appName, "/stop")
		Expect(response).To(Equal("OK"))
	})
})
