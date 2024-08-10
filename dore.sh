#!/bin/bash

# 定义颜色代码
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
RESET="\033[0m" # 重置为默认颜色

# 检查是否以root身份运行
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}未检测到ROOT权限，请使用命令sudo -i 或 sudo ./ore.sh 来提权运行.${RESET}"
   exit 1
fi

echo ""
echo -e "${GREEN}=============================================${RESET}"
echo -e "${GREEN}   ORE V2 一键挖矿脚本 1.5${RESET}"
echo -e "${GREEN}   By: Doge ${RESET}"
echo -e "${GREEN}   www.xiaot.eu.org ${RESET}"
echo -e "${GREEN}=============================================${RESET}"
echo ""

while true; do
    echo -e "${YELLOW}请选择操作:${RESET}"
    echo -e "${CYAN}1. 安装ORE依赖${RESET}"
    echo -e "${CYAN}2. 生成钱包${RESET}"
    echo -e "${CYAN}3. 导入钱包私钥对${RESET}"
    echo -e "${CYAN}4. 转换私钥格式${RESET}"
    echo -e "${CYAN}5. 查看当前私钥${RESET}"
    echo -e "${CYAN}6. 查询本机算力${RESET}"
    echo -e "${CYAN}7. 领取挖矿奖励${RESET}"
    echo -e "${CYAN}8. 更新脚本${RESET}"
    echo -e "${CYAN}9. 开始挖矿${RESET}"
    echo -e "${CYAN}10. 后台挖矿${RESET}"
    echo -e "${CYAN}11. 后台日志${RESET}"
    echo -e "${CYAN}12. 终止挖矿${RESET}"
    echo ""

    read -p "请输入您的选择: " choice
    case $choice in
        1)
            echo -e "${GREEN}正在安装ORE依赖...${RESET}"
            apt update && echo y | apt upgrade
            apt-get install -y build-essential
            apt install -y base58 xxd
            curl https://sh.rustup.rs -sSf | sh -s -- -y
            . "$HOME/.cargo/env"
            echo y | apt install cargo
            sh -c "$(curl -sSfL https://release.solana.com/stable/install)"
            export PATH="/root/.local/share/solana/install/active_release/bin:$PATH"
            cargo install ore-cli
            ;;

        2)
            echo -e "${GREEN}正在生成钱包...${RESET}"
            if [[ -f "/root/.config/solana/id.json" ]]; then
                read -p "当前存在钱包文件，是否替换？(y/n): " replace_choice
                if [[ $replace_choice == "y" || $replace_choice == "Y" ]]; then
                    solana-keygen new -o /root/.config/solana/id.json --force
                    echo -e "${GREEN}钱包文件已替换${RESET}"
                else
                    echo -e "${YELLOW}未替换钱包文件${RESET}"
                fi
            else
                solana-keygen new -o /root/.config/solana/id.json
                echo -e "${GREEN}已创建新钱包文件${RESET}"
            fi
            ;;

        3)
            read -p "请输入SOL私钥对，如：[21,12,21...]: " private_key
            echo "$private_key" > ~/.config/solana/id.json
            echo -e "${GREEN}私钥对已写入 ~/.config/solana/id.json${RESET}"
            ;;

        4)
            read -p "请输入Base58格式的私钥: " base58_private_key
            hex_private_key=$(echo "$base58_private_key" | base58 -d | xxd -p)
            decimal_array=$(echo "$hex_private_key" | sed 's/../0x& /g' | xargs printf "%d,")
            decimal_array="${decimal_array%?}"
            final_private_key="[$decimal_array]"
            echo -e "${GREEN}转换后的私钥对格式： $final_private_key${RESET}"
            ;;

        5)
            echo -e "${YELLOW}查看当前私钥...${RESET}"
            cat /root/.config/solana/id.json
            ;;

        6)
            echo -e "${YELLOW}查询本机算力...${RESET}"
            A=$(nproc)
            echo -e "${GREEN}本机CPU最大核心数为: $A${RESET}"
            ore benchmark --cores $A
            ;;

        7)
            echo -e "${YELLOW}领取挖矿奖励...${RESET}"
            read -p "请输入Gas费（默认值10000=0.0001 SOL）：" priority_fee
            priority_fee=${priority_fee:-10000}
            read -p "请输入RPC地址（默认：https://api.mainnet-beta.solana.com）：" rpc_url
            rpc_url=${rpc_url:-https://api.mainnet-beta.solana.com}
            ore claim --rpc $rpc_url --priority-fee $priority_fee
            ;;

        8)
            echo -e "${GREEN}更新脚本...${RESET}"
            curl -L https://github.com/crow4586/ore/releases/download/ore/dore.sh -o dore.sh && chmod +x dore.sh && ./dore.sh
            ;;

        9)
            if [ -f "dom.sh" ]; then
                read -p "已经存在配置，是否继续执行？1 继续，2 重新配置：" continue_option
                case $continue_option in
                    1)
                        echo -e "${GREEN}正在执行dom.sh配置...${RESET}"
                        bash dom.sh
                        ;;
                    2)
                        echo -e "${YELLOW}重新配置挖矿选项...${RESET}"
                        read -p "核心数（最大核心数为 $A）：" cores
                        cores=${cores:-$A}
                        read -p "请输入RPC地址（默认：https://api.mainnet-beta.solana.com）：" rpc_url
                        rpc_url=${rpc_url:-https://api.mainnet-beta.solana.com}
                        read -p "缓冲时间（默认5秒）：" buffer_time
                        buffer_time=${buffer_time:-5}
                        read -p "优先Gas费（默认值10000=0.0001 SOL）：" priority_fee
                        priority_fee=${priority_fee:-10000}

                        echo "#!/bin/bash" > dom.sh
                        echo "" >> dom.sh
                        echo "cores=$cores" >> dom.sh
                        echo "rpc_url=$rpc_url" >> dom.sh
                        echo "buffer_time=$buffer_time" >> dom.sh
                        echo "priority_fee=$priority_fee" >> dom.sh
                        echo "" >> dom.sh
                        echo "while true; do" >> dom.sh
                        echo "    # 检查 ore 进程是否在运行" >> dom.sh
                        echo "    if ! pgrep -f \"ore mine\" > /dev/null; then" >> dom.sh
                        echo "        # ore 进程不存在,重新启动挖矿" >> dom.sh
                        echo "        echo \"重新启动挖矿...\" >> dore.log" >> dom.sh
                        echo "        echo \"\$(date +'%Y-%m-%d %H:%M:%S') - 启动挖矿...\" >> dore.log" >> dom.sh
                        echo "        current_difficulty=\$(ore get difficulty)" >> dom.sh
                        echo "        avg_difficulty=\$(ore get avg_difficulty)" >> dom.sh # 替换为实际命令
                        echo "        earnings=\$(ore get earnings)" >> dom.sh # 替换为实际命令
                        echo "        total_balance=\$(ore get balance)" >> dom.sh # 替换为实际命令
                        echo "        hourly_avg=\$(ore get hourly_avg)" >> dom.sh # 替换为实际命令
                        echo "        echo \"\$(date +'%Y-%m-%d %H:%M:%S') - 当前难度: \$current_difficulty, 平均难度: \$avg_difficulty, 当前收益: \$earnings, 总余额: \$total_balance, 每小时平均获得量: \$hourly_avg\" >> dore.log" >> dom.sh
                        echo "        ore mine --cores \$cores --rpc \$rpc_url --buffer-time \$buffer_time --priority-fee \$priority_fee" >> dom.sh
                        echo "    fi" >> dom.sh
                        echo "" >> dom.sh
                        echo "    # 等待一段时间再检查" >> dom.sh
                        echo "    sleep \$buffer_time" >> dom.sh
                        echo "done" >> dom.sh
                        chmod +x dom.sh
                        bash dom.sh
                        ;;
                    *)
                        echo -e "${RED}无效选择,请重新输入.${RESET}"
                        ;;
                esac
            else
                read -p "核心数（最大核心数为 $A）：" cores
                cores=${cores:-$A}
                read -p "请输入RPC地址（默认：https://api.mainnet-beta.solana.com）：" rpc_url
                rpc_url=${rpc_url:-https://api.mainnet-beta.solana.com}
                read -p "缓冲时间（默认5秒）：" buffer_time
                buffer_time=${buffer_time:-5}
                read -p "优先Gas费（默认值10000=0.0001 SOL）：" priority_fee
                priority_fee=${priority_fee:-10000}

                echo "#!/bin/bash" > dom.sh
                echo "" >> dom.sh
                echo "cores=$cores" >> dom.sh
                echo "rpc_url=$rpc_url" >> dom.sh
                echo "buffer_time=$buffer_time" >> dom.sh
                echo "priority_fee=$priority_fee" >> dom.sh
                echo "" >> dom.sh
                echo "while true; do" >> dom.sh
                echo "    # 检查 ore 进程是否在运行" >> dom.sh
                echo "    if ! pgrep -f \"ore mine\" > /dev/null; then" >> dom.sh
                echo "        # ore 进程不存在,重新启动挖矿" >> dom.sh
                echo "        echo \"重新启动挖矿...\" >> dore.log" >> dom.sh
                echo "        echo \"\$(date +'%Y-%m-%d %H:%M:%S') - 启动挖矿...\" >> dore.log" >> dom.sh
                echo "        current_difficulty=\$(ore get difficulty)" >> dom.sh
                echo "        avg_difficulty=\$(ore get avg_difficulty)" >> dom.sh # 替换为实际命令
                echo "        earnings=\$(ore get earnings)" >> dom.sh # 替换为实际命令
                echo "        total_balance=\$(ore get balance)" >> dom.sh # 替换为实际命令
                echo "        hourly_avg=\$(ore get hourly_avg)" >> dom.sh # 替换为实际命令
                echo "        echo \"\$(date +'%Y-%m-%d %H:%M:%S') - 当前难度: \$current_difficulty, 平均难度: \$avg_difficulty, 当前收益: \$earnings, 总余额: \$total_balance, 每小时平均获得量: \$hourly_avg\" >> dore.log" >> dom.sh
                echo "        ore mine --cores \$cores --rpc \$rpc_url --buffer-time \$buffer_time --priority-fee \$priority_fee" >> dom.sh
                echo "    fi" >> dom.sh
                echo "" >> dom.sh
                echo "    # 等待一段时间再检查" >> dom.sh
                echo "    sleep \$buffer_time" >> dom.sh
                echo "done" >> dom.sh
                chmod +x dom.sh
                nohup bash dom.sh > dore.log 2>&1 &
                echo -e "${GREEN}后台挖矿已启动${RESET}"
            fi
            ;;

        10)
            if [ -f "dom.sh" ]; then
                read -p "已经存在配置,是否继续后台挖矿？1 继续，2 重新配置：" continue_option
                case $continue_option in
                    1)
                        echo -e "${GREEN}后台挖矿中...${RESET}"
                        nohup bash dom.sh > dore.log 2>&1 &
                        echo -e "${GREEN}后台挖矿已启动${RESET}"
                        ;;
                    2)
                        echo -e "${YELLOW}重新配置挖矿选项...${RESET}"
                        read -p "核心数（最大核心数为 $A）：" cores
                        cores=${cores:-$A}
                        read -p "请输入RPC地址（默认：https://api.mainnet-beta.solana.com）：" rpc_url
                        rpc_url=${rpc_url:-https://api.mainnet-beta.solana.com}
                        read -p "缓冲时间（默认5秒）：" buffer_time
                        buffer_time=${buffer_time:-5}
                        read -p "优先Gas费（默认值10000=0.0001 SOL）：" priority_fee
                        priority_fee=${priority_fee:-10000}

                        echo "#!/bin/bash" > dom.sh
                        echo "" >> dom.sh
                        echo "cores=$cores" >> dom.sh
                        echo "rpc_url=$rpc_url" >> dom.sh
                        echo "buffer_time=$buffer_time" >> dom.sh
                        echo "priority_fee=$priority_fee" >> dom.sh
                        echo "" >> dom.sh
                        echo "while true; do" >> dom.sh
                        echo "    # 检查 ore 进程是否在运行" >> dom.sh
                        echo "    if ! pgrep -f \"ore mine\" > /dev/null; then" >> dom.sh
                        echo "        # ore 进程不存在,重新启动挖矿" >> dom.sh
                        echo "        echo \"重新启动挖矿...\" >> dore.log" >> dom.sh
                        echo "        echo \"\$(date +'%Y-%m-%d %H:%M:%S') - 启动挖矿...\" >> dore.log" >> dom.sh
                        echo "        current_difficulty=\$(ore get difficulty)" >> dom.sh
                        echo "        avg_difficulty=\$(ore get avg_difficulty)" >> dom.sh # 替换为实际命令
                        echo "        earnings=\$(ore get earnings)" >> dom.sh # 替换为实际命令
                        echo "        total_balance=\$(ore get balance)" >> dom.sh # 替换为实际命令
                        echo "        hourly_avg=\$(ore get hourly_avg)" >> dom.sh # 替换为实际命令
                        echo "        echo \"\$(date +'%Y-%m-%d %H:%M:%S') - 当前难度: \$current_difficulty, 平均难度: \$avg_difficulty, 当前收益: \$earnings, 总余额: \$total_balance, 每小时平均获得量: \$hourly_avg\" >> dore.log" >> dom.sh
                        echo "        ore mine --cores \$cores --rpc \$rpc_url --buffer-time \$buffer_time --priority-fee \$priority_fee" >> dom.sh
                        echo "    fi" >> dom.sh
                        echo "" >> dom.sh
                        echo "    # 等待一段时间再检查" >> dom.sh
                        echo "    sleep \$buffer_time" >> dom.sh
                        echo "done" >> dom.sh
                        chmod +x dom.sh
                        nohup bash dom.sh > dore.log 2>&1 &
                        echo -e "${GREEN}后台挖矿已启动${RESET}"
                        ;;
                    *)
                        echo -e "${RED}无效选择,请重新输入.${RESET}"
                        ;;
                esac
            else
                read -p "核心数（最大核心数为 $A）：" cores
                cores=${cores:-$A}
                read -p "请输入RPC地址（默认：https://api.mainnet-beta.solana.com）：" rpc_url
                rpc_url=${rpc_url:-https://api.mainnet-beta.solana.com}
                read -p "缓冲时间（默认5秒）：" buffer_time
                buffer_time=${buffer_time:-5}
                read -p "优先Gas费（默认值10000=0.0001 SOL）：" priority_fee
                priority_fee=${priority_fee:-10000}

                echo "#!/bin/bash" > dom.sh
                echo "" >> dom.sh
                echo "cores=$cores" >> dom.sh
                echo "rpc_url=$rpc_url" >> dom.sh
                echo "buffer_time=$buffer_time" >> dom.sh
                echo "priority_fee=$priority_fee" >> dom.sh
                echo "" >> dom.sh
                echo "while true; do" >> dom.sh
                echo "    # 检查 ore 进程是否在运行" >> dom.sh
                echo "    if ! pgrep -f \"ore mine\" > /dev/null; then" >> dom.sh
                echo "        # ore 进程不存在,重新启动挖矿" >> dom.sh
                echo "        echo \"重新启动挖矿...\" >> dore.log" >> dom.sh
                echo "        echo \"\$(date +'%Y-%m-%d %H:%M:%S') - 启动挖矿...\" >> dore.log" >> dom.sh
                echo "        current_difficulty=\$(ore get difficulty)" >> dom.sh
                echo "        avg_difficulty=\$(ore get avg_difficulty)" >> dom.sh # 替换为实际命令
                echo "        earnings=\$(ore get earnings)" >> dom.sh # 替换为实际命令
                echo "        total_balance=\$(ore get balance)" >> dom.sh # 替换为实际命令
                echo "        hourly_avg=\$(ore get hourly_avg)" >> dom.sh # 替换为实际命令
                echo "        echo \"\$(date +'%Y-%m-%d %H:%M:%S') - 当前难度: \$current_difficulty, 平均难度: \$avg_difficulty, 当前收益: \$earnings, 总余额: \$total_balance, 每小时平均获得量: \$hourly_avg\" >> dore.log" >> dom.sh
                echo "        ore mine --cores \$cores --rpc \$rpc_url --buffer-time \$buffer_time --priority-fee \$priority_fee" >> dom.sh
                echo "    fi" >> dom.sh
                echo "" >> dom.sh
                echo "    # 等待一段时间再检查" >> dom.sh
                echo "    sleep \$buffer_time" >> dom.sh
                echo "done" >> dom.sh
                chmod +x dom.sh
                nohup bash dom.sh > dore.log 2>&1 &
                echo -e "${GREEN}后台挖矿已启动${RESET}"
            fi
            ;;

        11)
            echo -e "${YELLOW}后台日志...${RESET}"
            tail -f dore.log
            ;;

        12)
            echo -e "${RED}正在终止挖矿...${RESET}"
            pkill -f "dom.sh"
            pkill -f "ore mine"
            ;;

        *)
            echo -e "${RED}无效选择，请重新输入.${RESET}"
            ;;
    esac
done
