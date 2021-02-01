## data block 的读写过程

### 写过程
代码位置：table/block_builder.h .cc 
```
// 向data block 添加KV.
void BlockBuilder::Add(const Slice& key, const Slice& value) {
  // 上次添加的key（internal_key）
  Slice last_key_piece(last_key_);
  size_t shared = 0;
  // block_restart_interval 重启点间隔
  // 对于第一条KV，last_key_为空，则第一条肯定是重启点
  if (counter_ < options_->block_restart_interval) {
    // See how much sharing to do with previous string
    const size_t min_length = std::min(last_key_piece.size(), key.size());
    while ((shared < min_length) && (last_key_piece[shared] == key[shared])) {
      shared++;
    }
  } else {
    // Restart compression
    restarts_.push_back(buffer_.size());
    counter_ = 0;
  }
  // 如果shared == 0, 则代表当前key 和上一个key没有公共部分，因而是可以作为重启点的
  // if (counter_ < options_->block_restart_interval) {
  //   // See how much sharing to do with previous string
  //   const size_t min_length = std::min(last_key_piece.size(), key.size());
  //   while ((shared < min_length) && (last_key_piece[shared] == key[shared])) {
  //     shared++;
  //   }
  // }
  // if (shared == 0 || last_key_.empty()) {
  //   restarts_.push_back(buffer_.size());
  //   counter_ = 0;
  // }
  // 当然这是存贮和查找的折中，如果存储的数据太大，也是不利于查找的。

  const size_t non_shared = key.size() - shared;

  // Add "<shared><non_shared><value_size>" to buffer_
  PutVarint32(&buffer_, shared);
  PutVarint32(&buffer_, non_shared);
  PutVarint32(&buffer_, value.size());

  // Add string delta to buffer_ followed by value
  buffer_.append(key.data() + shared, non_shared);
  buffer_.append(value.data(), value.size());

  // Update state
  last_key_.resize(shared);
  last_key_.append(key.data() + shared, non_shared);
  assert(Slice(last_key_) == key);
  counter_++;
}

// 如果一个datablock 的大小超于阈值， 则进行flush。
// 在flush 之前，应该把把冲洗点信息加入到buffer 中。（还需要记录是否压缩，crc校验，至此datablock构造完毕）
Slice BlockBuilder::Finish() {
  // Append restart array
  // restarts_ 记录了每个重启点的位置
  for (size_t i = 0; i < restarts_.size(); i++) {
    PutFixed32(&buffer_, restarts_[i]);
  }
  PutFixed32(&buffer_, restarts_.size());
  finished_ = true;
  return Slice(buffer_);
}
```

### Fixed32 和 Varint32
先考虑一个问题，在只给出指针的情况下， 怎么解析出数据

因为使用内存映射，数据在磁盘和内存的逻辑排列形式是一样的。
在内存中读取数据, 如果约定好类型，则可以直接解析。否则知道必须数据的长度。 varint通过约定的方式，可以解析值的大小，以及改值占多少个字节, 这个值就代表目标数据的size。

```
以data block为例, 假设
|shared|unshard|value_size|key_detal|value|...|restart0|...|restartn-1|n|
shared, unshard, value_size 是varint 类型
restart0 到 restartn-1，以及n 均是Fixed32

那么，直接通过 buffer_size-4 就能获取数值n。
通过n，则 buffer_size-4-n*4 就能得到重启点的首地址。因为是数组可以随机访问（二分查找）
```
那么为什么不全部用Fixed呢？ 原因显而易见，

### 读过程
源码table/block.h .cc. 获取record通过迭代器获取。
```
// 先看三个小函数
// 获取下一个Entry的偏移量。（对照写过程）
inline uint32_t NextEntryOffset() const {
  return (value_.data() + value_.size()) - data_;
}
// 重启点是一个数组，所以可以随机访问
// int32* p = data_ + restarts_ , 直接返回 p[index]
uint32_t GetRestartPoint(uint32_t index) {
  return DecodeFixed32(data_ + restarts_ + index * sizeof(uint32_t));
}
// 根据重启点，重置了Entry的起始位置。
void SeekToRestartPoint(uint32_t index) {
  key_.clear();
  restart_index_ = index;
  // current_ will be fixed by ParseNextKey();
  // ParseNextKey() starts at the end of value_, so set value_ accordingly
  uint32_t offset = GetRestartPoint(index);
  // 这里value_是该restart_point的起始位置，之后调用NextEntryOffset 就能获取restart_point 的内容
  value_ = Slice(data_ + offset, 0);
}
```
对迭代器的访问一般有， 1. 顺序访问`for(it->SeekToFirst(); it->Valid(); it—>Next()` 或者逆序访问, 2 根据target进行查找`it->Seek(target)`

顺序访问逻辑很简单。如果逆序访问，时间负责幅度超高。这里仅对`解析`函数展开
```
// 根据上一个Entry的value_, 解析下一个Entry, 这里利用value_进行指针的移动
bool ParseNextKey() {
  current_ = NextEntryOffset();
  // p 是上一个Entry(value_)的结束位置，即当前Entry 的开始位置
  const char* p = data_ + current_;

  // ... 

  // DecodeEntry解析出3个varint，把key_detal的起始位置赋给p 
  p = DecodeEntry(p, limit, &shared, &non_shared, &value_length);
  if (p == nullptr || key_.size() < shared) {
    CorruptionError();
    return false;
  } else {
    // 公共前缀
    key_.resize(shared);
    // 拼接成完成key
    key_.append(p, non_shared);
    // 获取value，
    // 则根绝当前value_, 可以获取下一个Entry的偏移量(value_.data() + value_.size() - data_)
    value_ = Slice(p + non_shared, value_length);
    while (restart_index_ + 1 < num_restarts_ &&
           GetRestartPoint(restart_index_ + 1) < current_) {
      ++restart_index_;
    }
    return true;
  }
}
```

根据target进行查找
```
virtual void Seek(const Slice& target) {
  // 重启点是一个数组，可以随机访问
  // 重启点的key是完整的
  // 那么进行二分查找, 找到目标重启点(restart_point.key < target)
  // 再顺序遍历, 找到第一个Key>=target, 返回
  uint32_t left = 0;
  uint32_t right = num_restarts_ - 1;
  while (left < right) {
    uint32_t mid = (left + right + 1) / 2;
    uint32_t region_offset = GetRestartPoint(mid);
    uint32_t shared, non_shared, value_length;
    const char* key_ptr =
        DecodeEntry(data_ + region_offset, data_ + restarts_, &shared,
                    &non_shared, &value_length);
    if (key_ptr == nullptr || (shared != 0)) {
      CorruptionError();
      return;
    }
    Slice mid_key(key_ptr, non_shared);
    if (Compare(mid_key, target) < 0) {
      // Key at "mid" is smaller than "target".  Therefore all
      // blocks before "mid" are uninteresting.
      left = mid;
    } else {
      // Key at "mid" is >= "target".  Therefore all blocks at or
      // after "mid" are uninteresting.
      right = mid - 1;
    }
  }

  // Linear search (within restart block) for first key >= target
  SeekToRestartPoint(left);
  while (true) {
    if (!ParseNextKey()) {
      return;
    }
    if (Compare(key_, target) >= 0) {
      return;
    }
  }
}
```


