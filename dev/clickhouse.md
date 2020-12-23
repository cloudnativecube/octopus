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
$ cmake ..-DCMAKE_C_COMPILER=`brew --prefix llvm`/bin/clang -DCMAKE_CXX_COMPILER=`brew --prefix llvm`/bin/clang++ -DCMAKE_PREFIX_PATH=`brew --prefix llvm`
$ ninja
$ cd ..
```

