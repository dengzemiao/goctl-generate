# Go-Zero 代码生成工具集

> **快速、可靠、多数据库支持的 go-zero 代码生成脚本**

[![Go-Zero](https://img.shields.io/badge/Go--Zero-v1.6-blue)](https://go-zero.dev/)
[![Database](https://img.shields.io/badge/Database-MySQL%20%7C%20PostgreSQL%20%7C%20MongoDB-green)](https://github.com)
[![License](https://img.shields.io/badge/License-MIT-yellow)](https://opensource.org/licenses/MIT)

---

## 💡 核心特点

- 🎯 **标准开发流程**：数据库 → Model → API → Logic，清晰明确
- 🗄️ **多数据库支持**：MySQL、PostgreSQL、MongoDB 一键生成
- 🚀 **开箱即用**：3分钟快速上手，5步完成项目搭建
- 🛡️ **安全可靠**：自动验证配置，详细错误提示
- 📦 **分层架构**：Handler、Logic、Model 清晰分离

> 💡 **新手提示**：第一次使用？直接跳转 [🚀 推荐开发流程](#-推荐开发流程重要)

---

## 🚀 推荐开发流程（重要）

### 标准开发流程

```
第1步：设计数据库 → 第2步：生成Model → 第3步：设计API → 第4步：生成API → 第5步：写业务逻辑
    ↓                  ↓                ↓              ↓              ↓
 创建数据表          model.sh         编写.api       api.sh         logic层编码
```

### 详细步骤说明

#### 第1步：设计并创建数据库表

```sql
-- 示例：创建用户表
CREATE TABLE `user` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `username` varchar(50) NOT NULL COMMENT '用户名',
  `password` varchar(255) NOT NULL COMMENT '密码',
  `email` varchar(100) DEFAULT NULL COMMENT '邮箱',
  `phone` varchar(20) DEFAULT NULL COMMENT '手机号',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户表';
```

#### 第2步：生成 Model 层代码

```bash
# 配置数据库连接
vim etc/test-api.yaml

# generate 文件夹是我在根目录创建的文件夹，方便存放使用脚本，也可以把脚本直接放在根目录直接使用
# 生成所有表的Model
sh generate/model.sh

# 或只生成指定表
sh generate/model.sh -t user

# 生成结果：internal/model/usermodel.go
```

**生成后得到：**
- `usermodel.go` - CRUD 基础方法（可自定义扩展）
- 自动包含：Insert、FindOne、Update、Delete 等方法

#### 第3步：设计 API 接口

根据业务需求，编写 `.api` 文件定义接口：

```go
// api/user.api
syntax = "v1"

type RegisterRequest {
    Username string `json:"username"`
    Password string `json:"password"`
    Email    string `json:"email,optional"`
}

type RegisterResponse {
    Code    int    `json:"code"`
    Message string `json:"message"`
}

@server(
    group: auth
    prefix: api/user
)
service test-api {
    @handler RegisterHandler
    post /register (RegisterRequest) returns (RegisterResponse)
}
```

#### 第4步：生成 API 层代码

```bash
# 生成 API 相关代码
sh generate/api.sh

# 生成结果：
# - internal/handler/auth/registerHandler.go  (HTTP处理)
# - internal/logic/auth/registerlogic.go      (业务逻辑)
# - internal/types/types.go                    (类型定义)
```

#### 第5步：编写业务逻辑

在 `internal/logic/` 目录下编写具体业务代码：

```go
// internal/logic/auth/registerlogic.go
func (l *RegisterLogic) Register(req *types.RegisterRequest) (*types.RegisterResponse, error) {
    // 1. 参数校验（可选，根据需要）
    if len(req.Username) < 3 {
        return &types.RegisterResponse{
            Code:    400,
            Message: "用户名至少3个字符",
        }, nil
    }

    // 2. 业务逻辑：检查用户是否已存在
    _, err := l.svcCtx.UserModel.FindOneByUsername(l.ctx, req.Username)
    if err == nil {
        return &types.RegisterResponse{
            Code:    400,
            Message: "用户名已存在",
        }, nil
    }

    // 3. 调用 Model 层：插入数据
    _, err = l.svcCtx.UserModel.Insert(l.ctx, &model.User{
        Username: req.Username,
        Password: req.Password,  // 实际项目需要加密
        Email:    req.Email,
    })
    if err != nil {
        return nil, err
    }

    // 4. 返回响应
    return &types.RegisterResponse{
        Code:    0,
        Message: "注册成功",
    }, nil
}
```

### 为什么按这个顺序？

| 步骤 | 原因 |
|-----|------|
| **先数据库** | 数据结构是业务的基础，决定了数据如何存储 |
| **后生成Model** | Model 层依赖数据库表结构，自动生成 CRUD 方法 |
| **再设计API** | API 接口定义了对外暴露的功能和数据格式 |
| **后生成API** | 自动生成 Handler 和 Logic 骨架代码 |
| **最后写业务** | 在生成的 Logic 层填充具体业务逻辑 |

### 开发建议

✅ **推荐做法：**
- Model 先行：数据库表结构设计清楚后再开始
- 小步迭代：一个表一个表生成，一个接口一个接口开发
- 分层开发：Model 只负责数据操作，Logic 负责业务逻辑
- Git 管理：每次生成前提交代码，方便对比变化

❌ **避免陷阱：**
- 不要手动修改 `types.go`（会被覆盖）
- 不要在 Handler 层写业务逻辑（应该在 Logic 层）
- 不要直接修改生成的 Model 基础方法（可以扩展新方法）

---

## 📦 文件列表

| 文件 | 说明 | 类型 |
|------|------|------|
| `model.sh` | 数据模型生成脚本 | 可执行脚本 |
| `api.sh` | API 代码生成脚本 | 可执行脚本 |
| `README.md` | 完整使用文档（本文档） | 文档 |
| `README.yaml` | 配置示例（带注释） | 配置示例 |

---

## ⚡ 快速开始（3分钟上手）

### 第一次使用

```bash
# 步骤1：配置数据库连接
vim etc/test-api.yaml

# 步骤2：测试数据库连接（推荐）
sh generate/model.sh --dry-run

# 步骤3：生成 Model 层
sh generate/model.sh

# 步骤4：编写 API 定义
vim api/user.api

# 步骤5：生成 API 层
sh generate/api.sh

# 步骤6：查看生成的代码结构
tree internal/
```

### 数据库配置示例

编辑 `etc/test-api.yaml`：

```yaml
Database:
  Type: mysql  # 支持：mysql、postgres、mongo
  DataSource: "root:password@tcp(127.0.0.1:3306)/mydb"
```

**⚠️ 重要：** 不要添加 `?charset`、`?parseTime` 等 URL 参数！

### 常用命令速查

```bash
# === Model 生成 ===
sh generate/model.sh                    # 生成所有表
sh generate/model.sh -t user,order      # 只生成指定表
sh generate/model.sh --dry-run          # 测试连接（不生成文件）
sh generate/model.sh -s goZero          # 使用小驼峰命名

# === API 生成 ===
sh generate/api.sh                      # 生成API代码
sh generate/api.sh --validate           # 只验证语法
sh generate/api.sh -v                   # 详细输出模式

# === 帮助信息 ===
sh generate/model.sh --help             # Model 完整帮助
sh generate/api.sh --help               # API 完整帮助
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

## 🎓 实战示例

### 场景 1：完整的用户注册登录功能

**第1步：创建数据表**

```sql
CREATE TABLE `user` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `username` varchar(50) NOT NULL,
  `password` varchar(255) NOT NULL,
  `email` varchar(100) DEFAULT NULL,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

**第2步：配置数据库并生成 Model**

```bash
# 配置数据库
vim etc/test-api.yaml
# 内容：
# Database:
#   Type: mysql
#   DataSource: "root:123456@tcp(127.0.0.1:3306)/mydb"

# 生成 user 表的 Model
sh generate/model.sh -t user
```

**第3步：编写 API 定义**

```bash
vim api/user.api
```

```go
syntax = "v1"

type RegisterRequest {
    Username string `json:"username"`
    Password string `json:"password"`
    Email    string `json:"email,optional"`
}

type RegisterResponse {
    Code    int    `json:"code"`
    Message string `json:"message"`
}

type LoginRequest {
    Username string `json:"username"`
    Password string `json:"password"`
}

type LoginResponse {
    Code    int    `json:"code"`
    Message string `json:"message"`
    Token   string `json:"token,optional"`
}

@server(
    group: auth
    prefix: api/user
)
service test-api {
    @handler RegisterHandler
    post /register (RegisterRequest) returns (RegisterResponse)
    
    @handler LoginHandler
    post /login (LoginRequest) returns (LoginResponse)
}
```

**第4步：生成 API 代码**

```bash
sh generate/api.sh
```

**第5步：编写业务逻辑**

编辑 `internal/logic/auth/registerlogic.go`，添加注册逻辑（示例已在上文"推荐开发流程"中）

**第6步：启动服务测试**

```bash
go run test.go
# 访问：http://localhost:8888/api/user/register
```

---

### 场景 2：MySQL 项目（常用）

```bash
# 配置数据库
vim etc/test-api.yaml

# 生成所有表
sh generate/model.sh

# 生成指定表（推荐，更快）
sh generate/model.sh -t user,order,product

# 使用小驼峰风格（可读性更好）
sh generate/model.sh -t user -s goZero
```

---

### 场景 3：PostgreSQL 项目

```bash
# 创建配置文件
cat > etc/pg-config.yaml << EOF
Database:
  Type: postgres
  DataSource: "postgres://admin:pass@localhost:5432/mydb"
EOF

# 生成模型
sh generate/model.sh -c etc/pg-config.yaml --db-type postgres
```

---

### 场景 4：MongoDB 项目

```bash
# 创建配置文件
cat > etc/mongo-config.yaml << EOF
Database:
  Type: mongo
  DataSource: "mongodb://admin:pass@localhost:27017/mydb"
EOF

# 生成模型
sh generate/model.sh -c etc/mongo-config.yaml --db-type mongo
```

---

### 场景 5：多环境配置

```bash
# 开发环境
sh generate/model.sh -c etc/dev.yaml

# 测试环境
sh generate/model.sh -c etc/test.yaml

# 生产环境（只测试连接，不生成）
sh generate/model.sh -c etc/prod.yaml --dry-run
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

## 🎯 最佳实践与开发建议

### 1. 开发前准备

**✅ 推荐流程：**

```bash
# 第一步：测试数据库连接
sh generate/model.sh --dry-run

# 第二步：使用 Git 管理代码
git add .
git commit -m "生成代码前的快照"

# 第三步：开始生成
sh generate/model.sh
sh generate/api.sh

# 第四步：查看变化
git diff
```

### 2. 项目分层开发（重要）

```
┌─────────────────────────────────────────┐
│  Handler 层 (HTTP 入口)                  │
│  - 只负责：参数接收、响应返回            │
│  - 不要写：业务逻辑、数据库操作          │
└──────────────┬──────────────────────────┘
               ↓
┌─────────────────────────────────────────┐
│  Logic 层 (业务逻辑)  ⭐ 核心层           │
│  - 负责：业务逻辑、流程控制、数据组装    │
│  - 调用：Model 层、第三方服务            │
└──────────────┬──────────────────────────┘
               ↓
┌─────────────────────────────────────────┐
│  Model 层 (数据库操作)                    │
│  - 只负责：数据库 CRUD                    │
│  - 不要写：业务逻辑                       │
└─────────────────────────────────────────┘
```

**示例对比：**

```go
// ❌ 错误：在 Handler 层写业务逻辑
func (h *LoginHandler) Login(req *LoginRequest) {
    user, _ := h.userModel.FindOne(req.Username)  // 不要这样做！
    if user.Password != req.Password {
        // ...
    }
}

// ✅ 正确：Handler 只负责调用 Logic
func (h *LoginHandler) Login(req *LoginRequest) {
    return h.loginLogic.Login(req)  // 业务逻辑在 Logic 层
}

// ✅ 正确：Logic 层处理业务
func (l *LoginLogic) Login(req *types.LoginRequest) (*types.LoginResponse, error) {
    // 1. 调用 Model 层查询用户
    user, err := l.svcCtx.UserModel.FindOneByUsername(l.ctx, req.Username)
    
    // 2. 业务逻辑：验证密码
    if user.Password != req.Password {
        return &types.LoginResponse{Code: 401, Message: "密码错误"}, nil
    }
    
    // 3. 业务逻辑：生成 Token
    token, _ := l.svcCtx.JwtUtil.GenerateToken(user.Id)
    
    return &types.LoginResponse{Code: 0, Token: token}, nil
}
```

### 3. 文件覆盖规则（必读）

| 文件类型 | 是否覆盖 | 说明 | 建议 |
|---------|---------|------|------|
| `types.go` | ⚠️ **会覆盖** | 由 .api 文件生成 | 不要手动修改 |
| `*model_gen.go` | ⚠️ **会覆盖** | Model 生成文件 | 不要手动修改 |
| `routes.go` | ⚠️ **会覆盖** | 路由配置 | 不要手动修改 |
| `*logic.go` | ✅ **不覆盖** | 业务逻辑 | 可以修改和扩展 |
| `*handler.go` | ✅ **不覆盖** | HTTP 处理 | 可以修改和扩展 |
| `*model.go` | ✅ **不覆盖** | Model 方法 | 可以添加自定义方法 |

**扩展 Model 示例：**

```go
// internal/model/usermodel.go
// 在生成的基础上添加自定义方法

func (m *defaultUserModel) FindOneByUsername(ctx context.Context, username string) (*User, error) {
    // 自定义查询方法
    var user User
    err := m.conn.QueryRowCtx(ctx, &user, 
        "SELECT * FROM user WHERE username = ? LIMIT 1", username)
    return &user, err
}
```

### 4. 命名风格统一

```bash
# ⭐ 推荐：goZero（小驼峰，可读性最好）
sh generate/model.sh -s goZero
sh generate/api.sh -s goZero

# 生成的文件：
# - userModel.go  (而不是 usermodel.go)
# - loginLogic.go (而不是 loginlogic.go)
```

**命名风格对比：**

| 风格 | 示例 | 推荐度 | 说明 |
|-----|------|-------|------|
| `goZero` | `userModel.go` | ⭐⭐⭐⭐⭐ | 小驼峰，最易读 |
| `gozero` | `usermodel.go` | ⭐⭐⭐ | 官方默认 |
| `GoZero` | `UserModel.go` | ⭐⭐ | 大驼峰 |
| `go_zero` | `user_model.go` | ⭐⭐ | 下划线 |

### 5. API 设计建议

```go
// ✅ 推荐：统一的响应格式
type BaseResponse {
    Code    int    `json:"code"`    // 0=成功，其他=失败
    Message string `json:"message"` // 提示信息
}

type LoginResponse {
    Code    int       `json:"code"`
    Message string    `json:"message"`
    Data    LoginInfo `json:"data,optional"` // 业务数据
}

// ✅ 推荐：按功能模块分组
@server(
    group: auth     // 认证相关
    prefix: api/user
)

@server(
    group: order    // 订单相关
    prefix: api/order
)

// ✅ 推荐：使用有意义的 Handler 名称
@handler LoginHandler        // 清晰明确
@handler UserRegisterHandler // 而不是 Register
```

### 6. 验证与测试

```bash
# 生成前：验证 API 语法
sh generate/api.sh --validate

# 生成前：测试数据库连接
sh generate/model.sh --dry-run

# 生成后：查看代码差异
git diff

# 生成后：运行测试
go test ./...
```

### 7. 性能优化建议

```bash
# ✅ 只生成需要的表（避免不必要的生成）
sh generate/model.sh -t user,order

# ✅ 使用索引（数据库设计阶段）
CREATE INDEX idx_username ON user(username);

# ✅ 在 Logic 层实现缓存逻辑
// 先查缓存，再查数据库
```

### 8. 安全建议

```go
// ❌ 危险：明文存储密码
Password: req.Password

// ✅ 安全：加密存储
import "golang.org/x/crypto/bcrypt"
hashedPassword, _ := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)

// ✅ 安全：使用 JWT
import "github.com/golang-jwt/jwt/v4"
token := jwt.NewWithClaims(...)

// ✅ 安全：参数校验
if len(req.Username) < 3 || len(req.Username) > 50 {
    return &types.RegisterResponse{Code: 400, Message: "用户名长度 3-50"}, nil
}
```

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

---

## 🎴 5分钟速查卡

```bash
# ========== 基础流程 ==========
# 1. 配置数据库
vim etc/test-api.yaml

# 2. 生成 Model (从数据库表)
sh generate/model.sh -t user

# 3. 编写 API 定义
vim api/user.api

# 4. 生成 API 代码
sh generate/api.sh

# 5. 编写业务逻辑
vim internal/logic/auth/registerlogic.go

# ========== 常用命令 ==========
# 测试数据库连接
sh generate/model.sh --dry-run

# 验证 API 语法
sh generate/api.sh --validate

# 使用小驼峰命名（推荐）
sh generate/model.sh -s goZero
sh generate/api.sh -s goZero

# 查看完整帮助
sh generate/model.sh --help
sh generate/api.sh --help

# ========== 分层原则 ==========
# Handler → 只接收请求和返回响应
# Logic   → 编写业务逻辑（核心）⭐
# Model   → 只负责数据库 CRUD
```

---

## 📑 快速导航

| 章节 | 内容 | 适用人群 |
|-----|------|---------|
| [🚀 推荐开发流程](#-推荐开发流程重要) | **⭐ 必读**：完整开发步骤 | 新手必看 |
| [⚡ 快速开始](#-快速开始3分钟上手) | 3分钟快速上手 | 所有人 |
| [🎓 实战示例](#-实战示例) | 完整的用户注册登录案例 | 实战学习 |
| [🎯 最佳实践](#-最佳实践与开发建议) | 分层开发、命名规范、安全建议 | 进阶学习 |
| [📖 详细文档](#-详细文档) | 完整命令行参数说明 | 参考文档 |
| [🆘 遇到问题](#-遇到问题) | 常见错误排查 | 故障排查 |
| [✨ 核心特性](#-核心特性) | 多数据库支持、智能检测 | 了解功能 |
| [🆕 版本信息](#-版本信息) | 更新日志 | 版本历史 |
