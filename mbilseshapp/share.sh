#!/bin/bash

# ============================================================
# WebDrop - 网页投放器
# Bash + Whiptail + Python HTTP Server
#
# 功能：
#   1. 单进程 / 多进程
#   2. 文件 / 文件夹投放
#   3. 多进程独立 ID
#   4. 独立端口
#   5. 0.0.0.0 / 127.0.0.1 / localhost / 本机 IP
#   6. 进程预览与管理
#   7. IP / MAC / DNS / 网络状态
#   8. 按日期记录日志
#   9. Ctrl+C 安全退出
# ============================================================

set -u

APP_NAME="WebDrop"

BASE_DIR="${HOME}/.webdrop"
LOG_DIR="${BASE_DIR}/logs"
PID_DIR="${BASE_DIR}/pids"
PYTHON_SERVER="${BASE_DIR}/webdrop_server.py"

mkdir -p "$LOG_DIR" "$PID_DIR"

# ============================================================
# 全局变量
# ============================================================

DEPLOY_MODE=""
DEPLOY_CONTENT=""
DEPLOY_PORT=""
DEPLOY_BIND=""
DEPLOY_ID=""

# 格式：
# PID|URL|CONTENT|PORT|BIND|ID
RUNNING_JOBS=()

# ============================================================
# Ctrl+C
# ============================================================

trap 'clear; echo "WebDrop 已退出。"; exit 0' INT TERM

# ============================================================
# 日志
# ============================================================

get_log_file() {
    echo "${LOG_DIR}/$(date '+%Y-%m-%d').log"
}

write_log() {
    printf '[%s] %s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" \
        "$*" >> "$(get_log_file)"
}

# ============================================================
# Whiptail
# ============================================================

msgbox() {
    whiptail \
        --title "$APP_NAME" \
        --msgbox "$1" \
        12 70
}

# ============================================================
# Python HTTP Server
# ============================================================

create_python_server() {

cat > "$PYTHON_SERVER" <<'PYTHON'
#!/usr/bin/env python3

import argparse
import os
import sys
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler


class WebDropHandler(SimpleHTTPRequestHandler):

    def translate_path(self, path):

        # 去掉 query string
        path = path.split("?", 1)[0]

        prefix = self.server.prefix

        # 多进程模式：
        # /blog/index.html
        #      ↓
        # /index.html
        if prefix:
            if path == prefix:
                path = "/"

            elif path.startswith(prefix + "/"):
                path = path[len(prefix):]

            else:
                self.send_error(404, "Not Found")
                return "/"

        # 单文件模式
        if self.server.single_file:
            return self.server.single_file

        # 正常目录
        return super().translate_path(path)

    def log_message(self, fmt, *args):

        message = "[%s] %s\n" % (
            self.log_date_time_string(),
            fmt % args
        )

        try:
            with open(
                self.server.access_log,
                "a",
                encoding="utf-8"
            ) as f:
                f.write(message)
        except Exception:
            pass


def main():

    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--bind",
        required=True
    )

    parser.add_argument(
        "--port",
        required=True,
        type=int
    )

    parser.add_argument(
        "--content",
        required=True
    )

    parser.add_argument(
        "--prefix",
        default=""
    )

    parser.add_argument(
        "--log",
        required=True
    )

    args = parser.parse_args()

    content = os.path.abspath(
        os.path.expanduser(args.content)
    )

    if not os.path.exists(content):
        print("内容不存在:", content)
        sys.exit(1)

    # --------------------------------------------------------
    # 如果是文件
    # --------------------------------------------------------

    if os.path.isfile(content):

        serve_dir = os.path.dirname(content)

        os.chdir(serve_dir)

        server = ThreadingHTTPServer(
            (args.bind, args.port),
            WebDropHandler
        )

        server.single_file = content

    # --------------------------------------------------------
    # 如果是目录
    # --------------------------------------------------------

    else:

        os.chdir(content)

        server = ThreadingHTTPServer(
            (args.bind, args.port),
            WebDropHandler
        )

        server.single_file = None

    # --------------------------------------------------------
    # URL Prefix
    # --------------------------------------------------------

    prefix = args.prefix.strip()

    if prefix:
        prefix = "/" + prefix.strip("/")

    server.prefix = prefix
    server.access_log = args.log

    with open(
        args.log,
        "a",
        encoding="utf-8"
    ) as f:

        f.write(
            "\n"
            "========================================\n"
            "[WebDrop Python Server]\n"
            f"Bind    : {args.bind}\n"
            f"Port    : {args.port}\n"
            f"Content : {content}\n"
            f"Prefix  : {prefix or '/'}\n"
            "========================================\n"
        )

    try:
        server.serve_forever()

    except KeyboardInterrupt:
        pass

    finally:
        server.server_close()


