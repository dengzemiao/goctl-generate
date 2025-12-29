# Go-Zero 代码生成工具集

> **快速、可靠、多数据库支持的 go-zero 代码生成脚本**

---

## 📦 文件列表

| 文件 | 说明 | 类型 |
|------|------|------|
| `model.sh` | 数据模型生成脚本 | 可执行脚本 |
| `api.sh` | API 代码生成脚本 | 可执行脚本 |
| `README.md` | 完整使用文档（本文档） | 文档 |
| `README.yaml` | 配置示例（带注释） | 配置示例 |

---

## ⚡ 快速开始

### 5 分钟上手

```bash
# 1️⃣ 配置数据库
vim etc/test-api.yaml

# 2️⃣ 生成模型
sh generate/model.sh

# 3️⃣ 生成 API
sh generate/api.sh

# ✅ 完成！查看生成的代码
tree internal/
```

### 配置示例

编辑 `etc/test-api.yaml`：

```yaml
Database:
  Type: mysql
  DataSource: "root:password@tcp(127.0.0.1:3306)/mydb"
```

**⚠️ 重要：** 不要添加 `?charset`、`?parseTime` 等 URL 参数！

### 运行生成

```bash
# 生成所有表的模型
sh generate/model.sh

# 生成指定表
sh generate/model.sh -t user,order

# 预览模式（不实际生成）
sh generate/model.sh --dry-run

# 生成 API 代码
sh generate/api.sh
```

---

## ✨ 核心特性

### 🗄️ 多数据库支持
- ✅ **MySQL** - 完全支持，自动表发现
- ✅ **PostgreSQL** - 完全支持，schema 扫描
- ✅ **MongoDB** - 基础支持

### 🎯 智能检测
- 自动识别数据库类型
- DSN 格式预验证
- 语法错误详细提示

### 🛡️ 增强错误处理
- 准确的失败检测（PIPESTATUS）
- 详细的错误日志
- 针对性的排查建议

### 🎨 统一格式
- 清晰的消息层次
- 一致的颜色语义
- 友好的用户体验

---

## 📖 详细文档

### 查看命令行帮助

```bash
# Model 生成帮助
sh generate/model.sh --help

# API 生成帮助
sh generate/api.sh --help
```

### 查看配置示例

```bash
# 数据库配置示例（带详细注释）
cat generate/README.yaml
```

### Model 生成脚本

**基本用法：**
```bash
# 生成所有表
sh generate/model.sh

# 指定配置文件
sh generate/model.sh -c etc/dev.yaml

# 生成指定表
sh generate/model.sh -t user,order,product

# 指定输出目录
sh generate/model.sh -o internal/dao

# 使用小驼峰命名风格
sh generate/model.sh -s goZero

# 预览模式（测试连接）
sh generate/model.sh --dry-run
```

**命令行参数：**

| 参数 | 简写 | 说明 | 示例 |
|------|------|------|------|
| `--help` | `-h` | 显示帮助信息 | `sh model.sh -h` |
| `--config FILE` | `-c` | 指定配置文件 | `sh model.sh -c etc/dev.yaml` |
| `--output DIR` | `-o` | 指定输出目录 | `sh model.sh -o internal/dao` |
| `--style STYLE` | `-s` | 指定命名风格 | `sh model.sh -s goZero` |
| `--table TABLE` | `-t` | 仅生成指定的表 | `sh model.sh -t user,order` |
| `--db-type TYPE` | - | 指定数据库类型 | `sh model.sh --db-type postgres` |
| `--dry-run` | `-d` | 预览模式 | `sh model.sh --dry-run` |

**命名风格选项：**
- `gozero` - 纯小写（官方推荐）
- `goZero` - 小驼峰（可读性好）
- `GoZero` - 大驼峰
- `go_zero` - 下划线分隔

**数据库类型选项：**
- `mysql` - MySQL 数据库
- `postgres` - PostgreSQL 数据库
- `mongo` - MongoDB 数据库

### API 生成脚本

**基本用法：**
```bash
# 使用默认配置
sh generate/api.sh

# 指定 API 文件
sh generate/api.sh -f api/user.api

# 使用小驼峰命名风格
sh generate/api.sh -s goZero

# 仅验证语法
sh generate/api.sh --validate

# 详细模式
sh generate/api.sh -v
```

**命令行参数：**

