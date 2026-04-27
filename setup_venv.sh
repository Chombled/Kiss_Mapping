#!/usr/bin/env bash

set -euo pipefail

readonly ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly DEFAULT_MAP_CLOSURES_REF="81fa42258933f0b4c80bb5283f09999575262526"
readonly MAP_CLOSURES_REPO_URL="https://github.com/PRBonn/MapClosures.git"
readonly VENV_DIR="${ROOT_DIR}/.venv"
readonly VENV_PYTHON="${VENV_DIR}/bin/python"

MAP_CLOSURES_REF="${MAP_CLOSURES_REF:-${DEFAULT_MAP_CLOSURES_REF}}"
MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-11.0}"
export MACOSX_DEPLOYMENT_TARGET

find_tool_outside_managed_venv() {
    local tool="$1"
    local path_entry
    local IFS=:

    for path_entry in ${PATH}; do
        if [[ -z "${path_entry}" || "${path_entry}" == "${VENV_DIR}/bin" ]]; then
            continue
        fi
        if [[ -x "${path_entry}/${tool}" ]]; then
            printf '%s\n' "${path_entry}/${tool}"
            return 0
        fi
    done

    return 1
}

require_repo_root() {
    if [[ "$(pwd)" != "${ROOT_DIR}" ]]; then
        echo "error: run this script from ${ROOT_DIR}" >&2
        exit 1
    fi
}

require_checkout() {
    if [[ ! -d "${ROOT_DIR}/kiss-icp/python" ]]; then
        echo "error: expected local repo at ${ROOT_DIR}/kiss-icp/python" >&2
        exit 1
    fi

    if [[ ! -f "${ROOT_DIR}/kiss-slam/pyproject.toml" ]]; then
        echo "error: expected local repo at ${ROOT_DIR}/kiss-slam" >&2
        exit 1
    fi
}

require_tools() {
    if ! UV_BIN="$(find_tool_outside_managed_venv uv)"; then
        echo "error: uv is required on PATH outside ${VENV_DIR}" >&2
        exit 1
    fi
    readonly UV_BIN

    if ! GIT_BIN="$(command -v git)"; then
        echo "error: git is required to install upstream MapClosures" >&2
        exit 1
    fi
    readonly GIT_BIN
}

