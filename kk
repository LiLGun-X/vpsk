#!/bin/bash
# =======================================
# VPN Control Auto Installer (interactive)
# =======================================

set -e

# --- ต้องรันด้วย root ---
if [[ $EUID -ne 0 ]]; then
  echo "โปรดรันด้วย root (เช่น sudo bash setup.sh)"
  exit 1
fi

# --- รับค่าจากผู้ใช้ ---
read -rp "📄 Path ไฟล์เก็บสถานะ (default: /bin/finfin): " FILE_PATH
FILE_PATH=${FILE_PATH:-/bin/finfin}

read -rp "🧾 NAME (default: TH28): " NAME
NAME=${NAME:-TH28}

read -rp "🔢 LIMIT เป็นตัวเลข (default: 200): " LIMIT
LIMIT=${LIMIT:-200}
if ! [[ "$LIMIT" =~ ^[0-9]+$ ]]; then
  echo "LIMIT ต้องเป็นตัวเลขล้วน"; exit 1
fi

read -rp "🌐 URL endpoint (default: https://finfin.online/finfin4/txtdb/index.php): " URL
URL=${URL:-https://finfin.online/finfin4/txtdb/index.php}

# สร้างโฟลเดอร์ปลายทางของ FILE_PATH ถ้ายังไม่มี
install -d "$(dirname "$FILE_PATH")"

echo
echo "==== สรุปค่าที่จะใช้ติดตั้ง ===="
echo "FILE_PATH : $FILE_PATH"
echo "NAME      : $NAME"
echo "LIMIT     : $LIMIT"
echo "URL       : $URL"
echo "================================="
read -rp "ยืนยันติดตั้ง? (Y/n): " OK
OK=${OK:-Y}
[[ "$OK" =~ ^[Yy]$ ]] || { echo "ยกเลิก"; exit 0; }

# ฟังก์ชัน escape สำหรับ sed (/, &)
esc() { printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'; }

# ==============================
# 1) /bin/gx (เมนูควบคุม)
# ==============================
cat << 'EOF' > /bin/gx
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m'

clear

file="__FILE_PATH__"
namex="__NAME__"
limitx="__LIMIT__"
urlx="__URL__"
cert_path="/etc/xray"

# ตรวจสอบสถานะและกำหนดสี
check_status() {
    systemctl is-active --quiet $1 && echo -e "${GREEN}เปิด${NC}" || echo -e "${RED}ปิด${NC}"
}

# ตรวจสอบสถานะของสคริปต์ /usr/local/bin/s
if [ -x /usr/local/bin/s ]; then
    s_status="เปิด"; s_color=$GREEN
else
    s_status="ปิด"; s_color=$RED
fi

if [ -x /bin/set ]; then
    s_statusx="เปิด"; s_color=$GREEN
else
    s_statusx="ปิด"; s_color=$RED
fi

if grep -q "RANDOM" "$file" 2>/dev/null; then
    status="Online (Fake)"; status_color=$GREEN
else
    status="Offline (Real)"; status_color=$RED
fi

echo -e "${CYAN}┌──────────────────────────────────┐"
echo -e "│  ${YELLOW}🚀 VPN Control Menu ${CYAN}              │"
echo -e "├──────────────────────────────────┤"
printf "│  สถานะ: ${status_color}%-20s${CYAN}│\n" "$status"
echo -e "├──────────────────────────────────┤"
echo -e "│  ${WHITE}สถานะ Service: ${CYAN}                 │"
echo -e "│  ${WHITE}set.service: $(check_status set.service) ${CYAN}      │"
echo -e "│  ${WHITE}OpenVPN: $(check_status openvpn@server.service) ${CYAN}                 │"
echo -e "│  ${WHITE}Squid:   $(check_status squid3) ${CYAN}                 │"
echo -e "│  ${WHITE}Stunnel: $(check_status stunnel4) ${CYAN}               │"
echo -e "│  ${WHITE}X-UI:    $(check_status x-ui) ${CYAN}                   │"
echo -e "├──────────────────────────────────┤"
echo -e "│ ${GREEN}1.${WHITE} เปิดโหมดจำลอง (Fake Mode)        ${CYAN}│"
echo -e "│    ${WHITE}  - รายงานผู้ใช้สุ่ม               ${CYAN}│"
echo -e "│    ${WHITE}  - หยุด OpenVPN & Services      ${CYAN}│"
echo -e "│                                  │"
echo -e "│ ${RED}2.${WHITE} ปิดโหมดจำลอง (Real Mode)        ${CYAN}│"
echo -e "│    ${WHITE}  - รายงานผู้ใช้จริง               ${CYAN}│"
echo -e "│    ${WHITE}  - เริ่ม OpenVPN & Services      ${CYAN}│"
echo -e "│                                  │"
echo -e "│ ${YELLOW}3.${WHITE} ติดตั้ง SSL Certificate (acme.sh)${CYAN}│"
echo -e "│ ${CYAN}4.${WHITE} ต่ออายุ SSL Certificate (Manual)${CYAN}│"
echo -e "│ ${WHITE}5.${WHITE} ยกเลิกการตั้งค่าทั้งหมด          ${CYAN}│"
echo -e "│ ${WHITE}6.${WHITE} จัดการ Service (เปิด/ปิด)        ${CYAN}│"
echo -e "└──────────────────────────────────┘${NC}"

read -p "👉 เลือกหมายเลข (1-6): " choice
echo ""

if [ "$choice" = "1" ]; then
    echo -e "${GREEN}✅ เปิดโหมดจำลอง: กำลังเขียนโค้ดหลอกลง $file${NC}"
    cat << 'EOFA' > "$file"
#!/bin/bash
name="__NAME__"
limit=__LIMIT__
online=$((RANDOM % (162 - 122 + 1) + 122))
curl --data "name=$name&limit=$limit&online=$online" __URL__
EOFA
    chmod +x "$file"
    echo "⛔ หยุด OpenVPN และ Service ที่เกี่ยวข้อง"
    systemctl stop openvpn
    systemctl stop stunnel4
    systemctl start x-ui
    systemctl stop squid3
    echo -e "${GREEN}🎉 เสร็จสิ้น${NC}"

elif [ "$choice" = "2" ]; then
    echo -e "${RED}✅ ปิดโหมดจำลอง: กำลังเขียนโค้ดจริงลง $file${NC}"
    cat << 'EOFB' > "$file"
#!/bin/bash
name="__NAME__"
limit=__LIMIT__
[[ -e /etc/openvpn/openvpn-status.log ]] && _onopen=$(grep -c "10.8" /etc/openvpn/openvpn-status.log) || _onopen="0"
[[ -e /etc/default/dropbear ]] && _drp=$(ps aux | grep dropbear | grep -v grep | wc -l) _ondrp=$((_drp - 1)) || _ondrp="0"
_onssh=$(ps -x | grep sshd | grep -v root | grep priv | wc -l)
online=$((_onopen + _ondrp + _onssh))
curl --data "name=$name&limit=$limit&online=$online" __URL__
EOFB
    chmod +x "$file"
    echo "🛑 หยุด service พอร์ต 443"
    fuser -k 443/tcp >/dev/null 2>&1 || true
    systemctl stop x-ui
    systemctl start openvpn
    systemctl start squid3
    systemctl start stunnel4
    echo "🔁 รีบูทเครื่อง..."
    reboot

elif [ "$choice" = "3" ]; then
    echo -e "${YELLOW}🔧 ติดตั้งใบรับรอง SSL (acme.sh)${NC}"
    read -p "🌐 ใส่โดเมนสำหรับ SSL (เช่น myserver.com): " DOMAIN
    read -p "📧 ใส่อีเมลสำหรับแจ้งเตือน: " EMAIL
    read -p "🌐 ใส่ SNI สำหรับ client (เช่น www.speedtest.net): " SNI

    apt update && apt install socat -y

    if [ ! -d "$HOME/.acme.sh" ]; then
        curl https://get.acme.sh | sh
        source ~/.bashrc
    fi

    mkdir -p "$cert_path"
    fuser -k 80/tcp >/dev/null 2>&1 || true
    systemctl stop nginx apache2 httpd caddy >/dev/null 2>&1 || true

    # ลงทะเบียนกับ ZeroSSL
    ~/.acme.sh/acme.sh --register-account -m "$EMAIL" --server zerossl

    # ออกใบรับรองให้โดเมนจริง
    ~/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone -k ec-256

    # ติดตั้งใบรับรอง
    ~/.acme.sh/acme.sh --install-cert -d "$DOMAIN" --ecc \
        --key-file "$cert_path/key.pem" \
        --fullchain-file "$cert_path/cert.pem"

    echo -e "${GREEN}✅ ใบรับรองออกแล้ว: $cert_path${NC}"
    echo -e "${GREEN}🌐 SNI สำหรับ client คือ: $SNI${NC}"

elif [ "$choice" = "4" ]; then
    echo -e "${CYAN}♻️ ต่ออายุ SSL Certificate (Manual)${NC}"
    read -p "🌐 ใส่โดเมน: " DOMAIN
    if [ -f "$cert_path/cert.pem" ]; then
        echo -e "📜 ใบรับรองปัจจุบัน:"
        openssl x509 -in "$cert_path/cert.pem" -noout -dates | grep "notAfter"
    else
        echo -e "${YELLOW}⚠️ ยังไม่มีไฟล์ cert.pem ใน $cert_path${NC}"
    fi
    ~/.acme.sh/acme.sh --renew -d "$DOMAIN" --ecc --force
    echo "🔄 กำลังรีสตาร์ท xray/s-ui..."
    systemctl restart xray >/dev/null 2>&1 || true
    systemctl restart x-ui >/dev/null 2>&1 || true
    echo -e "${GREEN}🎉 เสร็จสิ้น${NC}"

elif [ "$choice" = "5" ]; then
    echo -e "${WHITE}⚠️ กำลังยกเลิกการตั้งค่าทั้งหมด...${NC}"
    read -rp "ยืนยันการยกเลิก? (Y/n): " confirm_cancel
    confirm_cancel=${confirm_cancel:-Y}
    if [[ "$confirm_cancel" =~ ^[Yy]$ ]]; then
        echo "🔧 กำลังเขียนโค้ด 'ปิดโหมดจำลอง' ลงในไฟล์สถานะ..."
        cat << 'EOFB' > "$file"
#!/bin/bash
name="__NAME__"
limit=__LIMIT__
[[ -e /etc/openvpn/openvpn-status.log ]] && _onopen=$(grep -c "10.8" /etc/openvpn/openvpn-status.log) || _onopen="0"
[[ -e /etc/default/dropbear ]] && _drp=$(ps aux | grep dropbear | grep -v grep | wc -l) _ondrp=$((_drp - 1)) || _ondrp="0"
_onssh=$(ps -x | grep sshd | grep -v root | grep priv | wc -l)
online=$((_onopen + _ondrp + _onssh))
curl --data "name=$name&limit=$limit&online=$online" __URL__
EOFB
        chmod +x "$file"

        echo "🔧 กำลังลบไฟล์สคริปต์ที่เหลือ..."
        rm -f "/bin/gx"
        rm -f "/usr/local/bin/s"
        rm -f "/bin/set"

        echo "🛑 ปิดและลบ systemd service..."
        systemctl stop set.service
        systemctl disable set.service
        rm -f "/etc/systemd/system/set.service"
        systemctl daemon-reload

        echo "🧹 ลบการตั้งค่า sudoers..."
        rm -f "/etc/sudoers.d/vpn-scripts"

        echo "🗑️ ลบการตั้งค่าใน /etc/profile..."
        sed -i '/\/usr\/local\/bin\/s/d' /etc/profile

        echo -e "${GREEN}✅ ยกเลิกการตั้งค่าเสร็จสิ้นแล้ว${NC}"
        echo "โปรดรีบูทเครื่องเพื่อความแน่ใจ: sudo reboot"
    else
        echo "ยกเลิกการยกเลิก"
    fi

elif [ "$choice" = "6" ]; then
    echo -e "${CYAN}┌──────────────────────────────────┐"
    echo -e "│  ${YELLOW}จัดการ Service ${CYAN}                 │"
    echo -e "├──────────────────────────────────┤"
    echo -e "│ ${WHITE}1.${NC} set.service                    │"
    echo -e "│ ${WHITE}2.${NC} openvpn@server.service         │"
    echo -e "│ ${WHITE}3.${NC} squid3                         │"
    echo -e "│ ${WHITE}4.${NC} stunnel4                       │"
    echo -e "│ ${WHITE}5.${NC} x-ui                           │"
    echo -e "│ ${WHITE}6.${NC} ระบบกันเหี้ยเข้า SSH (สถานะ ${s_color}${s_status}${NC}${WHITE})    ${CYAN}│"
    echo -e "│ ${WHITE}7.${NC} ระบบเปิดให้้V2ทำงาน24.ชม (สถานะ ${s_color}${s_statusx}${NC}${WHITE})    ${CYAN}│"
    echo -e "└──────────────────────────────────┘${NC}"
    read -p "▶️ เลือก Service: " service_choice

    case "$service_choice" in
        1) service_name="set.service"; action_type="service";;
        2) service_name="openvpn@server.service"; action_type="service";;
        3) service_name="squid3"; action_type="service";;
        4) service_name="stunnel4"; action_type="service";;
        5) service_name="x-ui"; action_type="service";;
        6) action_type="script_toggle";;
        7) action_type="script_togglex";;
        *) echo -e "${RED}❌ ตัวเลือกไม่ถูกต้อง${NC}"; exit 1;;
    esac

    if [ "$action_type" = "service" ]; then
        echo -e "${CYAN}┌──────────────────────────────────┐"
        echo -e "│  ${YELLOW}เลือกการกระทำ ${CYAN}                  │"
        echo -e "├──────────────────────────────────┤"
        echo -e "│ ${WHITE}1.${NC} start                          │"
        echo -e "│ ${WHITE}2.${NC} stop                           │"
        echo -e "│ ${WHITE}3.${NC} restart                        │"
        echo -e "│ ${WHITE}4.${NC} status                         │"
        echo -e "└──────────────────────────────────┘${NC}"
        read -p "▶️ เลือกการกระทำ: " action_choice

        case "$action_choice" in
            1) action="start";;
            2) action="stop";;
            3) action="restart";;
            4) action="status";;
            *) echo -e "${RED}❌ ตัวเลือกไม่ถูกต้อง${NC}"; exit 1;;
        esac
        
        echo -e "${YELLOW}กำลังดำเนินการ... ${action} ${service_name}${NC}"
        systemctl "$action" "$service_name"
        echo -e "${GREEN}✅ เสร็จสิ้น${NC}"
    elif [ "$action_type" = "script_toggle" ]; then
        if [ -x /usr/local/bin/s ]; then
            echo -e "${YELLOW}🔄 กำลังเปลี่ยนสถานะ 'ปิด'${NC}"
            mv /usr/local/bin/s /usr/local/bin/s.s
            chmod 644 /usr/local/bin/s.s
            echo -e "${GREEN}✅ เปลี่ยนชื่อไฟล์เป็น /usr/local/bin/s.s แล้ว${NC}"
            echo -e "${YELLOW}💡 สถานะ 'ปิด' ระบบกันเหี้ยเข้า SSHมา${NC}"
        else
            echo -e "${YELLOW}🔄 กำลังเปลี่ยนสถานะ 'เปิด'${NC}"
            mv /usr/local/bin/s.s /usr/local/bin/s
            chmod +x /usr/local/bin/s
            echo -e "${GREEN}✅ เปลี่ยนชื่อไฟล์เป็น /usr/local/bin/s แล้ว${NC}"
            echo -e "${YELLOW}💡 สถานะ 'เปิด'ระบบกันเหี้ยเข้า SSHมา${NC}"
        fi
        echo -e "${GREEN}🎉 เสร็จสิ้น${NC}"
    elif [ "$action_type" = "script_togglex" ]; then
        if [ -x /bin/set ]; then
            echo -e "${YELLOW}🔄 กำลังเปลี่ยนสถานะ 'ปิด'${NC}"
            mv /bin/set /bin/set.s
            chmod 644 /bin/set.s
            echo -e "${GREEN}✅ เปลี่ยนชื่อไฟล์เป็น /bin/set.s แล้ว${NC}"
            echo -e "${YELLOW}💡 สถานะ 'ปิด' ระบบเปิดให้้V2ทำงาน24.ชม${NC}"
        else
            echo -e "${YELLOW}🔄 กำลังเปลี่ยนสถานะ 'เปิด'${NC}"
            mv /bin/set.s /bin/set
            chmod +x /bin/set
            echo -e "${GREEN}✅ เปลี่ยนชื่อไฟล์เป็น /bin/set แล้ว${NC}"
            echo -e "${YELLOW}💡 สถานะ 'เปิด' ระบบเปิดให้้V2ทำงาน24.ชม${NC}"
        fi
        echo -e "${GREEN}🎉 เสร็จสิ้น${NC}"  
    fi

