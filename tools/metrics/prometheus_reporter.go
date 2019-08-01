package main

// PrometheusReporter is translating events into Prometheus metrics
type PrometheusReporter struct {
	families map[string]*MetricFamily
}

type MetricFamily struct {
	Name    string
	Members []Metric
}

func (f MetricFamily) FindMetric(m Metric) (*Metric, *int) {
	for i, member := range f.Members {
		if member.Equals(m) {
			return &member, &i
		}
	}

	return nil, nil
}

// NewPrometheusReporter creates a new PrometheusReporter instance
func NewPrometheusReporter() *PrometheusReporter {
	return &PrometheusReporter{
		families: map[string]*MetricFamily{},
	}
}

// WriteMetrics converts the received metrics into Prometheus metrics.
// Any metrics are registered in the Prometheus registry the first time they created and we update these metrics later.
// This way we can manage counters correctly.
func (p *PrometheusReporter) WriteMetrics(events []Metric) error {
	for _, evt := range events {
		family, found := p.families[evt.Name]
		if !found {
			family = &MetricFamily{
				Name:    evt.Name,
				Members: []Metric{},
			}

			p.families[evt.Name] = family
		}

		foundMetric, foundMetricIndex := family.FindMetric(evt)
		if foundMetric == nil {
			family.Members = append(family.Members, evt)
		} else {
			family.Members = append(
				family.Members[:*foundMetricIndex],
				family.Members[*foundMetricIndex+1:]...,
			)
			family.Members = append(family.Members, evt)
		}
	}

	return nil

	//var errs error
	//for _, event := range events {
	//	labels := prometheus.Labels{}
	//	labelNames := make([]string, len(event.Tags))
	//	for i, tag := range event.Tags {
	//		labelNames[i] = tag.Label
	//		labels[tag.Label] = tag.Value
	//	}
	//
	//
	//	metricName := strings.Replace(event.Name, ".", "_", -1)
	//
	//	if event.Unit != "" {
	//		if !strings.HasSuffix(metricName, event.Unit) {
	//			metricName = metricName + "_" + strings.ToLower(event.Unit)
	//		}
	//	}
	//
	//	switch event.Kind {
	//	case Counter:
	//		vec, exists := p.metricVecs[event.Name]
	//		if !exists {
	//			counterVec := prometheus.NewCounterVec(prometheus.CounterOpts{
	//				Namespace: "paas",
	//				Name:      metricName,
	//			}, labelNames)
	//			p.registry.MustRegister(counterVec)
	//			p.metricVecs[event.Name] = counterVec
	//			vec = counterVec
	//		}
	//
	//		metric, err := vec.(*prometheus.CounterVec).GetMetricWith(labels)
	//		if err != nil {
	//			errs = multierror.Append(err)
	//			continue
	//		}
	//
	//		metric.Add(event.Value)
	//	case Gauge:
	//		vec, exists := p.metricVecs[event.Name]
	//		if !exists {
	//			gaugeVec := prometheus.NewGaugeVec(prometheus.GaugeOpts{
	//				Namespace: "paas",
	//				Name:      metricName,
	//			}, labelNames)
	//			p.registry.MustRegister(gaugeVec)
	//			p.metricVecs[event.Name] = gaugeVec
	//			vec = gaugeVec
	//		}
	//
	//		metric, err := vec.(*prometheus.GaugeVec).GetMetricWith(labels)
	//		if err != nil {
	//			errs = multierror.Append(err)
	//			continue
	//		}
	//		metric.Set(event.Value)
	//	}
	//}
	//
	//return errs
}
