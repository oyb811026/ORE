#!/bin/zsh

# ===== 配置区域 =====
REQUIRED_VERSION="0.8.10"   # 最低要求的版本
MAX_RESTART_DELAY=300      # 最大重启延迟（秒）
MIN_RESTART_DELAY=300       # 最小重启延迟（秒）
# ===================

# 显示banner
print_banner() {
    echo "
\033[34m
██████╗ ███████╗██╗  ██╗██╗   ██╗███████╗
██╔══██╗██╔════╝╚██╗██╔╝██║   ██║██╔════╝
██████╔╝█████╗   ╚███╔╝ ██║   ██║███████╗
██╔══██╗██╔══╝   ██╔██╗ ██║   ██║╚════██║
██║  ██║███████╗██╔╝ ██╗╚██████╔╝███████║
╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝
\033[0m

    === Nexus 多节点管理工具 (macOS 版) ===
\033[33m
** ====================================== **
*         支持同时运行多个节点ID          *
*         每个ID使用独立screen会话        *
** ====================================== **

* 作者: @YOYOMYOYOA
* 空投玩家 | 现货玩家 | meme收藏
* Github: github.com/mumumusf

** ====================================== **
*            免责声明                      *
* 此脚本仅供学习交流使用                  *
* 使用本脚本所产生的任何后果由用户自行承担 *
* 如果因使用本脚本造成任何损失，作者概不负责*
** ====================================== **
\033[0m
"
}

# 检查并安装依赖
install_dependencies() {
    # 检查是否安装了 screen
    if ! command -v screen &> /dev/null; then
        echo "正在安装 screen..."
        if ! command -v brew &> /dev/null; then
            echo "正在安装 Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
            source ~/.zshrc
        fi
        brew install screen
        echo "✅ screen 安装完成！"
    fi
    
    # 检查是否安装了 nexus-network
    if ! command -v nexus-network &> /dev/null; then
        echo "正在安装 nexus-cli..."
        curl -fL https://cli.nexus.xyz/ | sh
        source ~/.zshrc
        echo "✅ nexus-network 安装完成！"
    fi
    
    # 验证版本
    INSTALLED_VERSION=$(nexus-network --version 2>&1 | awk '{print $NF}')
    if [[ "$(printf '%s\n' "$REQUIRED_VERSION" "$INSTALLED_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]]; then
        echo "❌ 错误：需要 nexus-network 版本 $REQUIRED_VERSION 或更高，当前版本 $INSTALLED_VERSION"
        echo "请手动升级：curl https://cli.nexus.xyz/ | sh"
        exit 1
    fi
}

# 验证节点ID - 修复了多节点输入问题
validate_node_id() {
    local id="$1"
    
    # 验证是否为空
    if [[ -z "$id" ]]; then
        echo "❌ 错误：节点ID不能为空"
        return 1
    fi
    
    # 验证是否只包含数字
    if ! [[ "$id" =~ ^[0-9]+$ ]]; then
        echo "❌ 错误：节点ID应该只包含数字"
        return 1
    fi
    
    # 验证长度
    if [[ ${#id} -lt 6 || ${#id} -gt 8 ]]; then
        echo "⚠️ 警告：节点ID '${id}' 长度异常 (${#id}位)，请确认是否正确"
        echo -n "是否继续？(y/n): "
        read choice
        if [[ $choice != "y" && $choice != "Y" ]]; then
            return 1
        fi
    fi
    
    return 0
}

# 获取系统资源信息
system_resources() {
    echo "\n\033[36m=== 系统资源状态 ===\033[0m"
    echo "CPU 使用率: $(top -l 1 | grep -E "^CPU" | awk '{print $3 + $5}')%"
    echo "内存使用: $(top -l 1 -s 0 | grep PhysMem | awk '{print $2 " used, " $6 " free"}')"
    echo "磁盘空间: $(df -h / | tail -1 | awk '{print $4 " free of " $2}')"
    
    # 检查节点进程
    local node_count=$(pgrep -f "nexus-network start --node-id" | wc -l | tr -d ' ')
    echo "运行中的节点: ${node_count}个"
}

# 节点监控循环
node_monitor() {
    local node_id="$1"
    local restart_delay=$MIN_RESTART_DELAY
    
    while true; do
        # 清理可能存在的僵尸进程
        pkill -f "nexus-network start --node-id ${node_id}" || true
        
        # 启动节点
        echo "\n\033[32m[$(date '+%Y-%m-%d %H:%M:%S')] 启动节点 ${node_id}...\033[0m"
        nexus-network start --node-id "${node_id}"
        local exit_code=$?
        
        # 记录退出原因
        echo "\033[31m[$(date '+%Y-%m-%d %H:%M:%S')] 节点 ${node_id} 已停止 (退出码: ${exit_code})\033[0m"
        
        # 动态调整重启延迟
        if [[ $exit_code -eq 0 ]]; then
            echo "正常退出，将在 ${restart_delay} 秒后重启..."
        else
            echo "异常退出，缩短重启等待时间..."
            restart_delay=$((restart_delay > MIN_RESTART_DELAY ? restart_delay / 2 : MIN_RESTART_DELAY))
        fi
        
        # 显示倒计时
        echo "等待重启:"
        for ((i=restart_delay; i>0; i--)); do
            printf "\r%02d:%02d " $((i/60)) $((i%60))
            sleep 1
        done
        echo
        
        # 重置延迟（逐步增加）
        restart_delay=$((restart_delay * 2))
        if [[ $restart_delay -gt $MAX_RESTART_DELAY ]]; then
            restart_delay=$MAX_RESTART_DELAY
        fi
    done
}

# 显示节点状态
show_node_status() {
    local nodes=(${(@s: :)1})
    
    echo "\n\033[36m=== 节点状态概览 ===\033[0m"
    echo "节点ID     状态     会话名称"
    echo "--------------------------------"
    
    for node_id in "${nodes[@]}"; do
        local session_name="nexus_${node_id}"
        local status="\033[31m停止\033[0m"
        
        # 检查会话是否存在
        if screen -list | grep -q "$session_name"; then
            status="\033[32m运行中\033[0m"
        fi
        
        echo "${node_id}   ${status}   ${session_name}"
    done
    
    echo "--------------------------------"
    echo "使用 'screen -r <会话名称>' 连接节点"
}

# 启动所有节点
start_all_nodes() {
    local nodes=(${(@s: :)1})
    
    for node_id in "${nodes[@]}"; do
        local session_name="nexus_${node_id}"
        
        # 如果会话已存在，跳过
        if screen -list | grep -q "$session_name"; then
            echo "节点 ${node_id} 已在运行 (会话: ${session_name})"
            continue
        fi
        
        # 创建新会话
        screen -dmS "$session_name" zsh -c "
            echo '=== Nexus 节点 ${node_id} 启动 ==='
            echo '开始时间: $(date)'
            
            # 设置退出时清理
            trap 'echo \"\n\033[31m节点 ${node_id} 终止，清理中...\033[0m\"; pkill -f \"nexus-network start --node-id ${node_id}\"; exit 0' EXIT
            
            $(declare -f node_monitor)
            node_monitor \"$node_id\"
        "
        
        echo "✅ 节点 ${node_id} 已启动 (会话: ${session_name})"
    done
}

# 停止所有节点
stop_all_nodes() {
    local nodes=(${(@s: :)1})
    
    for node_id in "${nodes[@]}"; do
        local session_name="nexus_${node_id}"
        
        if screen -list | grep -q "$session_name"; then
            screen -S "$session_name" -X quit 2>/dev/null
            echo "✅ 已停止节点 ${node_id} (会话: ${session_name})"
        else
            echo "⚠️ 节点 ${node_id} 未运行"
        fi
        
        # 确保进程被终止
        pkill -f "nexus-network start --node-id ${node_id}" 2>/dev/null || true
    done
}

# 主函数 - 修复了多节点输入处理
main() {
    print_banner
    
    # 检查依赖
    install_dependencies
    
    # 显示系统资源
    system_resources
    
    # 获取节点ID列表
    while true; do
        echo ""
        echo "请输入您的节点ID（多个ID用空格分隔，如：6723995 6514134 7354621）:"
        echo -n "节点ID列表: "
        read NODE_IDS
        
        # 清理输入：移除前后空格，将多个空格压缩为单个空格
        NODE_IDS=$(echo "$NODE_IDS" | tr -s ' ' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        
        # 验证每个ID
        local valid=1
        local nodes=()
        
        if [[ -z "$NODE_IDS" ]]; then
            echo "❌ 错误：节点ID列表不能为空"
            continue
        fi
        
        # 分割为单独的ID
        for node_id in ${(s: :)NODE_IDS}; do
            # 移除每个ID周围的空格
            node_id=$(echo "$node_id" | tr -d '[:space:]')
            
            if [[ -z "$node_id" ]]; then
                continue
            fi
            
            if ! validate_node_id "$node_id"; then
                valid=0
                break
            fi
            
            nodes+=("$node_id")
        done
        
        if [[ $valid -eq 1 && ${#nodes[@]} -gt 0 ]]; then
            NODE_IDS="${nodes[@]}"
            break
        else
            echo "请重新输入有效的节点ID列表"
        fi
    done
    
    # 转换为数组
    local nodes=(${(@s: :)NODE_IDS})
    
    echo "\n✅ 节点ID验证通过:"
    for node_id in "${nodes[@]}"; do
        echo " - ${node_id}"
    done
    
    # 显示管理菜单
    while true; do
        echo "\n\033[34m=== Nexus 多节点管理 ===\033[0m"
        echo "1. 启动所有节点"
        echo "2. 停止所有节点"
        echo "3. 查看节点状态"
        echo "4. 连接到特定节点会话"
        echo "5. 添加新节点"
        echo "6. 退出"
        echo -n "请选择操作 [1-6]: "
        read choice
        
        case $choice in
            1)
                echo "\n启动所有节点..."
                start_all_nodes "$NODE_IDS"
                ;;
            2)
                echo "\n停止所有节点..."
                stop_all_nodes "$NODE_IDS"
                ;;
            3)
                show_node_status "$NODE_IDS"
                ;;
            4)
                echo "\n可连接的会话:"
                screen -list | grep "nexus_"
                echo -n "输入要连接的会话名称: "
                read session_name
                if [[ -n "$session_name" ]]; then
                    screen -r "$session_name"
                else
                    echo "无效的会话名称"
                fi
                ;;
            5)
                echo -n "输入要添加的新节点ID: "
                read new_id
                new_id=$(echo "$new_id" | tr -d '[:space:]')
                if validate_node_id "$new_id"; then
                    nodes+=("$new_id")
                    NODE_IDS="${nodes[@]}"
                    echo "✅ 节点 ${new_id} 已添加"
                fi
                ;;
            6)
                echo "退出管理程序"
                exit 0
                ;;
            *)
                echo "无效选择"
                ;;
        esac
    done
}

# 启动主函数
main "$@"
