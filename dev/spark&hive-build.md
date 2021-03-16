# spark-2.4.7编译

- 编译命令

  ```
  # mvn clean package -Phadoop-2.7 -Phive -Phive-thriftserver -Pyarn -Dmaven.test.skip=true -DskipTests
  # ./dev/make-distribution.sh  --name hadoop2.7.0 --tgz -Phadoop-2.7 -Phive -Phive-thriftserver -Pyarn -Dmaven.test.skip=true -DskipTests
  ```

  

# spark-3.0.1编译

- 编译命令

  ```
  # ./dev/make-distribution.sh  --name hadoop2.6.0 --tgz -Phadoop-2.6 -Phive-1.2 -Phive-thriftserver -Pyarn -Dmaven.test.skip=true -DskipTests
  ```

  

# hive-1.2.1.spark2编译

- 项目地址：https://github.com/cloudnativecube/hive，分支：release-1.2.1-spark2。

- 原始项目：https://github.com/JoshRosen/hive/tree/release-1.2.1-spark2 。

- 编译命令

  ```
  # mvn clean compile -Phadoop-2 -DskipTests -Psources
  # mvn install -Phadoop-2 -DskipTests -Psources
  ```

  生成的jar包将安装到目录`~/.m2/repository/org/spark-project/hive`中。

- 单元测试

  ```
  # mvn test -Phadoop-2
  ```

  但以上命令并没有执行patch新打进去的UT，不知道什么原因。

  可以根据新的ut所在的package执行以下命令：

  ```
   # mvn test -Phadoop-2 -Dtest='TestAcidUtils' //单个UT类
   # mvn test -Phadoop-2 -Dtest='TestAcidUtils#testOverlapingDelta2' //单个UT函数
   # mvn test -Phadoop-2 -Dtest='org.apache.hadoop.hive.ql.txn.compactor.*' //某个package下所有UT
  ```

- spark测试

  ```
  // 这里是生成的测试代码
  # ll itests/qtest-spark/target/generated-test-sources/java/org/apache/hadoop/hive/cli/
  ```

  

- clientpositive/clientnegative unit tests

  ```
  // clientpositive tests
  # cd itests/qtest
  # mvn test -Dtest=TestCliDriver
  // clientnegative test
  # cd itests/qtest
  # mvn test -Dtest=TestNegativeCliDriver -Dqfile=alter1.q
  
  # cd itests/qtest
  # mvn test -Dtest=TestCliDriver -Dqfile_regex=partition_wise_fileformat.*
   
  // Alternatively, you can specify comma separated list with "-Dqfile" argument
  # mvn test -Dtest=TestMiniLlapLocalCliDriver -Dqfile='vectorization_0.q,vectorization_17.q,vectorization_8.q'
  ```

  

### 参考链接

- Release Notes： https://issues.apache.org/jira/secure/ConfigureReleaseNote.jspa?projectId=12310843&version=12329278
- 官方开发文档：https://cwiki.apache.org/confluence/display/Hive/HiveDeveloperFAQ

# hive-1.2.1问题修复

spark-2.x依赖的hive client版本是`1.2.1.spark2`。

以下的修改都在分支：https://github.com/cloudnativecube/hive/commits/bugfix-for-1.2.1.spark2

- https://issues.apache.org/jira/browse/HIVE-11102 ReaderImpl: getColumnIndicesFromNames does not work for some cases
- https://issues.apache.org/jira/browse/HIVE-11592 ORC metadata section can sometimes exceed protobuf message size limit
- https://issues.apache.org/jira/browse/HIVE-11928 ORC footer and metadata section can also exceed protobuf message limit
- https://issues.apache.org/jira/browse/HIVE-11835 Type decimal(1,1) reads 0.0, 0.00, etc from text file as NULL
- https://issues.apache.org/jira/browse/HIVE-10191 ORC: Cleanup writer per-row synchronization
- https://issues.apache.org/jira/browse/HIVE-11095 SerDeUtils another bug ,when Text is reused
- https://issues.apache.org/jira/browse/HIVE-11112 ISO-8859-1 text output has fragments of previous longer rows appended
- https://issues.apache.org/jira/browse/HIVE-10165 Improve hive-hcatalog-streaming extensibility and support updates and deletes.
- https://issues.apache.org/jira/browse/HIVE-11030 Enhance storage layer to create one delta file per write
- https://issues.apache.org/jira/browse/HIVE-11546 Projected columns read size should be scaled to split size for ORC Splits
- https://issues.apache.org/jira/browse/HIVE-14400 Handle concurrent insert with dynamic partition【影响版本2.2.0】

以下优化性能：

- https://issues.apache.org/jira/browse/HIVE-12897 Improve dynamic partition loading: There are many redundant calls to metastore which is not needed.

  https://issues.apache.org/jira/browse/HIVE-12907 Improve dynamic partition loading - II: Remove unnecessary calls to metastore.

  https://issues.apache.org/jira/browse/HIVE-12908 Improve dynamic partition loading III: Remove unnecessary Namenode calls. 【接口有变化，需要先引入[HIVE-7476] CTAS does not work properly for s3】

  https://issues.apache.org/jira/browse/HIVE-12988 Improve dynamic partition loading IV: Parallelize copyFiles()【多线程move文件】

  https://issues.apache.org/jira/browse/HIVE-13572 Redundant setting full file status in Hive::copyFiles

  https://issues.apache.org/jira/browse/HIVE-11378 Remove hadoop-1 support from master branch

  https://issues.apache.org/jira/browse/HIVE-13661 [Refactor] Move common FS operations out of shim layer

  https://issues.apache.org/jira/browse/HIVE-13716 Improve dynamic partition loading V: Parallelize permission settings and other refactoring.【依赖HIVE-11378, HIVE-13661】

  https://issues.apache.org/jira/browser/HIVE-13726 Improve dynamic partition loading VI: Parallelize deletes and other refactoring.
  
  https://issues.apache.org/jira/browse/HIVE-14268 INSERT-OVERWRITE is not generating an INSERT event during hive replication【影响版本2.2.0】
  
  这是由HIVE-12907引入的bug。如果打了HIVE-12907，则需要引入该patch。
  

- https://issues.apache.org/jira/browse/HIVE-13632 Hive failing on insert empty array into parquet table【修复版本2.1.0，依赖HIVE-9605, HIVE-11096】

  https://issues.apache.org/jira/browse/HIVE-9605 Remove parquet nested objects from wrapper writable objects

  https://issues.apache.org/jira/browse/HIVE-11131 Get row information on DataWritableWriter once for better writing performance

  https://issues.apache.org/jira/browse/HIVE-11096 Bump the parquet version to 1.7.0【先不合入】

以下未合并：

- https://issues.apache.org/jira/browse/HIVE-14204 Optimize loading dynamic partitions【修复版本2.2.0】

