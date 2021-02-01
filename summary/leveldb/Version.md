## 版本控制
### 数据结构
* Version
* VersionSet
* VersionEdit
1. 通过`Get(KEY)` 方法获取VALUE时，则会调用掉`current->Get(options, lkey, value, &stats)` 这个`current`就是指向`当前Version`的指针
2. 经过`Compaction`时会更新`Version`. `new_version = old_version + version_edit`. 其中`Version Edit`代表在Compaction过程中产生的变化。例如：meta信息，新的sstable，删除的sstable。
3. VersionSet是一个双向链表，每当有新的Version产生时，则加入该链表。

通过以上两个方面可知，Version 是掌控着Leveldb读取写入的全局信息。

// 在open db 和 compaction 过程中均会调用LogAndApply。
```
Status VersionSet::LogAndApply(VersionEdit* edit, port::Mutex* mu) {
  // new_version = old + edit
  Version* v = new Version(this);
  {
    Builder builder(this, current_);
    builder.Apply(edit);
    builder.SaveTo(v);
  }
  // 根据version 信息，做一些检查。比如计算Level0-6哪一层适合compaction
  Finalize(v);

  // Initialize new descriptor log file if necessary by creating
  // a temporary file that contains a snapshot of the current version.
  // manifest结构会在下边给出。
  std::string new_manifest_file;
  Status s;

  // 如果descriptor_log_==null则新建一个文件

  // Unlock during expensive MANIFEST log write
  {
    mu->Unlock();

    // Write new record to MANIFEST log
    if (s.ok()) {
      std::string record;
      // 把edit 信息记录在 record 中
      edit->EncodeTo(&record);
      // 写log
      s = descriptor_log_->AddRecord(record);
      if (s.ok()) {
        s = descriptor_file_->Sync();
      }
      if (!s.ok()) {
        Log(options_->info_log, "MANIFEST write: %s\n", s.ToString().c_str());
      }
    }

    // If we just created a new descriptor file, install it by writing a
    // new CURRENT file that points to it.
    if (s.ok() && !new_manifest_file.empty()) {
      s = SetCurrentFile(env_, dbname_, manifest_file_number_);
    }

    mu->Lock();
  }

  // Install the new version
  if (s.ok()) {
    // new version 加入到vset，并把current指向new version
    AppendVersion(v);
    log_number_ = edit->log_number_;
    prev_log_number_ = edit->prev_log_number_;
  } 
}
```

### manifest 逻辑结构
![](https://images2015.cnblogs.com/blog/384029/201612/384029-20161218225859729-1379682001.png)

### VersionSet 的功能
1. 既然Version 是一个最新的全局信息，为什么还要保留old version？
2. 如果在顺序遍历数据库时，发生了Compaction，怎样保证读写一致？

关注这块可以关注`Multiversion Concurrency Control`内容。

其实Version 这块是比较复杂了。这里只是high level 的介绍. 更多可以阅读参考文献

### TODO LIST
* MVCC
  
### 参考文献
1. https://github.com/balloonwj/CppGuide/blob/master/articles/leveldb%E6%BA%90%E7%A0%81%E5%88%86%E6%9E%90/leveldb%E6%BA%90%E7%A0%81%E5%88%86%E6%9E%9015.md
2. https://leveldb-handbook.readthedocs.io/zh/latest/version.html#current
3. https://draveness.me/database-concurrency-control/