| 参数 | 简写 | 说明 | 示例 |
|------|------|------|------|
| `--help` | `-h` | 显示帮助信息 | `sh api.sh -h` |
| `--file FILE` | `-f` | 指定 API 文件 | `sh api.sh -f api/user.api` |
| `--output DIR` | `-o` | 指定输出目录 | `sh api.sh -o .` |
| `--style STYLE` | `-s` | 指定命名风格 | `sh api.sh -s goZero` |
| `--verbose` | `-v` | 显示详细日志 | `sh api.sh -v` |
| `--validate` | - | 仅验证语法 | `sh api.sh --validate` |

---

## 🎓 使用示例

### 场景 1：MySQL 项目

```bash
# 配置数据库
vim etc/test-api.yaml

# 生成所有表
sh generate/model.sh

# 生成指定表
sh generate/model.sh -t user,order

# 使用小驼峰风格
sh generate/model.sh -s goZero
```

### 场景 2：PostgreSQL 项目

```bash
# 配置 PostgreSQL
cat > etc/pg-config.yaml << EOF
Database:
  Type: postgres
  DataSource: "postgres://admin:pass@localhost:5432/mydb"
EOF

# 生成模型
sh generate/model.sh -c etc/pg-config.yaml --db-type postgres
```

### 场景 3：MongoDB 项目

```bash
# 配置 MongoDB
cat > etc/mongo-config.yaml << EOF
Database:
  Type: mongo
  DataSource: "mongodb://admin:pass@localhost:27017/mydb"
EOF

# 生成模型
sh generate/model.sh -c etc/mongo-config.yaml --db-type mongo
```

### 场景 4：API 生成

编辑 `test.api` 文件：

```go
type LoginRequest {
    Username string `json:"username"`
    Password string `json:"password"`
}

type LoginResponse {
    Token string `json:"token"`
}

@server(
    group: auth
)
service test-api {
    @handler Login
    post /api/login (LoginRequest) returns (LoginResponse)
}
```

生成代码：

```bash
# 基本生成
sh generate/api.sh

# 验证语法
sh generate/api.sh --validate

# 详细模式
sh generate/api.sh -v
```

---

## 🆘 遇到问题？

### 常见错误速查

| 错误 | 原因 | 解决方案 |
|------|------|---------|
| `invalid DSN` | DSN 包含不支持的参数 | 移除 `?charset`、`?parseTime` 等参数 |
| `未找到 goctl` | goctl 未安装 | 运行 `go install github.com/zeromicro/go-zero/tools/goctl@latest` |
| `连接失败` | 数据库配置错误 | 检查配置文件中的连接信息，使用 `--dry-run` 测试 |
| `语法错误` | API 文件格式错误 | 运行 `sh generate/api.sh --validate` 检查语法 |
| `权限错误` | 输出目录权限不足 | 检查目录权限或更换输出目录 |

### 详细错误排查

#### Q1: 提示 "invalid DSN" 错误？

**原因：** DSN 格式不正确或包含了额外参数

**解决：**
```yaml
# ❌ 错误：包含 URL 参数
DataSource: "user:pass@tcp(host:port)/db?charset=utf8mb4&parseTime=true"

# ✅ 正确：纯净的连接字符串
DataSource: "user:pass@tcp(host:port)/db"
```

脚本会在执行前自动验证并给出明确提示！

#### Q2: 如何测试数据库连接？

```bash
# 使用预览模式测试连接
sh generate/model.sh --dry-run

# 脚本会自动：
# 1. 连接数据库
# 2. 显示表列表
# 3. 但不实际生成文件
```

#### Q3: 如何切换数据库类型？

**方式 1：修改配置文件（推荐）**
```yaml
Database:
  Type: postgres  # 改为 postgres 或 mongo
  DataSource: "..."
```

**方式 2：使用命令行参数**
```bash
sh generate/model.sh --db-type postgres
```

#### Q4: 密码包含特殊字符怎么办？

**方式 1：使用引号包裹**
```yaml
DataSource: "user:p@ss#word@tcp(localhost:3306)/db"
```

**方式 2：使用 URL 编码**
```yaml
# 特殊字符编码：
# @ → %40
# # → %23
# / → %2F
DataSource: "user:p%40ss%23word@tcp(localhost:3306)/db"
```

#### Q5: 如何安装 goctl？

```bash
# 方式 1：使用 go install
go install github.com/zeromicro/go-zero/tools/goctl@latest

# 方式 2：使用 brew（macOS）
brew install goctl

# 验证安装
goctl --version
```

