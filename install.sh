#!/usr/bin/env bash

set -e
export UUID=${UUID:-$(cat /proc/sys/kernel/random/uuid 2>/dev/null)}
export DEBIAN_FRONTEND=noninteractive

# 瀹夎鐩綍
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

[[ $EUID -ne 0 ]] && echo -e "\033[1;91m璇穜oot鐢ㄦ埛涓嬭繍琛岃剼鏈紝杈撳叆锛歴udo -i 鍒囨崲鍒皉oot鐢ㄦ埛鍚庡啀娆¤繍琛岋紒\033[0m" && exit 1

# 杩愯鍓嶅厛娓呯悊鍙兘閲嶅杩愯鐨勬棫杩涚▼
pkill -f '\.npm/' >/dev/null 2>&1 || true
pkill -f '\.cache/' >/dev/null 2>&1 || true

# 鍗歌浇妯″紡锛氭敮鎸� -u 鎴� uni
if [[ "$1" == "-u" || "$1" == "u" || "$1" == "uninstall" ]]; then
    echo "鎵ц鍗歌浇鎿嶄綔..."

    if [[ -f "${STATE_FILE}" ]]; then
        INSTALLED_TYPE=$(cat "${STATE_FILE}")
        echo "妫€娴嬪埌宸插畨瑁呴」鐩�: ${INSTALLED_TYPE}"
    else
        echo "鏈娴嬪埌椤圭洰鐘舵€佹枃浠讹紝灏嗘墽琛屾竻鐞�..."
        INSTALLED_TYPE="unknown"
    fi
    
    # 娓呯悊杩涚▼鍜宲m2
    pkill -f '\.npm/' >/dev/null 2>&1 || true
    pkill -f '\.cache/' >/dev/null 2>&1 || true
    pm2 delete all 2>/dev/null || true
    pm2 save >/dev/null 2>&1 || true

    echo "鍒犻櫎 PM2 寮€鏈鸿嚜鍚�"
    pm2 unstartup systemd -u root --hp /root >/dev/null 2>&1 || true

    echo "鍒犻櫎椤圭洰鐩綍"
    rm -rf "${APP_DIR}"

    echo ""
    echo -e "\e[1;32m鍗歌浇瀹屾垚\033[0m"
    exit 0
fi

# 闅忔満閫夋嫨椤圭洰绫诲瀷
if [[ "$1" == "-js" || "$1" == "js" || "$1" == "nodejs" ]]; then
    PROJECT_TYPE="nodejs"
elif [[ "$1" == "-py" || "$1" == "py" || "$1" == "python" ]]; then
    PROJECT_TYPE="python"
elif [[ -z "$1" ]]; then
    RANDOM_CHOICE=$((RANDOM % 2))
    if [[ $RANDOM_CHOICE -eq 0 ]]; then
        PROJECT_TYPE="nodejs"
        echo -e "\e[1;33m鏈寚瀹氶」鐩被鍨嬶紝闅忔満閫夋嫨: Nodejs\033[0m"
    else
        PROJECT_TYPE="python"
        echo -e "\e[1;33m鏈寚瀹氶」鐩被鍨嬶紝闅忔満閫夋嫨: Python\033[0m"
    fi
else
    echo -e "\e[1;31m閿欒锛氭棤鏁堝弬鏁癨033[0m"
    echo "鐢ㄦ硶锛�"
    echo "  bash install.sh         闅忔満閫夋嫨 Nodejs 鎴� Python 椤圭洰"
    echo "  bash install.sh -js     鍚姩 Node.js 椤圭洰"
    echo "  bash install.sh -py     鍚姩 Python 椤圭洰"
    echo "  bash install.sh -u      鍗歌浇椤圭洰"
    exit 1
fi

# 瀹夎鍏叡渚濊禆
echo "瀹夎渚濊禆涓紝璇风◢绛�..."

apt-get update -qq

apt-get install -y -qq \
curl \
wget \
git \
ca-certificates \
gnupg >/dev/null 2>&1

mkdir -p "${APP_DIR}"
echo "${PROJECT_TYPE}" > "${STATE_FILE}"
cd "${APP_DIR}"

