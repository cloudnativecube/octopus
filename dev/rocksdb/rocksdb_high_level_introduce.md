## rocksdb
### 架构图

![架构](https://img-blog.csdn.net/20151129153850144)

rocksdb对leveldb的优化
* 增加了column family. 所有 CF 共享一个 WAL 文件，但是每个 CF 有自己单独的 memtable & ssttable(sstfile)，即 log 共享而数据分离。
* 内存中有多个immute memtalbe，可防止Leveldb中的 write stall
* flush与compation分开不同的线程池来调度，flush优先级高于compation.
* 可支持多线程同时compation.
* 支持DB级的TTL
* 增加了merge operator. 
* Multithread compaction
* Multithread memtable inserts
* Reduced DB mutex holding
* Optimized level-based compaction style and universal compaction style
* Prefix bloom filter
* Memtable bloom filter
* Single bloom filter covering the whole SST file
* Write lock optimization
* Improved Iter::Prev() performance
* Fewer comparator calls during SkipList searches
* Allocate memtable memory using huge page.

### memtable inserts
leveldb groupcommit
![leveldb](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/89e2746a08e478cfbb23f75f3949d69a.png)

rocksdb ***pipelined*** write
![rocksdb](https://ata2-img.oss-cn-zhangjiakou.aliyuncs.com/14840bd3f5f8a69f12f268fe8cdc22e0.png)
1. JoinBatchGroup. 所有的writer 完成WAL之后, 多个writer同时写
2. pipelined. 在1的基础上, 单个writer完成wal, 不需要等待其他的writer的wal. 则开始写操作.


### 参考文献
1. https://blog.csdn.net/flyqwang/article/details/50096377
2. http://alexstocks.github.io/html/rocksdb.html
3. https://github.com/facebook/rocksdb/wiki/Features-Not-in-LevelDB