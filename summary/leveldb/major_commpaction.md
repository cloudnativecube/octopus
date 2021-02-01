## major commpaction

过程描述:
1. 进入到BackgroundCompaction， 开始进行 compaction
2. 如果rtable 有数据， 则进行 minor compaction。
3. 如果rtable 没有数据，则选择目标数据进行compaction。 // versions_->PickCompaction(); 这里边选择策略，就不展开了
4. 获取目标数据的迭代器（NewMergingIterator）
5. for kv 添加到 table, 如果有重复数据，则去重. 重点关于一下去重部分
6. 跟新meta信息

```
// 步骤1
void DBImpl::BackgroundCompaction() {
  mutex_.AssertHeld();

  if (imm_ != nullptr) {
    // 步骤2
    CompactMemTable();
    return;
  }

  // 步骤三， 后续会展开描述
  c = versions_->PickCompaction();
  CompactionState* compact = new CompactionState(c);
  // 步骤4，5，6. 接下来对这个函数展开
  status = DoCompactionWork(compact);
  if (!status.ok()) {
    RecordBackgroundError(status);
  }
  // 清理compaction 信息
  CleanupCompaction(compact);
  c->ReleaseInputs();
  // 清理过时的文件
  DeleteObsoleteFiles();
  // ...
}
```

