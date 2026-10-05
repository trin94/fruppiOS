#!/usr/bin/env bash
# Publishes a tested image to ghcr. Only runs in GitHub Actions, through the
# action next to it. Each phase is idempotent, so a re-run starts from the top.
set -euo pipefail

if [[ ${GITHUB_ACTIONS:-} != true ]]; then
    echo "publish.sh only runs in GitHub Actions" >&2
    exit 1
fi
for var in IMAGE TESTED_IMAGE SIGNING_KEY REGISTRY_TOKEN GITHUB_ACTOR GITHUB_SHA RUNNER_TEMP GITHUB_WORKSPACE; do
    if [[ -z ${!var:-} ]]; then
        echo "publish.sh needs ${var}" >&2
        exit 1
    fi
done

export REGISTRY_AUTH_FILE="${RUNNER_TEMP}/auth.json"
sha_tag=
digest=

login() {
    echo "$REGISTRY_TOKEN" | podman login --authfile "$REGISTRY_AUTH_FILE" ghcr.io -u "$GITHUB_ACTOR" --password-stdin
    echo "$REGISTRY_TOKEN" | cosign login ghcr.io -u "$GITHUB_ACTOR" --password-stdin
}

# the commit tag goes first, nobody tracks it, so no tracked tag points at an unsigned image
push_commit_tag() {
    sha_tag=$(podman images --format '{{.Repository}}:{{.Tag}}' --filter "reference=${IMAGE}:${GITHUB_SHA::7}-*")
    podman manifest push --all --compression-format=gzip \
        --digestfile "${RUNNER_TEMP}/digest" "$sha_tag" "docker://${sha_tag}"
    digest=$(<"${RUNNER_TEMP}/digest")
}

# legacy signature format, containers/image only reads .sig tags
sign() {
    COSIGN_PASSWORD="" COSIGN_YES=true cosign sign --key=env://SIGNING_KEY \
        --new-bundle-format=false --use-signing-config=false \
        --recursive "${IMAGE}@${digest}"
    cosign verify --key="${GITHUB_WORKSPACE}/cosign.pub" "${IMAGE}@${digest}"
}

push_other_tags() {
    local tag
    podman images --format '{{.Repository}}:{{.Tag}}' --filter "reference=${IMAGE}" |
        while read -r tag; do
            [[ $tag == "$sha_tag" ]] && continue
            podman manifest exists "$tag" 2>/dev/null || continue
            skopeo copy --all --preserve-digests "docker://${IMAGE}@${digest}" "docker://${tag}"
        done
}

# the image is already out, a failure here can only turn the run red
pull_with_policy() {
    local policy="${RUNNER_TEMP}/policy" container
    mkdir -p "$policy"
    container=$(podman create "$TESTED_IMAGE")
    podman cp "${container}:/etc/containers/policy.json" "${policy}/policy.json"
    podman cp "${container}:/etc/containers/registries.d" "${policy}/registries.d"
    podman cp "${container}:/etc/pki/containers/fruppios.pub" "${policy}/fruppios.pub"
    podman rm "$container"
    jq -e --arg repo "$IMAGE" '.transports.docker[$repo][0].type == "sigstoreSigned"' "${policy}/policy.json"
    sudo install -Dm644 "${policy}/fruppios.pub" /etc/pki/containers/fruppios.pub
    skopeo --policy "${policy}/policy.json" --registries.d "${policy}/registries.d" \
        copy "docker://${IMAGE}@${digest}" containers-storage:localhost/fruppios-sigcheck:latest
}

# phase <title> <function>
phase() {
    echo "::group::${1}"
    "$2"
    echo "::endgroup::"
}

phase "Log in to ghcr" login
phase "Push commit tag" push_commit_tag
phase "Sign and verify" sign
phase "Push other tags" push_other_tags
phase "Pull with the image's signature policy" pull_with_policy
