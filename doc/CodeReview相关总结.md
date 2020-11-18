# 一些参考：

https://mp.weixin.qq.com/s/p_CNasQxzdni4G2eD0xUrQ https://chris.beams.io/posts/git-commit/ https://en.wikipedia.org/wiki/SOLID https://item.jd.com/10875285.html https://item.jd.com/11728740.html https://item.jd.com/10064006.html

# 个人观点：

CodeReview 需要从多个方面入手：

1. developers需要对编码规范有较为统一的认识，这样在CR时会过滤掉一些次要的问题；
2. reviewer 需要是搞明白 commit 是解决了什么问题（what），为什么这么做（why），解决步骤是什么（how），从这几个面去review代码是否合理；
3. reviewer可以对Review的内容组建自己的Checklist，大体上按照checklist的内容去review；
4. 重在参与，每个人都参与 review；
5. 至少 两个 人 lgtm 才能 ok；

# 之前的实践：

## 规范

### 工具

1. 尽量使用工具来完成书写格式上的规范性约束 譬如使用 gofmt 来完成代码的格式化（或使用 goimports来替代 gofmt） 强制执行 gofmt, go vet, go lint #例如，使用 vim 时，可以安装使用 vim-go插件，开启如下自动处理： let g:syntastic_go_checkers = ['gometalinter', 'govet', 'errcheck'] let g:syntastic_mode_map = { 'mode': 'active', 'passive_filetypes': ['go'] } let g:go_metalinter_autosave = 1 let g:go_fmt_command = "goimports"

使用 vscode 时，也有对应的插件和配置 2. 提交CR的代码需要使用 gofmt 或 goimports 进行格式化，统一格式

### 命名及注释

1. 在编码阶段同步写好变量、函数、包注释，注释可以通过godoc导出生成文档 注释必须是完整的句子，以需要注释的内容作为开头，句点作为结尾 程序中每一个被导出的（大写的）名字，都应该有一个文档注释 （https://github.com/golang/go/wiki/CodeReviewComments#comment-sentences https://golang.org/doc/effective_go.html#commentary）
2. 命名最好是自注释的（请学习 《代码大全》） 采用驼峰方式命名 |需要注释来补充的命名就不算是好命名 使用可搜索的名称：单字母名称和数字常量很难从一大堆文字中搜索出来。单字母名称仅适用于短方法中的本地变量，名称长短应与其作用域相对应。若变量或常量可能在代码中多处使用，则应赋其以便于搜索的名称。 做有意义的区分：Product和ProductInfo和ProductData没有区别，NameString和Name没有区别，要区分名称，就要以读者能鉴别不同之处的方式来区分 。 函数命名规则：驼峰式命名，名字可以长但是得把功能，必要的参数描述清楚，函数名名应当是动词或动词短语，如postPayment、deletePage、save。 结构体命名规则：结构体名应该是名词或名词短语，如Custome、WikiPage、Account、AddressParser，避免使用Manager、Processor、Data、Info、这样的类名，类名不应当是动词。 包名命名规则：包名应该为小写单词，不要使用下划线或者混合大小写。 接口命名规则：单个函数的接口名以”er”作为后缀，如Reader,Writer。
3. 避免出现大量注释掉的代码或无用代码、注释，不需要的请直接删掉
4. 一行代码不要过长，适当使用换行来增加代码可读性 一个函数避免过长，过长时考虑拆分或提取子函数 一个文件避免过长，按照函数进行文件分类

### 函数及语句

1. DRY 尽量将功能代码抽取成独立的函数，并对函数进行单测
2. （强制）map 使用前要初始化 map 在并发场景中需要使用锁进行保护
3. 建议用 sync.Mutex 的指针类型来使用变量值，从而避免 Mutex 的值拷贝
4. 在定义函数或方法时，如果该函数或方法有远程访问调用，需要增加一个 context参数，且作为第一个传入参数 可以用于超时处理、传递内含数据（用户信息、trace信息等）
5. 避免使用 interface{} (empty interface)作为函数传入参数，可是使用 Named Interface
6. 声明  slice 变量时，只声明不定义 var someSlice []string // not someSlice := []string{}
7. 在 range 循环时，在 循环 slice、array 或 map 时， 第二个 迭代量是可以省略的 也就是  for  i := range slice {} 或 for  k := range map {} for  i, _ := range slice {} 或 for  k, _ := range map {} 是不可取的
8. if 判断时，如果判断的变量为 boolean 类型时，不需要再与 true/false 进行对比 //不建议 if isPrefix == true { // blabla }

// 建议 if isPrefix { // blabla }

1. 要明白函数返回值 return nil 与 return someVar (var someVar *someStruct == nil) 的区别 type InternalError struct { msg string }

func (ie InternalError) Error() string { return ie.msg }

func main() { fmt.Printf("%#v\n", func() error { return nil }()) fmt.Printf("%#v\n", func() error { var err *InternalError; return err }()) }

