package scripts_test

import (
	"net/http"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
)

func mockDatadogApi() {
	respJson := []byte(`{
    "created": "1970-01-01T00:00:00.000000+00:00",
    "created_at": 1000000000000,
    "deleted": null,
    "id": 1,
    "message": "Test",
    "modified": "1970-01-01T00:00:00.000000+00:00",
    "multi": false,
    "name": "Fake monitor",
    "options": {
        "locked": false,
        "notify_no_data": false,
        "require_full_window": false,
        "silenced": {}
    },
    "org_id": 1,
    "overall_state": "No Data",
    "query": "fake_query",
    "tags": [
        "service:fake_monitors",
        "deployment: fake_tag"
    ],
    "type": "metric alert"
}`)

	http.HandleFunc("/api/v1/monitor/1", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(respJson))
	})
	err := http.ListenAndServe("127.0.0.1:8080", nil)
	Expect(err).ToNot(HaveOccurred())
}

func TestScripts(t *testing.T) {
	RegisterFailHandler(Fail)

	BeforeSuite(func() {
		go mockDatadogApi()
	})

	AfterSuite(func() {
	})
	RunSpecs(t, "Scripts Suite")
}
