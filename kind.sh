#!/usr/bin/env bash

# Copyright The Helm Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

DEFAULT_KIND_VERSION=v0.11.1
DEFAULT_CLUSTER_NAME=testing
KUBECTL_VERSION=v1.20.2

show_help() {
cat << EOF
Usage: $(basename "$0") <options>

    -h, --help                              Display help
    -v, --version                           The kind version to use (default: $DEFAULT_KIND_VERSION)"
    -c, --config                            The path to the kind config file"
    -i, --node-image                        The Docker image for the cluster nodes"
    -n, --cluster-name                      The name of the cluster to create (default: chart-testing)"
    -w, --wait                              The duration to wait for the control plane to become ready (default: 60s)"
    -l, --log-level                         The log level for kind [panic, fatal, error, warning, info, debug, trace] (default: warning)

EOF
}

main() {
    local version="$DEFAULT_KIND_VERSION"
    local config=
    local node_image=
    local cluster_name="$DEFAULT_CLUSTER_NAME"
    local wait=60s
    local log_level=

    parse_command_line "$@"

    if [[ ! -d "$RUNNER_TOOL_CACHE" ]]; then
        echo "Cache directory '$RUNNER_TOOL_CACHE' does not exist" >&2
        exit 1
    fi

    local arch
    arch=$(dpkg --print-architecture)
    local cache_dir="$RUNNER_TOOL_CACHE/kind/$version/$arch"

    local kind_dir="$cache_dir/kind/bin/"
    if [[ ! -x "$kind_dir/kind" ]]; then
        install_kind
    fi

    echo 'Adding kind directory to PATH...'
    echo "$kind_dir" >> "$GITHUB_PATH"

    local kubectl_dir="$cache_dir/kubectl/bin/"
    if [[ ! -x "$kubectl_dir/kubectl" ]]; then
        install_kubectl
    fi

    echo 'Adding kubectl directory to PATH...'
    echo "$kubectl_dir" >> "$GITHUB_PATH"

    "$kind_dir/kind" version
    "$kubectl_dir/kubectl" version --client=true

    create_kind_cluster
}

parse_command_line() {
    while :; do
        case "${1:-}" in
            -h|--help)
                show_help
                exit
                ;;
            -v|--version)
                if [[ -n "${2:-}" ]]; then
                    version="$2"
                    shift
                else
                    echo "ERROR: '-v|--version' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -c|--config)
                if [[ -n "${2:-}" ]]; then
                    config="$2"
                    shift
                else
                    echo "ERROR: '--config' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -i|--node-image)
                if [[ -n "${2:-}" ]]; then
                    node_image="$2"
                    shift
                else
                    echo "ERROR: '-i|--node-image' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -n|--cluster-name)
                if [[ -n "${2:-}" ]]; then
                    cluster_name="$2"
                    shift
                else
                    echo "ERROR: '-n|--cluster-name' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -w|--wait)
                if [[ -n "${2:-}" ]]; then
                    wait="$2"
                    shift
                else
                    echo "ERROR: '--wait' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -l|--log-level)
                if [[ -n "${2:-}" ]]; then
                    log_level="$2"
                    shift
                else
                    echo "ERROR: '--log-level' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            *)
                break
                ;;
        esac

        shift
    done
}

install_kind() {
    echo 'Installing kind...'

    mkdir -p "$kind_dir"

    curl -sSLo "$kind_dir/kind" "https://github.com/kubernetes-sigs/kind/releases/download/$version/kind-linux-$arch"
    chmod +x "$kind_dir/kind"
}

install_kubectl() {
    echo 'Installing kubectl...'

    mkdir -p "$kubectl_dir"

    curl -sSLo "$kubectl_dir/kubectl" "https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/$arch/kubectl"
    chmod +x "$kubectl_dir/kubectl"
}

create_kind_cluster() {
    echo 'Creating kind cluster...'
    local args=(create cluster "--name=$cluster_name" "--wait=$wait")

    if [[ -n "$node_image" ]]; then
        args+=("--image=$node_image")
    fi

    if [[ -n "$config" ]]; then
        args+=("--config=$config")
    fi

    if [[ -n "$log_level" ]]; then
        args+=("--loglevel=$log_level")
    fi

    "$kind_dir/kind" "${args[@]}"
}

main "$@"
