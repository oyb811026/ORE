#!/bin/bash

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "未检测到ROOT权限，请使用命令sudo -i 或 sudo ./ore.sh 来提权运行."
   exit 1
fi


echo ""
echo "============================================="
echo "   ORE V2 一键挖矿脚本 1.5"
echo "   By: Doge "
echo "   www.xiaot.eu.org "
echo "============================================="
echo ""
while true; do
    echo "请选择操作:"
    echo "1. 安装ORE依赖"
    echo "2. 生成钱包"
    echo "3. 导入钱包私钥对"
    echo "4. 转换私钥格式"
    echo "5. 查看当前私钥"
    echo "6. 查询本机算力"
    echo "7. 领取挖矿奖励"
    echo "8. 更新脚本"
    echo "9. 开始挖矿"
    echo "0. 后台挖矿"
    echo "00. 后台日志"
    echo "09. 终止挖矿"
    echo ""
    read -p "请输入您的选择: " choice
    case $choice in
        1)
            echo "正在安装ORE依赖..."
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
    echo "正在生成钱包..."
    if [[ -f "/root/.config/solana/id.json" ]]; then
        read -p "当前存在钱包文件，是否替换？(y/n): " replace_choice
        if [[ $replace_choice == "y" || $replace_choice == "Y" ]]; then
            solana-keygen new -o /root/.config/solana/id.json --force
            echo "钱包文件已替换"
        else
            echo "未替换钱包文件"
        fi
    else
        solana-keygen new -o /root/.config/solana/id.json
        echo "已创建新钱包文件"
    fi
    ;;

        3)
            read -p "请输入SOL私钥对，如：[21,12,21......: " private_key
            echo "$private_key" > ~/.config/solana/id.json
            echo "私钥对已写入 ~/.config/solana/id.json"
            ;;

        4)
            read -p "请输入Base58格式的私钥: " base58_private_key
            hex_private_key=$(echo "$base58_private_key" | base58 -d | xxd -p)
            decimal_array=$(echo "$hex_private_key" | sed 's/../0x& /g' | xargs printf "%d,")
            decimal_array="${decimal_array%?}"
            final_private_key="[$decimal_array]"
            echo "转换后的私钥对格式： $final_private_key"
      ;;