remove_generated_path() {
    local target="$1"

    case "${target}" in
        "${ROOT_DIR}/.venv" | "${ROOT_DIR}/kiss-icp/python/build" | "${ROOT_DIR}/kiss-slam/build")
            ;;
        *)
            echo "error: refusing to remove unexpected path: ${target}" >&2
            exit 1
            ;;
    esac

    case "${target}" in
        "${ROOT_DIR}"/*)
            ;;
        *)
            echo "error: refusing to remove path outside repo root: ${target}" >&2
            exit 1
            ;;
    esac

    if [[ -e "${target}" ]]; then
        echo "Removing generated path: ${target}"
        rm -rf -- "${target}"
    fi
}

clean_generated_state() {
    remove_generated_path "${VENV_DIR}"
    remove_generated_path "${ROOT_DIR}/kiss-icp/python/build"
    remove_generated_path "${ROOT_DIR}/kiss-slam/build"
}

create_venv() {
    echo "Creating managed virtual environment: ${VENV_DIR}"
    "${UV_BIN}" venv --python python3.12 "${VENV_DIR}"

    if [[ ! -x "${VENV_PYTHON}" ]]; then
        echo "error: expected Python at ${VENV_PYTHON}" >&2
        exit 1
    fi
}

install_build_stack() {
    echo "Installing pinned native build stack"
    "${UV_BIN}" pip install --python "${VENV_PYTHON}" \
        pip==26.1 \
        setuptools==82.0.1 \
        wheel==0.47.0 \
        scikit-build-core==0.12.2 \
        pyproject-metadata==0.11.0 \
        pathspec==1.1.1 \
        pybind11==3.0.4 \
        cmake==4.3.2 \
        ninja==1.13.0 \
        numpy==2.4.4
}

install_kiss_icp() {
    echo "Installing local kiss-icp with vendored native dependencies"
    "${UV_BIN}" pip install --python "${VENV_PYTHON}" \
        --no-build-isolation \
        -Ccmake.define.USE_SYSTEM_EIGEN3=OFF \
        -Ccmake.define.USE_SYSTEM_SOPHUS=OFF \
        -Ccmake.define.USE_SYSTEM_TBB=OFF \
        -Ccmake.define.USE_SYSTEM_TSL-ROBIN-MAP=OFF \
        -e "${ROOT_DIR}/kiss-icp/python"
}

install_map_closures() {
    echo "Installing MapClosures ref: ${MAP_CLOSURES_REF}"
    "${UV_BIN}" pip install --python "${VENV_PYTHON}" \
        --no-build-isolation \
        "git+${MAP_CLOSURES_REPO_URL}@${MAP_CLOSURES_REF}#subdirectory=python"
}

install_kiss_slam() {
    echo "Installing local kiss-slam with vendored native dependencies"
    "${UV_BIN}" pip install --python "${VENV_PYTHON}" \
        --no-build-isolation \
        -Ccmake.define.USE_SYSTEM_EIGEN3=OFF \
        -Ccmake.define.USE_SYSTEM_G2O=OFF \
        -Ccmake.define.USE_SYSTEM_TSL-ROBIN-MAP=OFF \
        -e "${ROOT_DIR}/kiss-slam"
}

find_top_level_cp312_cache() {
    local build_root="$1"
    local package_name="$2"
    local caches=("${build_root}"/cp312-*/CMakeCache.txt)

    if [[ ${#caches[@]} -ne 1 || ! -f "${caches[0]}" ]]; then
        echo "error: expected exactly one cp312 CMakeCache for ${package_name} under ${build_root}" >&2
        exit 1
    fi

    printf '%s\n' "${caches[0]}"
}

require_cache_value() {
    local cache="$1"
    local key="$2"
    local expected="$3"

    if ! grep -q "^${key}:BOOL=${expected}$" "${cache}"; then
        echo "error: expected ${key}:BOOL=${expected} in ${cache}" >&2
        exit 1
    fi
}

reject_stale_python_cache_refs() {
    local cache="$1"

    if grep -E "cp313|python3\\.13|cpython-3\\.13" "${cache}" >/dev/null; then
        echo "error: stale Python 3.13/cp313 reference found in ${cache}" >&2
        grep -E "cp313|python3\\.13|cpython-3\\.13" "${cache}" >&2
        exit 1
    fi
}

verify_imports_and_paths() {
    echo "Verifying imports and resolved extension paths"
    "${VENV_PYTHON}" - <<'PY'
import kiss_icp
import kiss_icp.pybind.kiss_icp_pybind as kiss_icp_pybind
import kiss_slam
import kiss_slam.kiss_slam_pybind.kiss_slam_pybind as kiss_slam_pybind
import map_closures
from map_closures.map_closures import MapClosures

if not hasattr(MapClosures, "get_ground_alignment_from_id"):
    raise RuntimeError("MapClosures does not expose get_ground_alignment_from_id")

print(f"kiss_icp package: {kiss_icp.__file__}")
print(f"kiss_icp extension: {kiss_icp_pybind.__file__}")
print(f"kiss_slam package: {kiss_slam.__file__}")
print(f"kiss_slam extension: {kiss_slam_pybind.__file__}")
print(f"map_closures package: {map_closures.__file__}")
PY
}

verify_cmake_caches() {
    local kiss_icp_cache
    local kiss_slam_cache

    echo "Verifying CMake cache dependency selections"
    kiss_icp_cache="$(find_top_level_cp312_cache "${ROOT_DIR}/kiss-icp/python/build" "kiss-icp")"
    require_cache_value "${kiss_icp_cache}" "USE_SYSTEM_EIGEN3" "OFF"
    require_cache_value "${kiss_icp_cache}" "USE_SYSTEM_SOPHUS" "OFF"
    require_cache_value "${kiss_icp_cache}" "USE_SYSTEM_TBB" "OFF"
    require_cache_value "${kiss_icp_cache}" "USE_SYSTEM_TSL-ROBIN-MAP" "OFF"
    reject_stale_python_cache_refs "${kiss_icp_cache}"

    kiss_slam_cache="$(find_top_level_cp312_cache "${ROOT_DIR}/kiss-slam/build" "kiss-slam")"
    require_cache_value "${kiss_slam_cache}" "USE_SYSTEM_EIGEN3" "OFF"
    require_cache_value "${kiss_slam_cache}" "USE_SYSTEM_G2O" "OFF"
    require_cache_value "${kiss_slam_cache}" "USE_SYSTEM_TSL-ROBIN-MAP" "OFF"
    reject_stale_python_cache_refs "${kiss_slam_cache}"
}

verify_install() {
    verify_imports_and_paths
    "${UV_BIN}" pip check --python "${VENV_PYTHON}"
    verify_cmake_caches
}

main() {
    require_repo_root
    require_checkout
    require_tools

    echo "Using uv: ${UV_BIN}"
    echo "Using git: ${GIT_BIN}"
    echo "Using MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET}"
    echo "Using MapClosures ref: ${MAP_CLOSURES_REF}"

    clean_generated_state
    create_venv
    install_build_stack
    install_kiss_icp
    install_map_closures
    install_kiss_slam
    verify_install

    cat <<EOF

Install complete in managed virtual environment:
  ${VENV_DIR}

Direct CLI paths:
  ${VENV_DIR}/bin/kiss_icp_pipeline
  ${VENV_DIR}/bin/kiss_slam_pipeline

MapClosures:
  pinned ref ${MAP_CLOSURES_REF}
EOF
}

main "$@"