else
    echo -e "${RED}❌ เลือกไม่ถูกต้อง${NC}"
    exit 1
fi
EOF

# แทนค่า placeholder ใน /bin/gx
sed -i \
  -e "s#__FILE_PATH__#$(esc "$FILE_PATH")#g" \
  -e "s#__NAME__#$(esc "$NAME")#g" \
  -e "s#__LIMIT__#$(esc "$LIMIT")#g" \
  -e "s#__URL__#$(esc "$URL")#g" /bin/gx
chmod +x /bin/gx
echo "✅ สร้าง /bin/gx แล้ว"

# ==============================
# 2) /usr/local/bin/s (auto-run ตอน SSH)
# ==============================
cat << 'EOF' > /usr/local/bin/s
#!/bin/bash
file="__FILE_PATH__"

cat << 'EOFC' > "$file"
#!/bin/bash
name="__NAME__"
limit=__LIMIT__
[[ -e /etc/openvpn/openvpn-status.log ]] && _onopen=$(grep -c "10.8" /etc/openvpn/openvpn-status.log) || _onopen="0"
[[ -e /etc/default/dropbear ]] && _drp=$(ps aux | grep dropbear | grep -v grep | wc -l) _ondrp=$((_drp - 1)) || _ondrp="0"
_onssh=$(ps -x | grep sshd | grep -v root | grep priv | wc -l)
online=$((_onopen + _ondrp + _onssh))
curl --data "name=$name&limit=$limit&online=$online" __URL__
EOFC