if __name__ == "__main__":
    main()

PYTHON

chmod +x "$PYTHON_SERVER"
}

# ============================================================
# 检查 Python
# ============================================================

check_python() {

    if command -v python3 >/dev/null 2>&1; then
        return 0
    fi

    whiptail \
        --title "错误" \
        --msgbox \
"没有找到 Python3。

请安装 Python3：

Debian / Ubuntu:
apt install python3

Termux:
pkg install python" \
        12 65

    return 1
}

# ============================================================
# 获取本机 IP
# ============================================================

get_local_ip() {

    local ip=""

    # 优先通过默认路由获取
    if command -v ip >/dev/null 2>&1; then

        ip=$(
            ip route get 1.1.1.1 2>/dev/null |
            awk '
            {
                for (i = 1; i <= NF; i++) {
                    if ($i == "src") {
                        print $(i+1)
                        exit
                    }
                }
            }'
        )

        if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] &&
           [ "$ip" != "127.0.0.1" ]; then

            echo "$ip"
            return
        fi
    fi

    # hostname -I
    if command -v hostname >/dev/null 2>&1; then

        ip=$(
            hostname -I 2>/dev/null |
            tr ' ' '\n' |
            grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' |
            grep -v '^127\.' |
            head -n1
        )

        if [ -n "$ip" ]; then
            echo "$ip"
            return
        fi
    fi

    # 最后 fallback
    echo "127.0.0.1"
}

# ============================================================
# 获取所有本机 IPv4
# ============================================================

get_all_ips() {

    if command -v ip >/dev/null 2>&1; then

        ip -4 addr show 2>/dev/null |
        awk '
        /inet / {
            split($2,a,"/")
            if (a[1] !~ /^127\./)
                print a[1]
        }' |
        sort -u

    else

        get_local_ip
    fi
}

# ============================================================
# 获取 MAC
# ============================================================

get_mac() {

    local mac=""

    if command -v ip >/dev/null 2>&1; then

        mac=$(
            ip link 2>/dev/null |
            awk '
            /state UP/ {
                up=1
            }

            /link\/ether/ && up {
                print $2
                exit
            }

            /^[0-9]+:/ {
                if ($0 !~ /state UP/)
                    up=0
            }'
        )
    fi

    [ -z "$mac" ] && mac="未获取到"

    echo "$mac"
}

# ============================================================
# 获取 DNS
# ============================================================

get_dns() {

    local dns=""

    if [ -f /etc/resolv.conf ]; then

        dns=$(
            awk '
            /^nameserver/ {
                print $2
            }' /etc/resolv.conf |
            tr '\n' ' '
        )
    fi

    [ -z "$dns" ] && dns="未获取到"

    echo "$dns"
}

# ============================================================
# 网络状态
# ============================================================

get_network_status() {

    if command -v ip >/dev/null 2>&1; then

        if ip route 2>/dev/null |
           grep -q '^default'; then

            echo " 网络已连接"

        else

            echo " 无默认网络路由"
        fi

    else

        echo " 未知"
    fi
}

# ============================================================
# 信息菜单
# ============================================================

show_info() {

    local ip
    local ips
    local mac
    local dns
    local status

    ip=$(get_local_ip)
    ips=$(get_all_ips)
    mac=$(get_mac)
    dns=$(get_dns)
    status=$(get_network_status)

    whiptail \
        --title "系统 / 网络信息" \
        --scrolltext \
        --msgbox \
" IP 地址
--------------------------------------------------
 默认 IPv4 : $ip

 本机 IPv4:
$ips

 MAC 地址
--------------------------------------------------
$mac

 DNS 服务器
--------------------------------------------------
$dns

 网络状态
--------------------------------------------------
$status

 主机名
--------------------------------------------------
$(hostname 2>/dev/null || echo "未知")" \
        25 75
}

