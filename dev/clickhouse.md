# clickhouse

## build on centos7

### 参考文档

- https://clickhouse.tech/docs/en/development/build/
- https://clickhouse.tech/docs/en/development/cmake-in-clickhouse/

### 准备工作

系统环境：

```
# cat /etc/centos-release
CentOS Linux release 7.7.1908 (Core)
# uname -r
3.10.0-1062.el7.x86_64
```

**注意：磁盘空间至少预留40G，因为clickhouse编译后整个目录大小为34G。**

安装如下软件包：

```
# yum install -y git cmake python ninja-build clang
# yum install -y libicu-devel readline-devel mariadb-devel openssl-devel unixODBC-devel
```

clickhouse的编译有以下两种途径：

- cmake + gcc + make：要求版本gcc-10以上。
- cmake + clang + ninja：要求版本clang-8以上。

本次编译采用第二种方式。注意，clang的编译要依赖gcc-5.1.0以上，但是5.1.0这个版本有bug，会产生“编译器内部错误：段错误”，所以这里选择了gcc-6.5.0版本。按照gcc-6.5.0的编译方式也可以编译gcc-10.1.0（不要选择gcc-10.2.0，编译过程中有错误）。

### 安装clang

编译clang之前的依赖项：https://llvm.org/docs/GettingStarted.html#requirements。

这里主要记录gcc和cmake的编译和安装过程。

#### 安装gcc-6.5.0

```
// 安装texinfo
# yum install -y texinfo

// 安装automake，版本在1.14.1以上
# wget https://ftp.gnu.org/gnu/automake/automake-1.14.1.tar.xz
# tar xvf automake-1.14.1.tar.xz
# cd automake-1.14.1/
# ./bootstrap.sh
# ./configure && make && make install

// 安装gcc-6.5.0
# wget http://mirror.hust.edu.cn/gnu/gcc/gcc-6.5.0/gcc-6.5.0.tar.xz
# cd gcc-6.5.0/
// 下载依赖的软件包GMP、MPFR、MPC等，在该脚本中可看到它们的版本号。可以去百度上搜索对应的包，拷到本目录再执行此命令。
# ./contrib/download_prerequisites
# mkdir build
# cd build
# ../configure --enable-checking=release --enable-languages=c,c++ --disable-multilib
# make -j8 // 8线程同时跑
# make install
```

注意：

- 报错`Error：Building GCC requires GMP 4.2+, MPFR 3.1.0+ and MPC 0.8.0+`： https://rtczza.blog.csdn.net/article/details/107682135。
- gcc下载地址：http://mirror.hust.edu.cn/gnu/gcc。

#### 安装cmake

```
第一种方法（安装完成之后要使用cmake3命令）：
# yum install -y cmake3
# cmake3 --version
cmake3 version 3.17.5

第二种方法：
# wget https://github.com/Kitware/CMake/releases/download/v3.19.3/cmake-3.19.3-Linux-x86_64.tar.gz
# tar xvf cmake-3.19.3-Linux-x86_64.tar.gz
# vim ~/.bashrc
// 添加以下cmake别名，指向bin文件所在路径，后面使用cmake时就可以不用敲路径前缀了
alias cmake='/export/cmake-3.19.3-Linux-x86_64/bin/cmake'
```

#### 安装clang

编译手册：https://llvm.org/docs/GettingStarted.html，但参考意义不大，不如参考：https://www.jianshu.com/p/d7905fe696b0。

```
# git clone https://github.com.cnpmjs.org/llvm/llvm-project.git
# cd llvm-project
# git checkout remotes/origin/release/11.x
# mkdir build
# cd build
# cmake3 -DCMAKE_C_COMPILER=/usr/local/bin/gcc -DCMAKE_CXX_COMPILER=/usr/local/bin/g++ -DCMAKE_C_FLAGS=-L/usr/local/lib64 -DCMAKE_CXX_FLAGS=-L/usr/local/lib64 -DCMAKE_CXX_LINK_FLAGS="-Wl,-rpath,/usr/local/lib64 -L/usr/local/lib64" -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_PROJECTS="clang;compiler-rt;lld" -G "Ninja" ../llvm
# ninja
```

