# ROS 2 Jazzy SLAM Docker 开发环境

基于 `ros:jazzy-ros-base`，在容器内提供 Ubuntu 24.04 ARM64 + ROS 2 Jazzy 开发环境。当前 Compose 固定使用 `linux/arm64`，主要面向 Apple Silicon Mac。

本仓库提供 SLAM 开发依赖和模拟点云示例，尚未集成具体 SLAM 算法、传感器驱动或建图流程。无需在 macOS 上另外安装 ROS 2。

采用手动开发流程：宿主机构建和管理 Docker；容器内运行 `colcon build` 和 ROS 节点；VS Code 连接容器编辑调试；宿主机 Foxglove 显示点云。无需额外编译脚本。

操作顺序：宿主机准备 → 构建镜像 → 启动容器 → 编译工作空间 → 验证点云 → Foxglove 可视化 → VS Code 日常开发。

## 1. 当前配置

| 项目 | 配置 |
| --- | --- |
| Compose 服务 | `ros2-slam` |
| 容器名 | `ros2-slam-m5` |
| 本地镜像名 | `ros2-jazzy-slam:arm64-dev` |
| 工作空间 | `/workspaces/slam_ws` |
| ROS 发行版 | Jazzy |
| DDS 实现 | `rmw_fastrtps_cpp` |
| ROS Domain | `10` |
| 自动发现范围 | `LOCALHOST`，用于同一容器内节点通信 |
| Foxglove 端口 | 宿主机 `127.0.0.1:8765` → 容器 `8765` |
| 编译并行度 | CMake/Make 默认 4；colcon 按包顺序构建 |
| 共享内存 | `2gb` |

Dockerfile 已安装：

- 编译与调试：GCC 工具链、CMake、Ninja、Git、GDB、gdbserver、Clang、clangd、clang-format、ccache。
- ROS 开发工具：colcon、vcstool、rosdep。
- 算法依赖：Eigen、PCL、Ceres、OpenCV、OpenMP、TBB、yaml-cpp、NumPy。
- ROS 组件：TF2、PCL 转换、rosbag2、MCAP 存储插件、Foxglove Bridge、C++ 示例节点。

当前未配置 RViz2 图形界面、CUDA、雷达设备透传或跨主机 DDS 通信。ccache 已安装并挂载缓存目录，下面的编译命令通过 CMake 编译器 launcher 启用缓存。

## 2. 目录与数据保存位置

```text
.
├── Dockerfile
├── compose.yaml
├── datasets/                  # 宿主机数据集
└── ws/
    └── src/
        └── slam_demo/          # 当前本地已有的模拟点云示例
```

| 宿主机目录或 Docker 卷 | 容器路径 | 用途 |
| --- | --- | --- |
| `./ws` | `/workspaces/slam_ws` | 源码工作空间，双向读写 |
| `./datasets` | `/data` | 数据集，只读 |
| `slam_build` 命名卷 | `/workspaces/slam_ws/build` | 构建产物 |
| `slam_install` 命名卷 | `/workspaces/slam_ws/install` | 安装产物 |
| `slam_log` 命名卷 | `/workspaces/slam_ws/log` | 构建日志 |
| `slam_ccache` 命名卷 | `/root/.cache/ccache` | 编译缓存目录 |

Compose 通常会为命名卷添加项目名前缀。`build/`、`install/`、`log/` 实际存储在 Docker 卷中，宿主机 `ws/` 里的同名目录不能用于查看容器内这些产物。

注意：当前 `.gitignore` 忽略整个 `ws/`。本机存在的 `slam_demo` 不代表全新克隆后也有该示例；运行前请确认 `ws/src/slam_demo/package.xml` 存在。后续需要版本管理源码时，应调整忽略规则，只忽略构建产物。

## 3. 宿主机准备

在宿主机安装：