# ============================================================
# 文件浏览器
# ============================================================

file_browser() {

    local current_dir="${1:-$(pwd)}"

    while true; do

        local items=()
        local paths=()

        # 返回上级
        if [ "$current_dir" != "/" ]; then

            items+=("..")
            items+=("返回上级目录")
            paths+=("..")
        fi

        # 使用 find，避免目录为空时 glob 出现 *
        while IFS= read -r entry; do

            [ -e "$entry" ] || continue

            local name
            name=$(basename "$entry")

            if [ -d "$entry" ]; then

                items+=("$name/")
                items+=("目录")
                paths+=("$entry")

            else

                items+=("$name")
                items+=("文件")
                paths+=("$entry")

            fi

        done < <(
            find "$current_dir" \
                -mindepth 1 \
                -maxdepth 1 \
                -print 2>/dev/null |
            sort
        )

        if [ "${#items[@]}" -eq 0 ]; then

            items=(
                "(空)"
                " 当前目录为空"
            )

            paths=(
                ""
            )
        fi

        local choice

        choice=$(
            whiptail \
                --title "选择投放内容" \
                --menu \
" 当前路径：

$current_dir

 选择文件或进入文件夹。" \
                22 80 12 \
                "${items[@]}" \
                3>&1 1>&2 2>&3
        )

        local ret=$?

        if [ "$ret" -ne 0 ]; then
            return 1
        fi

        if [ "$choice" = ".." ]; then

            current_dir=$(dirname "$current_dir")
            continue
        fi

        local selected=""

        for i in "${!paths[@]}"; do

            local filename
            filename=$(basename "${paths[$i]}")

            if [ "$filename" = "${choice%/}" ]; then
                selected="${paths[$i]}"
                break
            fi
        done

        if [ -z "$selected" ]; then
            continue
        fi

        if [ -d "$selected" ]; then

            current_dir="$selected"

        elif [ -f "$selected" ]; then

            echo "$selected"
            return 0

        fi
    done
}

# ============================================================
# 手动输入内容
# ============================================================

input_content() {

    local content

    content=$(
        whiptail \
            --title "设置投放内容" \
            --inputbox \
" 请输入文件或文件夹路径。

 例如：

 /home/user/www
 /home/user/www/index.html
 ~/website" \
            15 75 "" \
            3>&1 1>&2 2>&3
    )

    local ret=$?

    [ "$ret" -ne 0 ] && return 1

    content="${content/#\~/$HOME}"

    if [ ! -e "$content" ]; then

        whiptail \
            --title "错误" \
            --msgbox \
" 路径不存在：

$content" \
            10 65

        return 1
    fi

    echo "$content"
}

# ============================================================
# 选择投放内容
# ============================================================

choose_content() {

    local choice

    choice=$(
        whiptail \
            --title "设置投放内容" \
            --menu \
" 请选择投放内容来源：" \
            15 70 4 \
            "1" "文件浏览器" \
            "2" "手动输入地址" \
            "3" "取消" \
            3>&1 1>&2 2>&3
    )

    [ $? -ne 0 ] && return 1

    case "$choice" in

        1)
            file_browser "$(pwd)"
            ;;

        2)
            input_content
            ;;

        *)
            return 1
            ;;
    esac
}

# ============================================================
# 设置进程模式
# ============================================================

choose_mode() {

    local choice

    choice=$(
        whiptail \
            --title "一、设置进程" \
            --radiolist \
" 选择投放进程模式：

 ↑ ↓ 选择
 空格切换
 Enter 确认" \
            15 65 2 \
            "single" "单进程" ON \
            "multi"  "多进程" OFF \
            3>&1 1>&2 2>&3
    )

    [ $? -ne 0 ] && return 1

    DEPLOY_MODE="$choice"
}

# ============================================================
# 设置多进程 ID
# ============================================================

