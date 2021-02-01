## git clone 慢的问题
解决方法为： 使用`github.com.cnpmjs.org`代替`github.com`

git clone clickhouse 为例
1. `git clone https://github.com.cnpmjs.org/ClickHouse/ClickHouse.git`(不要加 `--recursive` 参数) (cd ClickHouse)
2. `vim .gitmodule` + `:%s/github.com/github.com.cnpmjs.org/g`
3. `git submodule init && git submodule update`

### 参考
1. https://www.zhihu.com/question/27159393/answer/1117219745

