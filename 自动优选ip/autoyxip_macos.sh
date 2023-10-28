#!/bin/bash

API_KEY="xxxx"
API_EMAIL="xxx@gmail.com"
ZONE_ID="xxx"
DOMAINS=("yx.example.com" "yx1.example.com" "yx2.example.com")
pdir="/Users/mareep/Desktop" # 替换为你的路径

arch=$(uname -m)
case ${arch} in
    x86_64)
        cf_arch="amd64"
        ;;
    arm64)
        cf_arch="arm64"
        ;;
    *)
        echo "不支持的架构: ${arch}"
        exit 1
        ;;
esac

cf_url="https://github.com/XIU2/CloudflareSpeedTest/releases/latest/download/CloudflareST_darwin_${cf_arch}.zip"
curl -sL "$cf_url" -o "$pdir/cloudflaredST.zip"
mkdir -p "$pdir/CF"
unzip -q "$pdir/cloudflaredST.zip" -d "$pdir/CF"
chmod +x "$pdir/CF/CloudflareST"
echo ""

domain_count=${#DOMAINS[@]}

cd "$pdir/CF"
"$pdir/CF/CloudflareST" -p $domain_count -n 1000 -f "$pdir/CF/ip.txt"
bestips=($(awk -F ',' 'NR>1 {print $1}' "$pdir/CF/result.csv" | head -n ${#DOMAINS[@]}))

for domain in "${DOMAINS[@]}"; do
    record_info=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=A&name=$domain" \
        -H "X-Auth-Email: $API_EMAIL" \
        -H "X-Auth-Key: $API_KEY" \
        -H "Content-Type: application/json")
    record_id=$(echo "$record_info" | awk -F '"id":"' '{print $2}' | awk -F '","' '{print $1}')
    
    if [ -z "$record_id" ]; then
        echo "无法提取记录ID for 域名 $domain"
    else
        echo "域名 $domain 的RECORD NAME为 $record_id"
        update_result=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$record_id" \
            -H "X-Auth-Email: $API_EMAIL" \
            -H "X-Auth-Key: $API_KEY" \
            -H "Content-Type: application/json" \
            --data '{"type":"A","name":"'"$domain"'","content":"'"$bestip"'","ttl":1,"proxied":false}')
        echo "域名 $domain 的DNS记录已更新为IP地址 $bestip"
    fi
done