核心部分，步骤4，5，6
```
Status DBImpl::DoCompactionWork(CompactionState* compact) {
  // ... 
  // 步骤4， 这个一个merge sort iter。在sstable 顺序读讲过了iter的迭代过程
  // 多路归并过程比较简单不再展开
  Iterator* input = versions_->MakeInputIterator(compact->compaction);
  // 指向第一个Entry
  input->SeekToFirst();
  Status status;
  ParsedInternalKey ikey;
  std::string current_user_key;
  bool has_current_user_key = false;
  SequenceNumber last_sequence_for_key = kMaxSequenceNumber;
  // 步骤5 核心
  for (; input->Valid() && !shutting_down_.load(std::memory_order_acquire);) {
    // Prioritize immutable compaction work
    if (has_imm_.load(std::memory_order_relaxed)) {
      const uint64_t imm_start = env_->NowMicros();
      mutex_.Lock();
      if (imm_ != nullptr) {
        CompactMemTable();
        // Wake up MakeRoomForWrite() if necessary.
        background_work_finished_signal_.SignalAll();
      }
      mutex_.Unlock();
      imm_micros += (env_->NowMicros() - imm_start);
    }

    Slice key = input->key();
    if (compact->compaction->ShouldStopBefore(key) &&
        compact->builder != nullptr) {
      status = FinishCompactionOutputFile(compact, input);
      if (!status.ok()) {
        break;
      }
    }

    // 有两种情况可以drop数据
    // 1. update
    //    当前的KEY 出现过，再次出现则直接drop。 
    //    例如 PUT(KEY, V1), PUT(KEY, V2)
    //    按照排序规则：比较User_key, 如果相等比较SequcenceNum。
    //    则(KEY, V2)先于 (KEY, V1)，
    //    则(KEY,V1) 可以扔掉
    //    或者  PUT(KEY, V1), DELETE(KEY)
    //    则(KEY, NULL) 先于 (KEY, V1)
    //    则(KEY, V1) 可以扔掉. (KEY, NULL) 保存到新的sstabl 中
    // 2. delete
    //    如果当前的type位delete，并且更高的level上没有出现这个KEY，则可以drop
    //    判断更高level 是否含有该KEY，直接通过meta 信息进行过滤，而没有真的定位到该KEY是否存在
  
    // Handle key/value, add to state, etc.
    bool drop = false;
    if (!ParseInternalKey(key, &ikey)) {
      // Do not hide error keys
      current_user_key.clear();
      has_current_user_key = false;
      last_sequence_for_key = kMaxSequenceNumber;
    } else {
      if (!has_current_user_key ||
          user_comparator()->Compare(ikey.user_key, Slice(current_user_key)) !=
              0) {
        // First occurrence of this user key
        current_user_key.assign(ikey.user_key.data(), ikey.user_key.size());
        has_current_user_key = true;
        last_sequence_for_key = kMaxSequenceNumber;
      }
      // 如果该key 是第一次出现则 last_sequence_for_key=kMaxSequenceNumber 很大的一个值
      // 则必然大于compact->smallest_snapshot
      // 如果不是第一次出现，last_sequence_for_key=上一个相同key的sequence num， 
      // 则必然小于compact->smallest_snapshot

      if (last_sequence_for_key <= compact->smallest_snapshot) {
        // Hidden by an newer entry for same user key
        drop = true;  // (A)
      } else if (ikey.type == kTypeDeletion &&
                 ikey.sequence <= compact->smallest_snapshot &&
                 compact->compaction->IsBaseLevelForKey(ikey.user_key)) {
        // delete type 并且更高的level 没有出现这个key
        // For this user key:
        // (1) there is no data in higher levels
        // (2) data in lower levels will have larger sequence numbers
        // (3) data in layers that are being compacted here and have
        //     smaller sequence numbers will be dropped in the next
        //     few iterations of this loop (by rule (A) above).
        // Therefore this deletion marker is obsolete and can be dropped.
        drop = true;
      }

      last_sequence_for_key = ikey.sequence;
    }
    if (!drop) {
      // Open output file if necessary
      if (compact->builder == nullptr) {
        status = OpenCompactionOutputFile(compact);
        if (!status.ok()) {
          break;
        }
      }
      if (compact->builder->NumEntries() == 0) {
        compact->current_output()->smallest.DecodeFrom(key);
      }
      compact->current_output()->largest.DecodeFrom(key);
      // sstable 的写操作
      compact->builder->Add(key, input->value());

      // Close output file if it is big enough
      if (compact->builder->FileSize() >=
          compact->compaction->MaxOutputFileSize()) {
        status = FinishCompactionOutputFile(compact, input);
        if (!status.ok()) {
          break;
        }
      }
    }
    // iter 迭代器，指向下一个KV
    input->Next();
  }
  // ... 更新一些统计信息

  // 步骤6， 跟新meta 信息
  if (status.ok()) {
    status = InstallCompactionResults(compact);
  }
  if (!status.ok()) {
    RecordBackgroundError(status);
  }
  VersionSet::LevelSummaryStorage tmp;
  Log(options_.info_log, "compacted to: %s", versions_->LevelSummary(&tmp));
  return status;
}
```
如何进行c = versions_->PickCompaction(); 整体效果如图.
在每次更新version完毕或者查找key后均会跟新
// void VersionSet::Finalize(Version* v);
// bool Version::UpdateStats(const GetStats& stats);
![](https://leveldb-handbook.readthedocs.io/zh/latest/_images/compaction_expand.jpeg)

1. 选取目标sstable，如果是level0， 根据overlap扩展是stable
2. 选取一下层和当前sstable 有overlap的sstables. 运行两次该方法,扩展leveli 和 leveli+1
```

Compaction* VersionSet::PickCompaction() {
  Compaction* c;
  int level;
  // 情况1： level0的文件数大于阈值，或者level1-6 文件容量大于阈值
  const bool size_compaction = (current_->compaction_score_ >= 1);
  // 情况2： 当某个文件无效读取的次数过多
  const bool seek_compaction = (current_->file_to_compact_ != nullptr);
  if (size_compaction) {
    // 情况1， 采用轮询机制
    level = current_->compaction_level_;
    c = new Compaction(options_, level);

    // Pick the first file that comes after compact_pointer_[level]
    for (size_t i = 0; i < current_->files_[level].size(); i++) {
      FileMetaData* f = current_->files_[level][i];
      if (compact_pointer_[level].empty() ||
          icmp_.Compare(f->largest.Encode(), compact_pointer_[level]) > 0) {
        c->inputs_[0].push_back(f);
        break;
      }
    }
    if (c->inputs_[0].empty()) {
      // Wrap-around to the beginning of the key space
      c->inputs_[0].push_back(current_->files_[level][0]);
    }
  } else if (seek_compaction) {
    // 情况2， 直接操作文件
    level = current_->file_to_compact_level_;
    c = new Compaction(options_, level);
    c->inputs_[0].push_back(current_->file_to_compact_);
  } else {
    return nullptr;
  }

  c->input_version_ = current_;
  c->input_version_->Ref();

  // level0 不是整体有序的， 所以要遍历全部level0 的sstable的meta，得到level0 的meta
  if (level == 0) {
    InternalKey smallest, largest;
    GetRange(c->inputs_[0], &smallest, &largest);
    current_->GetOverlappingInputs(0, &smallest, &largest, &c->inputs_[0]);
  }
  // 根据当前定位的sstable 的meta，选取下一层有重叠的sstable
  // 进一步展开
  SetupOtherInputs(c);
}


// 扩张leveli 和 liveli+1
void VersionSet::SetupOtherInputs(Compaction* c) {
  const int level = c->level();
  InternalKey smallest, largest;
  // 第一次扩张
  // 扩展当前层， 并获取meta最大值最小值
  // TODO: AddBoundaryInputs 没啥作用吧
  // 如果是 level0的sstable，则在调用前已经进行了扩张
  // 如果是 level1的sstable，是不存在overlap的
  AddBoundaryInputs(icmp_, current_->files_[level], &c->inputs_[0]);
  GetRange(c->inputs_[0], &smallest, &largest);
  // 根据最大值最小值扩张leveli+1 层
  current_->GetOverlappingInputs(level + 1, &smallest, &largest,
                                 &c->inputs_[1]);

  // 或者leveli 和 leveli+1 层的最大值最小值
  InternalKey all_start, all_limit;
  GetRange2(c->inputs_[0], c->inputs_[1], &all_start, &all_limit);

  // See if we can grow the number of inputs in "level" without
  // changing the number of "level+1" files we pick up.
  if (!c->inputs_[1].empty()) {
    // 第二次扩张
    std::vector<FileMetaData*> expanded0;
    current_->GetOverlappingInputs(level, &all_start, &all_limit, &expanded0);
    AddBoundaryInputs(icmp_, current_->files_[level], &expanded0);
    const int64_t inputs0_size = TotalFileSize(c->inputs_[0]);
    const int64_t inputs1_size = TotalFileSize(c->inputs_[1]);
    const int64_t expanded0_size = TotalFileSize(expanded0);
    if (expanded0.size() > c->inputs_[0].size() &&
        inputs1_size + expanded0_size <
            ExpandedCompactionByteSizeLimit(options_)) {
      InternalKey new_start, new_limit;
      GetRange(expanded0, &new_start, &new_limit);
      std::vector<FileMetaData*> expanded1;
      current_->GetOverlappingInputs(level + 1, &new_start, &new_limit,
                                     &expanded1);
      if (expanded1.size() == c->inputs_[1].size()) {
        Log(options_->info_log,
            "Expanding@%d %d+%d (%ld+%ld bytes) to %d+%d (%ld+%ld bytes)\n",
            level, int(c->inputs_[0].size()), int(c->inputs_[1].size()),
            long(inputs0_size), long(inputs1_size), int(expanded0.size()),
            int(expanded1.size()), long(expanded0_size), long(inputs1_size));
        smallest = new_start;
        largest = new_limit;
        // 存放leveli 的sstables
        c->inputs_[0] = expanded0;
        // 存放leveli+1 的sstables 
        c->inputs_[1] = expanded1;
        GetRange2(c->inputs_[0], c->inputs_[1], &all_start, &all_limit);
      }
    }
  }


```