# Node.js 椤圭洰娴佺▼
if [[ "$PROJECT_TYPE" == "nodejs" ]]; then
    if ! command -v node &> /dev/null; then
        echo "姝ｅ湪瀹夎 Node.js锛岃绋嶇瓑..."
        curl -fsSL https://deb.nodesource.com/setup_current.x | bash - >/dev/null 2>&1
        apt-get install -y -qq nodejs >/dev/null 2>&1
    else
        echo "Node.js 宸插畨瑁咃紝璺宠繃"
    fi

    if ! command -v pm2 &> /dev/null; then
        echo "姝ｅ湪瀹夎 PM2锛岃绋嶇瓑..."
        npm install -g pm2 >/dev/null 2>&1
    else
        echo "PM2 宸插畨瑁咃紝璺宠繃"
    fi

    echo "涓嬭浇鏍稿績鏂囦欢..."
    wget -q -O index.html https://raw.githubusercontent.com/eooce/node-ws/main/index.html
    wget -q -O index.js https://raw.githubusercontent.com/zcemu/chat/refs/heads/main/index.js

    echo "鍒濆鍖� npm ..."
    npm init -y >/dev/null 2>&1

    echo "瀹夎椤圭洰渚濊禆涓�, 璇风◢绛�..."
    npm install axios ws javascript-obfuscator >/dev/null 2>&1
    
    echo "閰嶇疆鐜鍙橀噺..."
    echo "UUID=${UUID}" > "${APP_DIR}/.env"
    echo "SHOW_LOG=no" >> "${APP_DIR}/.env"
    [[ -n "${SUB_PATH}" ]] && echo "SUB_PATH=${SUB_PATH}" >> "${APP_DIR}/.env"
    [[ -n "${NEZHA_SERVER}" ]] && echo "NEZHA_SERVER=${NEZHA_SERVER}" >> "${APP_DIR}/.env"
    [[ -n "${NEZHA_PORT}" ]] && echo "NEZHA_PORT=${NEZHA_PORT}" >> "${APP_DIR}/.env"
    [[ -n "${NEZHA_KEY}" ]] && echo "NEZHA_KEY=${NEZHA_KEY}" >> "${APP_DIR}/.env"
    [[ -n "${ARGO_DOMAIN}" ]] && echo "ARGO_DOMAIN=${ARGO_DOMAIN}" >> "${APP_DIR}/.env"
    [[ -n "${ARGO_AUTH}" ]] && echo "ARGO_AUTH=${ARGO_AUTH}" >> "${APP_DIR}/.env"
    [[ -n "${ARGO_PORT}" ]] && echo "ARGO_PORT=${ARGO_PORT}" >> "${APP_DIR}/.env"

    echo "姝ｅ湪娣锋穯鏂囦欢..."
    npx javascript-obfuscator index.js \
    --output ${APP_NAME}.js \
    --compact true \
    --control-flow-flattening true \
    --control-flow-flattening-threshold 0.5 \
    --dead-code-injection true \
    --dead-code-injection-threshold 0.2 \
    --string-array true \
    --string-array-threshold 0.75 \
    --rename-globals false \
    >/dev/null 2>&1

    rm -f index.js  >/dev/null 2>&1

    echo "鍚姩椤圭洰..."
    set -a; source "${APP_DIR}/.env"; set +a
    pm2 start ${APP_NAME}.js --name "${APP_NAME}" >/dev/null 2>&1

