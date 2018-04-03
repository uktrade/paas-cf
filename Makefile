prices.json: 050-rds-broker.yml rds_price_list.dump app_prices.json prod-plans.json elasticache_prices.json cdn_prices.json
	bundle exec ./get_prices.rb > $@

clean:
	rm -f 050-rds-broker.yml rds_price_list.dump rds_prices.yml
