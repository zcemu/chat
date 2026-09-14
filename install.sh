#!/usr/bin/env bash

set -e
export UUID=${UUID:-$(cat /proc/sys/kernel/random/uuid 2>/dev/null)}
export DEBIAN_FRONTEND=noninteractive

APP_DIR="/opt/myapp"
STATE_FILE="${APP_DIR}/.project_type"
APP_NAME=$(tr -dc a-z </dev/urandom | head -c 6)
export ARGO_PORT=${ARGO_PORT:-'8001'} 
export ARGO_DOMAIN=${ARGO_DOMAIN}
export ARGO_AUTH=${ARGO_AUTH}
export NEZHA_SERVER=${NEZHA_SERVER}
export NEZHA_PORT=${NEZHA_PORT}
export NEZHA_KEY=${NEZHA_KEY}
export SUB_PATH=${SUB_PATH}

[[ $EUID -ne 0 ]] && echo -e "\033[1;91m请用root用户下运行脚本，输入：sudo -i 切换到root用户后再次运行！\033[0m" && exit 1

pkill -f '\.npm/' >/dev/null 2>&1 || true
pkill -f '\.cache/' >/dev/null 2>&1 || true

if [[ "$1" == "-u" || "$1" == "u" || "$1" == "uninstall" ]]; then
    echo "执行卸载操作..."
    if [[ -f "${STATE_FILE}" ]]; then
        INSTALLED_TYPE=$(cat "${STATE_FILE}")
        echo "检测到已安装项目: ${INSTALLED_TYPE}"
    else
        echo "未检测到项目状态文件，将执行清理..."
        INSTALLED_TYPE="unknown"
    fi

    pkill -f '\.npm/' >/dev/null 2>&1 || true
    pkill -f '\.cache/' >/dev/null 2>&1 || true
    pm2 delete all 2>/dev/null || true
    pm2 save >/dev/null 2>&1 || true

    pm2 unstartup systemd -u root --hp /root >/dev/null 2>&1 || true
    rm -rf "${APP_DIR}"
    echo -e "\e[1;32m卸载完成\033[0m"
    exit 0
fi

if [[ "$1" == "-js" || "$1" == "js" || "$1" == "nodejs" ]]; then
    PROJECT_TYPE="nodejs"
elif [[ "$1" == "-py" || "$1" == "py" || "$1" == "python" ]]; then
    PROJECT_TYPE="python"
elif [[ -z "$1" ]]; then
    RANDOM_CHOICE=$((RANDOM % 2))
    if [[ $RANDOM_CHOICE -eq 0 ]]; then
        PROJECT_TYPE="nodejs"
    else
        PROJECT_TYPE="python"
    fi
else
    exit 1
fi

apt-get update -qq
apt-get install -y -qq curl wget git ca-certificates gnupg >/dev/null 2>&1

mkdir -p "${APP_DIR}"
echo "${PROJECT_TYPE}" > "${STATE_FILE}"
cd "${APP_DIR}"

if [[ "$PROJECT_TYPE" == "nodejs" ]]; then
    if ! command -v node &> /dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_current.x | bash - >/dev/null 2>&1
        apt-get install -y -qq nodejs >/dev/null 2>&1
    fi

    if ! command -v pm2 &> /dev/null; then
        npm install -g pm2 >/dev/null 2>&1
    fi

    wget -q -O index.html https://raw.githubusercontent.com/eooce/node-ws/main/index.html
    wget -q -O index.js https://raw.githubusercontent.com/eooce/Sing-box/main/nodejs/index.js

    npm init -y >/dev/null 2>&1
    npm install axios ws javascript-obfuscator >/dev/null 2>&1

    echo "UUID=${UUID}" > "${APP_DIR}/.env"
    echo "SHOW_LOG=no" >> "${APP_DIR}/.env"
    [[ -n "${SUB_PATH}" ]] && echo "SUB_PATH=${SUB_PATH}" >> "${APP_DIR}/.env"
    [[ -n "${NEZHA_SERVER}" ]] && echo "NEZHA_SERVER=${NEZHA_SERVER}" >> "${APP_DIR}/.env"
    [[ -n "${NEZHA_PORT}" ]] && echo "NEZHA_PORT=${NEZHA_PORT}" >> "${APP_DIR}/.env"
    [[ -n "${NEZHA_KEY}" ]] && echo "NEZHA_KEY=${NEZHA_KEY}" >> "${APP_DIR}/.env"
    [[ -n "${ARGO_DOMAIN}" ]] && echo "ARGO_DOMAIN=${ARGO_DOMAIN}" >> "${APP_DIR}/.env"
    [[ -n "${ARGO_AUTH}" ]] && echo "ARGO_AUTH=${ARGO_AUTH}" >> "${APP_DIR}/.env"
    [[ -n "${ARGO_PORT}" ]] && echo "ARGO_PORT=${ARGO_PORT}" >> "${APP_DIR}/.env"

    npx javascript-obfuscator index.js --output ${APP_NAME}.js --compact true >/dev/null 2>&1
    rm -f index.js >/dev/null 2>&1

    # 强制规范化输出标准明文节点（确保路由器与在线聚合 100% 兼容）
    mkdir -p "${APP_DIR}/.npm"
    cat <<EOF > "${APP_DIR}/.npm/sub.txt"
