#!/bin/bash

# ============================================
# MySQL 模型生成脚本
# ============================================
# 功能说明：
#   此脚本用于自动生成 go-zero 框架的 MySQL 数据模型文件
#   支持批量生成、单表生成、预览模式等多种工作方式
# 
# 依赖工具：
#   1. goctl - go-zero 的代码生成工具
#   2. mysql - MySQL 客户端命令行工具
# 
# 使用方法：
#   sh generate-model.sh [选项] [表名]
# 
# 作者：Go-Zero Team
# 更新时间：2025-12-23
# ============================================

# 设置错误时立即退出（严格模式）
# 任何命令返回非零状态码都会导致脚本立即终止
set -e

# ============================================
# 终端颜色和样式定义
# ============================================
# 使用 ANSI 转义序列定义颜色，用于美化终端输出
# 格式：\033[样式;前景色m 或 \033[0;颜色代码m

RED='\033[0;31m'       # 红色 - 用于错误信息
GREEN='\033[0;32m'     # 绿色 - 用于成功信息
YELLOW='\033[1;33m'    # 黄色 - 用于警告信息
BLUE='\033[0;34m'      # 蓝色 - 用于普通信息
PURPLE='\033[0;35m'    # 紫色 - 用于标题和分割线
CYAN='\033[0;36m'      # 青色 - 用于步骤提示
WHITE='\033[1;37m'     # 白色 - 用于高亮文本
GRAY='\033[0;90m'      # 灰色 - 用于次要信息
NC='\033[0m'           # No Color - 重置颜色（必须在彩色文本后使用）

# ============================================
# 全局配置变量
# ============================================

# 配置文件路径（YAML 格式）
# 默认从项目根目录的 etc 子目录读取
CONFIG_FILE="etc/test-api.yaml"

# 模型文件输出目录
# 生成的 Go 模型文件将存放在此目录
OUTPUT_DIR="internal/model"

# 预览模式标志
# true: 仅显示将要生成的内容，不实际创建文件
# false: 正常执行生成操作
DRY_RUN=false

# 数据库类型（自动检测或手动指定）
# 支持: mysql, postgres, mongo
# 留空表示自动检测
DB_TYPE=""

# 文件命名风格（决定生成的 .go 文件的命名方式）
# 
# 说明：此参数仅影响生成文件的命名格式，不影响代码内容
#       生成后的文件名会根据所选风格自动命名
#
# 可选风格：
#   gozero  - 纯小写无分隔（官方推荐）
#             生成: usermodel.go, usermodel_gen.go
#   
#   goZero  - 小驼峰（首字母小写）
#             生成: userModel.go, userModel_gen.go
#   
#   GoZero  - 大驼峰（首字母大写）
#             生成: UserModel.go, UserModel_gen.go
#   
#   go_zero - 下划线分隔
#             生成: user_model.go, user_model_gen.go
STYLE="gozero"

# 需要跳过的数据库表列表
# 可以在此数组中添加不想生成模型的表名
# 例如：系统表、临时表、测试表等
SKIP_TABLES=(
    # 示例（取消注释以启用）：
    # "migrations"        # 数据库迁移表
    # "schema_version"    # 版本控制表
    # "temp_*"            # 临时表（支持通配符需额外处理）
)

# ============================================
# 工具函数库
# ============================================
# 以下函数用于统一日志输出格式，提升用户体验

