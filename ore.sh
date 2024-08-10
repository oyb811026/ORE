#!/bin/bash

# 检查是否以root用户运行脚本
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要以root用户权限运行。"
    echo "请尝试使用 'sudo -i' 命令切换到root用户，然后再次运行此脚本。"
    exit 1
fi

function check_and_install_dependencies() {
    # 检查是否已安装 Rust 和 Cargo
    if ! command -v cargo &> /dev/null; then
        echo "Rust 和 Cargo 未安装，正在安装..."
        curl https://sh.rustup.rs -sSf | sh -s -- -y
        source $HOME/.cargo/env
    else
        echo "Rust 和 Cargo 已安装。"
    fi

    # 检查是否已安装 Solana CLI
    if ! command -v solana-keygen &> /dev/null; then
        echo "Solana CLI 未安装，正在安装..."
        sh -c "$(curl -sSfL https://release.solana.com/v1.18.4/install)"
    else
        echo "Solana CLI 已安装。"
    fi

    # 检查是否已安装 Ore CLI
    if ! command -v ore &> /dev/null; then
        echo "Ore CLI 未安装，正在安装..."
        cargo install ore-cli
    else
        echo "Ore CLI 已安装。"
    fi

    export PATH="$HOME/.local/share/solana/install/active_release/bin:$HOME/.cargo/bin:$PATH"
}

function add_to_bashrc() {
    grep -qxF "$1" ~/.bashrc || echo "$1" >> ~/.bashrc
}

