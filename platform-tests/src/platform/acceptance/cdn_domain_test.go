package acceptance_test

import (
	"crypto/x509"
	"crypto/tls"
	"fmt"
	"github.com/alphagov/paas-cf/tools/metrics/tlscheck"


	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"


)

type CryptoConfig struct {
	tlsConfig *tls.Config
}

var _ = Describe("Strict-Transport-Security headers", func() {

	It("should serve HSTS headers from the apex domain", func() {
		appsDomain := testConfig.GetAppsDomain()
		apexDomainUrl := testConfig.Protocol() + appsDomain + "/"
		config := new(CryptoConfig)
		cert := config.getCert()
		fmt.Print(cert)

		Expect(cert).To(ContainElement(appsDomain))
		Expect(cert).To(ContainElement(apexDomainUrl))
	})

})


func (c *CryptoConfig) getCert() (*x509.Certificate) {
	appsDomain := testConfig.GetAppsDomain()
	apexDomainUrl := testConfig.Protocol() + appsDomain + "/"
	certificate, err :=tlscheck.GetCertificate(apexDomainUrl, c.tlsConfig)
	if err != nil {
		fmt.Print(err)
	}
	return certificate
}