ninja在编译过程中可能出现如下错误：

```
中文 “g++: 编译器内部错误：已杀死(程序 cc1plus)”
英文 “g++: internal compiler error: Killed (program cc1plus)”
```

解决办法是增大虚拟机内存，或减少ninja并行任务数（默认是10个并行，改成使用4个：`ninja -j4`）。

### 编译clickhouse

```
// 注意指定clang可执行文件的路径和llvm生成文件的路径
# cmake3 .. \
    -DCMAKE_C_COMPILER=/export/llvm-project/build/bin/clang \
    -DCMAKE_CXX_COMPILER=/export/llvm-project/build/bin/clang++ \
    -DCMAKE_PREFIX_PATH=/export/llvm-project/build \
    -DCMAKE_BUILD_TYPE=Release \
    -DENABLE_CLICKHOUSE_ALL=OFF \
    -DENABLE_CLICKHOUSE_COPIER=ON 
# ninja
```

以下两个参数的作用是只编译clickhouse-copier模块，默认是编译所有模块。参考：https://clickhouse.tech/docs/en/development/cmake-in-clickhouse/。

```
-DENABLE_CLICKHOUSE_ALL=OFF
-DENABLE_CLICKHOUSE_COPIER=ON
```

如果不指定`-DCMAKE_BUILD_TYPE=Release`，则按Debug方式编译，编译出的clickhouse可执行文件很大，可以用`strip --strip-debug programs/clickhouse`移除debug信息，减小文件大小（从2G减小到300M+）。

## build on macOS

### 编译步骤

安装软件包

```
$ brew install cmake ninja libtool gettext
$ brew install llvm // 会安装cmake
$ brew install binutils // 会安装objcopy
```

添加环境变量

```
$ echo 'export PATH="/usr/local/opt/llvm/bin:$PATH"' >> ~/.bash_profile
```

编译

```
$ git clone --recursive https://github.com/ClickHouse/ClickHouse.git
$ cd ClickHouse
$ mkdir build
$ cd build
$ cmake .. -DCMAKE_C_COMPILER=`brew --prefix llvm`/bin/clang -DCMAKE_CXX_COMPILER=`brew --prefix llvm`/bin/clang++ -DCMAKE_PREFIX_PATH=`brew --prefix llvm` -DCMAKE_BUILD_TYPE=Debug // Debug选项可选
$ ninja
$ cd ..
```

### 错误处理

如果出现以下状态，同时cmake出错，则需要重新下载第三方库：

```
$ git status
  modified:   contrib/abseil-cpp (modified content)
	modified:   contrib/antlr4-runtime (modified content)
	modified:   contrib/grpc (untracked content)
```

然后把以上目录删除，再执行：

```
$ git submodule update --init --recursive
Submodule path 'contrib/antlr4-runtime': checked out 'a2fa7b76e2ee16d2ad955e9214a90bbf79da66fc'
Submodule path 'contrib/grpc': checked out '7436366ceb341ba5c00ea29f1645e02a2b70bf93'
Submodule path 'contrib/grpc/third_party/cares/cares': checked out 'e982924acee7f7313b4baa4ee5ec000c5e373c30'
```



## CLion configuration on macOS

Preferences>Build,Execution,Deployment>Toolchains

```
Name: Deafult
CMake: cmake (/usr/local/Cellar/cmake/3.19.1/bin/cmake)
Make: Detected: /usr/bin/make
C Compiler: /usr/local/opt/llvm/bin/clang
C++ Compiler: /usr/local/opt/llvm/bin/clang++
Debugger: Bundled LLDB
```

## CLion debug on macOS

编译时一定要加上-DCMAKE_BUILD_TYPE=Debug

启动server：

```
$ ./build/programs/clickhouse server -C ./programs/server/config.xml
```

在CLion上选择Run->Attach to process，输入clickhouse并选择正在运行的server进程。

在CLion里选择代码打上断点。

启动client：

```
$ ./build/programs/clickhouse client
```

执行一些语句，就可以停在断点上了。

