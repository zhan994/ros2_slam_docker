FROM ros:jazzy-ros-base

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    CMAKE_BUILD_PARALLEL_LEVEL=4 \
    CCACHE_DIR=/root/.cache/ccache

# Ubuntu 24.04 ARM64 packages; ROS keeps its own APT source.
RUN printf '%s\n' \
    'Types: deb' \
    'URIs: https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/' \
    'Suites: noble noble-updates noble-backports noble-security' \
    'Components: main restricted universe multiverse' \
    'Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg' \
    > /etc/apt/sources.list.d/ubuntu.sources

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        ninja-build \
        git \
        curl \
        wget \
        vim \
        nano \
        less \
        gdb \
        gdbserver \
        clang \
        clangd \
        clang-format \
        ccache \
        pkg-config \
        python3-colcon-common-extensions \
        python3-vcstool \
        python3-rosdep \
        python3-numpy \
        python3-opencv \
        libeigen3-dev \
        libpcl-dev \
        libceres-dev \
        libopencv-dev \
        libomp-dev \
        libtbb-dev \
        libyaml-cpp-dev \
        ros-jazzy-tf2-ros \
        ros-jazzy-tf2-eigen \
        ros-jazzy-pcl-ros \
        ros-jazzy-pcl-conversions \
        ros-jazzy-rosbag2 \
        ros-jazzy-rosbag2-storage-mcap \
        ros-jazzy-foxglove-bridge \
        ros-jazzy-demo-nodes-cpp \
    && rm -rf /var/lib/apt/lists/*

RUN printf '%s\n' \
    '' \
    'source /opt/ros/jazzy/setup.bash' \
    'if [ -f /workspaces/slam_ws/install/setup.bash ]; then' \
    '    source /workspaces/slam_ws/install/setup.bash' \
    'fi' \
    >> /root/.bashrc

WORKDIR /workspaces/slam_ws
CMD ["sleep", "infinity"]
