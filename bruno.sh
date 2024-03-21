#!/bin/bash

dependencies=(az jq)
local_env_file="$(dirname "$0")/.env"

if [[ -f "$local_env_file" ]]; then
    source "$local_env_file"
else
    echo "No .env file found. Please create one with your FEED_PATH, COMMON_SCOPE, PROD_SCOPE, DEV_URL, TEST_URL, and PROD_URL set."
    exit 1
fi

if [[ -z "$FEED_PATH" ]] || [[ -z "$COMMON_SCOPE" ]] || [[ -z "$PROD_SCOPE" ]]; then
    echo "One or more required settings (FEED_PATH, COMMON_SCOPE, PROD_SCOPE) are not set in .env. Please set them to continue."
    sleep 5
    exit 2
fi

function check_for_dependencies {
    for dep in "${dependencies[@]}"; do
        command -v $dep &> /dev/null || { echo "$dep not found."; exit 1; }
    done
    
    az account show &> /dev/null || { echo "Login to Azure."; exit 1; }
}

function prompt_for_environment {
    PS3="Choose an environment: "
    select opt in "DEV" "TEST" "PROD"; do
        case $opt in
            DEV) ENV_URL="$DEV_URL"; SCOPE="$COMMON_SCOPE"; break ;;
            TEST) ENV_URL="$TEST_URL"; SCOPE="$COMMON_SCOPE"; break ;;
            PROD) ENV_URL="$PROD_URL"; SCOPE="$PROD_SCOPE"; break ;;
            *) echo "Invalid option. Please try again."; continue ;;
        esac
    done
}

function fetch_token {
    az account get-access-token --scope "$SCOPE" > /tmp/az.json || { echo "Token fetch failed."; exit 1; }
    token=$(jq -r .accessToken /tmp/az.json)
    expires_on=$(jq -r '.expiresOn' /tmp/az.json)

    [ -n "$token" ] || { echo "Token empty."; exit 1; }

    if [[ "$(uname -s)" == "Darwin" ]]; then
        sed -i '' '/^TOKEN/d' "$FEED_PATH"
        sed -i '' '/^TOKEN_EXPIRES/d' "$FEED_PATH"
    else
        sed -i '/^TOKEN/d' "$FEED_PATH"
        sed -i '/^TOKEN_EXPIRES/d' "$FEED_PATH"
    fi

    echo "TOKEN=\"$token\"" >> "$FEED_PATH"
    echo "TOKEN_EXPIRES=\"$expires_on\"" >> "$FEED_PATH"

    if [[ "$(uname -s)" == "Darwin" ]]; then
        expires_str=$(echo $expires_on | sed -E 's/\.[0-9]+//')
        expires_timestamp=$(date -j -f "%Y-%m-%d %H:%M:%S" "$expires_str" +%s)
    else
        expires_timestamp=$(date -d "$expires_on" +%s)
    fi
    current_time=$(date +%s)
    validity_in_minutes=$(( (expires_timestamp - current_time) / 60 ))

    if [[ "$(uname -s)" == "Darwin" ]]; then
        expires_CEST=$(date -r "$expires_timestamp" '+%Y-%m-%d %H:%M:%S CET')
    else
        expires_CEST=$(TZ='Europe/Oslo' date -d "@$expires_timestamp" '+%Y-%m-%d %H:%M:%S CET')
    fi
    echo "Token acquired. It is valid for $validity_in_minutes minutes (until $expires_CEST)."
    echo "Token was copied to '$FEED_PATH'."
}

check_for_dependencies
prompt_for_environment
fetch_token
