#! /bin/bash
# List all apps on the platform into ./app-guids
echo "" > app-guids
total_pages=$(cf curl "/v2/apps?results-per-page=100" | jq '.total_pages')
for ((i=1; i<=$total_pages; i++))
do
    cf curl "/v2/apps?results-per-page=100&page=$i" | \
        jq -r '.resources[].metadata.guid' \
        >> app-guids
    echo "."
done

# Strip empty lines from ./app-guids
mv app-guids app-guids.null
grep -v -e '^$' app-guids.null > app-guids

# List the UUIDs of all service instances on the platform into ./service-instances
echo "" > service-instances
while read guid
do
    entities=$(cf curl "/v2/apps/$guid/service_bindings" | \
        jq -rc '.resources[].entity')
    while read entity
    do
        service_instance_guid=$(echo "${entity}" | jq -r '.service_instance_guid')
        uri=$(echo "${entity}" | jq -r '.credentials.uri')
        if [[ $uri == postgres://* ]]
        then
            echo "${service_instance_guid}" >> service-instances
        fi
    done <<< "$entities"
done < app-guids

# Strip empty lines from ./service-instances
mv service-instances service-instances.null
grep -v -e '^ *$' service-instances.null > service-instances

# Return a unique list of postgres service instance UUIDs.
cat service-instances | sort | uniq