# --------------------------------------------
# 打印醒目的标题栏
# --------------------------------------------
# 参数：
#   $1 - 标题文本
# 示例：
#   print_header "开始执行任务"
# --------------------------------------------
print_header() {
    echo ""
    # 使用 Unicode 字符绘制分割线
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}  $1${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# --------------------------------------------
# 打印普通分割线
# --------------------------------------------
# 用于分隔不同的信息区块
# --------------------------------------------
print_separator() {
    echo -e "${GRAY}────────────────────────────────────────${NC}"
}

# --------------------------------------------
# 打印成功日志
# --------------------------------------------
# 参数：
#   $1 - 成功信息文本
# 特点：
#   - 绿色对勾图标
#   - 适用于操作完成、验证通过等场景
# --------------------------------------------
log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# --------------------------------------------
# 打印信息日志
# --------------------------------------------
# 参数：
#   $1 - 普通信息文本
# 特点：
#   - 蓝色信息图标
#   - 适用于状态说明、配置展示等场景
# --------------------------------------------
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# --------------------------------------------
# 打印警告日志
# --------------------------------------------
# 参数：
#   $1 - 警告信息文本
# 特点：
#   - 黄色警告图标
#   - 适用于非致命问题、需要注意的情况
# --------------------------------------------
log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# --------------------------------------------
# 打印错误日志并退出程序
# --------------------------------------------
# 参数：
#   $1 - 错误信息文本
# 特点：
#   - 红色错误图标
#   - 输出到标准错误流（stderr）
#   - 自动以状态码 1 退出程序
# 注意：
#   此函数会终止脚本执行，调用后的代码不会运行
# --------------------------------------------
log_error() {
    echo -e "${RED}✗${NC} $1" >&2
    exit 1
}

# --------------------------------------------
# 打印步骤日志
# --------------------------------------------
# 参数：
#   $1 - 步骤描述文本
# 特点：
#   - 青色箭头图标
#   - 用于标识正在执行的操作
# --------------------------------------------
log_step() {
    echo -e "${CYAN}▶${NC} $1"
}

# --------------------------------------------
# 打印详细信息（缩进显示）
# --------------------------------------------
# 参数：
#   $1 - 详细信息文本
# 特点：
#   - 灰色文本
#   - 自动添加缩进（两个空格）
#   - 用于显示步骤的详细内容或子项
# --------------------------------------------
log_detail() {
    echo -e "${GRAY}  $1${NC}"
}

# --------------------------------------------
# 显示帮助信息
# --------------------------------------------
# 功能：
#   展示脚本的使用说明、参数选项和示例
# 注意：
#   调用后会以状态码 0 退出程序
# --------------------------------------------
show_help() {
    cat << EOF
${WHITE}Go-Zero MySQL 模型生成脚本${NC}

${CYAN}使用方法:${NC}
  $0 [选项] [表名]

${CYAN}选项说明:${NC}
  -h, --help          显示此帮助信息
  -c, --config FILE   指定配置文件路径（默认: etc/test-api.yaml）
  -o, --output DIR    指定模型文件输出目录（默认: internal/model）
  -s, --style STYLE   指定文件命名风格（默认: gozero）
                      可选值: gozero, goZero, GoZero, go_zero
  -d, --dry-run       启用预览模式，仅显示将要执行的操作，不实际生成文件
  -t, --table TABLE   仅生成指定的表模型（多个表用逗号分隔，如: user,order）
  --db-type TYPE      指定数据库类型（默认: 自动检测）
                      可选值: mysql, postgres, mongo

${CYAN}文件命名风格说明:${NC}
  ${WHITE}gozero${NC}   - 官方推荐（纯小写，无分隔）
            示例: usermodel.go, usermodel_gen.go, ordermodel.go
  
  ${WHITE}goZero${NC}   - 小驼峰命名（首字母小写，后续单词首字母大写）
            示例: userModel.go, userModel_gen.go, orderModel.go
  
  ${WHITE}GoZero${NC}   - 大驼峰命名（所有单词首字母大写，PascalCase）
            示例: UserModel.go, UserModel_gen.go, OrderModel.go
  
  ${WHITE}go_zero${NC}  - 下划线分隔（小写+下划线）
            示例: user_model.go, user_model_gen.go, order_model.go

${CYAN}使用示例:${NC}
  ${GRAY}# 生成所有表的模型（排除 SKIP_TABLES 中定义的表）${NC}
  $0

  ${GRAY}# 仅生成 user 和 order 表的模型${NC}
  $0 user,order

  ${GRAY}# 使用 -t 参数指定表名（效果同上）${NC}
  $0 -t user,order

  ${GRAY}# 使用小驼峰命名风格${NC}
  $0 -s goZero

  ${GRAY}# 使用大驼峰命名风格${NC}
  $0 -s GoZero

  ${GRAY}# 使用自定义配置文件${NC}
  $0 -c config/production.yaml

  ${GRAY}# 指定自定义输出目录${NC}
  $0 -o internal/dao

  ${GRAY}# 预览模式：查看将要生成哪些表，但不实际生成文件${NC}
  $0 --dry-run

  ${GRAY}# 组合使用多个参数${NC}
  $0 -c custom.yaml -o models -s goZero -t user

  ${GRAY}# 指定数据库类型为 PostgreSQL${NC}
  $0 --db-type postgres

  ${GRAY}# 使用 PostgreSQL 并指定表${NC}
  $0 --db-type postgres -t users,orders

${CYAN}配置文件格式:${NC}
  配置文件需包含数据库连接信息（YAML 格式）：
  
  ${WHITE}推荐格式（通用，支持多种数据库）：${NC}
  Database:
    Type: mysql          # 数据库类型: mysql, postgres, mongo
    DataSource: "user:password@tcp(host:port)/database"
  
  ${WHITE}旧格式（仍然支持，自动检测类型）：${NC}
  MySQL:
    DataSource: "user:password@tcp(host:port)/database"
  
  Postgres:
    DataSource: "postgres://user:password@host:port/database"
  
  Mongo:
    DataSource: "mongodb://user:password@host:port/database"

  ${YELLOW}注意：${NC}
  • DataSource 用于 goctl 生成模型，不要包含额外参数
  • MySQL 格式: "root:123456@tcp(127.0.0.1:3306)/mydb"
  • PostgreSQL 格式: "postgres://user:pass@localhost:5432/db"
  • MongoDB 格式: "mongodb://user:pass@localhost:27017/db"
  • 不要添加 charset、parseTime、loc 等参数（会导致 goctl 解析失败）

${CYAN}输出说明:${NC}
  生成的文件包括：
  • *_gen.go  - 自动生成的基础 CRUD 代码（只读，不要手动修改）
  • *.go      - 自定义扩展代码文件（可以添加自定义方法）
  • vars.go   - 公共变量定义文件

${CYAN}常见问题:${NC}
  Q: 提示 "invalid DSN" 错误？
  A: 检查 DataSource 格式，确保不包含 charset 等参数

  Q: 如何跳过某些表？
  A: 在脚本开头的 SKIP_TABLES 数组中添加表名

  Q: 重新生成会覆盖自定义代码吗？
  A: *_gen.go 会被覆盖，但自定义的 *.go 文件不会（需提前备份）

EOF
    exit 0
}

# ============================================
# 命令行参数解析
# ============================================
# 使用 while 循环解析命令行传入的所有参数
# 支持短选项（-h）和长选项（--help）两种格式

# 存储用户通过命令行指定的表名
# 如果指定，将覆盖自动扫描的表列表
SPECIFIED_TABLES=""

# 循环处理所有命令行参数
# $# 表示参数数量，每处理一个参数就 shift 移除
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            # 显示帮助信息并退出
            show_help
            ;;
        -c|--config)
            # 自定义配置文件路径
            # $2 是该选项的值，shift 2 移除选项和值
            CONFIG_FILE="$2"
            shift 2
            ;;
        -o|--output)
            # 自定义输出目录
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -s|--style)
            # 自定义文件命名风格
            # 验证风格参数是否有效
            if [[ "$2" != "gozero" && "$2" != "goZero" && "$2" != "GoZero" && "$2" != "go_zero" ]]; then
                log_error "无效的命名风格: $2 (支持: gozero, goZero, GoZero, go_zero)"
            fi
            STYLE="$2"
            shift 2
            ;;
        -d|--dry-run)
            # 启用预览模式
            # 这是一个开关选项，没有值，只需 shift 1
            DRY_RUN=true
            shift
            ;;
        -t|--table)
            # 指定要生成的表名
            # 多个表用逗号分隔，例如：user,order,product
            SPECIFIED_TABLES="$2"
            shift 2
            ;;
        --db-type)
            # 指定数据库类型
            # 验证数据库类型是否有效
            if [[ "$2" != "mysql" && "$2" != "postgres" && "$2" != "mongo" ]]; then
                log_error "无效的数据库类型: $2 (支持: mysql, postgres, mongo)"
            fi
            DB_TYPE="$2"
            shift 2
            ;;
        *)
            # 如果参数不匹配任何选项，当作表名处理
            # 这允许用户直接运行：sh generate-model.sh user
            # 而不需要 -t 选项
            SPECIFIED_TABLES="$1"
            shift
            ;;
    esac