- Docker Desktop（Apple Silicon 版本），启动后等待 Docker 引擎就绪，确保可使用 Docker Compose V2。
- VS Code，以及 Dev Containers 扩展。
- Foxglove 客户端，用于连接容器内的 Foxglove Bridge。

VS Code 和 Foxglove 的具体操作分别见第 9 节和第 7 节。

以下命令均在**宿主机终端**执行：

```bash
cd /Users/zhan/work/ros2_slam_docker

docker version
docker compose version
docker compose config --quiet
```

如果仓库位于其他目录，请相应修改 `cd` 路径。`docker version` 应能正常显示服务端信息，`docker compose config --quiet` 成功时不输出内容。

Docker Desktop 需要有足够的内存和磁盘空间供 PCL、Ceres 等依赖构建使用；出现内存不足时可先降低编译并行度。Intel/AMD 主机使用当前配置会涉及 ARM64 仿真，迁移时需重新确认目标架构。

## 4. 先拉取基础镜像，再构建并启动容器

本机曾遇到直接构建时 `load metadata for docker.io/library/ros:jazzy-ros-base` 超时，先手动拉取基础镜像后完成构建。首次搭建按下面顺序执行，每一步成功后再继续。

以下均在**宿主机仓库根目录**执行：

```bash
cd /Users/zhan/work/ros2_slam_docker
docker compose config --quiet

# 1. 手动拉取 Dockerfile 的基础镜像，架构与 Compose 保持一致
docker pull --platform linux/arm64 ros:jazzy-ros-base

# 2. 确认基础镜像已在本地，预期输出 linux/arm64
docker image inspect ros:jazzy-ros-base \
  --format '{{.Os}}/{{.Architecture}}'

# 3. 在基础镜像上安装开发依赖，构建本项目的开发镜像
docker compose --progress plain build

# 4. 使用构建好的开发镜像启动容器，不再自动构建
docker compose up -d --no-build

# 5. 确认容器处于运行状态
docker compose ps
```

这里有两个不同的镜像：`ros:jazzy-ros-base` 是下载的基础镜像；`ros2-jazzy-slam:arm64-dev` 是根据本仓库 Dockerfile 构建的开发镜像。只执行 `docker pull` 不会安装本项目额外的 PCL、Ceres 等开发依赖，也不会创建开发容器。

手动拉取便于提前检查网络并复用本地镜像，但**不保证 BuildKit 构建时完全不访问 Docker Hub**。如果第 3 步仍在 `load metadata` 阶段超时，请按第 11 节排查 Docker Desktop 网络、代理或镜像加速器；无需先修改 `RUN` 命令，也不要通过 `--no-cache` 尝试修复网络问题。

构建期间 `apt-get update/install` 仍需要网络。当前 Dockerfile 已将 Ubuntu 24.04 ARM64 软件源切换为清华 `ubuntu-ports`，ROS 软件包使用独立的 ROS APT 源。镜像仓库超时与 APT 下载缓慢属于不同阶段的问题。

`up -d` 创建并在后台启动容器，`ps` 中服务应显示为运行状态。容器启动后运行 `sleep infinity` 保持在线，**不会自动编译工作空间或启动 ROS 节点**。

检查启动情况后进入容器：

```bash
docker compose exec ros2-slam bash
```

以下检查在**容器终端**执行：

```bash
cat /etc/os-release
uname -m
printenv ROS_DISTRO
pwd
ros2 pkg prefix rclcpp
```

预期分别能确认 Ubuntu 24.04、`aarch64`、`jazzy`、`/workspaces/slam_ws`，以及 `rclcpp` 的安装路径。

交互式 Bash 会通过 `/root/.bashrc` 自动加载 ROS 环境；工作空间构建完成后，新开的交互式 Bash 也会加载已有的 `install/setup.bash`。使用非交互命令时应显式 `source` 所需环境。