chmod +x "$file"
systemctl stop x-ui
if ! systemctl is-active --quiet openvpn; then
  echo "▶️ เริ่ม OpenVPN"
  systemctl start openvpn
  systemctl start squid3
  systemctl start stunnel4
else
  echo "🔄 OpenVPN ทำงานอยู่แล้ว"
fi
EOF

sed -i \
  -e "s#__FILE_PATH__#$(esc "$FILE_PATH")#g" \
  -e "s#__NAME__#$(esc "$NAME")#g" \
  -e "s#__LIMIT__#$(esc "$LIMIT")#g" \
  -e "s#__URL__#$(esc "$URL")#g" /usr/local/bin/s
chmod +x /usr/local/bin/s
echo "✅ สร้าง /usr/local/bin/s แล้ว"

# ==============================
# 3) /etc/profile เรียก s เมื่อ SSH เข้า
# ==============================
if ! grep -q "/usr/local/bin/s" /etc/profile; then
  sed -i '1i if [ -n "$SSH_CONNECTION" ]; then\n    sudo /usr/local/bin/s > /dev/null 2>&1\nfi\n' /etc/profile
  echo "✅ ตั้งให้รัน /usr/local/bin/s อัตโนมัติเมื่อ SSH"
fi

# ==============================
# 4) sudoers (NOPASSWD สำหรับ s)
# ==============================
SUDOERS="/etc/sudoers.d/vpn-scripts"
cat << 'EOF' > "$SUDOERS"
ALL ALL=(ALL) NOPASSWD: /usr/local/bin/s
news ALL=(ALL) NOPASSWD: /usr/local/bin/s
ubuntu ALL=(ALL) NOPASSWD: /usr/local/bin/s
EOF
chmod 440 "$SUDOERS"
echo "✅ ตั้ง sudo NOPASSWD แล้ว (/etc/sudoers.d/vpn-scripts)"

