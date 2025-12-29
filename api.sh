#!/bin/bash

# 生成 API 代码
# goctl api go -api test.api -dir . -style gozero

# ============================================
# Go-Zero API 代码生成脚本
# ============================================
# 功能说明：
#   根据 .api 文件自动生成 go-zero 的 HTTP API 代码
#   包括：Handler（路由处理）、Logic（业务逻辑）、Types（数据结构）
# 
# 依赖工具：
#   goctl - go-zero 的代码生成工具
# 
# 使用方法：
#   sh generate-api.sh [选项]
# 
# 作者：Go-Zero Team
# 更新时间：2025-12-23
# ============================================

set -e  # 遇到错误立即退出

# ============================================
# 颜色定义
# ============================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'

# ============================================
# 配置参数
# ============================================

# API 定义文件路径
# 这是描述 API 接口的源文件（类似 Swagger 的 YAML）
API_FILE="test.api"

# 输出目录（项目根目录）
# 
# 重要说明：
#   - 此参数指定的是项目根目录，不是 internal 目录
#   - goctl 会自动在指定目录下创建 internal/、etc/ 等目录结构
#   - 设置为 "." 表示当前目录（项目根目录），这是标准用法
#   - 不要设置为 "internal"，否则会创建 internal/internal/... 的错误路径
#   - 如果项目有多个模块，可以设置为不同的根目录（如 "module1", "module2"）
OUTPUT_DIR="."

# 文件命名风格（决定生成的 .go 文件的命名方式）
# 
# 说明：此参数仅影响生成文件的命名格式，不影响代码内容
#       生成后的 Handler、Logic 等文件名会根据所选风格自动命名
#
# 可选风格：
#   gozero  - 纯小写无分隔（官方推荐）
#             生成: loginhandler.go, userlogic.go
#   
#   goZero  - 小驼峰（首字母小写）
#             生成: loginHandler.go, userLogic.go
#   
#   GoZero  - 大驼峰（首字母大写）
#             生成: LoginHandler.go, UserLogic.go
#   
#   go_zero - 下划线分隔
#             生成: login_handler.go, user_logic.go
STYLE="goZero"

# 是否显示详细日志
VERBOSE=false

# 是否仅验证 API 文件语法（不生成代码）
VALIDATE_ONLY=false

# ============================================
# 工具函数
# ============================================

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1" >&2
    exit 1
}

log_step() {
    echo -e "${CYAN}▶${NC} $1"
}

log_detail() {
    echo -e "${GRAY}  $1${NC}"
}

