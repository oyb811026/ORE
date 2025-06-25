#!/bin/zsh

# ===== 配置区域 =====
REQUIRED_VERSION="0.8.10"   # 最低要求的版本
MAX_RESTART_DELAY=7200      # 最大重启延迟（秒）
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

    === Nexus 自动化工具 (macOS 优化版) ===
\033[33m
** ====================================== **
*         此脚本仅供免费使用              *
*         禁止出售或用于盈利              *
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

# 验证节点ID
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
    
    # 验证长度 (假设有效ID在6-7位)
    if [[ ${#id} -lt 6 || ${#id} -gt 7 ]]; then
        echo "⚠️ 警告：节点ID长度异常 (${#id}位)，请确认是否正确"
        read -p "是否继续？(y/n): " choice
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
}

# 节点监控循环
node_monitor() {
    local node_id="$1"
    local session_name="nexus_${node_id}"
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

# 主函数
main() {
    print_banner
    
    # 检查依赖
    install_dependencies
    
    # 显示系统资源
    system_resources
    
    # 获取节点ID
    echo ""
    echo "请输入您的节点ID（纯数字，如：7366937）:"
    while true; do
        read -p "节点ID: " NODE_ID
        NODE_ID=$(echo "$NODE_ID" | tr -d '[:space:]')
        
        if validate_node_id "$NODE_ID"; then
            break
        else
            echo "请重新输入有效的节点ID"
        fi
    done
    
    echo "✅ 节点ID验证通过: $NODE_ID"
    
    # 会话名称
    SESSION_NAME="nexus_${NODE_ID}"
    
    # 检查现有会话
    if screen -list | grep -q "$SESSION_NAME"; then
        echo "\n发现已存在的会话: $SESSION_NAME"
        echo "1. 连接到现有会话"
        echo "2. 重启会话"
        echo "3. 查看会话状态"
        read -p "请选择操作 [1-3]: " choice
        
        case $choice in
            1)
                echo "连接到现有会话..."
                screen -r "$SESSION_NAME"
                exit 0
                ;;
            2)
                echo "重启会话..."
                screen -S "$SESSION_NAME" -X quit 2>/dev/null || true
                sleep 2
                ;;
            3)
                screen -S "$SESSION_NAME" -X hardcopy /tmp/screen_dump
                echo "\n=== 会话最后输出 ==="
                tail -n 20 /tmp/screen_dump
                rm /tmp/screen_dump
                echo "===================="
                exit 0
                ;;
            *)
                echo "终止现有会话并创建新会话..."
                screen -S "$SESSION_NAME" -X quit 2>/dev/null || true
                ;;
        esac
    fi
    
    # 创建screen会话
    echo "\n启动节点: $NODE_ID"
    echo "Screen会话名称: $SESSION_NAME"
    
    # 在screen会话中运行监控
    screen -dmS "$SESSION_NAME" zsh -c "
        echo '=== Nexus 节点监控 ==='
        echo '节点ID: $NODE_ID'
        echo '会话名称: $SESSION_NAME'
        echo '主机名: $(hostname)'
        echo '开始时间: $(date)'
        echo ''
        
        # 设置退出时清理
        trap 'echo \"\n\033[31m会话终止，清理中...\033[0m\"; pkill -f \"nexus-network start --node-id $NODE_ID\"; exit 0' EXIT
        
        $(declare -f node_monitor)
        node_monitor \"$NODE_ID\"
    "
    
    # 用户指南
    echo "\n\033[32m✅ 节点已在Screen会话中启动！\033[0m"
    echo "\n\033[34m📋 常用命令：\033[0m"
    echo "• 查看会话列表:    screen -list"
    echo "• 连接到会话:      screen -r $SESSION_NAME"
    echo "• 分离会话:        按 Ctrl+A 然后按 D"
    echo "• 停止节点:        screen -S $SESSION_NAME -X quit"
    echo "• 查看节点状态:    $0 --status"
    echo "\n\033[33m🌐 现在您可以安全地关闭终端，节点会继续运行！\033[0m"
}

# 启动主函数
main "$@"
