#!/bin/bash

USER_ADC_SECRET_NAME=${USER_ADC_SECRET_NAME:?USER_ADC_SECRET_NAME is not set.}
echo '--- [Cloud Batch Task Start - User Cred Workaround] ---'
echo '1. Fetching user credentials from Secret Manager...'
gcloud secrets versions access latest --secret="$USER_ADC_SECRET_NAME" --project="docker-rlef-exploration" > /tmp/user_adc.json
chmod 600 /tmp/user_adc.json # Good practice for credential files

echo '2. Setting GOOGLE_APPLICATION_CREDENTIALS environment variable...'
export GOOGLE_APPLICATION_CREDENTIALS=/tmp/user_adc.json

echo '3. Verifying authentication (should show YOUR user account)...'
gcloud auth list

# Capture the active account WITHIN the container's shell
ACTIVE_ACCOUNT=$(gcloud config get-value account)
echo "Active Account for Task: ${ACTIVE_ACCOUNT}"

MODEL_NAME=${MODEL:-'gemini/gemini-2.5-flash-preview-05-20'}
GEMINI_API_KEY=${GEMINI_API_KEY:?GEMINI_API_KEY is not set.}
API_BASE=${API_BASE:-'https://generativelanguage.googleapis.com'}

INSTANCES_TYPE=${INSTANCES_TYPE:-'swe_bench'}
INSTANCES_SUBSET=${INSTANCES_SUBSET:-'lite'}
INSTANCES_SPLIT=${INSTANCES_SPLIT:-'dev'}
INSTANCES_SLICE=${INSTANCES_SLICE:-'0:1'}
INSTANCES_SHUFFLE=${INSTANCES_SHUFFLE:-'False'}

# Create the directory to store trajectories.
RUN_ID=${RUN_ID:-sweagent-$(date +%Y%m%d%H%M%S)}
SHARD_ID=${SHARD_ID:-'0'}
export SWE_AGENT_TRAJECTORY_DIR="./trajectories/${RUN_ID}/${SHARD_ID}"
mkdir -p "${SWE_AGENT_TRAJECTORY_DIR}"

echo 'MODEL_NAME: '${MODEL_NAME}''
echo 'API_BASE: '${API_BASE}''

echo 'INSTANCES_TYPE: '${INSTANCES_TYPE}''
echo 'INSTANCES_SUBSET: '${INSTANCES_SUBSET}''
echo 'INSTANCES_SPLIT: '${INSTANCES_SPLIT}''
echo 'INSTANCES_SLICE: '${INSTANCES_SLICE}''
echo 'INSTANCES_SHUFFLE: '${INSTANCES_SHUFFLE}''

echo 'HF_HOME: '${HF_HOME}''
echo 'HF_DATASETS_CACHE: '${HF_DATASETS_CACHE}''

echo 'RUN_ID: '${RUN_ID}''
echo 'SHARD_ID: '${SHARD_ID}''
echo 'SWE_AGENT_TRAJECTORY_DIR: '${SWE_AGENT_TRAJECTORY_DIR}''

# Run evaluation. See README at
# https://github.com/SWE-agent/SWE-agent/blob/main/docs/usage/batch_mode.md#a-first-example-swe-bench.
sweagent run-batch \
    --config config/gemini.yaml \
    --agent.model.name "$MODEL_NAME" \
    --agent.model.api_key "$GEMINI_API_KEY" \
    --instances.type "$INSTANCES_TYPE"  \
    --instances.subset "$INSTANCES_SUBSET" \
    --instances.split "$INSTANCES_SPLIT" \
    --instances.slice "$INSTANCES_SLICE" \
    --instances.shuffle "$INSTANCES_SHUFFLE" \
    --agent.model.api_base "$API_BASE" \
    --agent.model.per_instance_cost_limit 0.0