done

# ============================================
# 数据库抽象层函数
# ============================================

# --------------------------------------------
# 自动检测数据库类型
# --------------------------------------------
# 参数：
#   $1 - 配置文件路径
# 返回：
#   数据库类型字符串 (mysql, postgres, mongo)
# --------------------------------------------
detect_database_type() {
    local config_file="$1"
    
    # 优先读取 Database.Type 字段
    local db_type
    db_type=$(grep -A 5 "^Database:" "$config_file" | grep "Type:" | sed 's/.*Type:[[:space:]]*\([^[:space:]]*\).*/\1/' | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    if [ -n "$db_type" ]; then
        echo "$db_type"
        return 0
    fi
    
    # 如果没有 Database.Type，根据配置项推断
    if grep -q "^MySQL:" "$config_file"; then
        echo "mysql"
        return 0
    elif grep -q "^Postgres:" "$config_file" || grep -q "^PostgreSQL:" "$config_file"; then
        echo "postgres"
        return 0
    elif grep -q "^Mongo:" "$config_file" || grep -q "^MongoDB:" "$config_file"; then
        echo "mongo"
        return 0
    fi
    
    # 默认返回 mysql（向后兼容）
    echo "mysql"
}

# --------------------------------------------
# 从配置文件读取 DataSource
# --------------------------------------------
# 参数：
#   $1 - 配置文件路径
#   $2 - 数据库类型
# 返回：
#   DataSource 连接字符串
# --------------------------------------------
read_datasource() {
    local config_file="$1"
    local db_type="$2"
    local datasource=""
    
    # 首先尝试读取通用的 Database.DataSource
    datasource=$(grep -A 5 "^Database:" "$config_file" | grep "DataSource:" | sed 's/.*DataSource:[[:space:]]*"\(.*\)".*/\1/' | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    if [ -n "$datasource" ]; then
        echo "$datasource"
        return 0
    fi
    
    # 如果没有找到，根据数据库类型读取特定配置
    case "$db_type" in
        mysql)
            datasource=$(grep -A 20 "MySQL:" "$config_file" | grep "DataSource:" | sed 's/.*DataSource:[[:space:]]*"\(.*\)".*/\1/' | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            ;;
        postgres)
            # 尝试 Postgres 或 PostgreSQL
            datasource=$(grep -A 20 "Postgres:" "$config_file" | grep "DataSource:" | sed 's/.*DataSource:[[:space:]]*"\(.*\)".*/\1/' | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if [ -z "$datasource" ]; then
                datasource=$(grep -A 20 "PostgreSQL:" "$config_file" | grep "DataSource:" | sed 's/.*DataSource:[[:space:]]*"\(.*\)".*/\1/' | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            fi
            ;;
        mongo)
            # 尝试 Mongo 或 MongoDB
            datasource=$(grep -A 20 "Mongo:" "$config_file" | grep "DataSource:" | sed 's/.*DataSource:[[:space:]]*"\(.*\)".*/\1/' | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if [ -z "$datasource" ]; then
                datasource=$(grep -A 20 "MongoDB:" "$config_file" | grep "DataSource:" | sed 's/.*DataSource:[[:space:]]*"\(.*\)".*/\1/' | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            fi
            ;;
    esac
    
    echo "$datasource"
}

# --------------------------------------------
# 获取数据库表列表（MySQL）
# --------------------------------------------
# 参数：
#   $1 - 主机地址
#   $2 - 端口
#   $3 - 用户名
#   $4 - 密码
#   $5 - 数据库名
# 返回：
#   表名列表（每行一个）
# --------------------------------------------
get_tables_mysql() {
    local host="$1"
    local port="$2"
    local user="$3"
    local password="$4"
    local database="$5"
    
    if [ -n "$password" ]; then
        mysql -h "$host" -P "$port" -u "$user" -p"$password" -D "$database" -e "SHOW TABLES;" 2>/dev/null | tail -n +2 | tr -d ' '
    else
        mysql -h "$host" -P "$port" -u "$user" -D "$database" -e "SHOW TABLES;" 2>/dev/null | tail -n +2 | tr -d ' '
    fi
}

# --------------------------------------------
# 获取数据库表列表（PostgreSQL）
# --------------------------------------------
get_tables_postgres() {
    local host="$1"
    local port="$2"
    local user="$3"
    local password="$4"
    local database="$5"
    
    # PostgreSQL 使用 psql 命令
    # 使用 PGPASSWORD 环境变量传递密码
    if [ -n "$password" ]; then
        PGPASSWORD="$password" psql -h "$host" -p "$port" -U "$user" -d "$database" -t -c "SELECT tablename FROM pg_tables WHERE schemaname='public';" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v "^$"
    else
        psql -h "$host" -p "$port" -U "$user" -d "$database" -t -c "SELECT tablename FROM pg_tables WHERE schemaname='public';" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v "^$"
    fi
}

# --------------------------------------------
# 获取数据库集合列表（MongoDB）
# --------------------------------------------
get_collections_mongo() {
    local datasource="$1"
    
    # MongoDB 使用 mongosh 或 mongo 命令
    # DataSource 格式: mongodb://user:password@host:port/database
    if command -v mongosh &> /dev/null; then
        mongosh "$datasource" --quiet --eval "db.getCollectionNames().join('\n')" 2>/dev/null
    elif command -v mongo &> /dev/null; then
        mongo "$datasource" --quiet --eval "db.getCollectionNames().join('\n')" 2>/dev/null
    else
        return 1
    fi
}

# --------------------------------------------
# 解析 DSN 信息（通用）
# --------------------------------------------
# 参数：
#   $1 - DataSource 连接字符串
#   $2 - 数据库类型
# 副作用：
#   设置全局变量 DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME
# --------------------------------------------
parse_dsn() {
    local datasource="$1"
    local db_type="$2"
    
    case "$db_type" in
        mysql)
            # MySQL DSN 格式: user:password@tcp(host:port)/database
            DB_USER=$(echo "$datasource" | sed -n 's/\([^:]*\):.*/\1/p')
            DB_PASSWORD=$(echo "$datasource" | sed -n 's/[^:]*:\([^@]*\)@.*/\1/p')
            DB_HOST=$(echo "$datasource" | sed -n 's/.*@tcp(\([^:]*\):.*/\1/p')
            DB_PORT=$(echo "$datasource" | sed -n 's/.*@tcp([^:]*:\([^)]*\)).*/\1/p')
            DB_NAME=$(echo "$datasource" | sed -n 's/.*\/\([^?]*\).*/\1/p')
            ;;
        postgres)
            # PostgreSQL DSN 格式: 
            # user:password@host:port/database 或
            # postgres://user:password@host:port/database
            datasource=$(echo "$datasource" | sed 's|^postgres://||; s|^postgresql://||')
            DB_USER=$(echo "$datasource" | sed -n 's/\([^:]*\):.*/\1/p')
            DB_PASSWORD=$(echo "$datasource" | sed -n 's/[^:]*:\([^@]*\)@.*/\1/p')
            DB_HOST=$(echo "$datasource" | sed -n 's/.*@\([^:]*\):.*/\1/p')
            DB_PORT=$(echo "$datasource" | sed -n 's/.*@[^:]*:\([^/]*\)\/.*/\1/p')
            DB_NAME=$(echo "$datasource" | sed -n 's/.*\/\([^?]*\).*/\1/p')
            ;;
        mongo)
            # MongoDB DSN 格式: mongodb://user:password@host:port/database
            # Mongo 通常直接使用 DataSource，不需要解析
            DB_USER=""
            DB_PASSWORD=""
            DB_HOST=""
            DB_PORT=""
            DB_NAME=$(echo "$datasource" | sed -n 's/.*\/\([^?]*\).*/\1/p')
            ;;
    esac
}

# --------------------------------------------
# 验证 DSN 格式是否正确
# --------------------------------------------
# 参数：
#   $1 - DataSource 连接字符串
#   $2 - 数据库类型
# 返回：
#   0 - 格式正确
#   1 - 格式错误
# --------------------------------------------
validate_dsn() {
    local datasource="$1"
    local db_type="$2"
    
    case "$db_type" in
        mysql)
            # MySQL DSN 必须包含: @tcp( 和 )/
            # 不应包含: ?charset 等参数（goctl 不支持）
            if [[ ! "$datasource" =~ @tcp\( ]] || [[ ! "$datasource" =~ \)/ ]]; then
                echo ""
                echo -e "${RED}✗${NC} MySQL DataSource 格式错误"
                log_detail "正确格式: user:password@tcp(host:port)/database"
                echo ""
                exit 1
            fi
            # 检查是否包含不支持的参数
            if [[ "$datasource" =~ \?charset ]] || [[ "$datasource" =~ \?parseTime ]] || [[ "$datasource" =~ \?loc ]]; then
                echo ""
                echo -e "${RED}✗${NC} MySQL DataSource 不应包含 URL 参数（如 ?charset, ?parseTime 等）"
                log_detail "goctl 工具不支持这些参数，请使用纯净的连接字符串"
                log_detail "正确格式: user:password@tcp(host:port)/database"
                echo ""
                exit 1
            fi
            ;;
        postgres)
            # PostgreSQL DSN 检查
            if [[ ! "$datasource" =~ / ]]; then
                echo ""
                echo -e "${RED}✗${NC} PostgreSQL DataSource 格式错误"
                log_detail "正确格式: postgres://user:password@host:port/database"
                echo ""
                exit 1
            fi
            ;;
        mongo)
            # MongoDB DSN 检查
            if [[ ! "$datasource" =~ ^mongodb:// ]]; then
                echo ""
                echo -e "${RED}✗${NC} MongoDB DataSource 格式错误"
                log_detail "正确格式: mongodb://user:password@host:port/database"
                echo ""
                exit 1
            fi
            ;;
    esac
    
    return 0
}

# ============================================
# 主程序开始
# ============================================

# 打印脚本标题
print_header "Go-Zero 数据模型生成工具"

# --------------------------------------------
# 步骤 1: 检查配置文件
# --------------------------------------------
log_step "检查配置文件..."

# 使用 -f 测试文件是否存在
# ! 表示取反，如果文件不存在则为 true
if [ ! -f "$CONFIG_FILE" ]; then
    log_error "配置文件不存在: $CONFIG_FILE"
fi

log_success "配置文件: $CONFIG_FILE"

# --------------------------------------------
# 步骤 2: 检测数据库类型
# --------------------------------------------
log_step "检测数据库类型..."

# 如果用户没有通过命令行指定数据库类型，则自动检测
if [ -z "$DB_TYPE" ]; then
    DB_TYPE=$(detect_database_type "$CONFIG_FILE")
    log_detail "自动检测到数据库类型: $DB_TYPE"
else
    log_detail "使用指定的数据库类型: $DB_TYPE"
fi

log_success "数据库类型: $DB_TYPE"

# --------------------------------------------
# 步骤 3: 从配置文件读取数据库连接信息
# --------------------------------------------
log_step "读取数据库配置..."

# 使用抽象函数读取 DataSource
DATASOURCE_URL=$(read_datasource "$CONFIG_FILE" "$DB_TYPE")

# 验证是否成功读取到 DataSource
if [ -z "$DATASOURCE_URL" ]; then
    log_error "无法从配置文件中读取 DataSource，请检查配置格式"
fi

# --------------------------------------------
# 步骤 4: 验证 DSN 格式
# --------------------------------------------
log_step "验证 DSN 格式..."

# 验证 DSN 格式是否正确（如果失败会自动退出）
validate_dsn "$DATASOURCE_URL" "$DB_TYPE"

log_success "DSN 格式验证通过"

# --------------------------------------------
# 步骤 5: 解析 DSN（数据源名称）
# --------------------------------------------
log_step "解析连接信息..."

# 使用抽象函数解析 DSN
parse_dsn "$DATASOURCE_URL" "$DB_TYPE"

# --------------------------------------------
# 步骤 6: 验证数据库连接信息的完整性
# --------------------------------------------
# MongoDB 只需验证数据库名
if [ "$DB_TYPE" = "mongo" ]; then
    if [ -z "$DB_NAME" ]; then
        log_error "数据库连接信息不完整，请检查 DataSource 格式"
    fi
    log_detail "数据库: $DB_NAME"
else
    # MySQL/PostgreSQL 需要验证完整信息
    if [ -z "$DB_HOST" ] || [ -z "$DB_PORT" ] || [ -z "$DB_NAME" ]; then
        log_error "数据库连接信息不完整，请检查 DataSource 格式"
    fi
    log_detail "数据库: ${DB_USER}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
fi

log_success "配置读取完成"

# --------------------------------------------
# 步骤 7: 显示配置摘要
# --------------------------------------------
echo ""
print_separator
log_info "配置摘要"
log_detail "数据库类型: $DB_TYPE"

if [ "$DB_TYPE" != "mongo" ]; then
    log_detail "数据库主机: $DB_HOST:$DB_PORT"
    log_detail "数据库名称: $DB_NAME"
    if [ -n "$DB_USER" ]; then
        log_detail "数据库用户: $DB_USER"
    fi
else
    log_detail "数据库名称: $DB_NAME"
fi

log_detail "输出目录: $OUTPUT_DIR"
log_detail "命名风格: $STYLE"

# 检查是否配置了跳过表
# ${#SKIP_TABLES[@]} 获取数组长度
# -n 检查第一个元素是否非空（排除空数组）
if [ ${#SKIP_TABLES[@]} -gt 0 ] && [ -n "${SKIP_TABLES[0]}" ]; then
    # ${SKIP_TABLES[*]} 将数组元素用空格连接成字符串
    log_detail "跳过的表: ${SKIP_TABLES[*]}"
fi

# 如果是预览模式，显示提示
if [ "$DRY_RUN" = true ]; then
    log_warning "运行模式: 预览模式 (不会实际生成文件)"
fi

print_separator
echo ""

# --------------------------------------------
# 步骤 8: 检查必需的命令行工具
# --------------------------------------------

# 8.1 检查数据库客户端
log_step "检查数据库客户端..."

case "$DB_TYPE" in
    mysql)
        if ! command -v mysql &> /dev/null; then
            log_error "未找到 mysql 命令，请先安装 MySQL 客户端"
        fi
        log_success "MySQL 客户端已安装"
        ;;
    postgres)
        if ! command -v psql &> /dev/null; then
            log_error "未找到 psql 命令，请先安装 PostgreSQL 客户端"
        fi
        log_success "PostgreSQL 客户端已安装"
        ;;
    mongo)
        if ! command -v mongosh &> /dev/null && ! command -v mongo &> /dev/null; then
            log_error "未找到 mongosh 或 mongo 命令，请先安装 MongoDB 客户端"
        fi
        if command -v mongosh &> /dev/null; then
            log_success "MongoDB Shell (mongosh) 已安装"
        else
            log_success "MongoDB Shell (mongo) 已安装"
        fi
        ;;
