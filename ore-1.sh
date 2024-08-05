#!/bin/bash

# 检查是否以root用户运行脚本
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要以root用户权限运行。"
    echo "请尝试使用 'sudo -i' 命令切换到root用户，然后再次运行此脚本。"
    exit 1
fi

# 安装 Node.js 和必要的工具
function install_node() {
    # 更新系统和安装必要的包
    echo "更新系统软件包..."
    brew update && brew upgrade
    echo "安装必要的工具和依赖..."
    brew install curl jq git openssl pkg-config screen

    # 安装 Rust 和 Cargo
    echo "正在安装 Rust 和 Cargo..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source $HOME/.cargo/env

    # 安装 Solana CLI
    echo "正在安装 Solana CLI..."
    sh -c "$(curl -sSfL https://release.solana.com/v1.18.4/install)"

    # 检查 solana-keygen 是否在 PATH 中
    if ! command -v solana-keygen &> /dev/null; then
        echo "将 Solana CLI 添加到 PATH"
        export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
        export PATH="$HOME/.cargo/bin:$PATH"
    fi

    # 创建 Solana 密钥对
    echo "正在创建 Solana 密钥对..."
    solana-keygen new --derivation-path m/44'/501'/0'/0' --force | tee solana-keygen-output.txt

    # 显示提示信息，要求用户确认已备份
    echo "请确保你已经备份了上面显示的助记词和私钥信息。"
    echo "请向pubkey充值sol资产，用于挖矿gas费用。"

    echo "备份完成后，请输入 'yes' 继续："

    read -p "" user_confirmation

    if [[ "$user_confirmation" == "yes" ]]; then
        echo "确认备份。继续执行脚本..."
    else
        echo "脚本终止。请确保备份你的信息后再运行脚本。"
        exit 1
    fi

    # 安装 Ore CLI
    echo "正在安装 Ore CLI..."
    cargo install ore-cli

    # 更新 .bash_profile 或 .zshrc，以确保 PATH 设置生效
    echo 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"' >> ~/.bash_profile
    echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bash_profile

    # 使改动生效
    source ~/.bash_profile

    # 获取用户输入的 RPC 地址或使用默认地址
    read -p "请输入自定义的 RPC 地址，建议使用免费的Quicknode 或者alchemy SOL rpc(默认设置使用 https://api.mainnet-beta.solana.com): " custom_rpc
    RPC_URL=${custom_rpc:-https://api.mainnet-beta.solana.com}

    # 获取用户输入的线程数或使用默认值
    read -p "请输入挖矿时要使用的线程数 (默认设置 1): " custom_threads
    THREADS=${custom_threads:-1}

    # 获取用户输入的优先费用或使用默认值
    read -p "请输入交易的优先费用 (默认设置 1): " custom_priority_fee
    PRIORITY_FEE=${custom_priority_fee:-1}

    # 使用 screen 和 Ore CLI 开始挖矿
    session_name="ore"
    echo "开始挖矿，会话名称为 $session_name ..."

    start="while true; do ore --rpc $RPC_URL --keypair ~/.config/solana/id.json --priority-fee $PRIORITY_FEE mine --threads $THREADS; echo '进程异常退出，等待重启' >&2; sleep 1; done"
    screen -dmS "$session_name" bash -c "$start"

    echo "挖矿进程已在名为 $session_name 的 screen 会话中后台启动。"
    echo "使用 'screen -r $session_name' 命令重新连接到此会话。"
}

# 恢复钱包并开始挖矿
function export_wallet() {
    echo "更新系统软件包..."
    brew update && brew upgrade
    echo "安装必要的工具和依赖..."
    brew install curl jq git openssl pkg-config screen

    echo "正在恢复Solana钱包..."
    echo "下方请粘贴/输入你的助记词，用空格分隔，盲文不会显示的"

    # 使用助记词恢复钱包
    solana-keygen recover 'prompt:?key=0/0' --force

    echo "钱包已恢复。"
    echo "请确保你的钱包地址已经充足的 SOL 用于交易费用。"

    # 更新 .bash_profile 或 .zshrc
    echo 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"' >> ~/.bash_profile
    echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bash_profile

    source ~/.bash_profile

    read -p "请输入自定义的 RPC 地址，建议使用免费的Quicknode 或者alchemy SOL rpc(默认设置使用 https://api.mainnet-beta.solana.com): " custom_rpc
    RPC_URL=${custom_rpc:-https://api.mainnet-beta.solana.com}

    read -p "请输入挖矿时要使用的线程数 (默认设置 1): " custom_threads
    THREADS=${custom_threads:-1}

    read -p "请输入交易的优先费用 (默认设置 1): " custom_priority_fee
    PRIORITY_FEE=${custom_priority_fee:-1}

    session_name="ore"
    echo "开始挖矿，会话名称为 $session_name ..."

    start="while true; do ore --rpc $RPC_URL --keypair ~/.config/solana/id.json --priority-fee $PRIORITY_FEE mine --threads $THREADS; echo '进程异常退出，等待重启' >&2; sleep 1; done"
    screen -dmS "$session_name" bash -c "$start"

    echo "挖矿进程已在名为 $session_name 的 screen 会话中后台启动。"
    echo "使用 'screen -r $session_name' 命令重新连接到此会话。"
}

# 杀死screen会话的函数
function kill_screen_session() {
    local session_name="Quili"
    if screen -list | grep -q "$session_name"; then
        echo "找到以下screen会话："
        screen -list | grep "$session_name"
        
        read -p "请输入要杀死的会话ID（例如11687）: " session_id
        if [[ -n "$session_id" ]]; then
            echo "正在杀死screen会话 '$session_id'..."
            screen -S "$session_id" -X quit || echo "杀死会话失败"
            echo "Screen会话 '$session_id' 已被杀死."
        else
            echo "无效的会话ID。"
        fi
    else
        echo "没有找到名为 '$session_name' 的screen会话."
    fi
}

# 主菜单
function main_menu() {
    while true; do
        clear
        echo "退出脚本，请按键盘ctrl c退出即可"
        echo "请选择要执行的操作:"
        echo "1. 安装新节点"
        echo "2. 导入钱包运行"
        echo "3. 单独启动运行"
        echo "4. 查看挖矿收益"
        echo "5. 领取挖矿收益"
        echo "6. 查看节点运行情况"
        echo "7. 单机多开钱包（需要提供私钥）"
        echo "8. 单机多开钱包（不检查环境）"
        echo "9. 单机多开钱包，查看奖励"
        echo "10. 单机多开钱包，领取奖励（自动轮询）"
        echo "11. 多开监控，自动读取配置文件"
        echo "12. 算力测试"
        echo "13. 杀死screen会话"
        
        
        read -p "请输入选项（1-12）: " OPTION

        case $OPTION in
        1) install_node ;;
        2) export_wallet ;;
        3) start ;;
        4) view_rewards ;;
        5) claim_rewards ;;
        6) check_logs ;;
        7) multiple ;;
        8) lonely ;; 
        9) check_multiple ;;
        10) cliam_multiple ;; 
        11) rerun_rpc ;; 
        12) benchmark ;;
        13) kill_screen_session ;;
        esac
        echo "按任意键返回主菜单..."
        read -n 1
    done
}

# 显示主菜单
main_menu
