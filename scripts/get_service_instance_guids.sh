#! /bin/bash

POSTGRES_GUID=$(cf curl /v2/services | jq -r '.resources[] | select(.entity.label=="postgres") | .metadata.guid')
TOTAL_PAGES=$(cf curl '/v2/service_instances?results-per-page=100&page=1' | jq -r .total_pages)

for ((i = 1 ; i <= "${TOTAL_PAGES}" ; i++)); do 
	cf curl "/v2/service_instances?results-per-page=100&page=$i" |  \
	  jq -r --arg POSTGRES_GUID "${POSTGRES_GUID}" '.resources[] | select(.entity.service_guid==$POSTGRES_GUID) | .metadata.guid'
done

