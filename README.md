# Kiss Mapping
Repository for the mapping stack using custom extensions of kiss-slam and kiss-icp as well as associated scripts and configs 

# Setup
Create a `uv` virtual environment first, then use `./setup_venv.sh` from the workspace root to install the local `kiss-icp` and `kiss-slam` checkouts into that active environment.

The bootstrap also replaces the published `map_closures==2.0.2` wheel with a pinned upstream Git commit. This is intentional: `--refuse-scans` needs `MapClosures.get_ground_alignment_from_id`, and the published `2.0.2` wheel plus the upstream `v2.0.2` tag both predate that API.

```sh
uv venv --python python3.12 .venv
source .venv/bin/activate
./setup_venv.sh
```

Optional overrides:

- `MAP_CLOSURES_REF`: upstream MapClosures commit to install. Default: `81fa42258933f0b4c80bb5283f09999575262526`

After setup, `--refuse-scans` should work with the installed `MapClosures` build. If you only need the standard SLAM outputs and local map PLY exports, you can still run without `--refuse-scans`.

# Example Usage
```sh
source .venv/bin/activate
./start_slam.sh
```
For more options see:
```sh
./start_slam.sh -h
```