vless://${UUID}@${ARGO_DOMAIN}:443?encryption=none&security=tls&type=ws&host=${ARGO_DOMAIN}&path=%2F&sni=${ARGO_DOMAIN}#Argo-Plain-Node
EOF

    set -a; source "${APP_DIR}/.env"; set +a
    pm2 start ${APP_NAME}.js --name "${APP_NAME}" >/dev/null 2>&1

elif [[ "$PROJECT_TYPE" == "python" ]]; then
    if ! command -v python3 &> /dev/null; then
        apt-get install -y -qq python3 python3-venv python3-pip >/dev/null 2>&1
    fi

    if ! command -v pm2 &> /dev/null; then
        if ! command -v node &> /dev/null; then
            curl -fsSL https://deb.nodesource.com/setup_current.x | bash - >/dev/null 2>&1
            apt-get install -y -qq nodejs >/dev/null 2>&1
        fi
        npm install -g pm2 >/dev/null 2>&1
    fi

    wget -q -O app.py https://raw.githubusercontent.com/eooce/Sing-box/main/python/app.py
    wget -q -O index.html https://github.com/eooce/python-ws/raw/refs/heads/main/index.html
    python3 -m venv venv
    source venv/bin/activate

    echo "UUID=${UUID}" > "${APP_DIR}/.env"
    echo "SHOW_LOG=no" >> "${APP_DIR}/.env"
    [[ -n "${SUB_PATH}" ]] && echo "SUB_PATH=${SUB_PATH}" >> "${APP_DIR}/.env"
    [[ -n "${NEZHA_SERVER}" ]] && echo "NEZHA_SERVER=${NEZHA_SERVER}" >> "${APP_DIR}/.env"
    [[ -n "${NEZHA_PORT}" ]] && echo "NEZHA_PORT=${NEZHA_PORT}" >> "${APP_DIR}/.env"
    [[ -n "${NEZHA_KEY}" ]] && echo "NEZHA_KEY=${NEZHA_KEY}" >> "${APP_DIR}/.env"
    [[ -n "${ARGO_DOMAIN}" ]] && echo "ARGO_DOMAIN=${ARGO_DOMAIN}" >> "${APP_DIR}/.env"
    [[ -n "${ARGO_AUTH}" ]] && echo "ARGO_AUTH=${ARGO_AUTH}" >> "${APP_DIR}/.env"
    [[ -n "${ARGO_PORT}" ]] && echo "ARGO_PORT=${ARGO_PORT}" >> "${APP_DIR}/.env"

    mv app.py ${APP_NAME}.py

    # 强制规范化输出标准明文节点
    mkdir -p "${APP_DIR}/.cache"
    cat <<EOF > "${APP_DIR}/.cache/sub.txt"
vless://${UUID}@${ARGO_DOMAIN}:443?encryption=none&security=tls&type=ws&host=${ARGO_DOMAIN}&path=%2F&sni=${ARGO_DOMAIN}#Argo-Plain-Node
EOF

    set -a; source "${APP_DIR}/.env"; set +a
    pm2 start ${APP_NAME}.py --name "${APP_NAME}" --interpreter "${APP_DIR}/venv/bin/python3" >/dev/null 2>&1
fi

pm2 startup systemd -u root --hp /root >/dev/null 2>&1
pm2 save >/dev/null 2>&1

sleep 5
echo -e "\e[1;32m安装完成（已转换为完美明文格式）\e[1;37m"
if [ "$PROJECT_TYPE" == "nodejs" ]; then
    cat ${APP_DIR}/.npm/sub.txt
elif [ "$PROJECT_TYPE" == "python" ]; then
    cat ${APP_DIR}/.cache/sub.txt
fi
exit 0