esac

# 8.2 检查 goctl 工具
log_step "检查 goctl 工具..."

if ! command -v goctl &> /dev/null; then
    log_error "未找到 goctl 命令，请先安装 go-zero 工具链"
fi

# 获取 goctl 版本信息
GOCTL_VERSION=$(goctl --version 2>&1 | head -n 1)
log_success "goctl 已安装 (${GOCTL_VERSION})"

# --------------------------------------------
# 步骤 9: 连接数据库并获取表列表
# --------------------------------------------
log_step "连接数据库并获取表/集合列表..."

# 使用抽象函数获取表列表
case "$DB_TYPE" in
    mysql)
        TABLES=$(get_tables_mysql "$DB_HOST" "$DB_PORT" "$DB_USER" "$DB_PASSWORD" "$DB_NAME") || log_error "无法连接到 MySQL 数据库，请检查连接信息和权限"
        ;;
    postgres)
        TABLES=$(get_tables_postgres "$DB_HOST" "$DB_PORT" "$DB_USER" "$DB_PASSWORD" "$DB_NAME") || log_error "无法连接到 PostgreSQL 数据库，请检查连接信息和权限"
        ;;
    mongo)
        TABLES=$(get_collections_mongo "$DATASOURCE_URL") || log_error "无法连接到 MongoDB 数据库，请检查连接信息和权限"
        ;;
