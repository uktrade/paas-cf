#! /bin/bash

CONFIG_FILE="/var/vcap/jobs/rds-broker/config/rds-config.json"
PASSWORD=$(python -c 'import sys, json; print json.load(sys.stdin)["password"]' < $CONFIG_FILE)
SERVICE_ID="ce71b484-d542-40f7-9dd4-5526e38c81ba" # postgres
PLAN_ID="5f2eec8a-0cad-4ab9-b81e-d6adade2fd42" # free plan

for instance_id in $(cat /tmp/instances); do
        BINDING_ID=$(cat /proc/sys/kernel/random/uuid)
        APP_GUID=$(cat /proc/sys/kernel/random/uuid)

        JSON="{\"service_id\": \""${SERVICE_ID}"\",
          \"plan_id\": \""${PLAN_ID}"\",
          \"bind_resource\": {
            \"app_guid\": \""${APP_GUID}"\"
          }
        }"

        BIND_URL=http://rds-broker:"${PASSWORD}"@127.0.0.1/v2/service_instances/"${instance_id}"/service_bindings/"${BINDING_ID}"
        BIND_HTTP_CODE=$(curl -o /tmp/"${instance_id}" -w "%{http_code}" -sL "${BIND_URL}" -d "${JSON}" -X PUT)
        if [[ "${BIND_HTTP_CODE}" != "201" ]]; then
                echo "${instance_id}" not migrated. Exit code "${BIND_HTTP_CODE}". Error message: $(cat /tmp/"${instance_id}")
                exit 1
        fi
        UNBIND_URL=http://rds-broker:"${PASSWORD}"@127.0.0.1/v2/service_instances/"${instance_id}"/service_bindings/"${BINDING_ID}"?service_id="${SERVICE_ID}"\&plan_id="${PLAN_ID}"
        UNBIND_HTTP_CODE=$(curl -o /tmp/"${instance_id}" -w "%{http_code}" -sL "${UNBIND_URL}" -X DELETE)
        if [[ "${UNBIND_HTTP_CODE}" != "200" ]] && [[ "${UNBIND_HTTP_CODE}" != "410" ]] ; then
                echo "${instance_id}" not unbound. Exit code "${UNBIND_HTTP_CODE}". Error message: $(cat /tmp/"${instance_id}". Plan ID: "${PLAN_ID}". Bind ID: "${BINDING_ID}" )
                exit 1
        fi
        rm /tmp/"${instance_id}"
        echo "${instance_id}" done
done