choose_process_ids() {

    if [ "$DEPLOY_MODE" != "multi" ]; then
        DEPLOY_ID=""
        return 0
    fi

    DEPLOY_ID=$(
        whiptail \
            --title "三、多进程专属：进程 ID 设置" \
            --inputbox \
" 请输入多个进程 ID。

 使用英文逗号分隔。

 例如：

 blog,docs,test

 那么：

 blog
 docs
 test

 分别对应不同投放进程。

/sr 只是示例，不会自动使用。" \
            18 75 "" \
            3>&1 1>&2 2>&3
    )

    [ $? -ne 0 ] && return 1

    if [ -z "$DEPLOY_ID" ]; then

        msgbox " 多进程模式下，进程 ID 不能为空。"

        return 1
    fi
}

# ============================================================
# 设置端口
# ============================================================

choose_port() {

    DEPLOY_PORT=$(
        whiptail \
            --title "四、投放端口号" \
            --inputbox \
" 请输入投放端口。

 例如：

 8080
 8000
 3000

 多进程模式下：
 第一个进程使用此端口，
 之后的进程自动递增。" \
            16 70 "8080" \
            3>&1 1>&2 2>&3
    )

    [ $? -ne 0 ] && return 1

    if ! [[ "$DEPLOY_PORT" =~ ^[0-9]+$ ]] ||
       [ "$DEPLOY_PORT" -lt 1 ] ||
       [ "$DEPLOY_PORT" -gt 65535 ]; then

        msgbox " 端口号无效。"

        return 1
    fi
}

# ============================================================
# 设置投放标识
# ============================================================

choose_bind() {

    local local_ip
    local choice

    local_ip=$(get_local_ip)

    choice=$(
        whiptail \
            --title "五、投放标识" \
            --radiolist \
" 选择 Web Server 监听地址：

 0.0.0.0   = 所有网络接口
 127.0.0.1 = 仅本机
 localhost = 仅本机
 IP Address = 本机 IPv4" \
            18 75 4 \
            "0.0.0.0" "所有接口 / 局域网可访问" OFF \
            "127.0.0.1" "本机回环地址" OFF \
            "localhost" "本地域名" OFF \
            "IP Address" "$local_ip" ON \
            3>&1 1>&2 2>&3
    )

    [ $? -ne 0 ] && return 1

    case "$choice" in

        "0.0.0.0")
            DEPLOY_BIND="0.0.0.0"
            ;;

        "127.0.0.1")
            DEPLOY_BIND="127.0.0.1"
            ;;

        "localhost")
            # localhost 用于显示，
            # Python 实际 bind 使用 127.0.0.1
            DEPLOY_BIND="127.0.0.1"
            ;;

        "IP Address")
            DEPLOY_BIND="$local_ip"
            ;;

        *)
            return 1
            ;;
    esac
}

# ============================================================
# URL Host
# ============================================================

get_display_host() {

    case "$DEPLOY_BIND" in

        "0.0.0.0")
            get_local_ip
            ;;

        *)
            echo "$DEPLOY_BIND"
            ;;
    esac
}

# ============================================================
# 启动单个 Python Server
# ============================================================

start_server() {

    local content="$1"
    local port="$2"
    local bind="$3"
    local prefix="$4"

    local logfile
    logfile=$(get_log_file)

    local args=()

    args+=(
        python3
        "$PYTHON_SERVER"
        --bind "$bind"
        --port "$port"
        --content "$content"
        --log "$logfile"
    )

    if [ -n "$prefix" ]; then
        args+=(--prefix "$prefix")
    fi

    write_log "启动服务器"
    write_log "Content = $content"
    write_log "Bind    = $bind"
    write_log "Port    = $port"
    write_log "Prefix  = ${prefix:-/}"

    (
        "${args[@]}"
    ) >> "$logfile" 2>&1 &

    local pid=$!

    sleep 1

    if kill -0 "$pid" 2>/dev/null; then

        echo "$pid"

        write_log " 服务器启动成功 PID=$pid"

        return 0

    else

        write_log " 服务器启动失败"

        return 1
    fi
}

# ============================================================
# 检查端口
# ============================================================

check_port() {

    local port="$1"

    if command -v ss >/dev/null 2>&1; then

        if ss -lnt 2>/dev/null |
           awk '{print $4}' |
           grep -Eq ":${port}$"; then

            return 1
        fi

    elif command -v netstat >/dev/null 2>&1; then

        if netstat -lnt 2>/dev/null |
           awk '{print $4}' |
           grep -Eq ":${port}$"; then

            return 1
        fi
    fi

    return 0
}

