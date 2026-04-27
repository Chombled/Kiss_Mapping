# Kiss_Mapping
Repository for a mapping stack using custom extensions of kiss-slam and kiss-icp as well as associated scripts and configs

# Setup
Run `./setup_venv.sh` from the workspace root to create a clean managed `.venv` and install the local `kiss-icp` and `kiss-slam` checkouts.

The setup script recreates generated install/build state on each run:

- `.venv`
- `kiss-icp/python/build`
- `kiss-slam/build`

Python sources are installed editable. Native C++ extensions are built during setup; rerun `./setup_venv.sh` after changing native code or build settings.

The bootstrap also replaces the published `map_closures==2.0.2` wheel with a pinned upstream Git commit. This is intentional: `--refuse-scans` needs `MapClosures.get_ground_alignment_from_id`, and the published `2.0.2` wheel plus the upstream `v2.0.2` tag both predate that API.

```sh
./setup_venv.sh
source .venv/bin/activate
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