esac

# 检查是否获取到表
if [ -z "$TABLES" ]; then
    if [ "$DB_TYPE" = "mongo" ]; then
        log_error "数据库中没有找到任何集合"
    else
        log_error "数据库中没有找到任何表"
    fi
fi

# 统计表的数量
TABLE_COUNT=$(echo "$TABLES" | wc -l | tr -d ' ')
if [ "$DB_TYPE" = "mongo" ]; then
    log_success "找到 $TABLE_COUNT 个集合"
else
    log_success "找到 $TABLE_COUNT 个数据库表"
fi

# --------------------------------------------
# 步骤 10: 过滤表（排除跳过列表中的表）
# --------------------------------------------

# 初始化变量
FILTERED_TABLES=""  # 存储最终要生成的表名列表（逗号分隔）
SKIP_COUNT=0        # 记录跳过的表数量

# 遍历所有表名
for table in $TABLES; do
    # 清理表名中的空格（防御性编程）
    table=$(echo "$table" | tr -d ' ')
    skip=false
    
    # 检查当前表是否在跳过列表中
    for skip_table in "${SKIP_TABLES[@]}"; do
        if [ "$table" = "$skip_table" ]; then
            # 找到匹配，标记为跳过
            skip=true
            SKIP_COUNT=$((SKIP_COUNT + 1))
            log_detail "跳过表: $table"
            break  # 跳出内层循环
        fi
    done
    
    # 如果不跳过，添加到生成列表
    if [ "$skip" = false ]; then
        if [ -z "$FILTERED_TABLES" ]; then
            # 第一个表：直接赋值
            FILTERED_TABLES="$table"
        else
            # 后续表：追加（用逗号分隔）
            FILTERED_TABLES="$FILTERED_TABLES,$table"
        fi
    fi
