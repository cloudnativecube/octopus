## SSTable 读写

### SSTable 写
这里介绍的 sstable写为rtable 中的数据写入磁盘过程。即minor compaction 过程。 major commpaction 会在后边介绍

[这里](https://github.com/FishermanZzhang/CodeAnnotation/blob/main/leveldb/leveldb_high_level_%E4%BB%8B%E7%BB%8D.md#write-%E8%BF%87%E7%A8%8B)介绍了KV 写入`wtable`, `rtable`, `SSTable`的过程. 对SSTable 写过程进行展开

```
// 添加KV
void TableBuilder::Add(const Slice& key, const Slice& value) {
  Rep* r = rep_;
  assert(!r->closed);
  if (!ok()) return;
  if (r->num_entries > 0) {
    assert(r->options.comparator->Compare(key, Slice(r->last_key)) > 0);
  }
  // 只有data block 写flush， 后pending_index_entry才会为真
  if (r->pending_index_entry) {
    // 这里做了校验
    assert(r->data_block.empty());
    // Key截断的最大值
    r->options.comparator->FindShortestSeparator(&r->last_key, key);
    std::string handle_encoding;
    r->pending_handle.EncodeTo(&handle_encoding);
    // value 为block的offset 和 size
    r->index_block.Add(r->last_key, Slice(handle_encoding));
    r->pending_index_entry = false;
  }

  if (r->filter_block != nullptr) {
    r->filter_block->AddKey(key);
  }

  r->last_key.assign(key.data(), key.size());
  r->num_entries++;
  // data block 写过程参考https://github.com/FishermanZzhang/CodeAnnotation/blob/main/leveldb/table/data_block.md#%E5%86%99%E8%BF%87%E7%A8%8B
  r->data_block.Add(key, value);
  
  const size_t estimated_block_size = r->data_block.CurrentSizeEstimate();
  if (estimated_block_size >= r->options.block_size) {
    Flush();
  }
}

void TableBuilder::Flush() {
  // 又做了了校验
  assert(!r->pending_index_entry);
  WriteBlock(&r->data_block, &r->pending_handle);
  if (ok()) {
    // 把data block 成功写入后，把index开启了index 的开关
    r->pending_index_entry = true;
    r->status = r->file->Flush();
  }
  if (r->filter_block != nullptr) {
    r->filter_block->StartBlock(r->offset);
  }
}

// WriteBlock 的逻辑为：
// block 调用Finish(), 获得当前block全部数据
// 选择压缩算法, 把block中的数据进行压缩
// 调用WriteRawBlock
// block重置

void TableBuilder::WriteRawBlock(const Slice& block_contents,
                                 CompressionType type, BlockHandle* handle) {
  Rep* r = rep_;
  // handle 是当前block 的索引信息
  handle->set_offset(r->offset);
  handle->set_size(block_contents.size());
  // 内容追加到文件
  r->status = r->file->Append(block_contents);
  if (r->status.ok()) {
    // kBlockTrailerSize = 5
    // 压缩方式1B
    // crc 4B
    char trailer[kBlockTrailerSize];
    trailer[0] = type;
    uint32_t crc = crc32c::Value(block_contents.data(), block_contents.size());
    crc = crc32c::Extend(crc, trailer, 1);  // Extend crc to cover block type
    EncodeFixed32(trailer + 1, crc32c::Mask(crc));
    // 追加压缩方式 和 crc校验信息
    r->status = r->file->Append(Slice(trailer, kBlockTrailerSize));
    if (r->status.ok()) {
      r->offset += block_contents.size() + kBlockTrailerSize;
    }
  }
}

// sstable 通过Flush 追加data_block, 且其更新index_block
// 追加以下内容
// filter_block, metaindex_block(filter_index_block)
// index_block(data_index_index)
// footer
Status TableBuilder::Finish() {
  Rep* r = rep_;
  Flush();
  assert(!r->closed);
  r->closed = true;

  BlockHandle filter_block_handle, metaindex_block_handle, index_block_handle;

  // Write filter block
  if (ok() && r->filter_block != nullptr) {
    WriteRawBlock(r->filter_block->Finish(), kNoCompression,
                  &filter_block_handle);
  }

  // Write metaindex block
  if (ok()) {
    BlockBuilder meta_index_block(&r->options);
    if (r->filter_block != nullptr) {
      // Add mapping from "filter.Name" to location of filter data
      std::string key = "filter.";
      key.append(r->options.filter_policy->Name());
      std::string handle_encoding;
      filter_block_handle.EncodeTo(&handle_encoding);
      meta_index_block.Add(key, handle_encoding);
    }

    // TODO(postrelease): Add stats and other meta blocks
    WriteBlock(&meta_index_block, &metaindex_block_handle);
  }

  // Write index block
  if (ok()) {
    if (r->pending_index_entry) {
      r->options.comparator->FindShortSuccessor(&r->last_key);
      std::string handle_encoding;
      r->pending_handle.EncodeTo(&handle_encoding);
      r->index_block.Add(r->last_key, Slice(handle_encoding));
      r->pending_index_entry = false;
    }
    WriteBlock(&r->index_block, &index_block_handle);
  }

  // Write footer
  if (ok()) {
    Footer footer;
    footer.set_metaindex_handle(metaindex_block_handle);
    footer.set_index_handle(index_block_handle);
    std::string footer_encoding;
    footer.EncodeTo(&footer_encoding);
    r->status = r->file->Append(footer_encoding);
    if (r->status.ok()) {
      r->offset += footer_encoding.size();
    }
  }
  return r->status;
}
```


### SSTable 读之随机读
简单回顾一下 客户端查找的过程：
1. 在wtable 中查找，如果没找到进入下一步
2. 在itable 中查找， 如果没有找到进入一下步
3. 在level0 上的sstable(磁盘--> 内存)， 如果没有找到进入下一步
4. 依次在level1 到 6 中查找。

步骤3 和 步骤4 的区别是， level0 中的sstable（一般是4个）是局部有序的。所以需要按照时间倒序查找即可。

步骤4：
1. 每个level 中的数据都是全局有序的， 所以可以基于meta信息二分查找定位具体的sstable. 
2. sstable 中可以使用 index 进行二分查找，定位重启点，再顺序遍历，定位data block。
3. [data block 读过程](./sstable_write_read.md) 进行二分查找，定位找到重启点，再顺序遍历定位KEY。

// 调用过程为`DBImpl::Get --> Version::Get --> FindFile if level> 0 else sstable sort --> TableCache::Get`

// 如果sstable 在磁盘中，则需要把数据读入内存，并加入cache（LRU）
// 在sstable 中进行查找
```
Status TableCache::Get(const ReadOptions& options, uint64_t file_number,
                       uint64_t file_size, const Slice& k, void* arg,
                       void (*handle_result)(void*, const Slice&,
                                             const Slice&)) {
  Cache::Handle* handle = nullptr;
  // file_number是sstable 的文件号
  // 首先 cache 中查找 sstable，如果没有则读取磁盘，并加入到cache中
  Status s = FindTable(file_number, file_size, &handle);
  if (s.ok()) {
    Table* t = reinterpret_cast<TableAndFile*>(cache_->Value(handle))->table;
    // sstable 中进行查找，对这个函数进行展开如下
    s = t->InternalGet(options, k, arg, handle_result);
    cache_->Release(handle);
  }
  return s;
}
```
读取sstable 的过程为读取 index block 再读取data block

index 和 data block 的存贮形式一致。参考[datablock读](./data_block.md#读过程)

```
// handle_result 功能：比较当前找到的KEY(internel_key) 的type类型以及是否和user_key 相等。
// 实现位于version_set.cc 中的SaveValue(void* arg, const Slice& ikey, const Slice& v)
Status Table::InternalGet(const ReadOptions& options, const Slice& k, void* arg,
                          void (*handle_result)(void*, const Slice&,
                                                const Slice&)) {
  Status s;
  // 获取index，从而定位data block
  Iterator* iiter = rep_->index_block->NewIterator(rep_->options.comparator);
  // 根据重启点进行二分查找，再进行顺序遍历
  iiter->Seek(k);
  if (iiter->Valid()) {
    Slice handle_value = iiter->value();
    FilterBlockReader* filter = rep_->filter;
    BlockHandle handle;
    if (filter != nullptr && handle.DecodeFrom(&handle_value).ok() &&
        !filter->KeyMayMatch(handle.offset(), k)) {
      // Not found
    } else {
      // 根据index的value，即offset|size, 获取data block
      Iterator* block_iter = BlockReader(this, options, iiter->value());
      // 根据重启点进行二分查找，再进行顺序遍历
      block_iter->Seek(k);
      if (block_iter->Valid()) {
        (*handle_result)(arg, block_iter->key(), block_iter->value());
      }
      s = block_iter->status();
      delete block_iter;
    }
  }
  if (s.ok()) {
    s = iiter->status();
  }
  delete iiter;
  return s;
}
```

### SSTable 读之顺序读
```
leveldb::DB* db;
// db 经过初始化后
auto it = db->NewIterator(leveldb::ReadOptions());
for (it->SeekToFirst(); it->Valid(); it->Next()) {
  auto key = it->key();
  auto value = it->value();
}
```

简单看一下迭代器的构造过程
```
db->NewIterator(leveldb::ReadOptions()); -->
Iterator* iter = NewInternalIterator(options, &latest_snapshot, &seed);

Iterator* DBImpl::NewInternalIterator(const ReadOptions& options,
                                      SequenceNumber* latest_snapshot,
                                      uint32_t* seed) {
  // ...
  std::vector<Iterator*> list;
  // wtable 的迭代器
  list.push_back(mem_->NewIterator());
  mem_->Ref();
  if (imm_ != nullptr) {
    // rtable 的迭代器
    list.push_back(imm_->NewIterator());
    imm_->Ref();
  }
  // sstable的迭代器，后续代码会展
  versions_->current()->AddIterators(options, &list);
  // 由于compaction 过程，wtable，rtable level0的sstable, level1-6 并不是全局有序的 ，所以要排序。不做展开
  Iterator* internal_iter =
      NewMergingIterator(&internal_comparator_, &list[0], list.size());
  versions_->current()->Ref();
}

// AddIterators 里边有两个迭代器，对于level0，和level1-6
// level0
vset_->table_cache_->NewIterator(options, files_[0][i]->number, files_[0][i]->file_size)
// level>0
NewConcatenatingIterator(options, level)

// 这两个迭代器， 都会构造成
NewTwoLevelIterator(new LevelFileNumIterator(vset_->icmp_, &files_[level]), &GetFileIterator,vset_->table_cache_, options)
// 为什么叫Two Level 呢？
// 这是由于sstable 是两层的结构，有index block，通过index block 可以定位data block
// 同时拥有index iter 和 data iter， 并且它们是层级关系就叫做Two Level iter了。
关于 index/data iter 的具体原理，在data block 的读取已经讲过了.
```

### LSM Tree 读过程思考
* 当某个文件无效读取的次数过多， 则也会可能触发compaction。
```
  // DBImpl::Get 中， 代码如下
  if (have_stat_update && current->UpdateStats(stats)) {
    MaybeScheduleCompaction();
  }
  
bool Version::UpdateStats(const GetStats& stats) {
  FileMetaData* f = stats.seek_file;
  if (f != nullptr) {
    f->allowed_seeks--;
    if (f->allowed_seeks <= 0 && file_to_compact_ == nullptr) {
      file_to_compact_ = f;
      file_to_compact_level_ = stats.seek_file_level;
      return true;
    }
  }
  return false;
}
```
#### 思考1
LSM Tree 读过程为层次遍历。 如果一个要读取的key在最高层，则必须经过依次遍历底层的数据。
那么，是否可以把一些高层比较热的table（block）， 重新提交到底层？
#### 思考2
是否能够出现读写分离的场景（在大数据场景下）, 写操作完成后，统一排序，写成B+Tree。
#### 思考3
LSM Tree 的本质是为了加速写， 并没有加速读或者说是以降低读，来换取的写。
那么，是否可以把`Tree`变成`Forest`