print_header() {
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}  $1${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_separator() {
    echo -e "${GRAY}────────────────────────────────────────${NC}"
}

# ============================================
# 显示帮助信息
# ============================================
show_help() {
    cat << EOF
${WHITE}Go-Zero API 代码生成脚本${NC}

${CYAN}使用方法:${NC}
  $0 [选项]

${CYAN}选项说明:${NC}
  -h, --help              显示此帮助信息
  -f, --file FILE         指定 API 定义文件（默认: test.api）
  -o, --output DIR        指定项目根目录（默认: .）
                          注意：这是项目根目录，不是 internal 目录
                          goctl 会自动在此目录下创建 internal/、etc/ 等目录
                          不要设置为 "internal"，否则会创建错误的嵌套路径
  -s, --style STYLE       指定代码风格（默认: gozero）
                          可选值: gozero, goZero, GoZero, go_zero
  -v, --verbose           显示详细的生成日志
  --validate              仅验证 API 文件语法，不生成代码

${CYAN}代码风格说明:${NC}
  ${WHITE}gozero${NC}   - 官方推荐（纯小写，无分隔）
            示例: loginhandler.go, userlogic.go
  
  ${WHITE}goZero${NC}   - 小驼峰命名（首字母小写，后续单词首字母大写）
            示例: loginHandler.go, userLogic.go
  
  ${WHITE}GoZero${NC}   - 大驼峰命名（所有单词首字母大写，PascalCase）
            示例: LoginHandler.go, UserLogic.go
  
  ${WHITE}go_zero${NC}  - 下划线分隔（小写+下划线）
            示例: login_handler.go, user_logic.go

${CYAN}使用示例:${NC}
  ${GRAY}# 使用默认配置生成代码${NC}
  $0

  ${GRAY}# 指定 API 文件${NC}
  $0 -f api/user.api

  ${GRAY}# 指定项目根目录（多模块项目）${NC}
  $0 -o module1
  ${GRAY}# 注意：不要设置为 "internal"，会创建错误的嵌套路径${NC}

  ${GRAY}# 使用小驼峰命名风格${NC}
  $0 -s goZero

  ${GRAY}# 使用大驼峰命名风格${NC}
  $0 -s GoZero

  ${GRAY}# 显示详细日志${NC}
  $0 -v

  ${GRAY}# 仅验证 API 文件语法${NC}
  $0 --validate

  ${GRAY}# 组合使用多个参数${NC}
  $0 -f api/user.api -o . -s gozero -v

${CYAN}goctl api 命令详解:${NC}
  ${WHITE}基础命令:${NC}
    goctl api go -api FILE -dir DIR [选项]

  ${WHITE}常用参数:${NC}
    -api string           API 定义文件路径（必需）
    -dir string           输出目录路径（必需）
    -style string         文件命名风格（推荐 gozero）
    
  ${WHITE}高级参数:${NC}
    -home string          自定义模板目录（用于定制生成代码格式）
    -remote string        远程模板仓库地址（Git URL）
    -branch string        远程模板仓库分支（配合 --remote 使用）
    
  ${WHITE}其他参数:${NC}
    -v, --version         查看 goctl 版本
    -h, --help            查看帮助信息

${CYAN}生成的目录结构:${NC}
  .
  ├── etc/                      # 配置文件目录
  │   └── test-api.yaml         # API 服务配置
  ├── internal/
  │   ├── config/               # 配置结构定义
  │   │   └── config.go
  │   ├── handler/              # HTTP 处理器（路由层）
  │   │   ├── routes.go         # 路由注册
  │   │   └── *handler.go       # 各接口的 Handler
  │   ├── logic/                # 业务逻辑层
  │   │   └── *logic.go         # 各接口的 Logic
  │   ├── svc/                  # 服务上下文
  │   │   └── servicecontext.go # 依赖注入容器
  │   └── types/                # 数据结构定义
  │       └── types.go          # 请求/响应结构体
  └── test.go                   # 服务启动入口

${CYAN}API 文件格式示例:${NC}
  ${GRAY}// 定义数据类型${NC}
  type LoginRequest {
      Username string \`json:"username"\`
      Password string \`json:"password"\`
  }
  
  type LoginResponse {
      Token string \`json:"token"\`
  }
  
  ${GRAY}// 定义 API 服务${NC}
  @server(
      group: auth
      prefix: /api/v1
  )
  service test-api {
      @handler Login
      post /auth/login (LoginRequest) returns (LoginResponse)
  }

${CYAN}常见使用场景:${NC}
  ${WHITE}场景 1: 新建项目${NC}
    1. 创建 API 文件: touch user.api
    2. 编写 API 定义（参考上面的格式示例）
    3. 生成代码: sh generate-api.sh -f user.api
    4. 实现业务逻辑（在 *logic.go 中编写代码）

  ${WHITE}场景 2: 更新 API${NC}
    1. 修改 API 文件（添加新接口或修改现有接口）
    2. 重新生成: sh generate-api.sh
    3. 注意: Handler 和 Logic 文件不会被覆盖，但会创建新的
    4. 手动删除不需要的旧文件

  ${WHITE}场景 3: 使用自定义模板${NC}
    1. 创建模板目录: mkdir -p templates/api
    2. 复制默认模板并修改
    3. 生成时指定模板: goctl api go -api test.api -dir . --home templates
    
  ${WHITE}场景 4: 多模块项目${NC}
    1. 为不同模块创建独立的 API 文件（如 user.api, order.api）
    2. 使用 -o 参数指定不同的项目根目录:
       $0 -f api/user.api -o user-service
       $0 -f api/order.api -o order-service
    3. 注意：-o 参数是项目根目录，goctl 会自动创建 internal/ 目录
    4. 在主服务中整合多个 API 模块

${CYAN}注意事项:${NC}
  • API 文件修改后需要重新运行此脚本
  • Handler 和 Logic 文件不会被覆盖，但新增接口会创建新文件
  • Types 文件会被完全覆盖，不要在其中添加自定义代码
  • 建议使用 Git 版本控制，方便对比生成前后的变化

${CYAN}相关命令:${NC}
  ${GRAY}# 验证 API 文件语法${NC}
  goctl api validate -api test.api

  ${GRAY}# 生成 API 文档${NC}
  goctl api doc -dir .

  ${GRAY}# 格式化 API 文件${NC}
  goctl api format -dir .

  ${GRAY}# 从 Swagger 生成 API${NC}
  goctl api plugin -plugin goctl-swagger="swagger -filename user.json" -api user.api -dir .

EOF
    exit 0
}

# ============================================
# 参数解析
# ============================================
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            ;;
        -f|--file)
            API_FILE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -s|--style)
            # 验证风格参数是否有效
            if [[ "$2" != "gozero" && "$2" != "goZero" && "$2" != "GoZero" && "$2" != "go_zero" ]]; then
                echo ""
                echo -e "${RED}✗${NC} 无效的命名风格: $2"
                log_detail "支持的风格: gozero, goZero, GoZero, go_zero"
                echo ""
                exit 1
            fi
            STYLE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --validate)
            VALIDATE_ONLY=true
            shift
            ;;
        *)
            echo ""
            echo -e "${RED}✗${NC} 未知参数: $1"
            log_detail "使用 -h 或 --help 查看帮助信息"
            echo ""
            exit 1
            ;;
    esac
done

# ============================================
# 主程序
# ============================================

print_header "Go-Zero API 代码生成工具"

# --------------------------------------------
# 检查 goctl 工具
# --------------------------------------------
log_step "检查 goctl 工具..."
if ! command -v goctl &> /dev/null; then
    echo ""
    echo -e "${RED}✗${NC} 未找到 goctl 命令"
    echo ""
    log_warning "安装方法:"
    log_detail "使用 go install 安装:"
    log_detail "  go install github.com/zeromicro/go-zero/tools/goctl@latest"
    log_detail ""
    log_detail "或使用 brew 安装（macOS）:"
    log_detail "  brew install goctl"
    log_detail ""
    log_detail "安装后请确保 \$GOPATH/bin 在 PATH 环境变量中"
    echo ""
    exit 1
fi
GOCTL_VERSION=$(goctl --version 2>&1 | head -n 1)
log_success "goctl 已安装 (${GOCTL_VERSION})"

# --------------------------------------------
# 检查 API 文件
# --------------------------------------------
log_step "检查 API 文件..."
if [ ! -f "$API_FILE" ]; then
    echo ""
    echo -e "${RED}✗${NC} API 文件不存在: $API_FILE"
    log_detail "请确认文件路径是否正确"
    log_detail "或使用 -f 参数指定正确的 API 文件路径"
    echo ""
    exit 1
fi
log_success "API 文件: $API_FILE"

# 显示文件信息
FILE_SIZE=$(du -h "$API_FILE" | cut -f1)
LINE_COUNT=$(wc -l < "$API_FILE" | tr -d ' ')
log_detail "文件大小: $FILE_SIZE"
log_detail "代码行数: $LINE_COUNT"

# --------------------------------------------
# 显示配置摘要
# --------------------------------------------
echo ""
print_separator
log_info "配置摘要"
log_detail "API 文件: $API_FILE"
log_detail "输出目录: $OUTPUT_DIR"
log_detail "代码风格: $STYLE"
if [ "$VERBOSE" = true ]; then
    log_detail "详细日志: 已启用"
fi
if [ "$VALIDATE_ONLY" = true ]; then
    log_warning "运行模式: 仅验证语法（不生成代码）"
fi
print_separator
echo ""

# --------------------------------------------
# 验证 API 语法
# --------------------------------------------
log_step "验证 API 文件语法..."

# 执行验证并捕获输出
VALIDATE_OUTPUT=$(goctl api validate -api "$API_FILE" 2>&1)
VALIDATE_EXIT_CODE=$?

# 检查是否有错误
if [ $VALIDATE_EXIT_CODE -ne 0 ] || echo "$VALIDATE_OUTPUT" | grep -qi "error"; then
    echo ""
    echo -e "${RED}✗${NC} API 文件语法错误"
    echo ""
    
    # 显示详细错误信息
    if [ -n "$VALIDATE_OUTPUT" ]; then
        log_warning "错误详情:"
        echo ""
        echo "$VALIDATE_OUTPUT" | while IFS= read -r line; do
            if [[ "$line" =~ [Ee]rror ]] || [[ "$line" =~ 行 ]] || [[ "$line" =~ line ]]; then
                echo -e "  ${RED}${line}${NC}"
            else
                echo -e "  ${GRAY}${line}${NC}"
            fi
        done
        echo ""
    fi
    
    log_warning "常见语法问题排查:"
    log_detail "1. 检查服务定义格式: service ServiceName { ... }"
    log_detail "2. 检查路由格式: @handler HandlerName"
    log_detail "3. 检查 HTTP 方法和路径格式: get /path/to/api (Request) returns (Response)"
    log_detail "4. 确认所有 type 定义正确，字段有类型标注"
    log_detail "5. 检查是否有中文引号、多余空格等问题"
    echo ""
    exit 1
else
    log_success "API 文件语法正确"
fi

# 如果只是验证模式，到此结束
if [ "$VALIDATE_ONLY" = true ]; then
    echo ""
    log_success "验证完成！"
    exit 0
fi

# --------------------------------------------
# 生成代码
# --------------------------------------------
log_step "开始生成 API 代码..."
sleep 0.5

START_TIME=$(date +%s)

# 构建 goctl 命令
GOCTL_CMD="goctl api go -api $API_FILE -dir $OUTPUT_DIR -style $STYLE"

# 执行生成命令并捕获输出
if [ "$VERBOSE" = true ]; then
    # 详细模式：显示所有输出
    log_detail "执行命令: $GOCTL_CMD"
    echo ""
    $GOCTL_CMD 2>&1 | tee /tmp/goctl_api_output.log
    GOCTL_EXIT_CODE=${PIPESTATUS[0]}
else
    # 静默模式：只显示关键信息
    $GOCTL_CMD 2>&1 | tee /tmp/goctl_api_output.log | grep -v "^$" | while IFS= read -r line; do
        # 过滤一些常见的提示信息
        if [[ ! "$line" =~ "Done" ]] && [[ ! "$line" =~ "Hint:" ]]; then
            log_detail "$line"
        fi
    done
    GOCTL_EXIT_CODE=${PIPESTATUS[0]}
fi

# 检查输出日志中是否包含错误关键字
if grep -qi "error\|failed\|cannot" /tmp/goctl_api_output.log 2>/dev/null; then
    GOCTL_EXIT_CODE=1
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# --------------------------------------------
# 显示结果
# --------------------------------------------
echo ""
print_separator

if [ $GOCTL_EXIT_CODE -eq 0 ]; then
    # ========================================
    # 生成成功
    # ========================================
    log_success "代码生成完成！"
    log_detail "耗时: ${DURATION}s"
    log_detail "输出: $OUTPUT_DIR"
    
    # 统计生成的文件
    if [ -d "$OUTPUT_DIR/internal" ]; then
        HANDLER_COUNT=$(find "$OUTPUT_DIR/internal/handler" -name "*handler.go" 2>/dev/null | wc -l | tr -d ' ')
        LOGIC_COUNT=$(find "$OUTPUT_DIR/internal/logic" -name "*logic.go" 2>/dev/null | wc -l | tr -d ' ')
        
        echo ""
        log_info "生成统计"
        log_detail "Handler 文件: $HANDLER_COUNT 个"
        log_detail "Logic 文件: $LOGIC_COUNT 个"
        log_detail "Types 文件: 1 个"
    fi
    
    print_separator
    echo ""
    log_success "全部完成！"
    
    # 温馨提示
    echo ""
    echo -e "${CYAN}💡 下一步:${NC}"
    log_detail "1. 在 internal/logic/*logic.go 中实现业务逻辑"
    log_detail "2. 在 etc/*.yaml 中配置数据库、Redis 等依赖"
    log_detail "3. 运行服务: go run test.go -f etc/test-api.yaml"
    echo ""
    
else
    # ========================================
    # 生成失败
    # ========================================
    echo -e "${RED}✗${NC} 代码生成失败！"
    log_detail "退出码: $GOCTL_EXIT_CODE"
    echo ""
    
    # 显示详细错误信息
    if [ -f /tmp/goctl_api_output.log ]; then
        log_warning "完整错误日志:"
        echo ""
        # 只显示包含错误的行
        grep -i "error\|failed\|cannot\|invalid" /tmp/goctl_api_output.log 2>/dev/null | while IFS= read -r line; do
            echo -e "  ${RED}${line}${NC}"
        done
        echo ""
    fi
    
    log_warning "常见问题排查:"
    log_detail "1. 确认 API 文件语法正确: goctl api validate -api $API_FILE"
    log_detail "2. 检查输出目录权限: ls -la $OUTPUT_DIR"
    log_detail "3. 确认 goctl 版本: goctl --version（建议使用最新版本）"
    log_detail "4. 检查是否有文件被占用或权限不足"
    log_detail "5. 查看完整日志: cat /tmp/goctl_api_output.log"
    echo ""
    print_separator
    echo ""
    exit 1
fi

# ============================================
# 附加说明（注释形式，可供参考）
# ============================================

# --------------------------------------------
# 常用命令速查
# --------------------------------------------
# 1. 基础生成（当前目录）
#    goctl api go -api test.api -dir . -style gozero

# 2. 生成到指定目录
#    goctl api go -api test.api -dir internal -style gozero

# 3. 使用自定义模板
#    goctl api go -api test.api -dir . -home ./templates

# 4. 使用远程模板
#    goctl api go -api test.api -dir . --remote https://github.com/username/templates --branch main

# 5. 验证 API 文件
#    goctl api validate -api test.api

# 6. 格式化 API 文件
#    goctl api format -dir . -iu

# 7. 生成 API 文档
#    goctl api doc -dir .

# 8. 查看 goctl 版本
#    goctl --version

# --------------------------------------------
# API 文件编写技巧
# --------------------------------------------
# 1. 使用 group 分组接口
#    @server(
#        group: user
#        prefix: /api/v1/user
#    )
#    service test-api {
#        @handler Info
#        get /info returns (UserInfo)
#    }

# 2. 添加 JWT 认证
#    @server(
#        jwt: Auth
#        group: user
#    )
#    service test-api {
#        @handler UpdateProfile
#        put /profile (UpdateRequest) returns (UpdateResponse)
#    }

# 3. 添加中间件
#    @server(
#        middleware: CORS
#        group: public
#    )
#    service test-api {
#        @handler Ping
#        get /ping returns (PingResponse)
#    }

# 4. 路径参数
#    @handler GetUser
#    get /user/:id (GetUserRequest) returns (GetUserResponse)

# 5. 可选字段
#    type UserRequest {
#        Name  string `json:"name"`
#        Email string `json:"email,optional"`  // 可选字段
#    }

# --------------------------------------------
# 项目结构最佳实践
# --------------------------------------------
# api/                  - API 定义文件目录
#   ├── user.api        - 用户模块 API
#   ├── order.api       - 订单模块 API
#   └── common.api      - 公共类型定义
#
# internal/
#   ├── handler/        - HTTP 处理层（接收请求、返回响应）
#   ├── logic/          - 业务逻辑层（核心业务代码）
#   ├── svc/            - 服务上下文（依赖注入）
#   ├── types/          - 数据类型定义
#   ├── middleware/     - 中间件（自定义）
#   └── model/          - 数据模型（数据库）
#
# etc/                  - 配置文件
#   ├── dev.yaml        - 开发环境配置
#   ├── test.yaml       - 测试环境配置
#   └── prod.yaml       - 生产环境配置

# --------------------------------------------
# 生成后的开发流程
# --------------------------------------------
# 1. 生成代码
#    sh generate-api.sh
#
# 2. 实现业务逻辑
#    打开 internal/logic/*logic.go
#    在各个 Logic 函数中编写业务代码
#
# 3. 添加依赖
#    在 internal/svc/servicecontext.go 中注入依赖
#    例如：数据库连接、Redis 客户端、RPC 客户端等
#
# 4. 测试接口
#    启动服务: go run test.go
#    使用 Postman 或 curl 测试接口
#
# 5. 更新 API
#    修改 .api 文件
#    重新运行 sh generate-api.sh
#    更新对应的 Logic 实现
