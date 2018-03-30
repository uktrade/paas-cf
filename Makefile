rds_prices.json: 050-rds-broker.yml rds_price_list.dump
	bundle exec ./get_prices.rb \
	  050-rds-broker.yml \
	  < prod-plans.json \
	  > $@

050-rds-broker.yml:
	curl https://raw.githubusercontent.com/alphagov/paas-cf/staging-0.0.688/manifests/cf-manifest/manifest/050-rds-broker.yml \
	  > $@

rds_price_list.dump:
	bundle exec ruby \
	  -r amazon-pricing \
	  -e "pl=AwsPricing::RdsPriceList.new;File.write('$@', Marshal.dump(pl))"

clean:
	rm -f 050-rds-broker.yml rds_price_list.dump rds_prices.yml
