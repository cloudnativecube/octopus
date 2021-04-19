# ClickHouse Testing

## Unit Tests
当你不是要测试整个 ClickHouse，而是只要针对其中一个独立的 library 或 class 进行测试时，可以使用 unit tests。测试代码分布在项目代码的各个 tests 子文件夹中。Build tests 可以通过 CMake 选项 ENABLE_TESTS 开启或关闭。

Functional tests 可以覆盖到的代码，无需运行 unit tests。 

### 参考文档

https://clickhouse.tech/docs/en/development/tests/  

### 执行步骤

1. cmake
```
export CC=gcc-11
export CXX=g++-11
mkdir build
cd build
cmake .. \
    -DCMAKE_C_COMPILER=/usr/bin/clang-11 \
    -DCMAKE_CXX_COMPILER=/usr/bin/clang++-11 \
    -DCMAKE_BUILD_TYPE=Release \
    -DENABLE_CLICKHOUSE_ALL=ON \
    -DENABLE_TESTS=ON
```

2. 在 CMakeLists.txt 中添加 unit tests。如
```
cd src/Core/tests
vim CMakeLists.txt
```
在文件最后添加 add_test，如 add_test(test_field field)。其中 test_field 是指定的测试名称，field 是执行命令。

3. 使用 ninja build（以上面的 field 为例）
```
ninja field
```
4. 执行测试，查看结果
```
ninja test
```



## clickhouse-benchmark

连接到 ClickHouse server 之后重复发送测试 queries 即可。

### 参考文档

https://clickhouse.tech/docs/en/operations/utilities/clickhouse-benchmark/

### 语法

```
clickhouse-benchmark --query ["single query"] [keys]
```

或

```
echo "single query" | clickhouse-benchmark [keys]
```

或

```
clickhouse-benchmark [keys] <<< "single query"
```

如果需要使用一组 queries，创建一个文件，在文件中写入 query 即可。如 queries_file：

```
SELECT * FROM system.numbers LIMIT 10000000;
SELECT 1;
```

然后执行

```
clickhouse-benchmark [keys] < queries_file;
```

### Keys

测试常用 keys：

* `-c N`, `--concurrency=N` 并发数。 默认值：1
* `-i N`, `--iterations=N` 查询的总次数。默认值：0

更多 keys 可使用 --help 查看，具体说明参见官方文档。

如果需要为 query 配置一些参数，可以使用 --<session setting name>= SETTING_VALUE，如 --max_memory_usage=1048576。

### 输出

例如

```
Queries executed: 10.

localhost:9000, queries 10, QPS: 6.772, RPS: 67904487.440, MiB/s: 518.070, result RPS: 67721584.984, result MiB/s: 516.675.

0.000%      0.145 sec.
10.000%     0.146 sec.
20.000%     0.146 sec.
30.000%     0.146 sec.
40.000%     0.147 sec.
50.000%     0.148 sec.
60.000%     0.148 sec.
70.000%     0.148 sec.
80.000%     0.149 sec.
90.000%     0.150 sec.
95.000%     0.150 sec.
99.000%     0.150 sec.
99.900%     0.150 sec.
99.990%     0.150 sec.
```

### 比较模式

clickhouse-benchmark 可以比较两个 ClickHouse server 性能。使用 --host`, `--port 分别指定两个 server 即可。参数通过位置对应，一个 --host 对应第一个 --port。clickhouse-benchmark 会连接两个 server 后执行queries。每个 query 发给随机选中的 server。测试结果将分别显示两个 server 的数据。



## Functional Tests

大部分 ClickHouse features 都可以使用 functional tests 进行验证。通过 Functional test 可以测试的新代码必须通过该测试。

测试代码在 tests/queries 目录下。其中有两个子文件夹：stateless 和 stateful。stateless tests 无需事先 load 测试数据。Stateful tests 需要提前 load Yandex.Metrica 测试数据。

每个 functional test 会执行一个或多个 queries。期望的测试结果定义在 .reference 文件中。

### 参考文档

https://clickhouse.tech/docs/en/development/tests/

### 执行步骤

1. 下载 Yandex.Metrica 测试数据

   ```
   mkdir yandex_metrica
   cd yandex_metrica
   wget -c https://datasets.clickhouse.tech/hits/tsv/hits_v1.tsv.xz
   wget -c https://datasets.clickhouse.tech/visits/tsv/visits_v1.tsv.xz
   unxz hits_v1.tsv.xz
   unxz visits_v1.tsv.xz
   ```

