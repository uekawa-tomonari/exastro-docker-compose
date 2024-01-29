#!/bin/bash

source "`dirname $0`/.env"

CURL_OPT=-sv
CONF_BASE_URL=http://127.0.0.1:${EXTERNAL_URL_MNG_PORT:-81}

if [ $# -gt 2 ]; then
    echo "Usage: `basename $0` [--retry] [organization info json file]"
    exit 1
fi

PARAM_JSON_FILE=""
PARAM_RETRY="OFF"
while [ $# -gt 0 ]
do
    if [ "$1" == "--retry" ]; then
        PARAM_RETRY="ON"
        QUERY_STRING="?retry=1"
    else
        PARAM_JSON_FILE="$1"
    fi
    shift
done

# echo "PARAM_JSON_FILE :[${PARAM_JSON_FILE}]"
# echo "PARAM_RETRY     :[${PARAM_RETRY}]"

if [ ! -z "${PARAM_JSON_FILE}" ]; then
    if [ ! -f "${PARAM_JSON_FILE}" ]; then
        echo "Error: not found organization info json file : ${PARAM_JSON_FILE}"
        exit 1
    fi
fi


if [ -z "${PARAM_JSON_FILE}" ]; then
    echo
    echo "Please enter the organization information to be created"
    echo
    read -p "organization id : " ORG_ID
    read -p "organization name : " ORG_NAME
    read -p "organization manager's username (default: admin): " ORG_MNG_USERNAME
    read -p "organization manager's email (default: admin@example.com): " ORG_MNG_EMAIL
    read -p "organization manager's first name (default: admin): " ORG_MNG_FIRST_NAME
    read -p "organization manager's last name (default: admin): " ORG_MNG_LAST_NAME
    read -p "organization manager's initial password : " ORG_MNG_PASSWORD
    read -p "organization plan id (optional) : " ORG_PLAN
    read -p "SSL Required (default: None): " SSL_REQUIRED

    if [ -n "${ORG_PLAN}" ]; then
        BODY_JSON_PLAN='"plan":{"id":"'"${ORG_PLAN}"'"},'
    else
        BODY_JSON_PLAN='"plan": {},'
    fi

    BODY_JSON=$(
        cat << EOF
        {
            "id"    :   "${ORG_ID}",
            "name"  :   "${ORG_NAME}",
            "organization_managers" : [
                {
                    "username"  :   "${ORG_MNG_USERNAME:-admin}",
                    "email"     :   "${ORG_MNG_EMAIL:-admin@example.com}",
                    "firstName" :   "${ORG_MNG_FIRST_NAME:-admin}",
                    "lastName"  :   "${ORG_MNG_LAST_NAME:-admin}",
                    "credentials"   :   [
                        {
                            "type"      :   "password",
                            "value"     :   "${ORG_MNG_PASSWORD}",
                            "temporary" :   true
                        }
                    ],
                    "requiredActions": [
                        "UPDATE_PROFILE"
                    ],
                    "enabled": true
                }
            ],
            ${BODY_JSON_PLAN}
            "options": {
                "sslRequired": "${SSL_REQUIRED:-None}"
            },
            "optionsIta": {}
        }
EOF
    )
else
    BODY_JSON=$(cat "${PARAM_JSON_FILE}")
fi

echo
USERNAME=${SYSTEM_ADMIN:-admin}
PASSWORD=${SYSTEM_ADMIN_PASSWORD}

echo
read -p "Create an organization, are you sure? (Y/other) : " CONFIRM
if [ "${CONFIRM}" != "Y" -a "${CONFIRM}" != "y" ]; then
    exit 1
fi

# echo "POST JSON:"
# echo "${BODY_JSON}"
# echo

TEMPFILE_API_RESPONSE="/tmp/`basename $0`.$$.1"
TEMPFILE_API_CODE="/tmp/`basename $0`.$$.2"

touch "${TEMPFILE_API_RESPONSE}"
touch "${TEMPFILE_API_CODE}"

curl ${CURL_OPT} -X POST \
    -u ${USERNAME}:${PASSWORD} \
    -H 'Content-type: application/json' \
    -d "${BODY_JSON}" \
    -o "${TEMPFILE_API_RESPONSE}" \
    -w '%{http_code}\n' \
    "${CONF_BASE_URL}/api/platform/organizations${QUERY_STRING}" > "${TEMPFILE_API_CODE}"

RESULT_CURL=$?
RESULT_CODE=$(cat "${TEMPFILE_API_CODE}")

which jq &> /dev/null
if [ $? -eq 0 ]; then
    cat "${TEMPFILE_API_RESPONSE}" | jq
    if [ $? -ne 0 ]; then
        cat "${TEMPFILE_API_RESPONSE}"
    fi
else
    cat "${TEMPFILE_API_RESPONSE}"
fi

rm "${TEMPFILE_API_RESPONSE}" "${TEMPFILE_API_CODE}"

cat<<_EOF_

Organization page:
  URL:                ${EXTERNAL_URL_PROTOCOL}://${EXTERNAL_URL_HOST}:${EXTERNAL_URL_PORT}/${ORG_ID}/platform/
  User:               ${ORG_MNG_USERNAME:-admin}
  Password:           ${ORG_MNG_PASSWORD}

_EOF_

if [ ${RESULT_CURL} -eq 0 -a "${RESULT_CODE}" == "200" ]; then
    exit 0
else
    exit -1
fi
