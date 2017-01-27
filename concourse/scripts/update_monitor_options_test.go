package scripts_test

import (
	"os"
	"os/exec"
	"strings"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gbytes"
	"github.com/onsi/gomega/gexec"
)

var _ = Describe("UpdateDataDogMonitor", func() {

	var (
		cmdInput string
		session  *gexec.Session
	)

	JustBeforeEach(func() {
		os.Setenv("TF_VAR_datadog_api_key", "aaaaaaaaaaaaa")
		os.Setenv("TF_VAR_datadog_app_key", "bbbbbbbbbbbbb")
		command := exec.Command("bundle", "exec", "./update_monitor_options.rb", "http://localhost:8080")
		command.Stdin = strings.NewReader(cmdInput)

		var err error
		session, err = gexec.Start(command, GinkgoWriter, GinkgoWriter)
		Expect(err).ToNot(HaveOccurred())
	})

	Context("when the require_full_window option is set to false", func() {
		BeforeEach(func() {
			cmdInput = `
{
    "version": 3,
    "terraform_version": "0.7.3",
    "serial": 5,
    "lineage": "bfa4e77c-4e4e-462e-92a9-dba07be0f409",
    "modules": [
        {
            "path": [
                "root"
            ],
            "outputs": {},
			"resources": {
				"datadog_monitor.continuous-smoketests-failures": {
					"type": "datadog_monitor",
					"depends_on": [],
					"primary": {
						"id": "1",
						"attributes": {
							"escalation_message": "Test",
							"id": "1",
							"message": "Test",
							"name": "Fake monitor",
							"notify_no_data": "false",
							"query": "fake_query",
							"require_full_window": "false",
							"tags.%": "2",
							"tags.deployment": "fake_tag",
							"tags.service": "fake_monitors",
							"thresholds.%": "1",
							"thresholds.critical": "3",
							"type": "metric alert"
						},
						"meta": {},
						"tainted": false
					},
					"deposed": [],
					"provider": ""
				}
			},
			"depends_on": []
		}
	]
}
			`
		})

		It("updates the monitor", func() {
			Eventually(session).Should(gexec.Exit(0))
			Expect(session.Out).To(gbytes.Say("Updating monitor 1 with attributes {\"require_full_window\"=>false}\n"))
		})
	})

	Context("when the require_full_window option is set to true", func() {
		BeforeEach(func() {
			cmdInput = `
{
    "version": 3,
    "terraform_version": "0.7.3",
    "serial": 5,
    "lineage": "bfa4e77c-4e4e-462e-92a9-dba07be0f409",
    "modules": [
        {
            "path": [
                "root"
            ],
            "outputs": {},
			"resources": {
				"datadog_monitor.continuous-smoketests-failures": {
					"type": "datadog_monitor",
					"depends_on": [],
					"primary": {
						"id": "1",
						"attributes": {
							"escalation_message": "Test",
							"id": "1",
							"message": "Test",
							"name": "Fake monitor",
							"notify_no_data": "false",
							"query": "fake_query",
							"require_full_window": "true",
							"tags.%": "2",
							"tags.deployment": "fake_tag",
							"tags.service": "fake_monitors",
							"thresholds.%": "1",
							"thresholds.critical": "3",
							"type": "metric alert"
						},
						"meta": {},
						"tainted": false
					},
					"deposed": [],
					"provider": ""
				}
			},
			"depends_on": []
		}
	]
}
			`
		})

		It("doesn't update the monitor", func() {
			Eventually(session).Should(gexec.Exit(0))
			Expect(session.Out).ToNot(gbytes.Say("Updating monitor 1 with attributes {\"require_full_window\"=>false}\n"))
		})
	})
})
