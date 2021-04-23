## 说明
1. 由于CK编译需要花费大量的CPU、Memory和磁盘，所以可以考虑远程开发、调试。
1. 远程调试有IDEA，它会自动同步两边的文件，确保一致；另外就是vscode，它完全把代码文件放到远程服务器，所以可以减轻本机压力。
1. 这里是搭建clickhouse的C++远程开发环境，但是理论上适用于任何后端开发（比如Java, Go等）；

## 步骤
### 0. 准备
1. 本机安装[vscode](https://code.visualstudio.com/download)最新版，如果已安装记得一定要升级到最新；
1. 在远程机器上准备好clickhouse代码：`git clone --recursive https://github.com/Clickhouse/Clickhouse`；
1. 开启到远程机器的免密登录（这里可参考网上资料），然后配置好`.ssh/config`文件：
```
Host c4
        Hostname 10.0.0.14
        User wgm
```

### 1. 安装vscode插件
点左侧的Extensions栏，安装插件：`Remote - SSH`, `Remote - Containers`；
1. `Remote - SSH`可以在你配置了ssh登录别的机器后，连到这台机器去，打开里面的项目，进行远程开发、调试，具体这里不再介绍；
1. `Remote - Containers`则可以连接到远程docker上去，这个更加灵活，尤其是在远程主机的环境不能满足要求的情况下；

### 2. 准备CK开发环境
1. 按住`Command + Shift + P`，打开command panel，输入`Remote container: open folder in container`，确认后选择一个本机空目录；
1. 按照提示选择系统为ubuntu 20.04，开发语言为C++，点确定，打开后可以立马关闭窗口（还需进一步配置）；
1. 切换到刚才的本机空目录，里面的隐藏文件夹`.devcontainer`下有两个文件`.devcontainer.json`和`Dockerfile`，  
由于vscode默认C++环境的clang是clang-10，clickhouse推荐用更新的clang-11，所以需要编辑这两个文件：
```Dockerfile
# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.166.1/containers/cpp/.devcontainer/base.Dockerfile

# [Choice] Debian / Ubuntu version: debian-10, debian-9, ubuntu-20.04, ubuntu-18.04
ARG VARIANT="buster"
ARG http_proxy
ARG https_proxy
FROM mcr.microsoft.com/vscode/devcontainers/cpp:0-${VARIANT}

# remove clang-10, cause ck recommand to use clang-11
RUN apt-get update && \
        apt-get -y purge clang-10 libclang-common-10-dev libclang-cpp10 libclang1-10 llvm-10-tools libllvm10:amd64 llvm-10 llvm-10-runtime llvm-10-runtime

# [Optional] Uncomment this section to install additional packages.
RUN export DEBIAN_FRONTEND=noninteractive \
        && apt-get -y install git cmake python ninja-build vim lsb-release wget software-properties-common \
        && wget -O llvm.sh https://apt.llvm.org/llvm.sh \
        && chmod +x llvm.sh \
        && ./llvm.sh 11 \
        && apt-get -y install liblldb-11-dev

ENV CC=clang-11 CXX=clang++-11


## add user
ARG USERNAME=dev
ARG USER_UID=$UID
ARG USER_GID=$GID
# Create the user
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    #
    # [Optional] Add sudo support. Omit if you don't need to install software after connecting.
    && apt-get update \
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# ********************************************************
# * Anything else you want to do like clean up goes here *
# ********************************************************

# [Optional] Set the default user. Omit if you want to keep the default as root.
USER $USERNAME
```
修改devcontainer.json：
```json
{
        "name": "C++",
        "build": {
                "dockerfile": "Dockerfile",
                // Update 'VARIANT' to pick an Debian / Ubuntu OS version: debian-10, debian-9, ubuntu-20.04, ubuntu-18.04
                "args": {
                        "VARIANT": "ubuntu-20.04" ,
                        // centos04不能连公网所以配置代理，若远程机器可以连公网则忽略
                        "http_proxy": "http://10.0.0.181:8080" ,
                        "https_proxy": "http://10.0.0.181:8080" ,
                }
        },
        "runArgs": [ "--cap-add=SYS_PTRACE", "--security-opt", "seccomp=unconfined"],

        // Set *default* container specific settings.json values on container create.
        "settings": {
                "terminal.integrated.shell.linux": "/bin/bash"
        },

        // Add the IDs of extensions you want installed when the container is created.
        "extensions": [
                "ms-vscode.cpptools",
                "eamodio.gitlens"
        ],

        // Use 'forwardPorts' to make a list of ports inside the container available locally.
        // "forwardPorts": [],

        // Use 'postCreateCommand' to run commands after the container is created.
        // "postCreateCommand": "gcc -v",

        // Comment out connect as root instead. More info: https://aka.ms/vscode-remote/containers/non-root.
        // workspaceMount是指如何从远程机器上挂载目录到容器里，workspaceFolder设置为workspace的工作目录
        "remoteUser": "dev",
        "workspaceMount": "source=/home/wgm/ck-build/Clickhouse,target=/ck-src,type=bind,consistency=cached",
        "workspaceFolder": "/ck-src",
}
```
1. 打开vscode重新执行刚才的步骤，用`Remote containers open`打开本地文件夹，这样就会重新编译镜像，点右下角的`show logs ...`可以看到进度，等会制作完成后就会自动打开工作目录了；
1. 另外需要在容器里安装`C++`（其实按理应该有了，但是可能vscode有问题导致默认安装的不能用），步骤跟本机基本一致，如果提示网络问题，在菜单栏-Code-Preferences-Settings里搜索proxy，切换到第二个tab（默认本地），添加上面的代理，关闭后后重新打开文件夹，等待安装完成即可；


### 调试
1. 打开项目文件`.vscode/launch.json`，配置如下：
```json
{
    // Use IntelliSense to learn about possible attributes.
    // Hover to view descriptions of existing attributes.
    // For more information, visit: https://go.microsoft.com/fwlink/?linkid=830387
    "version": "0.2.0",
    "configurations": [
        {
            "name": "(gdb) Launch",
            "type": "cppdbg",
            "request": "launch",
            "program": "${workspaceFolder}/build/programs/clickhouse",
            "args": ["server",  "--config-file=config.xml"],
            "stopAtEntry": false,
            "cwd": "${workspaceFolder}",
            "environment": [],
            "externalConsole": false,
            "MIMode": "gdb",
            "setupCommands": [
                {
                    "description": "pretty",
                    "text": "-enable-pretty-printing",
                    "ignoreFailures": true
                }
            ],
            "preLaunchTask": "ninja"
        }
    ]
}
```

准备编译配置：`.vscode/tasks.json`：
```json
{
    "tasks": [
      {
        "type": "shell",
        "label": "clang",
        "command": "cd build; cmake -G Ninja .. -DCMAKE_C_COMPILER=$(command -v clang-11) -DCMAKE_CXX_COMPILER=$(command -v clang++-11) -DCMAKE_BUILD_TYPE=Debug -DENABLE_JEMALLOC=0 -DENABLE_LIBRARIES=ON -DENABLE_CLICKHOUSE_ALL=OFF -DENABLE_CLICKHOUSE_SERVER=ON"
      },
      {
        "type": "shell",
        "label": "ninja",
        "dependsOn": "clang",
        "command": "cd build; ninja -j 11 clickhouse-server"
      },
      /*
      {
        "type": "shell",
        "label": "Pull Master",
        "command": "git pull && git submodule update --init --recursive"
      }*/
    ],
    "version": "2.0.0"
  }
```

1. 点击vscode左侧的`Run And Debug`，点启动按钮，即可开始编译并且Debug（初次编译可能有点慢）；

