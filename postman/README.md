# Postman 接口测试集合使用说明

本目录提供 EnterpriseAdmin 系统接口测试的 Postman Collection，可直接导入 Postman 使用，也可通过 Newman 在命令行批量执行。

## 一、文件说明

| 文件 | 说明 |
| --- | --- |
| `EnterpriseAdmin.postman_collection.json` | Postman 集合（v2.1 格式），含登录、用户管理、角色管理、定时任务、文件上传 5 个文件夹，共 21 个请求 |

集合内置能力：
- 环境变量 `{{base_url}}` / `{{token}}` / `{{username}}` / `{{password}}` 等。
- **集合级 Pre-request Script**：自动为需鉴权的请求注入 `Authorization: Bearer {{token}}` 头（排除登录类无鉴权接口）。
- **登录请求 Tests 脚本**：自动提取返回的 token 并写入环境变量，后续请求自动复用。
- **每个请求均含 Tests 断言**：校验 HTTP 状态码 200 + 业务码 code=200，关键接口额外校验返回字段。

## 二、导入 Collection

1. 打开 Postman，点击左上角 `Import`。
2. 选择 `File`，上传 `EnterpriseAdmin.postman_collection.json`。
3. 导入完成后，左侧 Collections 中出现「EnterpriseAdmin 接口测试集合」。
4. 展开可见 5 个文件夹：01-登录认证、02-用户管理、03-角色管理、04-定时任务、05-文件上传。

## 三、环境变量配置

1. 点击 Postman 右上角环境选择器 → `Manage Environments` → `Add`。
2. 新建环境，例如命名为 `EnterpriseAdmin-Test`，添加以下变量：

| 变量名 | 初始值 | 说明 |
| --- | --- | --- |
| base_url | http://localhost:8080 | 被测系统基础地址 |
| token | （留空） | 登录后自动写入 |
| username | admin | 登录账号 |
| password | Admin@123 | 登录密码 |
| uuid | test-uuid-0001 | 验证码 uuid（测试环境可关闭验证码或填固定值） |
| userId | 2 | 测试用户ID |
| roleId | 3 | 测试角色ID |
| jobId | 1 | 测试任务ID |

3. 保存后在右上角下拉选中该环境。

> 集合内也内置了同名 Collection Variables 作为默认值，环境变量优先级更高，可按需覆盖。

## 四、执行 Collection

### 4.1 单接口执行
1. 先执行 `01-登录认证 > 用户登录`，Tests 脚本会自动保存 token。
2. 后续请求会自动携带 token，可直接点击 `Send` 执行。

### 4.2 文件夹批量执行（Runner）
1. 选中集合或文件夹，点击 `Run`（Run Collection）。
2. 选择环境 `EnterpriseAdmin-Test`，勾选要执行的请求。
3. 注意：执行顺序需先「用户登录」再其他接口，确保 token 已生成。
4. 点击 `Run` 查看每个请求的断言结果。

### 4.3 文件上传说明
文件上传请求的 `file` 字段为 form-data，导入后需手动在 Postman 中选择本地文件：
- 「上传合规图片」：选择一张小于 10MB 的 jpg/png 图片。
- 「上传非法类型(应拒绝)」：选择一个 exe 文件，验证服务端类型校验。

## 五、Newman 命令行批量执行

### 5.1 安装 Newman

```bash
npm install -g newman
# 如需生成 HTML 报告，额外安装：
npm install -g newman-reporter-htmlextra
```

### 5.2 导出环境文件
在 Postman 中将 `EnterpriseAdmin-Test` 环境导出为 `env.json`，与集合放在同目录。

### 5.3 执行命令

```bash
# 基础执行（控制台输出）
newman run EnterpriseAdmin.postman_collection.json -e env.json

# 指定环境变量覆盖（如临时切换地址）
newman run EnterpriseAdmin.postman_collection.json -e env.json \
  --env-var "base_url=http://10.0.0.50:8080"

# 生成 HTML 报告
newman run EnterpriseAdmin.postman_collection.json -e env.json \
  -r htmlextra --reporter-htmlextra-export ./report/report.html

# 生成 JSON 报告（便于 CI 解析）
newman run EnterpriseAdmin.postman_collection.json -e env.json \
  -r json --reporter-json-export ./report/report.json

# 仅执行某个文件夹
newman run EnterpriseAdmin.postman_collection.json -e env.json \
  --folder "02-用户管理"
```

### 5.4 常用参数

| 参数 | 说明 |
| --- | --- |
| `-e <env.json>` | 指定环境文件 |
| `-g <globals.json>` | 指定全局变量文件 |
| `-d <data.csv>` | 数据驱动文件（参数化） |
| `-n <次数>` | 迭代执行次数 |
| `--folder <名称>` | 仅执行指定文件夹 |
| `--env-var "k=v"` | 命令行覆盖环境变量 |
| `-r <reporter>` | 报告格式：cli/json/junit/htmlextra |
| `--delay-request <ms>` | 请求间隔毫秒数 |
| `--bail` | 首个失败即停止 |

## 六、CI/CD 集成示例

可将 Newman 命令接入 CI 流水线实现接口回归自动化：

```bash
# run_api_regression.sh
newman run postman/EnterpriseAdmin.postman_collection.json \
  -e postman/env.json \
  -r cli,htmlextra,junit \
  --reporter-htmlextra-export report/api-report.html \
  --reporter-junit-export report/api-junit.xml
```

退出码非 0 表示有用例失败，CI 可据此阻断构建。

## 七、断言说明

集合内每个请求均包含以下断言：
1. `HTTP 状态码为 200`
2. `业务码 code 为 200`（异常场景用例除外，如「无Token访问」断言 401、「上传非法类型」断言 code 非 200）

登录请求额外断言返回 token 非空，并自动写入环境变量，实现鉴权链路自动贯通。