done

# --------------------------------------------
# 步骤 11: 处理命令行指定的表
# --------------------------------------------
# 如果用户通过 -t 或位置参数指定了表名，覆盖自动扫描的结果
if [ -n "$SPECIFIED_TABLES" ]; then
    FILTERED_TABLES="$SPECIFIED_TABLES"
    log_info "使用命令行指定的表: $FILTERED_TABLES"
fi

# 最终检查：确保至少有一个表要生成
if [ -z "$FILTERED_TABLES" ]; then
    log_error "没有可生成的表"
fi

# --------------------------------------------
# 步骤 12: 显示将要生成的表列表
# --------------------------------------------
echo ""
print_separator

# 将逗号分隔的表名转换为按行分隔（便于逐行处理）
TABLE_LIST=$(echo "$FILTERED_TABLES" | tr ',' '\n')

# 统计最终要生成的表数量
TABLE_COUNT_FILTERED=$(echo "$TABLE_LIST" | wc -l | tr -d ' ')

# 显示统计信息
if [ $SKIP_COUNT -gt 0 ]; then
    log_info "将生成 ${TABLE_COUNT_FILTERED} 个表的模型 (跳过了 ${SKIP_COUNT} 个表)"
else
    log_info "将生成 ${TABLE_COUNT_FILTERED} 个表的模型"
