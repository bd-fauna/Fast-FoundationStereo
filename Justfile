# Recipes for building and running the Fast-FoundationStereo Docker images.
# `just --list` shows a summary; `just <recipe> -- <args>` forwards args to
# the underlying docker compose call where applicable.

compose := "docker compose -f docker/docker-compose.yml"
engine_dir := env_var_or_default("ENGINE_DIR", justfile_directory() + "/output_plugin_onnx_320x736_iters4")

[private]
default:
    @just --list --unsorted

# ---- Build ----

# Build the ffs_ros2 image (ROS 2 Humble + TRT runtime + ffs_ros workspace).
build-ros2:
    {{compose}} build ffs_ros2

# Build the ffs image (Python/PyTorch/TRT for ONNX export and demos).
build-cpp:
    {{compose}} build ffs

# Build both images.
build: build-ros2 build-cpp

# ---- Inspection / debugging ----

# Drop into an interactive shell in the ffs_ros2 image (engine dir + /mnt/nas_mnt mounted, host net).
shell:
    ENGINE_DIR={{engine_dir}} {{compose}} run --rm ffs_ros2_shell

# Drop into an interactive shell in the ffs (Python/PyTorch) image; repo mounted at /workspace.
shell-cpp:
    {{compose}} run --rm ffs

# Print rosbag2/ros2 versions inside the ffs_ros2 image (handy for bag-format triage).
ros2-versions:
    {{compose}} run --rm ffs_ros2_shell bash -c '\
      echo "=== rosdistro ==="; cat /opt/ros/humble/setup.bash | head -1; \
      echo; \
      echo "=== rosbag2 packages ==="; dpkg -l | grep -E "rosbag2|mcap" || true; \
      echo; \
      echo "=== ros2 doctor ==="; ros2 doctor --report 2>&1 | head -40 || true \
    '

# ---- Run the stereo depth node ----

# Run ffs_stereo_node via launch file (default camera_name=zed -> /zed/zed_node/...).
node:
    ENGINE_DIR={{engine_dir}} {{compose}} run --rm ffs_stereo

# Run ffs_stereo_node with explicit topic params (default: /zed/{left,right}/... layout).
node-topics:
    ENGINE_DIR={{engine_dir}} {{compose}} run --rm ffs_stereo_topics

# ---- Engine build ----

# Build a TRT engine from a plugin ONNX inside the ffs_ros2 image (paths relative to engine dir).
build-engine onnx engine:
    ENGINE_DIR={{engine_dir}} {{compose}} run --rm ffs_build_engine \
        /engines/{{onnx}} /engines/{{engine}}

# ---- Bag inspection ----

# Run `ros2 bag info` against a bag under /mnt/nas_mnt (path relative to /mnt/nas_mnt).
bag-info path:
    {{compose}} run --rm ffs_ros2_shell bash -c \
        'ros2 bag info /mnt/nas_mnt/{{path}}'
