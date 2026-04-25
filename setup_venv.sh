#!/usr/bin/env bash

set -euo pipefail

readonly ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly DEFAULT_MAP_CLOSURES_REF="81fa42258933f0b4c80bb5283f09999575262526"
readonly MAP_CLOSURES_REPO_URL="https://github.com/PRBonn/MapClosures.git"

MAP_CLOSURES_REF="${MAP_CLOSURES_REF:-${DEFAULT_MAP_CLOSURES_REF}}"

if [[ "$(pwd)" != "${ROOT_DIR}" ]]; then
    echo "error: run this script from ${ROOT_DIR}" >&2
    exit 1
fi

if [[ ! -d "${ROOT_DIR}/kiss-icp/python" ]]; then
    echo "error: expected local repo at ${ROOT_DIR}/kiss-icp/python" >&2
    exit 1
fi

if [[ ! -f "${ROOT_DIR}/kiss-slam/pyproject.toml" ]]; then
    echo "error: expected local repo at ${ROOT_DIR}/kiss-slam" >&2
    exit 1
fi

if ! command -v uv >/dev/null 2>&1; then
    echo "error: uv is required on PATH" >&2
    exit 1
fi

if ! command -v git >/dev/null 2>&1; then
    echo "error: git is required to install upstream MapClosures" >&2
    exit 1
fi

if [[ -z "${VIRTUAL_ENV:-}" ]]; then
    echo "error: activate an existing uv virtual environment before running this script" >&2
    exit 1
fi

readonly VENV_PYTHON="${VIRTUAL_ENV}/bin/python"

if [[ ! -x "${VENV_PYTHON}" ]]; then
    echo "error: expected an active virtual environment at ${VIRTUAL_ENV}" >&2
    exit 1
fi

echo "Using active virtual environment: ${VIRTUAL_ENV}"
echo "Using MapClosures ref: ${MAP_CLOSURES_REF}"

uv pip install --python "${VENV_PYTHON}" --upgrade pip setuptools wheel
uv pip install --python "${VENV_PYTHON}" \
    scikit-build-core \
    pyproject_metadata \
    pathspec \
    pybind11 \
    cmake \
    ninja

uv pip install --python "${VENV_PYTHON}" --no-build-isolation -e "${ROOT_DIR}/kiss-icp/python"
uv pip uninstall --python "${VENV_PYTHON}" map_closures map-closures
uv pip install --python "${VENV_PYTHON}" \
    --no-build-isolation \
    "git+${MAP_CLOSURES_REPO_URL}@${MAP_CLOSURES_REF}#subdirectory=python"

if ! "${VENV_PYTHON}" -c \
    "from map_closures.map_closures import MapClosures; assert hasattr(MapClosures, 'get_ground_alignment_from_id')"
then
    echo "error: installed MapClosures build does not expose get_ground_alignment_from_id" >&2
    exit 1
fi

uv pip install --python "${VENV_PYTHON}" \
    --no-build-isolation \
    -Ccmake.define.USE_SYSTEM_EIGEN3=OFF \
    -Ccmake.define.USE_SYSTEM_G2O=OFF \
    -Ccmake.define.USE_SYSTEM_TSL-ROBIN-MAP=OFF \
    -e "${ROOT_DIR}/kiss-slam"

cat <<EOF

Install complete in active virtual environment:
  ${VIRTUAL_ENV}

Direct CLI paths:
  ${VIRTUAL_ENV}/bin/kiss_icp_pipeline
  ${VIRTUAL_ENV}/bin/kiss_slam_pipeline

MapClosures:
  pinned ref ${MAP_CLOSURES_REF}
EOF