fi

# 显示表清单（带序号）
echo ""
INDEX=1
while IFS= read -r table; do
    # IFS= 防止 read 去除前导/尾随空格
    # -r 禁用反斜杠转义
    echo -e "${GRAY}  [$INDEX]${NC} ${WHITE}$table${NC}"
    INDEX=$((INDEX + 1))
done <<< "$TABLE_LIST"  # <<< 是 here-string，将变量内容作为标准输入

print_separator
echo ""

# --------------------------------------------
# 步骤 13: 预览模式处理
# --------------------------------------------
# 如果启用了预览模式，到此为止，不执行实际生成
if [ "$DRY_RUN" = true ]; then
    log_info "预览模式完成，未生成任何文件"
    exit 0
fi

# --------------------------------------------
# 步骤 14: 执行模型生成
# --------------------------------------------
log_step "开始生成模型文件..."

# 短暂暂停，让用户看到提示信息
sleep 0.5

# 记录开始时间（用于计算耗时）
START_TIME=$(date +%s)

# 根据数据库类型执行不同的 goctl 命令
case "$DB_TYPE" in
    mysql)
        # MySQL 使用 goctl model mysql datasource
        GOCTL_CMD="goctl model mysql datasource --url \"$DATASOURCE_URL\" --table \"$FILTERED_TABLES\" --dir \"$OUTPUT_DIR\" --cache --style \"$STYLE\""
        ;;
    postgres)
        # PostgreSQL 使用 goctl model pg datasource
        GOCTL_CMD="goctl model pg datasource --url \"$DATASOURCE_URL\" --table \"$FILTERED_TABLES\" --dir \"$OUTPUT_DIR\" --cache --style \"$STYLE\""
        ;;
    mongo)
        # MongoDB 使用 goctl model mongo（语法略有不同）
        # MongoDB 使用 -t 而不是 --table，使用 -c 而不是 --cache
        GOCTL_CMD="goctl model mongo -t \"$FILTERED_TABLES\" -d \"$OUTPUT_DIR\" --style \"$STYLE\""
        # 注意：MongoDB 模型生成不需要 --url 参数，会自动从类型定义生成
        log_warning "MongoDB 模型生成需要预先定义类型，请参考 go-zero 文档"
        ;;
