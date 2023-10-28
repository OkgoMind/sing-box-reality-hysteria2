#!/bin/bash
# CF的优选ip
API_KEY="xxxxx"
API_EMAIL="xxxx@gmail.com"
ZONE_ID="xxxxxxxxx"
# 定义多个域名
DOMAINS=("yx1.example.com" "yx2.example.com" "yx3.example.com")
# 运行目录
pdir="/root"


arch=$(uname -m)
# Map architecture names
case ${arch} in
    x86_64)
        cf_arch="amd64"
        ;;
    aarch64)
        cf_arch="arm64"
        ;;
    armv7l)
        cf_arch="armv7"
        ;;
    armv5l)
        cf_arch="armv5"
        ;;
    armv6l)
        cf_arch="armv6"
        ;;
    mips)
        cf_arch="mips"
        ;;
    mips64|mips64el)
        cf_arch="mips64"
        ;;
    mipsle)
        cf_arch="mipsle"
        ;;
    mips64le)
        cf_arch="mips64le"
        ;;
    *)
        echo "不支持的架构: ${arch}"
        exit 1
        ;;
esac

# install cloudflareST
cf_url="https://github.com/XIU2/CloudflareSpeedTest/releases/latest/download/CloudflareST_linux_${cf_arch}.tar.gz"
curl -sLo "$pdir/cloudflaredST.tar.gz" "$cf_url"
# 解压cloudflaredST.tar.gz文件
mkdir -p "$pdir/CF"
tar -xzf "$pdir/cloudflaredST.tar.gz" -C "$pdir/CF"
# 赋予执行权限
chmod +x "$pdir/CF/CloudflareST"
echo ""

# 获取DOMAINS数组的长度
domain_count=${#DOMAINS[@]}

# 定位到CF目录
cd "$pdir/CF"
# 执行CloudflareST命令，参考：https://github.com/XIU2/CloudflareSpeedTest
"$pdir/CF/CloudflareST" -p $domain_count -n 1000 -f "$pdir/CF/ip.txt"
# 将结果保存为数组
bestips=($(awk -F ',' 'NR>1 {print $1}' "$pdir/CF/result.csv" | head -n ${#DOMAINS[@]}))

# 循环处理每个域名
for ((i=0; i<${#DOMAINS[@]}; i++)); do
    domain="${DOMAINS[$i]}"
    bestip="${bestips[$i]}"
    
    # 获取记录信息
    record_info=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=A&name=$domain" \
        -H "X-Auth-Email: $API_EMAIL" \
        -H "X-Auth-Key: $API_KEY" \
        -H "Content-Type: application/json")
    record_id=$(echo "$record_info" | grep -oP '(?<="id":")[^"]+' | head -1)
    
    if [ -z "$record_id" ]; then
        echo "无法提取记录ID for 域名 $domain"
    else
        echo "域名 $domain 的RECORD NAME为 $record_id"
        # 更新DNS记录
        update_result=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$record_id" \
            -H "X-Auth-Email: $API_EMAIL" \
            -H "X-Auth-Key: $API_KEY" \
            -H "Content-Type: application/json" \
            --data '{"type":"A","name":"'"$domain"'","content":"'"$bestip"'","ttl":1,"proxied":false}')
        echo "域名 $domain 的DNS记录已更新为IP地址 $bestip"
    fi
done



