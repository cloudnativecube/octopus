## SSTable 
### 逻辑结构
![sstable](https://pic3.zhimg.com/v2-3c42c44f51e3d0804455437a2b01ac0a_r.jpg)

* data block: 存贮数据信息
* filter block：可选项。用于快速检索，bloom 过滤器等信息。TODO:原理还不清楚
* metaindex block：filter block 的索引
* index block: data block的索引数据。格式为|key|offset|size|， 其中key 为是截断的最大值(粗略的可以理解abcdd.., abfdd.. 截断最大值为abe)。
* footer：用来存储meta index block及index block的索引信息。
注意：sstable 中的数据以内存映射的形式加载到内存。所以想访问每部分数据，则需要知道起始位置，偏移量，大小。

### data block 
#### 通过index 可以定位 data block
![](https://leveldb-handbook.readthedocs.io/zh/latest/_images/indexblock_format.jpeg)

~~TODO: 根据index的max_key 定位时，还是顺序遍历。搞成二分查找？~~
>根据index的max_key 定位时，也是二分查找. index 格式为|key|offset|size|, 则把offset+size 作为value。data_block 和 index_block 的数据结构一直的。 

#### data block 的逻辑结构
![](../imgs/leveldb_logistical_data_block_detail.jpg)

```
举个例子
原始：
record0 = (abc, value0)
record1 = (abd, value1)
存贮：
record0= 3+0+5+abc+value0 
record1= 2+1+5+d+value1
```
其中shared_bytes、unshared_bytes、 value_length 都是varint.

查找时，不支持跳越。因而每隔n（默认16）个元素，强制保存key的全部信息。这就是restart point.
即restart point 的数据 `key_delta = key`.  则可以根据restart point 进行二分查找，再顺序查找即可。..

### 参考文献
1. https://leveldb-handbook.readthedocs.io/zh/latest/sstable.html#id1
2. https://github.com/balloonwj/CppGuide/blob/master/articles/leveldb%E6%BA%90%E7%A0%81%E5%88%86%E6%9E%90/leveldb%E6%BA%90%E7%A0%81%E5%88%86%E6%9E%907.md