退出终端使用 `exit`，容器仍继续运行；在新宿主机终端再次执行 `docker compose exec ros2-slam bash`，即可打开同一容器的另一个终端。不要把 `docker compose exec` 命令放到容器内执行。

如需主动更新基础镜像，重新执行本节的手动 `docker pull`、`docker compose --progress plain build` 和 `docker compose up -d --no-build`。日常已有镜像时无需每次拉取。`docker compose build --pull` 会要求构建时尝试拉取更新，本机遇到过镜像元数据超时，因此不作为默认操作。通常不需要 `--no-cache`。

## 5. 编译工作空间

在上一步的**容器终端**执行：

```bash
source /opt/ros/jazzy/setup.bash
cd /workspaces/slam_ws
colcon list
colcon build --symlink-install --executor sequential \
  --cmake-args \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  -DCMAKE_C_COMPILER_LAUNCHER=ccache \
  -DCMAKE_CXX_COMPILER_LAUNCHER=ccache
source install/setup.bash
ros2 pkg prefix slam_demo
```

`colcon list` 应列出 `slam_demo`；如果没有，先检查宿主机 `ws/src` 中是否有源码。`RelWithDebInfo` 保留调试信息，`compile_commands.json` 可供 clangd 使用。

每次修改 `ws/src` 中的源码后，在容器内重新执行上述 `colcon build` 命令；不需要重新构建 Docker 镜像。构建成功后，在运行节点的终端重新执行 `source install/setup.bash`，并重启对应节点。

可用 `ccache -s` 查看缓存统计。使用 `--symlink-install` 时，C++ 源码修改仍需要重新编译。

如果只构建某个包，把包选择参数放在 `--cmake-args` 之前，例如：

```bash
colcon build --symlink-install --executor sequential \
  --packages-select slam_demo \
  --cmake-args \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  -DCMAKE_C_COMPILER_LAUNCHER=ccache \
  -DCMAKE_CXX_COMPILER_LAUNCHER=ccache
```

需要同时构建工作空间内该包的依赖时，使用 `--packages-up-to slam_demo`。

容器交互式 Bash 会自动加载已有工作空间的安装环境。修改依赖关系或排查旧安装环境干扰时，可在新的宿主机终端执行下面的命令进入不读取 `.bashrc` 的构建终端，然后手动 source `/opt/ros/jazzy/setup.bash` 并编译：

```bash
docker compose exec ros2-slam bash --noprofile --norc
```

## 6. 验证模拟点云

**终端 A：宿主机执行进入容器命令，然后在容器内启动发布器。**

```bash
docker compose exec ros2-slam bash
```

```bash
source /workspaces/slam_ws/install/setup.bash
ros2 run slam_demo cloud_publisher
```

保持终端 A 运行。在**另一个宿主机终端 B**进入同一容器：

```bash
docker compose exec ros2-slam bash
```

然后在**容器内**执行：

```bash
ros2 topic list
ros2 topic info /slam_demo/points
ros2 topic hz /slam_demo/points
```

预期话题类型为 `sensor_msgs/msg/PointCloud2`，频率接近 10 Hz，点云 frame 为 `lidar`。这是合成点云验证，不会输出地图或定位结果。按 `Ctrl+C` 停止当前前台命令。

## 7. 使用 Foxglove 查看点云

保持点云发布器运行，再从**宿主机终端 C**进入容器：

```bash
docker compose exec ros2-slam bash
```

在**容器内**启动桥接：

```bash
ros2 launch foxglove_bridge foxglove_bridge_launch.xml address:=0.0.0.0 port:=8765
```

在宿主机打开 Foxglove 客户端：

1. 选择打开连接（Open connection）。
2. 连接类型选择 **Foxglove WebSocket**。
3. 输入下面的地址并连接：

```text
ws://localhost:8765
```

连接成功后：

