#!/usr/bin/env bash

source "$(dirname $0)/common.sh"

if [ "$#" -ne 2 ]; then
    echo "Must provide a pruning index and a trial index!"
    exit 1
fi

PRUNE_INDEX="$1"
TRIAL_INDEX="$2"

ABBREVIATION_EPOCHS="9"

TRAIN_STEPS="$(expr 112590 - \( 1251 \* ${ABBREVIATION_EPOCHS} \))"
BASENAME="${NETWORK}/${BASE_PRUNE_METHOD}/${VERSION}/lottery_short_${ABBREVIATION_EPOCHS}/prune_${PRUNE_INDEX}/trial_${TRIAL_INDEX}"

if [ "${TRAIN_STEPS}" -le "${PRUNE_INDEX}" ]; then
    exit 0
fi

function name_of_seq() {
    echo "${BASENAME}/iter_$1"
}

for idx in `seq 0 ${PRUNE_ITERATIONS}`; do
    PREV_NAME="$(name_of_seq $(expr $idx - 1))"
    CURR_NAME="$(name_of_seq $idx)"

    set_prune_method "${idx}"

    if [ "$idx" -eq 0 ]; then
        extra_params=()
    else
        if is_first_attempt; then
            run_or_debug gsutil -m cp "${FS_PREFIX}/results/${PREV_NAME}/checkpoint_iter_${PRUNE_INDEX}"'*' "${FS_PREFIX}/execution_data/${CURR_NAME}/"
            run_or_debug gsutil -m cp "${FS_PREFIX}/results/${PREV_NAME}/checkpoint_iter_${PRUNE_INDEX}"'*' "${FS_PREFIX}/execution_data/${CURR_NAME}/"
            run_or_debug gsutil -m cp -r "${FS_PREFIX}/execution_data/${PREV_NAME}/graph.pbtxt" "${FS_PREFIX}/execution_data/${CURR_NAME}/"

            TEMP_CHECKPOINT="$(mktemp)"
            echo 'model_checkpoint_path: "'"checkpoint_iter_${PRUNE_INDEX}"'"' > "${TEMP_CHECKPOINT}"
            run_or_debug gsutil cp "${TEMP_CHECKPOINT}" "${FS_PREFIX}/execution_data/${CURR_NAME}/checkpoint"
            rm "${TEMP_CHECKPOINT}"
        fi

        extra_params=(
            "--lottery_reset_to" "${FS_PREFIX}/results/${PREV_NAME}/checkpoint_iter_${PRUNE_INDEX}"
            "--lottery_prune_at" "${FS_PREFIX}/results/${PREV_NAME}/checkpoint_iter_final"
        )
    fi

    run_or_debug "$(dirname $0)/run_base.sh" "${CURR_NAME}" --train_steps "${TRAIN_STEPS}" --lottery_pruning_method "${PRUNE_METHOD}" --lottery_checkpoint_iters "${PRUNE_INDEX}" "${extra_params[@]}"
done