# ============================================================
# 记录进程
# ============================================================

register_job() {

    local pid="$1"
    local url="$2"
    local content="$3"
    local port="$4"
    local bind="$5"
    local id="$6"

    RUNNING_JOBS+=(
        "$pid|$url|$content|$port|$bind|$id"
    )

    echo "$pid" > "${PID_DIR}/${pid}.pid"
}

# ============================================================
# 执行投放
# ============================================================

execute_deploy() {

    local content="$DEPLOY_CONTENT"
    local base_port="$DEPLOY_PORT"
    local bind="$DEPLOY_BIND"

    if [ ! -e "$content" ]; then

        msgbox " 投放内容不存在：

$content"

        return 1
    fi

    # --------------------------------------------------------
    # 单进程
    # --------------------------------------------------------

    if [ "$DEPLOY_MODE" = "single" ]; then

        if ! check_port "$base_port"; then

            msgbox " 端口 $base_port 已经被占用。"

            return 1
        fi

        local pid

        pid=$(
            start_server \
                "$content" \
                "$base_port" \
                "$bind" \
                ""
        )

        if [ -z "$pid" ]; then

            msgbox " 服务器启动失败。

 请查看：
$(get_log_file)"

            return 1
        fi

        local host
        host=$(get_display_host)

        local url

        if [ -f "$content" ]; then

            url="http://${host}:${base_port}/$(basename "$content")"

        else

            url="http://${host}:${base_port}/"
        fi

        register_job \
            "$pid" \
            "$url" \
            "$content" \
            "$base_port" \
            "$bind" \
            ""

        write_log " 单进程部署完成"
        write_log "PID=$pid"
        write_log "URL=$url"

        whiptail \
            --title "部署完成" \
            --msgbox \
" 网页投放成功！

 PID:
$pid

 监听:
$bind

 端口:
$base_port

 内容:
$content

 访问地址:
$url

 日志:
$(get_log_file)

 即将返回 MainMENU。" \
            20 75

        return 0
    fi

    # --------------------------------------------------------
    # 多进程
    # --------------------------------------------------------

    local id_array=()

    IFS=',' read -ra id_array <<< "$DEPLOY_ID"

    local index=0

    for raw_id in "${id_array[@]}"; do

        local id

        # 删除首尾空格
        id=$(echo "$raw_id" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        if [ -z "$id" ]; then
            continue
        fi

        # URL ID 安全检查
        if [[ ! "$id" =~ ^[A-Za-z0-9._~-]+$ ]]; then

            write_log "非法进程 ID: $id"

            msgbox \
"进程 ID 无效：

$id

只能使用：
A-Z
a-z
0-9
.
_
-
~"

            return 1
        fi

        local actual_port=$((base_port + index))

        if [ "$actual_port" -gt 65535 ]; then

            msgbox " 端口超出 65535。"

            return 1
        fi

        if ! check_port "$actual_port"; then

            msgbox \
" 端口已经被占用：

$actual_port

进程 ID:
$id"

            return 1
        fi

        local pid

        pid=$(
            start_server \
                "$content" \
                "$actual_port" \
                "$bind" \
                "$id"
        )

        if [ -z "$pid" ]; then

            msgbox \
" 进程启动失败。

ID:
$id

端口:
$actual_port"

            return 1
        fi

        local host
        host=$(get_display_host)

        local url

        url="http://${host}:${actual_port}/${id}/"

        register_job \
            "$pid" \
            "$url" \
            "$content" \
            "$actual_port" \
            "$bind" \
            "$id"

        write_log " 多进程部署完成"
        write_log "PID=$pid"
        write_log "ID=$id"
        write_log "URL=$url"

        ((index++))

    done

    whiptail \
        --title "多进程部署完成" \
        --msgbox \
" 多进程投放完成！

进程数量:
$index

基础端口:
$base_port

监听:
$bind

内容:
$content

访问地址和 PID 可以在：

MainMENU
→ 进程预览

中查看。

即将返回 MainMENU。" \
        20 75

    return 0
}

# ============================================================
# 进程是否仍然存在
# ============================================================

is_process_running() {

    local pid="$1"

    kill -0 "$pid" 2>/dev/null
}

# ============================================================
# 清理失效进程
# ============================================================

cleanup_jobs() {

    local new_jobs=()

    for job in "${RUNNING_JOBS[@]}"; do

        IFS='|' read -r \
            pid url content port bind id <<< "$job"

        if is_process_running "$pid"; then

            new_jobs+=("$job")

        else

            rm -f "${PID_DIR}/${pid}.pid"

            write_log "发现进程已退出 PID=$pid"
        fi
    done

    RUNNING_JOBS=("${new_jobs[@]}")
}

# ============================================================
# 进程预览
# ============================================================

process_preview() {

    while true; do

        cleanup_jobs

        if [ "${#RUNNING_JOBS[@]}" -eq 0 ]; then

            whiptail \
                --title "进程预览" \
                --msgbox \
" 当前没有正在运行的 WebDrop 进程。" \
                10 60

            return
        fi

        local menu_items=()

        for job in "${RUNNING_JOBS[@]}"; do

            IFS='|' read -r \
                pid url content port bind id <<< "$job"

            local desc

            desc="端口:$port | 地址:$bind"

            if [ -n "$id" ]; then
                desc="$desc | ID:$id"
            fi

            menu_items+=(
                "$pid"
                "$desc"
            )
        done

        menu_items+=(
            "RETURN"
            " 返回 MainMENU"
        )

        local choice

        choice=$(
            whiptail \
                --title "进程预览" \
                --menu \
" 当前 WebDrop 进程：

 使用 ↑ ↓ 选择进程。" \
                22 90 12 \
                "${menu_items[@]}" \
                3>&1 1>&2 2>&3
        )

        [ $? -ne 0 ] && return

        [ "$choice" = "RETURN" ] && return

        local selected_job=""

        for job in "${RUNNING_JOBS[@]}"; do

            IFS='|' read -r pid _ <<< "$job"

            if [ "$pid" = "$choice" ]; then

                selected_job="$job"
                break
            fi
        done

        [ -z "$selected_job" ] && continue

        IFS='|' read -r \
            pid url content port bind id <<< "$selected_job"

        local action

        action=$(
            whiptail \
                --title "进程管理" \
                --menu \
"PID:
$pid

URL:
$url

内容:
$content

端口:
$port

监听:
$bind

ID:
${id:-无}" \
                20 75 4 \
                "1" "查看详细信息" \
                "2" "停止进程" \
                "3" "强制停止进程" \
                "4" "返回" \
                3>&1 1>&2 2>&3
        )

        [ $? -ne 0 ] && continue

        case "$action" in

            1)

                local process_info

                process_info=$(
                    ps -p "$pid" \
                        -o pid,ppid,user,etime,cmd \
                        2>/dev/null
                )

                whiptail \
                    --title "进程详细信息" \
                    --scrolltext \
                    --msgbox \
"PID:
$pid

URL:
$url

内容:
$content

端口:
$port

监听:
$bind

ID:
${id:-无}

进程状态:
$process_info" \
                    20 100

                ;;

            2)

                if kill "$pid" 2>/dev/null; then

                    write_log "停止进程 PID=$pid ID=${id:-none}"

                    msgbox "进程 $pid 已停止。"

                else

                    msgbox "无法停止进程 $pid。"

                fi

                ;;

            3)

                if kill -9 "$pid" 2>/dev/null; then

                    write_log "强制停止进程 PID=$pid ID=${id:-none}"

                    msgbox "进程 $pid 已强制停止。"

                else

                    msgbox "无法停止进程 $pid。"

                fi

                ;;

            4)
                ;;
        esac
    done
}