1. 避免代码中出现 magic number or magic string 给每个 magic 值定义一个 常量
2. 返回值中如果有struct，最好是返回指针类型的数据 如 func() (*someStruct, error) 返回值中如果有struct的slice，则可以直接返回改 struct 的 slice 如 func() ([]someStruct, error)
3. 如果有变量引用了slice 或数组中的非指针数据，最好做一个临时拷贝再引用，会涉及到垃圾回收的效率。如： for idx := range listPods.Items { if listPods.Items[idx].Metadata.Name == destPodName { // not: return &listPods.Items[idx] tmp := listPods.Items[idx] return &tmp } }
4. time.Ticker must be stopped defer timer.Stop()

### 错误处理

1. 函数返回值中有 error的，一定要处理（最差打一条日志）
2. 优先处理错误，遇到错误可以提前处理，避免 if 嵌套 func doSomething() error { if err := do1(); err == nil { if err = do2(); err == nil { return nil } else { // print err return err } } else { // print err return err } }

func doSomething2() error { if err := do1(); err != nil { // print err return err } if err = do2(); err != nil { // print err return err } return nil }

### 设计与实现

1. 接口与实现分离 函数或类型要单一职责 （学习一下：SOLID设计原则，https://en.wikipedia.org/wiki/SOLID）
2. 注重实现效率，避免在一个for 循环内部进行多次 网络请求，可以一次请求完成后，再进行for循环处理
3. 关注自己实现接口的 耗时（设定自己的SLO）
4. "TODO" items typically have "TODO(yourname)" or "TODO(someone)" or "TODO(sig)"

测试及CR

1. 开发新接口的，要提供接口测试case
2. 尽量多写单测 test table mock interface（dependency injection，SOLID）
3. 在个人分支上开发时，适当对自己提交的同一个功能的多次 commit 进行压缩，保证提交 CR 时，只留一个 commit 如果 CR 已过，后续有bug 需要修复时，可以再次提交修复的commit
4. CR 的代码越短越好（保证实现功能）
5. 在一次 CR 提交过程中，尽量保证只有一个 功能进行 CR 即使顺手改了一个其他的小功能，也分开提CR （使用多个 个人开发分支，每个分支上进行一个功能的修改，分开提 CR） 譬如 使用 feature_dev_hanli_1 进行一个新功能的开发，使用 feature_dev_hanli_2 进行另一个功能的bug 修复之类的使用方式
6. 选取合适的reviewer 找一个功能相关者（backup）进行主功能 review 其他人也可以进行review
7. 重要逻辑不少于 2 位的 reviewer
8. 提前沟通好功能（文档、当面沟通）
9. 提交 CR 之前自己先Review 一遍
10. 提交CR前，保证程序编译通过，功能测试通过

## Reviewer 实践

checklist

### 清晰度

1. 能否看懂代码到底实现了什么(关键部分是否有相应的注释）
2. 看不懂的地方就要 comment your questions
3. 是否有相关的关键性注释文档（关键逻辑、功能、算法）
4. 变量命名是否规范
5. 函数命名是否规范
6. 是否有能提取的函数块
7. 代码是否易于维护（简单性，复杂的实习肯定不是一个好的实现）
8. 未来是否易于扩展或重构
9. 关键步骤是否有日志打印
10. 接口、远程调用是否有必要新增 metric 数据
11. 代码中能否提前判断错误进而提前返回
12. 错误字符串 不能以 大写开头、不能以标点符号结尾
13. 是否有不必要的垃圾代码、注释
14. 是否有被注释掉的代码（应该被删掉）
15. 变量是否被定义在最小的作用于范围内

### 功能逻辑

1. 代码逻辑是否正确
2. 算法是否正确
3. 是否实现目标功能、目标功能是否有遗漏
4. 修复是否必须（是否有已经存在的相关功能）
5. 关键逻辑是否有单元测试
6. 是否有相关的接口测试case
7. 接口方法是否正确（GET、POST、PUT..）
8. 接口是否有权限认证
9. 接口发生变化时是否能够向前兼容
10. 返回错误是否被忽略（resut, _ := someFunc()）
11. 依赖是否是通过接口的方式被注入依赖方
12. goroutine 中是否有未被保护的共享数据
13. goroute 是否有可能泄漏
14. channel 是否有可能被阻塞
15. sync.Mutex 是否有可能被拷贝
16. 使用自定义的 http.Request 进行HTTP 请求时，在 错误处理之后，需要 defer req.Body.Close()
17. 使用自定义的 http.Request 进行HTTP 请求时，需要增加 合适的 timeout

### 性能、效率与安全

1. 输入参数是否被验证（validate the input）
2. 相关逻辑是否会有潜在的性能缺陷（多余的网络交互）
3. 相关算法是否有优化的空间
4. 是否有越界行为
5. 是否有未受保护的goroutine 共享数据访问行文
6. map 是否被初始化
7. 代码是否易于扩展或修改
8. 代码是有能被重用
9. 错误是否被正确处理
10. 是有有可能使用未正确初始化的指针变量

### 其他

1. 要了解 CR 既是 Review的过程，也是学习过程
2. Review的过程可以多提 question
3. 提问时要阐明自己的疑问，让 developer 看懂问题