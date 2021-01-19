## MemTable
leveldb 包含wtable, rtable。memtable 的数据结构本质上是SlipList
`typedef SkipList<const char*, KeyComparator> Table`

一般memtable的大小为4\*1024\*1024, data_block 的大小为4*1024

这里对节点插入进行展开.
先看一下比较器, InternalKeyComparator排序规则为：
1. 按照user_key 升序。(user_comparator_ 默认为BytewiseComparator)
2. 按照sequence num 降序。
```
// format.h .cc
// 这里的key 为internal_key
int InternalKeyComparator::Compare(const Slice& akey, const Slice& bkey) const {
  // Order by:
  //    increasing user key (according to user-supplied comparator)
  //    decreasing sequence number
  //    decreasing type (though sequence# should be enough to disambiguate)
  int r = user_comparator_->Compare(ExtractUserKey(akey), ExtractUserKey(bkey));
  if (r == 0) {
    const uint64_t anum = DecodeFixed64(akey.data() + akey.size() - 8);
    const uint64_t bnum = DecodeFixed64(bkey.data() + bkey.size() - 8);
    if (anum > bnum) {
      r = -1;
    } else if (anum < bnum) {
      r = +1;
    }
  }
  return r;
}
```
SlipList insert 操作。(给一个有序单链表，插入KEY,插入后仍然有序)
```
// 这里的Key的形式为：user_size+user_key+(SN|Type)+value_size+value
// 通过memtable.cc 中的KeyComparator，会把Key解析成internal_key=user_key+(SN|Type)
// KeyComparator重载了()
template <typename Key, class Comparator>
void SkipList<Key, Comparator>::Insert(const Key& key) {
  Node* prev[kMaxHeight];
  // 找到前驱们，和当前要插入的位置。这个位置就是x所在的位置。
  // FindGreaterOrEqual --> KeyIsAfterNode --> 调用重载的()
  Node* x = FindGreaterOrEqual(key, prev);
  // 随机生成高度，即当前key后继指针的个数
  int height = RandomHeight();
  // 如果高度超过了当前sliplist 的最大值，则超过部分的pre为head_
  if (height > GetMaxHeight()) {
    for (int i = GetMaxHeight(); i < height; i++) {
      prev[i] = head_;
    }
    // 多线程
    max_height_.store(height, std::memory_order_relaxed);
  }
  // 构造当前节点
  x = NewNode(key, height);
  for (int i = 0; i < height; i++) {
    // 链表的插入操作
    x->NoBarrier_SetNext(i, prev[i]->NoBarrier_Next(i));
    prev[i]->SetNext(i, x);
  }
}
```
### memory oder 
1. http://senlinzhan.github.io/2017/12/04/cpp-memory-order/