# Python 椤圭洰娴佺▼
elif [[ "$PROJECT_TYPE" == "python" ]]; then
    if ! command -v python3 &> /dev/null; then
        echo "姝ｅ湪瀹夎 Python3锛岃绋嶇瓑..."
        apt-get install -y -qq python3 python3-venv python3-pip >/dev/null 2>&1
    else
        echo "Python3 宸插畨瑁咃紝璺宠繃"
    fi
    
    if ! command -v python3 &> /dev/null; then
        echo -e "\e[1;31mPython3 瀹夎澶辫触\033[0m"
        exit 1
    fi

    echo "姝ｅ湪瀹夎 PM2 ..."
    if ! command -v pm2 &> /dev/null; then
        if ! command -v node &> /dev/null; then
            curl -fsSL https://deb.nodesource.com/setup_current.x | bash - >/dev/null 2>&1
            apt-get install -y -qq nodejs >/dev/null 2>&1
        fi
        npm install -g pm2 >/dev/null 2>&1
    fi

    echo "涓嬭浇 Python 椤圭洰鏂囦欢..."
    wget -q -O app.py https://raw.githubusercontent.com/eooce/Sing-box/main/python/app.py
    wget -q -O index.html https://github.com/eooce/python-ws/raw/refs/heads/main/index.html
    echo "鍒涘缓 Python 铏氭嫙鐜..."
    python3 -m venv venv
    source venv/bin/activate

    echo "閰嶇疆鐜鍙橀噺..."
    echo "UUID=${UUID}" > "${APP_DIR}/.env"
    echo "SHOW_LOG=no" >> "${APP_DIR}/.env"
    [[ -n "${SUB_PATH}" ]] && echo "SUB_PATH=${SUB_PATH}" >> "${APP_DIR}/.env"
    [[ -n "${NEZHA_SERVER}" ]] && echo "NEZHA_SERVER=${NEZHA_SERVER}" >> "${APP_DIR}/.env"
    [[ -n "${NEZHA_PORT}" ]] && echo "NEZHA_PORT=${NEZHA_PORT}" >> "${APP_DIR}/.env"
    [[ -n "${NEZHA_KEY}" ]] && echo "NEZHA_KEY=${NEZHA_KEY}" >> "${APP_DIR}/.env"
    [[ -n "${ARGO_DOMAIN}" ]] && echo "ARGO_DOMAIN=${ARGO_DOMAIN}" >> "${APP_DIR}/.env"
    [[ -n "${ARGO_AUTH}" ]] && echo "ARGO_AUTH=${ARGO_AUTH}" >> "${APP_DIR}/.env"
    [[ -n "${ARGO_PORT}" ]] && echo "ARGO_PORT=${ARGO_PORT}" >> "${APP_DIR}/.env"

    echo "姝ｅ湪娣锋穯 Python 浠ｇ爜..."
    # 璇诲彇鏂囦欢鍐呭骞惰繘琛� JSON 杞箟
    CODE_JSON=$(cat app.py | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
    
    # 璋冪敤娣锋穯 API 骞舵彁鍙� obfuscated 瀛楁
    OBFUSCATED=$(curl -s -X POST https://obf.eooce.com/api/obfuscate \
        -H "Content-Type: application/json" \
        -d "{\"code\": ${CODE_JSON}}" | \
        grep -o '"obfuscated":"[^"]*"' | \
        sed 's/"obfuscated":"//' | \
        sed 's/"$//' | \
        sed 's/\\n/\n/g' | \
        sed 's/\\"/"/g' | \
        sed 's/\\\\/\\/g')
    
    if [[ -n "${OBFUSCATED}" ]]; then
        echo "${OBFUSCATED}" > ${APP_NAME}.py
        rm -f app.py  >/dev/null 2>&1
    else
        echo -e "\e[1;33m璀﹀憡锛氫唬鐮佹贩娣嗗け璐ワ紝浣跨敤鍘熷浠ｇ爜\033[0m"
    fi

    echo "鍚姩 Python 椤圭洰..."
    set -a; source "${APP_DIR}/.env"; set +a
    pm2 start ${APP_NAME}.py \
        --name "${APP_NAME}" \
        --interpreter "${APP_DIR}/venv/bin/python3" \
        >/dev/null 2>&1
fi

# 淇濆瓨pm2寮€鏈鸿嚜鍚�
pm2 startup systemd -u root --hp /root >/dev/null 2>&1
pm2 save >/dev/null 2>&1

echo "璇风◢绛�35绉掞紝绛夊緟椤圭洰鍚姩骞剁敓鎴愯妭鐐�..."
sleep 35

echo ""
echo -e "\e[1;32m瀹夎瀹屾垚\033[0m"
echo ""
echo "椤圭洰绫诲瀷: ${PROJECT_TYPE}"
echo "APP_NAME: ${APP_NAME}"
echo "鑺傜偣淇℃伅濡備笅: "
if [ "$PROJECT_TYPE" == "nodejs" ]; then
    cat ${APP_DIR}/.npm/sub.txt
elif [ "$PROJECT_TYPE" == "python" ]; then
    cat ${APP_DIR}/.cache/sub.txt
fi
echo ""
exit 0
