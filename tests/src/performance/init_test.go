package performance_test

import (
	"os"
	"testing"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry-incubator/cf-test-helpers/helpers"
)

var (
	DEFAULT_TIMEOUT      = 30 * time.Second
	CF_PUSH_TIMEOUT      = 2 * time.Minute
	LONG_CURL_TIMEOUT    = 2 * time.Minute
	CF_JAVA_TIMEOUT      = 10 * time.Minute
	DEFAULT_MEMORY_LIMIT = "256M"

	context helpers.SuiteContext
	config  helpers.Config
)

func TestSuite(t *testing.T) {
	RegisterFailHandler(Fail)

	config = helpers.LoadConfig()

	if config.DefaultTimeout > 0 {
		DEFAULT_TIMEOUT = config.DefaultTimeout * time.Second
	}
	if config.CfPushTimeout > 0 {
		CF_PUSH_TIMEOUT = config.CfPushTimeout * time.Second
	}
	if config.LongCurlTimeout > 0 {
		LONG_CURL_TIMEOUT = config.LongCurlTimeout * time.Second
	}

	if os.Getenv("DETERMINISTIC_ENV") == "" {
		context = helpers.NewPersistentAppContext(config)
	} else {
		context = helpers.NewContext(config)
	}

	environment := helpers.NewEnvironment(context)

	BeforeSuite(func() {
		if os.Getenv("DISABLE_ENV_SETUP") == "" {
			environment.Setup()
		}
	})

	AfterSuite(func() {
		if os.Getenv("DISABLE_ENV_TEARDOWN") == "" {
			environment.Teardown()
		}
	})

	RunSpecs(t, "Performance tests")
}
