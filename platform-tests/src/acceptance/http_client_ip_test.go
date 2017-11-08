package acceptance_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	. "github.com/onsi/gomega/gexec"

	"github.com/cloudfoundry-incubator/cf-test-helpers/cf"
	"github.com/cloudfoundry-incubator/cf-test-helpers/generator"
	"github.com/cloudfoundry-incubator/cf-test-helpers/helpers"

	"encoding/json"
	"fmt"
	"io/ioutil"
	"net"
	"net/http"
	"strings"
)

var _ = Describe("Client IP headers", func() {
	const (
		egressURL   = "https://icanhazip.com/"
		fakeProxyIP = "1.2.3.4"
	)

	var (
		egressIP string
		headers  struct {
			X_Forwarded_For []string `json:"X-Forwarded-For"`
			X_Real_IP       []string `json:"X-Real-IP"`
		}
	)

	BeforeEach(func() {
		resp, err := http.Get(egressURL)
		Expect(err).ToNot(HaveOccurred(), "Unable to get egress IP from %s", egressURL)
		defer resp.Body.Close()

		body, err := ioutil.ReadAll(resp.Body)
		Expect(err).ToNot(HaveOccurred())
		egressIP = strings.TrimSpace(fmt.Sprintf("%s", body))
		Expect(net.ParseIP(egressIP)).ToNot(BeNil(), "Unable to parse egress IP from %s: %s", egressURL, egressIP)

		appName := generator.PrefixedRandomName("CATS-APP-")
		Expect(cf.Cf(
			"push", appName,
			"-p", "../../example-apps/http_tester",
			"-f", "../../example-apps/http_tester/manifest.yml",
			"-d", config.AppsDomain,
		).Wait(CF_PUSH_TIMEOUT)).To(Exit(0))

		curlArgs := []string{"-f", "-H", fmt.Sprintf("X-Forwarded-For: %s", fakeProxyIP)}
		jsonData := helpers.CurlApp(appName, "/print-headers", curlArgs...)

		err = json.Unmarshal([]byte(jsonData), &headers)
		Expect(err).NotTo(HaveOccurred())
	})

	It("should append real egress IP to existing X-Forwarded-For request header", func() {
		Expect(headers.X_Forwarded_For).To(HaveLen(1))

		xffNoWhitespace := strings.Replace(headers.X_Forwarded_For[0], " ", "", -1)
		xffIPs := strings.Split(xffNoWhitespace, ",")

		Expect(xffIPs).To(HaveLen(3))
		Expect(xffIPs[0]).To(Equal(fakeProxyIP))
		Expect(xffIPs[1]).To(Equal(egressIP))

		elbIP := xffIPs[2]
		Expect(inPrivateV4Subnet(elbIP)).To(BeTrue())
	})

	It("should only contain real egress IP in X-Real-IP request header", func() {
		Expect(headers.X_Real_IP).To(HaveLen(1))
		Expect(headers.X_Real_IP).To(ConsistOf(
			egressIP,
		))
	})
})

type ipRange struct {
	start net.IP
	end   net.IP
}

func (r ipRange) contains(ipAddress net.IP) bool {
	// strcmp type byte comparison
	if bytes.Compare(ipAddress, r.start) >= 0 && bytes.Compare(ipAddress, r.end) < 0 {
		return true
	}
	return false
}

var privateRanges = []ipRange{
	ipRange{
		start: net.ParseIP("10.0.0.0"),
		end:   net.ParseIP("10.255.255.255"),
	},
	ipRange{
		start: net.ParseIP("100.64.0.0"),
		end:   net.ParseIP("100.127.255.255"),
	},
	ipRange{
		start: net.ParseIP("172.16.0.0"),
		end:   net.ParseIP("172.31.255.255"),
	},
	ipRange{
		start: net.ParseIP("192.0.0.0"),
		end:   net.ParseIP("192.0.0.255"),
	},
	ipRange{
		start: net.ParseIP("192.168.0.0"),
		end:   net.ParseIP("192.168.255.255"),
	},
	ipRange{
		start: net.ParseIP("198.18.0.0"),
		end:   net.ParseIP("198.19.255.255"),
	},
}

func inPrivateV4Subnet(ipAddress net.IP) bool {
	// my use case is only concerned with ipv4 atm
	if ipCheck := ipAddress.To4(); ipCheck != nil {
		for _, privateRange := range privateRanges {
			if privateRange.contains(ipAddress) {
				return true
			}
		}
	}
	return false
}