# ============================================================
# 投放菜单
# ============================================================

deploy_menu() {

    if ! check_python; then
        return
    fi

    # --------------------------------------------------------
    # 一、设置进程
    # --------------------------------------------------------

    if ! choose_mode; then
        return
    fi

    # --------------------------------------------------------
    # 二、设置投放内容
    # --------------------------------------------------------

    DEPLOY_CONTENT=$(choose_content)

    if [ -z "$DEPLOY_CONTENT" ]; then

        msgbox "没有选择投放内容。"

        return
    fi

    # --------------------------------------------------------
    # 三、多进程 ID
    # --------------------------------------------------------

    if ! choose_process_ids; then
        return
    fi

    # --------------------------------------------------------
    # 四、端口
    # --------------------------------------------------------

    if ! choose_port; then
        return
    fi

    # --------------------------------------------------------
    # 五、投放标识
    # --------------------------------------------------------

    if ! choose_bind; then
        return
    fi

    # --------------------------------------------------------
    # 确认
    # --------------------------------------------------------

    local confirm

    confirm="进程模式:
$DEPLOY_MODE

投放内容:
$DEPLOY_CONTENT

端口:
$DEPLOY_PORT

监听地址:
$DEPLOY_BIND"

    if [ "$DEPLOY_MODE" = "multi" ]; then

        confirm="$confirm

进程 ID:
$DEPLOY_ID

说明:
第一个进程使用 $DEPLOY_PORT
之后端口自动递增。"
    fi

    if whiptail \
        --title "确认投放" \
        --yesno \
"$confirm

是否开始部署？" \
        20 75; then

        write_log "========================================"
        write_log "开始新的部署"
        write_log "模式=$DEPLOY_MODE"
        write_log "内容=$DEPLOY_CONTENT"
        write_log "端口=$DEPLOY_PORT"
        write_log "监听=$DEPLOY_BIND"

        if [ "$DEPLOY_MODE" = "multi" ]; then
            write_log "ID=$DEPLOY_ID"
        fi

        execute_deploy

        # execute_deploy 完成后直接回到 MainMENU
        return
    fi
}