5)
            echo "查看当前私钥..."
            cat /root/.config/solana/id.json
            ;;


        6)
            echo "查询本机算力..."
            A=$(nproc)
            echo "本机CPU最大线程数为: $A"
            ore benchmark --threads $A
            ;;

        7)
    echo "领取挖矿奖励..."
    read -p "请输入Gas费（默认值10000=0.0001 SOL）：" priority_fee
    priority_fee=${priority_fee:-10000}
    read -p "请输入RPC地址（默认：https://api.mainnet-beta.solana.com）：" rpc_url
    rpc_url=${rpc_url:-https://api.mainnet-beta.solana.com}
    ore claim --rpc $rpc_url --priority-fee $priority_fee
    ;;

        8)
            echo "更新脚本..."
            curl -L https://github.com/crow4586/ore/releases/download/ore/dore.sh -o dore.sh && chmod +x dore.sh && ./dore.sh
            ;;

        9)
            if [ -f "dom.sh" ]; then
                read -p "已经存在配置，是否继续执行？ 1 继续，2 重新配置：" continue_option
                case $continue_option in
                    1)
                        echo "正在执行dom.sh配置..."
                        bash dom.sh
                        ;;
                    2)
                        echo "重新配置挖矿选项..."
                        read -p "线程数（最大线程数为 $A ）：" threads
                        threads=${threads:-$A}
                        read -p "请输入RPC地址（默认：https://api.mainnet-beta.solana.com）：" rpc_url
                        rpc_url=${rpc_url:-https://api.mainnet-beta.solana.com}
                        read -p "缓冲时间（默认5秒）：" buffer_time
                        buffer_time=${buffer_time:-5}
                        read -p "优先Gas费（默认值10000=0.0001 SOL）：" priority_fee
                        priority_fee=${priority_fee:-10000}

                        echo "#!/bin/bash" > dom.sh
                        echo "" >> dom.sh
                        echo "threads=$threads" >> dom.sh
                        echo "rpc_url=$rpc_url" >> dom.sh
                        echo "buffer_time=$buffer_time" >> dom.sh
                        echo "priority_fee=$priority_fee" >> dom.sh
                        echo "" >> dom.sh
                        echo "while true; do" >> dom.sh
                        echo "    # 检查 ore 进程是否在运行" >> dom.sh
                        echo "    if ! pgrep -f \"ore mine\" > /dev/null; then" >> dom.sh
                        echo "        # ore 进程不存在,重新启动挖矿" >> dom.sh
                        echo "        echo \"重新启动挖矿...\"" >> dom.sh
                        echo "        ore mine --threads \$threads --rpc \$rpc_url --buffer-time \$buffer_time --priority-fee \$priority_fee" >> dom.sh
                        echo "    fi" >> dom.sh
                        echo "" >> dom.sh
                        echo "    # 等待一段时间再检查" >> dom.sh
                        echo "    sleep \$buffer_time" >> dom.sh
                        echo "done" >> dom.sh
                        chmod +x dom.sh
                        bash dom.sh
                        ;;
                    *)
                        echo "无效选择,请重新输入."
                        ;;
                esac
            else
                read -p "线程数（最大线程数为 $A ）：" threads
                threads=${threads:-$A}
                read -p "请输入RPC地址（默认：https://api.mainnet-beta.solana.com）：" rpc_url
                rpc_url=${rpc_url:-https://api.mainnet-beta.solana.com}
                read -p "缓冲时间（默认5秒）：" buffer_time
                buffer_time=${buffer_time:-5}
                read -p "优先Gas费（默认值10000=0.0001 SOL）：" priority_fee
                priority_fee=${priority_fee:-10000}

                echo "#!/bin/bash" > dom.sh
                echo "" >> dom.sh
                echo "threads=$threads" >> dom.sh
                echo "rpc_url=$rpc_url" >> dom.sh
                echo "buffer_time=$buffer_time" >> dom.sh
                echo "priority_fee=$priority_fee" >> dom.sh
                echo "" >> dom.sh
                echo "while true; do" >> dom.sh
                echo "    # 检查 ore 进程是否在运行" >> dom.sh
                echo "    if ! pgrep -f \"ore mine\" > /dev/null; then" >> dom.sh
                echo "        # ore 进程不存在,重新启动挖矿" >> dom.sh
                echo "        echo \"重新启动挖矿...\"" >> dom.sh
                echo "        ore mine --threads \$threads --rpc \$rpc_url --buffer-time \$buffer_time --priority-fee \$priority_fee" >> dom.sh
                echo "    fi" >> dom.sh
                echo "" >> dom.sh
                echo "    # 等待一段时间再检查" >> dom.sh
                echo "    sleep \$buffer_time" >> dom.sh
                echo "done" >> dom.sh
                chmod +x dom.sh
                bash dom.sh
            fi
            ;;

        0)
            if [ -f "dom.sh" ]; then
                read -p "已经存在配置,是否继续后台挖矿？ 1 继续，2 重新配置：" continue_option
                case $continue_option in
                    1)
                        echo "后台挖矿中..."
                        nohup bash dom.sh > dore.log 2>&1 &
                        echo "后台挖矿已启动"
                        ;;
                    2)
                        echo "重新配置挖矿选项..."
                        read -p "线程数（最大线程数为 $A ）：" threads
                        threads=${threads:-$A}
                        read -p "请输入RPC地址（默认：https://api.mainnet-beta.solana.com）：" rpc_url
                        rpc_url=${rpc_url:-https://api.mainnet-beta.solana.com}
                        read -p "缓冲时间（默认5秒）：" buffer_time
                        buffer_time=${buffer_time:-5}
                        read -p "优先Gas费（默认值10000=0.0001 SOL）：" priority_fee
                        priority_fee=${priority_fee:-10000}

                        echo "#!/bin/bash" > dom.sh
                        echo "" >> dom.sh
                        echo "threads=$threads" >> dom.sh
                        echo "rpc_url=$rpc_url" >> dom.sh
                        echo "buffer_time=$buffer_time" >> dom.sh
                        echo "priority_fee=$priority_fee" >> dom.sh
                        echo "" >> dom.sh
                        echo "while true; do" >> dom.sh
                        echo "    # 检查 ore 进程是否在运行" >> dom.sh
                        echo "    if ! pgrep -f \"ore mine\" > /dev/null; then" >> dom.sh
                        echo "        # ore 进程不存在,重新启动挖矿" >> dom.sh
                        echo "        echo \"重新启动挖矿...\"" >> dom.sh
                        echo "        ore mine --threads \$threads --rpc \$rpc_url --buffer-time \$buffer_time --priority-fee \$priority_fee" >> dom.sh
                        echo "    fi" >> dom.sh
                        echo "" >> dom.sh
                        echo "    # 等待一段时间再检查" >> dom.sh
                        echo "    sleep \$buffer_time" >> dom.sh
                        echo "done" >> dom.sh
                        chmod +x dom.sh
                        nohup bash dom.sh > dore.log 2>&1 &
                        echo "后台挖矿已启动"
                        ;;
                    *)
                        echo "无效选择,请重新输入."
                        ;;
                esac
            else
                read -p "线程数（最大线程数为 $A ）：" threads
                threads=${threads:-$A}
                read -p "请输入RPC地址（默认：https://api.mainnet-beta.solana.com）：" rpc_url
                rpc_url=${rpc_url:-https://api.mainnet-beta.solana.com}
                read -p "缓冲时间（默认5秒）：" buffer_time
                buffer_time=${buffer_time:-5}
                read -p "优先Gas费（默认值10000=0.0001 SOL）：" priority_fee
                priority_fee=${priority_fee:-10000}

                echo "#!/bin/bash" > dom.sh
                echo "" >> dom.sh
                echo "threads=$threads" >> dom.sh
                echo "rpc_url=$rpc_url" >> dom.sh
                echo "buffer_time=$buffer_time" >> dom.sh
                echo "priority_fee=$priority_fee" >> dom.sh
                echo "" >> dom.sh
                echo "while true; do" >> dom.sh
                echo "    # 检查 ore 进程是否在运行" >> dom.sh
                echo "    if ! pgrep -f \"ore mine\" > /dev/null; then" >> dom.sh
                echo "        # ore 进程不存在,重新启动挖矿" >> dom.sh
                echo "        echo \"重新启动挖矿...\"" >> dom.sh
                echo "        ore mine --threads \$threads --rpc \$rpc_url --buffer-time \$buffer_time --priority-fee \$priority_fee" >> dom.sh
                echo "    fi" >> dom.sh
                echo "" >> dom.sh
                echo "    # 等待一段时间再检查" >> dom.sh
                echo "    sleep \$buffer_time" >> dom.sh
                echo "done" >> dom.sh
                chmod +x dom.sh
                nohup bash dom.sh > dore.log 2>&1 &
                echo "后台挖矿已启动"
            fi
            ;;

          00)
            echo "后台日志..."
            
            tail -f dore.log

            ;;

          09)
            echo "正在终止挖矿..."
            pkill -f "dom.sh"
            pkill -f "ore mine"
            
 
            ;;


        *)
            echo "无效选择，请重新输入."
            ;;
    esac
done