1. 新增 **3D** 面板。
2. 在面板设置的 Topics 中启用 `/slam_demo/points`。
3. 将固定坐标系（Fixed frame / Display frame，名称随客户端版本变化）设为 `lidar`。
4. 调整视角和缩放，应能看到环状起伏点云；需要时调整点大小。

模拟点云直接使用 `lidar` 坐标系显示，不要求额外发布 `map → lidar` TF。后续接入真实 SLAM 后，应根据算法输出选择 `map` 或 `odom`，并确保相关 TF 链完整。

`address:=0.0.0.0` 让桥接在容器网络接口上监听；Compose 仍将宿主机入口限制在 `127.0.0.1`。无需另外启动 ROS 网络转发，也不必额外设置 VS Code 端口转发。

此时应有三个相互独立的进程：终端 A 的点云发布器、终端 B 的话题检查（可随时停止）、终端 C 的 Foxglove Bridge。

容器运行并不代表桥接已启动；上述 launch 命令需要保持运行。端口仅绑定宿主机回环地址，其他电脑无法通过宿主机局域网 IP 访问此端口。

## 8. 回放 ROS 2 bag

把 bag 放到宿主机仓库的 `datasets/` 下，例如：

```text
datasets/my_bag/
├── metadata.yaml
└── ...                    # 对应的 .db3 或 .mcap 数据文件
```

在**容器终端**执行：

```bash
ros2 bag info /data/my_bag
ros2 bag play /data/my_bag --clock
```

bag 的实际话题名、消息类型、QoS 和 TF 必须与算法要求匹配。需要跟随 bag 时间的算法节点应设置 `use_sim_time:=true`；`--clock` 负责发布仿真时钟，不会自动修改其他节点的参数。

`/data` 为只读目录，不能用于录制输出。如需录制，可写到工作空间，例如：

```bash
mkdir -p /workspaces/slam_ws/bags
ros2 bag record -o /workspaces/slam_ws/bags/test /slam_demo/points
```

录制结果会保存在宿主机 `ws/bags/test`。ROS 1 bag 不能按上述 ROS 2 bag 流程直接使用，需要另行转换。

## 9. 使用 VS Code 在容器内开发

### 9.1 连接已启动的容器

1. 在宿主机确认 `docker compose up -d` 已完成。
2. 打开 VS Code，安装 Microsoft 的 **Dev Containers** 扩展。
3. 按 `Cmd+Shift+P`，执行 **Dev Containers: Attach to Running Container...**。
4. 选择 `ros2-slam-m5`，等待容器连接完成。
5. 在新窗口中选择 **File → Open Folder...**，打开 `/workspaces/slam_ws`。
6. 通过 **Terminal → New Terminal** 新建终端；该终端位于容器内，执行 `pwd` 应位于工作空间，`uname -m` 应为 `aarch64`。

在该窗口编辑 `src/` 中的文件，会同步到宿主机仓库的 `ws/src/`。编译和运行直接使用第 5、6 节命令，无需在 macOS 上安装编译依赖。

当前没有 `.devcontainer/devcontainer.json`，采用“Attach to Running Container”流程即可，不需要先创建 Dev Container 配置。

### 9.2 配置 C++ 补全

在连接容器的 VS Code 窗口内，安装 **clangd** 扩展，注意选择安装到容器环境。Dockerfile 已安装 `/usr/bin/clangd`。

至少完成一次第 5 节的构建，再在工作空间设置 `/workspaces/slam_ws/.vscode/settings.json` 中加入：

```json
{
  "clangd.path": "/usr/bin/clangd",
  "clangd.arguments": [
    "--compile-commands-dir=/workspaces/slam_ws/build/slam_demo"
  ]
}
```

这里指向当前示例包的编译数据库。多个 CMake 包需要使用包含所有包条目的编译数据库，不能一直只指向 `slam_demo`。如果同时安装 Microsoft C/C++ 扩展，可将其 `C_Cpp.intelliSenseEngine` 设为 `disabled`，避免与 clangd 重复诊断。