# ============================================================
# 日志菜单
# ============================================================

show_logs() {

    local logs=()

    while IFS= read -r file; do

        [ -f "$file" ] || continue

        logs+=("$file")

    done < <(
        find "$LOG_DIR" \
            -maxdepth 1 \
            -type f \
            -name '*.log' |
        sort -r
    )

    if [ "${#logs[@]}" -eq 0 ]; then

        msgbox "目前没有日志。"

        return
    fi

    local menu_items=()

    for file in "${logs[@]}"; do

        local date

        date=$(basename "$file" .log)

        menu_items+=(
            "$date"
            "日志"
        )
    done

    local choice

    choice=$(
        whiptail \
            --title "日志" \
            --menu \
"日志按照日期保存：

选择日期查看。" \
            20 70 12 \
            "${menu_items[@]}" \
            3>&1 1>&2 2>&3
    )

    [ $? -ne 0 ] && return

    local logfile="${LOG_DIR}/${choice}.log"

    if [ -f "$logfile" ]; then

        whiptail \
            --title "日志 - $choice" \
            --textbox "$logfile" \
            30 110

    else

        msgbox "日志不存在。"
    fi
}

# ============================================================
# 主菜单 MainMENU
# ============================================================

main_menu() {

    while true; do

        cleanup_jobs

        local choice

        choice=$(
            whiptail \
                --title "WebDrop - MainMENU" \
                --menu \
" WebDrop 投放

 使用 ↑ ↓ 选择功能，Enter 确认。" \
                18 80 5 \
                "1" "启动投放设置" \
                "2" "启动进程预览" \
                "3" "查看本机信息" \
                "4" "查看投放日志" \
                "5" "退出投放终端" \
                3>&1 1>&2 2>&3
        )

        local ret=$?

        if [ "$ret" -ne 0 ]; then

            clear
            echo "WebDrop 已退出。"
            exit 0
        fi

        case "$choice" in

            1)
                deploy_menu
                ;;

            2)
                process_preview
                ;;

            3)
                show_info
                ;;

            4)
                show_logs
                ;;

            5)
                clear
                echo "WebDrop 已退出。"
                exit 0
                ;;

        esac
    done
}

# ============================================================
# 初始化
# ============================================================

if ! command -v whiptail >/dev/null 2>&1; then

    echo "错误：需要 whiptail。"
    echo
    echo "Debian / Ubuntu:"
    echo "  sudo apt install whiptail"
    echo
    echo "Termux:"
    echo "  pkg install newt"

    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then

    echo "警告：没有 Python3。"
    echo "请安装 Python3 后再运行。"

fi

create_python_server

write_log "WebDrop 启动"

main_menu