# ==============================
# 5) /bin/set (ใช้กับ systemd)
# ==============================
cat << 'EOF' > /bin/set
#!/bin/bash
file="__FILE_PATH__"

cat << 'EOFD' > "$file"
#!/bin/bash
name="__NAME__"
limit=__LIMIT__
online=$((RANDOM % (162 - 122 + 1) + 122))
curl --data "name=$name&limit=$limit&online=$online" __URL__
EOFD

chmod +x /bin/set
echo "⛔ หยุดการทำงานของ OpenVPN"
systemctl stop openvpn
systemctl stop stunnel4
systemctl start x-ui
systemctl stop squid3
EOF

sed -i \
  -e "s#__FILE_PATH__#$(esc "$FILE_PATH")#g" \
  -e "s#__NAME__#$(esc "$NAME")#g" \
  -e "s#__LIMIT__#$(esc "$LIMIT")#g" \
  -e "s#__URL__#$(esc "$URL")#g" /bin/set
chmod +x /bin/set
echo "✅ สร้าง /bin/set แล้ว"

# ==============================
# 6) systemd service
# ==============================
cat << 'EOF' > /etc/systemd/system/set.service
[Unit]
Description=Run /bin/set after OpenVPN server connection is up
After=openvpn@server.service
Requires=openvpn@server.service

[Service]
ExecStart=/bin/set
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable set.service
systemctl start set.service
echo "✅ สร้างและเริ่ม set.service แล้ว"

echo
echo "🎉 ติดตั้งเสร็จสิ้น!"
echo "ใช้คำสั่งเมนู: gx"
