package scripts_test

import (
	"net/http"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
)

func mockDatadogApi() {
	respJsonPost := []byte(`{
  "tags": [
    "deployment:fake",
    "service:fake"
  ],
  "deleted": null,
  "query": "fake query",
  "message": "fake message",
  "id": 1,
  "multi": false,
  "name": "concourse continuous smoketests failures",
  "created": "1970-00-00T00:00:01.000000+00:00",
  "created_at": 1,
  "creator": {
    "id": 1,
    "handle": "fake.email@fake.com",
    "name": "Mr Fake",
    "email": "fake.email.@fake.com"
  },
  "org_id": 1,
  "modified": "1970-00-00T00:00:02.000000+00:00",
  "state": {
    "groups": {}
  },
  "overall_state": "No Data",
  "type": "query alert",
  "options": {
    "notify_audit": false,
    "locked": false,
    "silenced": {},
    "thresholds": {
      "critical": 3
    },
    "require_full_window": false,
    "new_host_delay": 300,
    "notify_no_data": false,
    "escalation_message": "Smoke test failures"
  }
}`)

	respJsonGet := []byte(`{
  "tags": [
    "deployment:fake",
    "service:fake"
  ],
  "deleted": null,
  "query": "fake query",
  "message": "fake message",
  "id": 1,
  "multi": false,
  "name": "concourse continuous smoketests failures",
  "created": "1970-00-00T00:00:01.000000+00:00",
  "created_at": 1,
  "creator": {
    "id": 1,
    "handle": "fake.email@fake.com",
    "name": "Mr Fake",
    "email": "fake.email.@fake.com"
  },
  "org_id": 1,
  "modified": "1970-00-00T00:00:02.000000+00:00",
  "state": {
    "groups": {}
  },
  "overall_state": "No Data",
  "type": "query alert",
  "options": {
    "notify_audit": false,
    "locked": false,
    "silenced": {},
    "thresholds": {
      "critical": 3
    },
    "new_host_delay": 300,
    "notify_no_data": false,
    "escalation_message": "Smoke test failures"
  }
}`)
	http.HandleFunc("/api/v1/monitor/1", func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case "GET":
			w.WriteHeader(http.StatusOK)
			w.Write(respJsonGet)
		case "PUT":
			w.WriteHeader(http.StatusOK)
			w.Write(respJsonPost)
		default:
			w.WriteHeader(http.StatusBadRequest)
		}
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
