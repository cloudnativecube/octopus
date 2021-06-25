# Waterdrop介绍

## 文档

- 官方文档：https://interestinglab.github.io/waterdrop-docs/#/zh-cn/v2/
- github：https://github.com/InterestingLab/waterdrop
- PPT：
  - http://slides.com/garyelephant/waterdrop/fullscreen?token=GKrQoxJi
  - https://elasticsearch.cn/slides/127#page=1

## 功能

Waterdrop 是一个`非常易用`，`高性能`、支持`实时流式`和`离线批处理`的`海量数据`处理产品，架构于`Apache Spark` 和 `Apache Flink`之上。可对接多种数据源，以插件化形式开发方便扩展。理论上来讲，只要是flink和spark能够支持的数据源，waterdrop都可以支持。

其版本分为1.x和2.x，主要区别是：

- 1.x基于spark运行，批、流分别用spark sql和spark streaming实现。1.x的代码用sbt构建。
- 2.x基于flink和spark运行，两种引擎都支持批、流的实现（spark用spark sql、spark streaming，flink用flink dataset、flink stream）。另外，spark流式计算还预留了structure streaming的接口，可以自行开发实现。2.x的代码用maven构建。

waterdrop架构简单，分为source、transform、sink三个模块，分别称为“输入数据源”、“转换”、“输出数据源”，每个模块都支持插件化开发。以下简单列出了目前支持一些插件（不分区1.x和2.x版本，1.x的插件可以移植到2.x上）：

| Source  | Sink          | Transform        |
| ------- | ------------- | ---------------- |
| Fake    | Console       | Json             |
| Jdbc    | Clickhouse    | Split            |
| Socker  | Elasticsearch | Sql              |
| Kakfa   | File          | Add              |
| Phoenix | Hdfs          | Checksum         |
| Kudu    | Phoenix       | Convert          |
| MongoDB | OpenTSDB      | Date             |
| MySQL   | S3            | Drop             |
| Hive    | TiDB          | Join             |
| Redis   | Alluxio       | Json             |
| TiDB    |               | Rename           |
| Alluxio |               | Truncate（等等） |

用户在使用时，可以实际业务需求，将source、transform、sink灵活组合，例如：

- 一个source后面可以对接多个transform或多个sink。
- 一个transform后面可以再对接其他transform，或对接sink。

## 可行性分析

如果将waterdrop应用到我们的平台，优势及待改进项列举如下：

- 架构和代码实现非常简单，方便维护和扩展。
- 基于spark和flink两个优秀的计算引擎执行数据转换任务，性能有保证。
- waterdrop有一个子项目，用于监控和报警：https://github.com/InterestingLab/guardian 。

- waterdrop自身实现的tranform逻辑比较简单，需要再开发一些复杂的transform以满足更多的业务场景。