esac

# 执行生成命令并捕获输出
# 注意：需要正确处理管道的退出状态
eval "$GOCTL_CMD" 2>&1 | tee /tmp/goctl_output.log | grep -v "^$" | while IFS= read -r line; do
    # 过滤掉 goctl 的版本迁移提示信息
    if [[ ! "$line" =~ It\ seems\ like\ that\ your\ goctl ]] && \
       [[ ! "$line" =~ back\ up\ the\ original ]] && \
       [[ ! "$line" =~ re-run\ the\ generate ]] && \
       [[ ! "$line" =~ populate ]]; then
        log_detail "$line"
    fi
done

# 检查管道中第一个命令（goctl）的退出状态
# 使用 PIPESTATUS[0] 获取管道第一个命令的返回码
GOCTL_EXIT_CODE=${PIPESTATUS[0]}

# 同时检查输出日志中是否包含错误关键字
if grep -qi "error\|failed\|invalid DSN\|cannot connect" /tmp/goctl_output.log 2>/dev/null; then
    GOCTL_EXIT_CODE=1
fi

# 判断是否执行成功
if [ $GOCTL_EXIT_CODE -eq 0 ]; then
    
    # ========================================
    # 生成成功
    # ========================================
    
    # 计算耗时
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    echo ""
    print_separator
    log_success "模型生成完成！"
    log_detail "耗时: ${DURATION}s"
    log_detail "输出: $OUTPUT_DIR"
    print_separator
    echo ""
    
    # 显示生成的文件列表
    log_info "生成的文件:"
    
    if [ -d "$OUTPUT_DIR" ]; then
        # 创建时间戳文件用于查找新生成的文件
        # 注意：如果时间戳文件不存在，find 命令会失败，但不影响脚本执行
        # 因此使用 || 提供备用方案：显示所有 .go 文件
        find "$OUTPUT_DIR" -type f -name "*.go" -newer /tmp/goctl_timestamp 2>/dev/null || \
        find "$OUTPUT_DIR" -type f -name "*.go" | while IFS= read -r file; do
            # 获取文件大小（人类可读格式，如 1.2K, 3.4M）
            # du -h 以人类可读格式显示
            # cut -f1 提取第一列（大小）
            FILE_SIZE=$(du -h "$file" | cut -f1)
            
            # 提取文件名（不含路径）
            FILE_NAME=$(basename "$file")
            
            # 显示文件信息
            log_detail "📄 $FILE_NAME ($FILE_SIZE)"
        done
    fi
    
    echo ""
    log_success "全部完成！"
    
    # ========================================
    # 显示温馨提示
    # ========================================
    echo ""
    echo -e "${CYAN}💡 提示:${NC}"
    log_detail "• *_gen.go 文件是自动生成的，请勿手动修改"
    log_detail "• 可以在 *model.go 文件中添加自定义方法"
    log_detail "• 如需重新生成，请先备份自定义代码"
    echo ""
    
else
    # ========================================
    # 生成失败
    # ========================================
    echo ""
    print_separator
    echo -e "${RED}✗${NC} 模型生成失败！"
    log_detail "退出码: $GOCTL_EXIT_CODE"
    echo ""
    
    # 显示详细错误信息
    if [ -f /tmp/goctl_output.log ]; then
        log_warning "完整错误日志:"
        echo ""
        # 只显示包含错误的行
        grep -i "error\|failed\|invalid\|cannot" /tmp/goctl_output.log 2>/dev/null | while IFS= read -r line; do
            echo -e "  ${RED}${line}${NC}"
        done
        echo ""
    fi
    
    # 根据不同的数据库类型给出针对性建议
    case "$DB_TYPE" in
        mysql)
            log_warning "MySQL 常见问题排查:"
            log_detail "1. 检查 DataSource 格式: user:password@tcp(host:port)/database"
            log_detail "2. 确认不包含额外参数（如 ?charset=utf8mb4）"
            log_detail "3. 检查特殊字符是否需要转义（密码中的 @, #, / 等）"
            ;;
        postgres)
            log_warning "PostgreSQL 常见问题排查:"
            log_detail "1. 检查 DataSource 格式: postgres://user:password@host:port/database"
            log_detail "2. 确认 goctl 支持 PostgreSQL (某些版本可能不支持)"
            ;;
        mongo)
            log_warning "MongoDB 常见问题排查:"
            log_detail "1. 检查 DataSource 格式: mongodb://user:password@host:port/database"
            log_detail "2. 确认已安装 MongoDB 支持"
            log_detail "3. MongoDB 模型生成需要预先定义类型"
            ;;
    esac
    
    echo ""
    print_separator
    echo ""
    exit 1
fi
