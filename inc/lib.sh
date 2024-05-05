#!/usr/bin/env bash

BLUE_DEPLOY_NAME="blue-app"
GREEN_DEPLOY_NAME="green-app"
BUILD_ENV_FILE=".env.build"

update_env_var() {
    local FILE="$1"
    local VARIABLE="$2"
    local NEW_VALUE="$3"

    # Check if the variable exists in the file
    if grep -q "^${VARIABLE}=" "$FILE"; then
        # Reverse the file, update the first occurrence of the variable (which is actually the last),
        # then reverse it back to the original order.
        tac "$FILE" | sed "0,/^${VARIABLE}=/{s/^${VARIABLE}=.*/${VARIABLE}=${NEW_VALUE}/}" | tac > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"
    else
        # Append the variable if it does not exist
        echo "${VARIABLE}=${NEW_VALUE}" >> "$FILE"
    fi
}

stage_build() {
    local BUILD=$1
    if [[ "${ACTIVE_DEPLOY}" == "${BLUE_DEPLOY_NAME}" ]]; then
        # Active deploy is BLUE, so staging GREEN
        update_env_var "${BUILD_ENV_FILE}" "GREEN_DEPLOY_BUILD" "${BUILD}" # update build
        update_env_var "${BUILD_ENV_FILE}" "STAGED_DEPLOY" "${GREEN_DEPLOY_NAME}" # set the staged deploy
        update_env_var "${BUILD_ENV_FILE}" "GREEN_APP_NETWORK" "${INTERNAL_NETWORK_NAME}" # turn off the network for staged deploy
        echo "${GREEN_DEPLOY_NAME}"
    else
        # Active deploy is GREEN, so staging BLUE
        update_env_var "${BUILD_ENV_FILE}" "BLUE_DEPLOY_BUILD" "${BUILD}" # update build
        update_env_var "${BUILD_ENV_FILE}" "STAGED_DEPLOY" "${BLUE_DEPLOY_NAME}" # update the name of the staged deploy
        update_env_var "${BUILD_ENV_FILE}" "BLUE_APP_NETWORK" "${INTERNAL_NETWORK_NAME}" # turn off the network for staged deploy
        echo "${BLUE_DEPLOY_NAME}"
    fi

    # Make sure that both deploy build variables are present in the build env file
    if [[ "${BLUE_DEPLOY_BUILD}" == "" ]]; then
        update_env_var "${BUILD_ENV_FILE}" "BLUE_DEPLOY_BUILD" "${BUILD}"
    fi

    if [[ "${GREEN_DEPLOY_BUILD}" == "" ]]; then
        update_env_var "${BUILD_ENV_FILE}" "GREEN_DEPLOY_BUILD" "${BUILD}"
    fi
}

switch_deploy() {
    if [[ "${ACTIVE_DEPLOY}" == "${BLUE_DEPLOY_NAME}" ]]; then
        # Active deploy is BLUE, so we are switching to GREEN
        update_env_var "${BUILD_ENV_FILE}" "ACTIVE_DEPLOY" "${GREEN_DEPLOY_NAME}" # set the active deploy
        update_env_var "${BUILD_ENV_FILE}" "BLUE_APP_NETWORK" "${INTERNAL_NETWORK_NAME}" # turn off the network of inactive deploy
        update_env_var "${BUILD_ENV_FILE}" "GREEN_APP_NETWORK" "${VIRTUAL_NETWORK_NAME}" # turn on the network of active deploy
        echo "Switched active deploy to ${GREEN_DEPLOY_NAME}"
    else
        # Active deploy is GREEN, so we are switching to BLUE
        update_env_var "${BUILD_ENV_FILE}" "ACTIVE_DEPLOY" "${BLUE_DEPLOY_NAME}" # set the active deploy
        update_env_var "${BUILD_ENV_FILE}" "BLUE_APP_NETWORK" "${VIRTUAL_NETWORK_NAME}" # turn on the network of active deploy
        update_env_var "${BUILD_ENV_FILE}" "GREEN_APP_NETWORK" "${INTERNAL_NETWORK_NAME}" # turn off the network of inactive deploy
        echo "Switched active deploy to ${BLUE_DEPLOY_NAME}"
    fi
}

get_active_deploy_build() {
    if [[ "${ACTIVE_DEPLOY}" == "${BLUE_DEPLOY_NAME}" ]]; then
        echo "${BLUE_DEPLOY_BUILD}"
    else
        echo "${GREEN_DEPLOY_BUILD}"
    fi
}

cleanup_docker_images() {
      local IMAGE_NAME="$1"
      local KEEP_COUNT="$2"

      # Fetch all image IDs of the specified image, sorted by creation date (newest first)
      readarray -t IMAGE_IDS < <(docker images --format '{{.CreatedAt}} {{.ID}}' "$IMAGE_NAME" | sort -ru | awk '{print $5}')

      # Calculate how many images to delete
      local TOTAL_IMAGES=${#IMAGE_IDS[@]}
      local IMAGES_TO_DELETE=$((TOTAL_IMAGES - KEEP_COUNT))

      # Delete the older images, if any
      if [ "$IMAGES_TO_DELETE" -gt 0 ]; then
        for ((i=KEEP_COUNT; i<TOTAL_IMAGES; i++)); do
          docker image rm -f "${IMAGE_IDS[$i]}"
        done
      else
        echo "No images to delete. Keeping the newest $KEEP_COUNT images."
      fi
}