function prompt_for_rpc() {
    read -p "请输入自定义的 RPC 地址 (默认 https://api.mainnet-beta.solana.com): " custom_rpc
    echo ${custom_rpc:-https://api.mainnet-beta.solana.com}
}

function prompt_for_priority_fee() {
    read -p "请输入交易的优先费用 (默认 1): " custom_priority_fee
    echo ${custom_priority_fee:-1}
}

function prompt_for_cores() {
    read -p "请输入要使用的核心数量 (默认 1): " custom_cores
    echo ${custom_cores:-1}
}

function install_node() {
    echo "更新系统软件包..."
    sudo apt update && sudo apt upgrade -y
    echo "安装必要的工具和依赖..."
    sudo apt install -y curl build-essential jq git libssl-dev pkg-config screen

    check_and_install_dependencies

    # 创建 Solana 密钥对
    echo "正在创建 Solana 密钥对..."
    solana-keygen new --derivation-path m/44'/501'/0'/0' --force | tee solana-keygen-output.txt

    echo "请确保你已经备份了上面显示的助记词和私钥信息。"
    echo "请向pubkey充值sol资产，用于挖矿gas费用。"
    echo "备份完成后，请输入 'yes' 继续："
    read -p "" user_confirmation

    if [[ "$user_confirmation" != "yes" ]]; then
        echo "脚本终止。请确保备份你的信息后再运行脚本。"
        exit 1
    fi

    # 检查并将Solana的路径添加到 .bashrc
    add_to_bashrc 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"'
    add_to_bashrc 'export PATH="$HOME/.cargo/bin:$PATH"'

    # 使改动生效
    source ~/.bashrc

    RPC_URL=$(prompt_for_rpc)
    PRIORITY_FEE=$(prompt_for_priority_fee)
    CORES=$(prompt_for_cores)

    session_name="ore"
    echo "开始挖矿，会话名称为 $session_name ..."

    start="while true; do ore --rpc $RPC_URL --keypair ~/.config/solana/id.json --priority-fee $PRIORITY_FEE mine --cores $CORES; echo '进程异常退出，等待重启' >&2; sleep 1; done"
    screen -dmS "$session_name" bash -c "$start"

    echo "挖矿进程已在名为 $session_name 的 screen 会话中后台启动。"
    echo "使用 'screen -r $session_name' 命令重新连接到此会话。"
}

function export_wallet() {
    check_and_install_dependencies

    # 提示用户输入助记词
    echo "下方请粘贴/输入你的助记词，用空格分隔，盲文不会显示的"
    solana-keygen recover 'prompt:?key=0/0' --force

    echo "钱包已恢复。请确保你的钱包地址充足的 SOL 用于交易费用。"

    # 和之前的一样添加PATH到.bashrc
    add_to_bashrc 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"'
    add_to_bashrc 'export PATH="$HOME/.cargo/bin:$PATH"'

    # 使改动生效
    source ~/.bashrc

    RPC_URL=$(prompt_for_rpc)
    PRIORITY_FEE=$(prompt_for_priority_fee)
    CORES=$(prompt_for_cores)

    session_name="ore"
    echo "开始挖矿，会话名称为 $session_name ..."

    start="while true; do ore --rpc $RPC_URL --keypair ~/.config/solana/id.json --priority-fee $PRIORITY_FEE mine --cores $CORES; echo '进程异常退出，等待重启' >&2; sleep 1; done"
    screen -dmS "$session_name" bash -c "$start"

    echo "挖矿进程已在名为 $session_name 的 screen 会话中后台启动。"
    echo "使用 'screen -r $session_name' 命令重新连接到此会话。"
}

function view_rewards() {
    ore --rpc https://api.mainnet-beta.solana.com --keypair ~/.config/solana/id.json rewards
}

function claim_rewards() {
    ore --rpc https://api.mainnet-beta.solana.com --keypair ~/.config/solana/id.json --priority-fee 50000 claim
}

function check_logs() {
    screen -r ore
}

function multiple() {
    echo "更新系统软件包..."
    sudo apt update && sudo apt upgrade -y
    echo "安装必要的工具和依赖..."
    sudo apt install -y curl build-essential jq git libssl-dev pkg-config screen
    check_and_install_dependencies

    # 提示用户输入RPC配置地址
    read -p "请输入RPC配置地址: " rpc_address

    # 用户输入要生成的钱包配置文件数量
    read -p "请输入你想要运行的钱包数量: " count

    # 用户输入优先费用
    read -p "请输入交易的优先费用 (默认设置为 1): " priority_fee
    priority_fee=${priority_fee:-1}

    # 用户输入核心数量
    CORES=$(prompt_for_cores)

    # 基础会话名
    session_base_name="ore"

    # 启动命令模板，使用变量替代rpc地址和优先费用
    start_command_template="while true; do ore --rpc $rpc_address --keypair ~/.config/solana/idX.json --priority-fee $priority_fee mine --cores $CORES; echo '进程异常退出，等待重启' >&2; sleep 1; done"

    # 确保.solana目录存在
    mkdir -p ~/.config/solana

    # 循环创建配置文件和启动挖矿进程
    for (( i=1; i<=count; i++ ))
    do
        # 提示用户输入私钥
        echo "为id${i}.json输入私钥 (格式为包含64个数字的JSON数组):"
        read -p "私钥: " private_key

        # 生成配置文件路径
        config_file=~/.config/solana/id${i}.json

        # 直接将私钥写入配置文件
        echo $private_key > $config_file

        # 生成会话名
        session_name="${session_base_name}_${i}"

        # 替换启动命令中的配置文件名和RPC地址
        start_command=${start_command_template//idX/id${i}}

        # 打印开始信息
        echo "开始挖矿，会话名称为 $session_name ..."

        # 使用 screen 在后台启动挖矿进程
        screen -dmS "$session_name" bash -c "$start_command"

        # 打印挖矿进程启动信息
        echo "挖矿进程已在名为 $session_name 的 screen 会话中后台启动。"
        echo "使用 'screen -r $session_name' 命令重新连接到此会话。"
    done
}

function check_multiple() {
    # 提示用户输入RPC地址
    echo -n "请输入RPC地址（例如 https://api.mainnet-beta.solana.com）: "
    read rpc_address

    # 提示用户同时输入起始和结束编号，用空格分隔
    echo -n "请输入起始和结束编号，中间用空格分隔（例如，对于10个钱包地址，输入1 10）: "
    read -a range

    # 获取起始和结束编号
    start=${range[0]}
    end=${range[1]}

    # 执行循环
    for i in $(seq $start $end); do
        ore --rpc $rpc_address --keypair ~/.config/solana/id$i.json --priority-fee 1 rewards
    done
}

function lonely() {
    # 提示用户输入RPC配置地址
    read -p "请输入RPC配置地址: " rpc_address

    # 用户输入要生成的钱包配置文件数量
    read -p "请输入你想要运行的钱包数量: " count

    # 用户输入优先费用
    read -p "请输入交易的优先费用 (默认设置为 1): " priority_fee
    priority_fee=${priority_fee:-1}

    # 用户输入核心数量
    CORES=$(prompt_for_cores)

    # 基础会话名
    session_base_name="ore"

    # 启动命令模板
    start_command_template="while true; do ore --rpc $rpc_address --keypair ~/.config/solana/idX.json --priority-fee $priority_fee mine --cores $CORES; echo '进程异常退出，等待重启' >&2; sleep 1; done"

    # 确保.solana目录存在
    mkdir -p ~/.config/solana

    # 循环创建配置文件和启动挖矿进程
    for (( i=1; i<=count; i++ ))
    do
        # 提示用户输入私钥
        echo "为id${i}.json输入私钥 (格式为包含64个数字的JSON数组):"
        read -p "私钥: " private_key

        # 生成配置文件路径
        config_file=~/.config/solana/id${i}.json

        # 直接将私钥写入配置文件
        echo $private_key > $config_file

        # 生成会话名
        session_name="${session_base_name}_${i}"

        # 替换启动命令中的配置文件名和RPC地址
        start_command=${start_command_template//idX/id${i}}

        # 打印开始信息
        echo "开始挖矿，会话名称为 $session_name ..."

        # 使用 screen 在后台启动挖矿进程
        screen -dmS "$session_name" bash -c "$start_command"

        # 打印挖矿进程启动信息
        echo "挖矿进程已在名为 $session_name 的 screen 会话中后台启动。"
        echo "使用 'screen -r $session_name' 命令重新连接到此会话。"
    done
}

function claim_multiple() {
    # 提示用户输入RPC地址
    echo -n "请输入RPC地址（例如：https://api.mainnet-beta.solana.com）: "
    read rpc_address

    # 确认用户输入的是有效RPC地址
    if [[ -z "$rpc_address" ]]; then
        echo "RPC地址不能为空。"
        exit 1
    fi

    # 提示用户输入优先费用
    echo -n "请输入优先费用（单位：lamports，例如：500000）: "
    read priority_fee

    # 确认用户输入的是有效的数字
    if ! [[ "$priority_fee" =~ ^[0-9]+$ ]]; then
        echo "优先费用必须是一个整数。"
        exit 1
    fi

    # 提示用户同时输入起始和结束编号
    echo -n "请输入起始和结束编号，中间用空格分隔比如跑了10个钱包地址，输入1 10即可: "
    read -a range

    # 获取起始和结束编号
    start=${range[0]}
    end=${range[1]}

    # 无限循环
    while true; do
        # 执行循环
        for i in $(seq $start $end); do
            echo "执行钱包 $i 并且RPC $rpc_address 和 $priority_fee"
            ore --rpc $rpc_address --keypair ~/.config/solana/id$i.json --priority-fee $priority_fee claim
        done
        echo "成功领取 $start 到 $end."
    done
}

function rerun_rpc() {
    # 提示用户输入RPC配置地址
    read -p "请输入RPC配置地址: " rpc_address

    # 用户输入优先费用
    PRIORITY_FEE=$(prompt_for_priority_fee)
    CORES=$(prompt_for_cores)

    # 自动查找所有的idn.json文件
    config_files=$(find ~/.config/solana -name "id*.json")
    for config_file in $config_files; do
        # 使用jq读取文件中的前五个数字，并将它们转换成逗号分隔的字符串
        key_prefix=$(jq -r '.[0:5] | join(",")' "$config_file")

        # 生成会话名
        session_name="ore_[${key_prefix}]"

        # 替换启动命令中的配置文件路径
        start_command="while true; do ore --rpc $rpc_address --keypair $config_file --priority-fee $PRIORITY_FEE mine --cores $CORES; echo '进程异常退出，等待重启' >&2; sleep 1; done"

        # 打印开始信息
        echo "开始挖矿，会话名称为 $session_name ..."

        # 使用screen在后台启动挖矿进程
        screen -dmS "$session_name" bash -c "$start_command"

        # 打印挖矿进程启动信息
        echo "挖矿进程已在名为 $session_name 的 screen 会话中后台启动。"
        echo "使用 'screen -r $session_name' 命令重新连接到此会话。"
    done
}

function benchmark() {
    CORES=$(prompt_for_cores)
    ore benchmark --cores "$CORES"
}

复制代码function jito() {
    if [ -d "ore-cli" ]; then
        echo "'ore-cli' 目录已存在，将备份并清空该目录..."
        mv ore-cli ore-cli_backup_$(date +"%Y%m%d%H%M%S")  # 备份已存在的目录
    fi
    
    git clone -b jito https://github.com/a3165458/ore-cli.git 
    cd ore-cli || exit 1
    cp ore /usr/bin

    # 提示用户输入私钥
    echo "为id.json输入私钥 (格式为包含64个数字的JSON数组):"
    read -p "私钥: " private_key

    # 生成配置文件路径
    config_file=~/id.json

    # 直接将私钥写入配置文件
    echo $private_key > $config_file

    RPC_URL=$(prompt_for_rpc)
    PRIORITY_FEE=$(prompt_for_priority_fee)
    CORES=$(prompt_for_cores)

    session_name="ore"
    echo "开始挖矿，会话名称为 $session_name ..."

    start="while true; do ore --rpc $RPC_URL --keypair ~/id.json --priority-fee $PRIORITY_FEE mine --cores $CORES; echo '进程异常退出，等待重启' >&2; sleep 1; done"
    screen -dmS "$session_name" bash -c "$start"

    echo "挖矿进程已在名为 $session_name 的 screen 会话中后台启动。"
    echo "使用 'screen -r $session_name' 命令重新连接到此会话。"
}

function dynamic_fee() {
    echo "为id.json输入私钥 (格式为包含64个数字的JSON数组):"
    read -p "私钥: " private_key

    config_file=~/id.json
    echo $private_key > $config_file

    RPC_URL=$(prompt_for_rpc)
    
    read -p "请输入动态费用估算的 RPC URL (需要helius或者triton的rpc): " dynamic_fee_url
    read -p "请输入动态费用估算策略 (helius 或 triton): " dynamic_fee_strategy

    CORES=$(prompt_for_cores)

    session_name="ore"
    echo "开始挖矿，会话名称为 $session_name ..."

    start="while true; do ore --rpc $RPC_URL --keypair ~/id.json mine --dynamic-fee-url $dynamic_fee_url --dynamic-fee-strategy $dynamic_fee_strategy --cores $CORES; echo '进程异常退出，等待重启' >&2; sleep 1; done"
    screen -dmS "$session_name" bash -c "$start"

    echo "挖矿进程已在名为 $session_name 的 screen 会话中后台启动。"
    echo "使用 'screen -r $session_name' 命令重新连接到此会话。"
}

# 主菜单
function main_menu() {
    while true; do
        clear
        echo "==========================Ore V2 节点安装======================================"
        echo "选项:"
        echo "1. 安装新节点"
        echo "2. 导入钱包运行"
        echo "3. 启动挖矿"
        echo "4. 查看挖矿收益"
        echo "5. 领取挖矿收益"
        echo "6. 查看节点运行情况"
        echo "7. 多开钱包并安装环境"
        echo "8. 多开钱包不检查安装环境"
        echo "9. 多开钱包查看奖励"
        echo "10. 多开钱包领取奖励（自动轮询）"
        echo "11. 更换rpc并多开自动读取"
        echo "12. 算力测试"
        echo "13. 低费率jito版本"
        echo "14. 动态费率启动"

        read -p "请输入选项（1-14）: " OPTION

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
        10) claim_multiple ;;
        11) rerun_rpc ;;
        12) benchmark ;;
        13) jito ;;
        14) dynamic_fee ;;
        esac
        echo "按任意键返回主菜单..."
        read -n 1
    done
}

# 显示主菜单
main_menu
