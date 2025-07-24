#!/bin/bash

# Exit on error.
set -e

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

MODEL_NAME=${MODEL:-'gemini/gemini-2.5-pro'}
GEMINI_API_KEY=${GEMINI_API_KEY:?GEMINI_API_KEY is not set.}
API_BASE=${API_BASE:-'https://generativelanguage.googleapis.com'}

CONFIG=${CONFIG:-'config/default_multilingual.yaml'} 

INSTANCES_TYPE=${INSTANCES_TYPE:-'swe_bench'}
INSTANCES_SUBSET=${INSTANCES_SUBSET:-'multilingual'}
INSTANCES_SPLIT=${INSTANCES_SPLIT:-'test'}
INSTANCES_SLICE=${INSTANCES_SLICE:-'0:1'}
INSTANCES_SHUFFLE=${INSTANCES_SHUFFLE:-'False'}

MAX_INPUT_TOKENS=${MAX_INPUT_TOKENS:-1048576}
MAX_OUTPUT_TOKENS=${MAX_OUTPUT_TOKENS:-65535}
PER_INSTANCE_CALL_LIMIT=${PER_INSTANCE_CALL_LIMIT:-100}

SCORE_USING_SWE_BENCH=${SCORE_USING_SWE_BENCH:-'True'}

# Create the directory to store trajectories.
RUN_ID=${RUN_ID:-$USER-$(date +"%Y%m%d%H%M%S")-sweagent}
SHARD_ID=${SHARD_ID:-'0'}
export SWE_AGENT_TRAJECTORY_DIR="trajectories/${RUN_ID}/${SHARD_ID}"
mkdir -p "${SWE_AGENT_TRAJECTORY_DIR}"

echo 'MODEL_NAME: '${MODEL_NAME}''
echo 'API_BASE: '${API_BASE}''

echo 'INSTANCES_TYPE: '${INSTANCES_TYPE}''
echo 'INSTANCES_SUBSET: '${INSTANCES_SUBSET}''
echo 'INSTANCES_SPLIT: '${INSTANCES_SPLIT}''
echo 'INSTANCES_SLICE: '${INSTANCES_SLICE}''
echo 'INSTANCES_SHUFFLE: '${INSTANCES_SHUFFLE}''

echo 'MAX_INPUT_TOKENS: '${MAX_INPUT_TOKENS}''
echo 'MAX_OUTPUT_TOKENS: '${MAX_OUTPUT_TOKENS}''
echo 'PER_INSTANCE_CALL_LIMIT: '${PER_INSTANCE_CALL_LIMIT}''

echo 'HF_HOME: '${HF_HOME}''
echo 'HF_DATASETS_CACHE: '${HF_DATASETS_CACHE}''

echo 'RUN_ID: '${RUN_ID}''
echo 'SHARD_ID: '${SHARD_ID}''
echo 'SWE_AGENT_TRAJECTORY_DIR: '${SWE_AGENT_TRAJECTORY_DIR}''

echo 'SCORE_USING_SWE_BENCH: '${SCORE_USING_SWE_BENCH}''

# Run evaluation. See README at
# https://github.com/SWE-agent/SWE-agent/blob/main/docs/usage/batch_mode.md#a-first-example-swe-bench.
sweagent run-batch \
    --config "$CONFIG" \
    --agent.model.name "$MODEL_NAME" \
    --agent.model.api_key "$GEMINI_API_KEY" \
    --agent.model.max_input_tokens $MAX_INPUT_TOKENS \
    --agent.model.max_output_tokens $MAX_OUTPUT_TOKENS \
    --instances.type "$INSTANCES_TYPE"  \
    --instances.subset "$INSTANCES_SUBSET" \
    --instances.split "$INSTANCES_SPLIT" \
    --instances.slice "$INSTANCES_SLICE" \
    --instances.shuffle "$INSTANCES_SHUFFLE" \
    --agent.model.api_base "$API_BASE" \
    --agent.model.per_instance_call_limit $PER_INSTANCE_CALL_LIMIT \
    --agent.model.per_instance_cost_limit 0.0

if [[ "${SCORE_USING_SWE_BENCH,,}" == "false" || "${INSTANCES_SUBSET}" == "multimodal" ]]; then
    echo "Skipping scoring using SWE-bench as per configuration."
    exit 0
fi

# Dynamically find the path to the predictions file.
echo "Searching for prediction file in '${SWE_AGENT_TRAJECTORY_DIR}'..."
PREDS_JSON_PATH=$(find "${SWE_AGENT_TRAJECTORY_DIR}" -type f -name "preds.json")

# Check if the file was found
if [ -z "$PREDS_JSON_PATH" ]; then
    echo "Error: Could not find 'preds.json' in '${SWE_AGENT_TRAJECTORY_DIR}'" >&2
    exit 1
fi

echo "Found prediction file: ${PREDS_JSON_PATH}"

declare -A INSTANCES_SUBSET_TO_DATASET_NAME=(
    ["multilingual"]="SWE-bench/SWE-bench_Multilingual"
    ["multimodal"]="princeton-nlp/SWE-bench_Multimodal"
    ["verified"]="princeton-nlp/SWE-bench_Verified"
    ["lite"]="princeton-nlp/SWE-bench_Lite"
)

cd SWE-bench
echo 'Scoring using SWE-bench...'
python -m swebench.harness.run_evaluation \
    --dataset_name=${INSTANCES_SUBSET_TO_DATASET_NAME[${INSTANCES_SUBSET}]} \
    --split="$INSTANCES_SPLIT" \
    --predictions_path="../${PREDS_JSON_PATH}" \
    --run_id="$RUN_ID"

echo "Searching for the .json report file..."
# Find a file in the current directory (.) that ends with .json.
# -maxdepth 1 is crucial to prevent it from searching in subdirectories like ./logs.
REPORT_FILE=$(find . -maxdepth 1 -type f -name "*.json")

# Check if the find command actually found a file before trying to copy it.
if [ -n "$REPORT_FILE" ]; then
    echo "Found report file: $REPORT_FILE"
    # The quotes around "$REPORT_FILE" handle cases where the filename might have spaces.
    cp "$REPORT_FILE" "../${SWE_AGENT_TRAJECTORY_DIR}/report.json"
else
    echo "Warning: No .json report file was found in the current directory."
fi