编译完成后可在容器终端确认文件存在：

```bash
ls /workspaces/slam_ws/build/slam_demo/compile_commands.json
```

### 9.3 使用 GDB 调试示例

需要图形断点调试时，在容器环境安装 Microsoft **C/C++** 扩展。在工作空间创建 `.vscode/launch.json`：

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug cloud_publisher",
      "type": "cppdbg",
      "request": "launch",
      "program": "/workspaces/slam_ws/install/slam_demo/lib/slam_demo/cloud_publisher",
      "args": [],
      "cwd": "/workspaces/slam_ws",
      "stopAtEntry": false,
      "MIMode": "gdb",
      "miDebuggerPath": "/usr/bin/gdb",
      "environment": [
        { "name": "ROS_DOMAIN_ID", "value": "10" },
        { "name": "ROS_AUTOMATIC_DISCOVERY_RANGE", "value": "LOCALHOST" },
        { "name": "RMW_IMPLEMENTATION", "value": "rmw_fastrtps_cpp" }
      ],
      "setupCommands": [
        { "text": "-enable-pretty-printing", "ignoreFailures": true }
      ]
    }
  ]
}
```

先手动编译成功，停止之前运行的示例节点，在源码设置断点，然后选择 `Debug cloud_publisher` 按 F5。此配置不会自动编译，适用于当前只依赖基础 ROS 库的示例。以后算法依赖其他工作空间包时，还需为调试进程提供 source 后的运行环境；VS Code 终端里的 source 不会自动修改已经启动的调试适配器环境。

### 9.4 增加开发依赖

加入新的 ROS 包后，可在**容器终端**按包的 `package.xml` 安装依赖：

```bash
source /opt/ros/jazzy/setup.bash
cd /workspaces/slam_ws
# 仅当 /etc/ros/rosdep/sources.list.d/20-default.list 不存在时执行：
# rosdep init
rosdep update
apt-get update
rosdep install --from-paths src --ignore-src -r -y --rosdistro jazzy
```

容器内临时安装的软件在容器重建后可能丢失；确定需要的系统依赖应加入 Dockerfile，并重新构建镜像。当前通过 root 用户开发，已为调试开放 `SYS_PTRACE` 并使用 `seccomp:unconfined`。

## 10. 日常启动、停止与更新

以下均在**宿主机仓库根目录**执行。

```bash
# 启动；已有容器则复用
docker compose up -d

# 进入容器
docker compose exec ros2-slam bash

# 查看容器状态和启动日志
docker compose ps
docker compose logs --tail=100 ros2-slam

# 停止容器，保留容器及命名卷
docker compose stop

# 删除容器及 Compose 网络，保留命名卷和宿主机源码
docker compose down

