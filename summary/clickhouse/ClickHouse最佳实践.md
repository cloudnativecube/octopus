# ClickHouse最佳实践

- ClickHouse需要用排序键索引来进行"跳跃"扫描，用户建表时应尽量把业务记录生命周期中不变的字段都放入排序键(一般distinct count越小的列放在越前)。
- order by则是单个DataPart文件内部记录的"有序状态"。