### 获取更多帮助

```bash
# 1. 查看配置示例
cat generate/README.yaml

# 2. 查看命令行完整帮助
sh generate/model.sh --help
sh generate/api.sh --help

# 3. 使用预览模式测试
sh generate/model.sh --dry-run
```

---

## 🎯 最佳实践

### 1. 使用预览模式

生成前先预览，确保配置正确：

```bash
sh generate/model.sh --dry-run
```

### 2. 验证 API 语法

生成前先验证语法：

```bash
sh generate/api.sh --validate
```

### 3. 使用 Git 管理

方便对比生成前后的变化：

```bash
git add .
git commit -m "before generate"
sh generate/model.sh
git diff  # 查看变化
```

### 4. 统一命名风格

建议整个项目使用同一种命名风格：

```bash
# 推荐使用 goZero（小驼峰，可读性好）
sh generate/model.sh -s goZero
sh generate/api.sh -s goZero
```

### 5. 分层开发

- **Model 层**：只负责数据库操作（CRUD）
- **Logic 层**：编写业务逻辑（核心代码）
- **Handler 层**：只做参数校验和响应返回（轻量级）

### 6. 注意文件覆盖

- ✅ `*model.go`、`*handler.go`、`*logic.go` - **不会覆盖**
- ⚠️ `*model_gen.go`、`types.go` - **会被覆盖**（不要手动修改）

---

## 🆕 版本信息

**当前版本**: v2.0  
**发布日期**: 2025-12-24

**主要更新：**
- 🎉 多数据库支持（MySQL、PostgreSQL、MongoDB）
- 🎉 增强的错误处理和友好提示
- 🎉 DSN 格式验证
- 🎉 详细的排查建议
- 🎉 统一的消息格式

**新特性详解：**

1. **多数据库支持**
   - MySQL - 完全支持，自动表发现
   - PostgreSQL - 完全支持，扫描 public schema
   - MongoDB - 基础支持，需预定义类型

2. **自动数据库类型检测**
   - 优先读取 `Database.Type` 字段
   - 回退到配置项推断（MySQL:, Postgres:, Mongo:）
   - 支持命令行参数 `--db-type` 覆盖

3. **增强的错误处理**
   - 使用 `PIPESTATUS` 准确检测命令失败
   - 双重检测机制（退出码 + 日志内容）
   - 详细的错误日志和高亮显示
   - 针对每种数据库的排查建议

4. **DSN 格式预验证**
   - 执行前验证 DSN 格式
   - 检测不支持的 URL 参数
   - 给出明确的错误提示和正确格式

5. **统一的消息格式**
   - 所有错误使用统一格式（✗ + 详细说明）
   - 颜色语义一致（红色=错误，黄色=警告，绿色=成功）
   - 多行消息带缩进和标识

---

## 📚 相关资源

### 配置示例

详细的数据库配置示例请查看：

```bash
cat generate/README.yaml
```

包含：
- MySQL、PostgreSQL、MongoDB 配置示例
- DSN 格式说明
- 常见问题解答
- 完整配置示例

### 官方文档

- [Go-Zero 官方网站](https://go-zero.dev/)
- [Goctl 工具文档](https://go-zero.dev/cn/goctl.html)
- [API 语法文档](https://go-zero.dev/cn/api-grammar.html)

### 项目文档

- [数据库迁移指南](../数据库迁移指南.md) - 多数据库详细说明
- [脚本改进汇总](../脚本改进汇总.md) - v2.0 改进内容
- [消息格式规范](../消息格式规范.md) - 统一的消息格式

---

## 💬 反馈与支持

如有问题或建议，请：

1. 查看本文档的常见问题章节（🆘）
2. 运行 `--help` 查看命令行帮助
3. 查看 `README.yaml` 了解配置示例
4. 使用 `--dry-run` 测试配置

**祝使用愉快！** 🚀

---

**快速导航：**
- [📦 文件列表](#-文件列表) - 了解所有文件
- [⚡ 快速开始](#-快速开始) - 5分钟上手
- [✨ 核心特性](#-核心特性) - 主要功能
- [📖 详细文档](#-详细文档) - 完整参数说明
- [🎓 使用示例](#-使用示例) - 实际场景
- [🆘 遇到问题](#-遇到问题) - 故障排查
- [🎯 最佳实践](#-最佳实践) - 使用建议
- [🆕 版本信息](#-版本信息) - 更新日志
