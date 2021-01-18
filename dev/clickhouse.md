# clickhouse

## build on macOS

安装软件包

```
brew install cmake ninja libtool gettext
brew install llvm // 会安装cmake
brew install binutils // 会安装objcopy
```

添加环境变量

```
echo 'export PATH="/usr/local/opt/llvm/bin:$PATH"' >> ~/.bash_profile
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

## IDE debug on macOS

编译时一定要加上-DCMAKE_BUILD_TYPE=Debug

启动server：

```
# ./build/programs/clickhouse server -C ./programs/server/config.xml
```

在CLion上选择Run->Attach to process，输入clickhouse并选择正在运行的server进程。

在CLion里选择代码打上断点。

启动client：

```
# ./build/programs/clickhouse client
```

执行一些语句，就可以停在断点上了。