# 修改 Dockerfile 后重新构建并启动
docker compose up -d --build
```

使用 `docker compose stop` 后，可用 `docker compose start` 恢复已有容器。容器重启不会恢复之前在交互终端手动启动的 ROS 节点，需要重新运行发布器、算法和桥接。`docker compose logs` 主要查看容器主进程输出，通过 `exec` 交互运行的节点日志应在对应终端查看。

修改内容与所需操作：

| 修改内容 | 操作 |
| --- | --- |
| `ws/src` 中的 C++ 源码 | 容器内重新 `colcon build`，source 环境后重启节点 |
| Dockerfile 中的系统依赖 | 宿主机 `docker compose up -d --build` |
| Compose 的环境变量、挂载或端口 | 宿主机 `docker compose up -d`，让 Compose 按配置重建容器 |
| `datasets` 下的 bag 文件 | 直接在容器 `/data` 访问，无需重建 |

不要随意执行 `docker compose down -v`：它会删除本项目的命名卷，包括构建产物、安装产物、日志和 ccache。

## 11. 常见问题

| 现象 | 检查方法 |
| --- | --- |
| `load metadata` / `DeadlineExceeded` | 先手动拉取本节指定的 ARM64 基础镜像，再重试构建；如果仍超时，按下方步骤检查 Docker Desktop 网络配置 |
| `apt-get` 下载缓慢 | 当前 Ubuntu 源使用清华 ubuntu-ports；确认慢的是 Ubuntu 包还是 ROS 包，Docker 镜像加速器不会替换 APT 源 |
| 无法连接 Docker daemon | 确认 Docker Desktop 已启动，`docker version` 能显示服务端信息 |
| `Package 'slam_demo' not found` | 确认源码存在、构建成功，并在当前终端 source 工作空间环境 |
| 重新克隆后没有示例源码 | 当前 `.gitignore` 忽略 `ws/`，需另行恢复源码或调整版本管理规则 |
| Foxglove 无法连接 | 确认桥接 launch 正在运行、8765 端口未被其他服务占用 |
| Foxglove 连接成功但没有点云 | 确认发布器运行、话题已启用，固定坐标系设为 `lidar` |
| 外部雷达或其他机器的 ROS 节点无法通信 | 当前为容器内 LOCALHOST 发现，需另行设计网络和设备接入 |
| 编译进程被杀死、内存不足 | 增加 Docker 可用内存，或在编译前设置 `export CMAKE_BUILD_PARALLEL_LEVEL=2` 和 `export MAKEFLAGS=-j2` |
| 宿主机看不到编译产物 | `build/`、`install/`、`log/` 位于命名卷，在容器内检查 |

### `load metadata` 超时排查

错误示例：

```text
load metadata for docker.io/library/ros:jazzy-ros-base
failed to solve: DeadlineExceeded: context deadline exceeded
```

该错误发生在基础镜像解析阶段，尚未执行 Dockerfile 的 `RUN apt-get ...`。

1. 先执行第 4 节的手动拉取及构建流程。
2. 如果拉取成功但构建仍失败，在宿主机执行 `docker context show` 和 `docker buildx ls`。本机使用 `desktop-linux` context，当前构建器 `desktop-linux*` 使用 `docker` 驱动；未选中的 `default` 报 `/var/run/docker.sock` 不存在，通常与本次构建无关，不要因此切换到 `default`。
3. 检查 **Docker Desktop → Settings → Resources → Proxies**，确认 Docker Desktop 使用有效的系统代理或手动代理，修改后应用并重启。终端的代理环境变量不等于 Docker Desktop 的代理设置。
4. 如使用镜像加速器，在 **Settings → Docker Engine** 检查 `registry-mirrors`，确认地址有效且支持目标镜像。保留其他 JSON 配置。配置加速器时，Dockerfile 的 `FROM ros:jazzy-ros-base` 无需更改。
5. 重试 `docker compose --progress plain build`。如果仍失败，保留完整的 `failed to solve` 错误，并通过 Docker Desktop 的 Troubleshoot 诊断。

宿主机 `curl https://registry-1.docker.io/v2/` 与 Docker 引擎可能使用不同的网络路径；即使 curl 超时，也不能单独判定 Docker 拉取失败。以实际的 pull 和 build 结果为准。已拉取镜像不等于后续构建不再访问仓库。

## 12. 官方参考

- [Docker Desktop：网络与代理](https://docs.docker.com/desktop/features/networking/)
- [Docker Hub：镜像加速器配置](https://docs.docker.com/docker-hub/image-library/mirror/)
- [VS Code：连接正在运行的容器](https://code.visualstudio.com/docs/devcontainers/attach-container)
- [Foxglove：ROS 2 连接说明](https://docs.foxglove.dev/docs/getting-started/frameworks/ros2)
- [Foxglove：3D 面板](https://docs.foxglove.dev/docs/visualization/panels/3d)

以上步骤基于当前仓库配置整理。文档静态检查和 Compose 配置校验不等同于镜像构建、节点运行及 Foxglove 连接的实际验证。