2. 创建测试表

   ```
   clickhouse-client --query "CREATE DATABASE IF NOT EXISTS test"
   ```

   ```
   clickhouse-client
   
   CREATE TABLE test.hits
   (
       `WatchID` UInt64,
       `JavaEnable` UInt8,
       `Title` String,
       `GoodEvent` Int16,
       `EventTime` DateTime,
       `EventDate` Date,
       `CounterID` UInt32,
       `ClientIP` UInt32,
       `ClientIP6` FixedString(16),
       `RegionID` UInt32,
       `UserID` UInt64,
       `CounterClass` Int8,
       `OS` UInt8,
       `UserAgent` UInt8,
       `URL` String,
       `Referer` String,
       `URLDomain` String,
       `RefererDomain` String,
       `Refresh` UInt8,
       `IsRobot` UInt8,
       `RefererCategories` Array(UInt16),
       `URLCategories` Array(UInt16),
       `URLRegions` Array(UInt32),
       `RefererRegions` Array(UInt32),
       `ResolutionWidth` UInt16,
       `ResolutionHeight` UInt16,
       `ResolutionDepth` UInt8,
       `FlashMajor` UInt8,
       `FlashMinor` UInt8,
       `FlashMinor2` String,
       `NetMajor` UInt8,
       `NetMinor` UInt8,
       `UserAgentMajor` UInt16,
       `UserAgentMinor` FixedString(2),
       `CookieEnable` UInt8,
       `JavascriptEnable` UInt8,
       `IsMobile` UInt8,
       `MobilePhone` UInt8,
       `MobilePhoneModel` String,
       `Params` String,
       `IPNetworkID` UInt32,
       `TraficSourceID` Int8,
       `SearchEngineID` UInt16,
       `SearchPhrase` String,
       `AdvEngineID` UInt8,
       `IsArtifical` UInt8,
       `WindowClientWidth` UInt16,
       `WindowClientHeight` UInt16,
       `ClientTimeZone` Int16,
       `ClientEventTime` DateTime,
       `SilverlightVersion1` UInt8,
       `SilverlightVersion2` UInt8,
       `SilverlightVersion3` UInt32,
       `SilverlightVersion4` UInt16,
       `PageCharset` String,
       `CodeVersion` UInt32,
       `IsLink` UInt8,
       `IsDownload` UInt8,
       `IsNotBounce` UInt8,
       `FUniqID` UInt64,
       `HID` UInt32,
       `IsOldCounter` UInt8,
       `IsEvent` UInt8,
       `IsParameter` UInt8,
       `DontCountHits` UInt8,
       `WithHash` UInt8,
       `HitColor` FixedString(1),
       `UTCEventTime` DateTime,
       `Age` UInt8,
       `Sex` UInt8,
       `Income` UInt8,
       `Interests` UInt16,
       `Robotness` UInt8,
       `GeneralInterests` Array(UInt16),
       `RemoteIP` UInt32,
       `RemoteIP6` FixedString(16),
       `WindowName` Int32,
       `OpenerName` Int32,
       `HistoryLength` Int16,
       `BrowserLanguage` FixedString(2),
       `BrowserCountry` FixedString(2),
       `SocialNetwork` String,
       `SocialAction` String,
       `HTTPError` UInt16,
       `SendTiming` Int32,
       `DNSTiming` Int32,
       `ConnectTiming` Int32,
       `ResponseStartTiming` Int32,
       `ResponseEndTiming` Int32,
       `FetchTiming` Int32,
       `RedirectTiming` Int32,
       `DOMInteractiveTiming` Int32,
       `DOMContentLoadedTiming` Int32,
       `DOMCompleteTiming` Int32,
       `LoadEventStartTiming` Int32,
       `LoadEventEndTiming` Int32,
       `NSToDOMContentLoadedTiming` Int32,
       `FirstPaintTiming` Int32,
       `RedirectCount` Int8,
       `SocialSourceNetworkID` UInt8,
       `SocialSourcePage` String,
       `ParamPrice` Int64,
       `ParamOrderID` String,
       `ParamCurrency` FixedString(3),
       `ParamCurrencyID` UInt16,
       `GoalsReached` Array(UInt32),
       `OpenstatServiceName` String,
       `OpenstatCampaignID` String,
       `OpenstatAdID` String,
       `OpenstatSourceID` String,
       `UTMSource` String,
       `UTMMedium` String,
       `UTMCampaign` String,
       `UTMContent` String,
       `UTMTerm` String,
       `FromTag` String,
       `HasGCLID` UInt8,
       `RefererHash` UInt64,
       `URLHash` UInt64,
       `CLID` UInt32,
       `YCLID` UInt64,
       `ShareService` String,
       `ShareURL` String,
       `ShareTitle` String,
       `ParsedParams` Nested(
           Key1 String,
           Key2 String,
           Key3 String,
           Key4 String,
           Key5 String,
           ValueDouble Float64),
       `IslandID` FixedString(16),
       `RequestNum` UInt32,
       `RequestTry` UInt8
   )
   ENGINE = MergeTree()
   PARTITION BY toYYYYMM(EventDate)
   ORDER BY (CounterID, EventDate, intHash32(UserID))
   SAMPLE BY intHash32(UserID);
   
   CREATE TABLE test.visits
   (
       `CounterID` UInt32,
       `StartDate` Date,
       `Sign` Int8,
       `IsNew` UInt8,
       `VisitID` UInt64,
       `UserID` UInt64,
       `StartTime` DateTime,
       `Duration` UInt32,
       `UTCStartTime` DateTime,
       `PageViews` Int32,
       `Hits` Int32,
       `IsBounce` UInt8,
       `Referer` String,
       `StartURL` String,
       `RefererDomain` String,
       `StartURLDomain` String,
       `EndURL` String,
       `LinkURL` String,
       `IsDownload` UInt8,
       `TraficSourceID` Int8,
       `SearchEngineID` UInt16,
       `SearchPhrase` String,
       `AdvEngineID` UInt8,
       `PlaceID` Int32,
       `RefererCategories` Array(UInt16),
       `URLCategories` Array(UInt16),
       `URLRegions` Array(UInt32),
       `RefererRegions` Array(UInt32),
       `IsYandex` UInt8,
       `GoalReachesDepth` Int32,
       `GoalReachesURL` Int32,
       `GoalReachesAny` Int32,
       `SocialSourceNetworkID` UInt8,
       `SocialSourcePage` String,
       `MobilePhoneModel` String,
       `ClientEventTime` DateTime,
       `RegionID` UInt32,
       `ClientIP` UInt32,
       `ClientIP6` FixedString(16),
       `RemoteIP` UInt32,
       `RemoteIP6` FixedString(16),
       `IPNetworkID` UInt32,
       `SilverlightVersion3` UInt32,
       `CodeVersion` UInt32,
       `ResolutionWidth` UInt16,
       `ResolutionHeight` UInt16,
       `UserAgentMajor` UInt16,
       `UserAgentMinor` UInt16,
       `WindowClientWidth` UInt16,
       `WindowClientHeight` UInt16,
       `SilverlightVersion2` UInt8,
       `SilverlightVersion4` UInt16,
       `FlashVersion3` UInt16,
       `FlashVersion4` UInt16,
       `ClientTimeZone` Int16,
       `OS` UInt8,
       `UserAgent` UInt8,
       `ResolutionDepth` UInt8,
       `FlashMajor` UInt8,
       `FlashMinor` UInt8,
       `NetMajor` UInt8,
       `NetMinor` UInt8,
       `MobilePhone` UInt8,
       `SilverlightVersion1` UInt8,
       `Age` UInt8,
       `Sex` UInt8,
       `Income` UInt8,
       `JavaEnable` UInt8,
       `CookieEnable` UInt8,
       `JavascriptEnable` UInt8,
       `IsMobile` UInt8,
       `BrowserLanguage` UInt16,
       `BrowserCountry` UInt16,
       `Interests` UInt16,
       `Robotness` UInt8,
       `GeneralInterests` Array(UInt16),
       `Params` Array(String),
       `Goals` Nested(
           ID UInt32,
           Serial UInt32,
           EventTime DateTime,
           Price Int64,
           OrderID String,
           CurrencyID UInt32),
       `WatchIDs` Array(UInt64),
       `ParamSumPrice` Int64,
       `ParamCurrency` FixedString(3),
       `ParamCurrencyID` UInt16,
       `ClickLogID` UInt64,
       `ClickEventID` Int32,
       `ClickGoodEvent` Int32,
       `ClickEventTime` DateTime,
       `ClickPriorityID` Int32,
       `ClickPhraseID` Int32,
       `ClickPageID` Int32,
       `ClickPlaceID` Int32,
       `ClickTypeID` Int32,
       `ClickResourceID` Int32,
       `ClickCost` UInt32,
       `ClickClientIP` UInt32,
       `ClickDomainID` UInt32,
       `ClickURL` String,
       `ClickAttempt` UInt8,
       `ClickOrderID` UInt32,
       `ClickBannerID` UInt32,
       `ClickMarketCategoryID` UInt32,
       `ClickMarketPP` UInt32,
       `ClickMarketCategoryName` String,
       `ClickMarketPPName` String,
       `ClickAWAPSCampaignName` String,
       `ClickPageName` String,
       `ClickTargetType` UInt16,
       `ClickTargetPhraseID` UInt64,
       `ClickContextType` UInt8,
       `ClickSelectType` Int8,
       `ClickOptions` String,
       `ClickGroupBannerID` Int32,
       `OpenstatServiceName` String,
       `OpenstatCampaignID` String,
       `OpenstatAdID` String,
       `OpenstatSourceID` String,
       `UTMSource` String,
       `UTMMedium` String,
       `UTMCampaign` String,
       `UTMContent` String,
       `UTMTerm` String,
       `FromTag` String,
       `HasGCLID` UInt8,
       `FirstVisit` DateTime,
       `PredLastVisit` Date,
       `LastVisit` Date,
       `TotalVisits` UInt32,
       `TraficSource` Nested(
           ID Int8,
           SearchEngineID UInt16,
           AdvEngineID UInt8,
           PlaceID UInt16,
           SocialSourceNetworkID UInt8,
           Domain String,
           SearchPhrase String,
           SocialSourcePage String),
       `Attendance` FixedString(16),
       `CLID` UInt32,
       `YCLID` UInt64,
       `NormalizedRefererHash` UInt64,
       `SearchPhraseHash` UInt64,
       `RefererDomainHash` UInt64,
       `NormalizedStartURLHash` UInt64,
       `StartURLDomainHash` UInt64,
       `NormalizedEndURLHash` UInt64,
       `TopLevelDomain` UInt64,
       `URLScheme` UInt64,
       `OpenstatServiceNameHash` UInt64,
       `OpenstatCampaignIDHash` UInt64,
       `OpenstatAdIDHash` UInt64,
       `OpenstatSourceIDHash` UInt64,
       `UTMSourceHash` UInt64,
       `UTMMediumHash` UInt64,
       `UTMCampaignHash` UInt64,
       `UTMContentHash` UInt64,
       `UTMTermHash` UInt64,
       `FromHash` UInt64,
       `WebVisorEnabled` UInt8,
       `WebVisorActivity` UInt32,
       `ParsedParams` Nested(
           Key1 String,
           Key2 String,
           Key3 String,
           Key4 String,
           Key5 String,
           ValueDouble Float64),
       `Market` Nested(
           Type UInt8,
           GoalID UInt32,
           OrderID String,
           OrderPrice Int64,
           PP UInt32,
           DirectPlaceID UInt32,
           DirectOrderID UInt32,
           DirectBannerID UInt32,
           GoodID String,
           GoodName String,
           GoodQuantity Int32,
           GoodPrice Int64),
       `IslandID` FixedString(16)
   )
   ENGINE = CollapsingMergeTree(Sign)
   PARTITION BY toYYYYMM(StartDate)
   ORDER BY (CounterID, StartDate, intHash32(UserID), VisitID)
   SAMPLE BY intHash32(UserID);
   
   quit;
   ```

   ```
   clickhouse-client --query "INSERT INTO test.hits FORMAT TSV" --max_insert_block_size=100000 < hits_v1.tsv
   clickhouse-client --query "INSERT INTO test.visits FORMAT TSV" --max_insert_block_size=100000 < visits_v1.tsv
   ```

3. 运行 functional tests

   * 运行所有 tests

     ```
     cd ClickHouse
     tests/clickhouse-test
     ```

   * 运行指定 tests

     ```
     tests/clickhouse-test 00001_select_1 00002_system_numbers
     ```

   * skip 某些 tests

     ```
     tests/clickhouse-test --skip 00006_agregates
     ```

   更多用法可通过 --help 查看。