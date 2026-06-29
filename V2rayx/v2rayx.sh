#!/bin/bash
set -e

# =======================================
# VPN Control Auto Installer (v3.0)
# V2Ray Edition (ไม่มี X-UI)
# =======================================

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}✖ โปรดรันด้วย root (sudo bash setup.sh)${NC}"
  exit 1
fi

clear
echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════╗"
echo "  ║      VPN Control Auto Installer      ║"
echo "  ║      Version 3.0 (V2Ray Edition)     ║"
echo "  ╚══════════════════════════════════════╝"
echo -e "${NC}"

# ==============================
# ฟังก์ชัน input บังคับใส่
# ==============================
ask() {
  local label="$1"
  local hint="$2"
  local var=""
  while true; do
    echo -e "${GRAY}  ┌─ ${WHITE}$label${NC}" >&2
    echo -e "${GRAY}  │  ${CYAN}ตัวอย่าง: ${hint}${NC}" >&2
    read -rp "$(echo -e "${GRAY}  └▶ ${NC}")" var
    if [[ -n "$var" ]]; then
      echo -e "${GREEN}  ✔ รับค่า: ${WHITE}$var${NC}\n" >&2
      echo "$var"
      break
    else
      echo -e "${RED}  ✖ ห้ามเว้นว่าง กรุณาใส่ใหม่${NC}\n" >&2
    fi
  done
}

ask_name() {
  local label="$1"
  local hint="$2"
  local var=""
  while true; do
    echo -e "${GRAY}  ┌─ ${WHITE}$label${NC}" >&2
    echo -e "${GRAY}  │  ${CYAN}ตัวอย่าง: ${hint}${NC}" >&2
    read -rp "$(echo -e "${GRAY}  └▶ ${NC}")" var
    if [[ -n "$var" ]]; then
      echo -e "${GREEN}  ✔ รับค่า: ${WHITE}/bin/$var${NC}\n" >&2
      echo "$var"
      break
    else
      echo -e "${RED}  ✖ ห้ามเว้นว่าง กรุณาใส่ใหม่${NC}\n" >&2
    fi
  done
}

ask_number() {
  local label="$1"
  local hint="$2"
  local var=""
  while true; do
    echo -e "${GRAY}  ┌─ ${WHITE}$label${NC}" >&2
    echo -e "${GRAY}  │  ${CYAN}ตัวอย่าง: ${hint}${NC}" >&2
    read -rp "$(echo -e "${GRAY}  └▶ ${NC}")" var
    if [[ "$var" =~ ^[0-9]+$ ]]; then
      echo -e "${GREEN}  ✔ รับค่า: ${WHITE}$var${NC}\n" >&2
      echo "$var"
      break
    else
      echo -e "${RED}  ✖ ต้องเป็นตัวเลขเท่านั้น กรุณาใส่ใหม่${NC}\n" >&2
    fi
  done
}

# ==============================
# รับค่าจากผู้ใช้
# ==============================
echo -e "${YELLOW}  ● กรอกข้อมูลการติดตั้ง${NC}\n"

FILE_NAME=$(ask_name   "ชื่อไฟล์เก็บสถานะ"  "finfin  →  จะได้ /bin/finfin")
FILE_PATH="/bin/$FILE_NAME"

NAME=$(ask             "ชื่อ Server (NAME)"  "TH28")
LIMIT=$(ask_number     "จำนวน Limit"         "200")
URL=$(ask              "URL Endpoint"        "https://finfin.online/finfin4/txtdb/index.php")

# ==============================
# สรุปก่อนติดตั้ง
# ==============================
echo -e "${CYAN}  ╔══════════════════════════════════════╗"
echo -e "  ║         สรุปค่าที่จะติดตั้ง           ║"
echo -e "  ╠══════════════════════════════════════╣"
printf  "  ║  ${WHITE}%-10s${CYAN} : ${GREEN}%-25s${CYAN}║\n" "FILE_PATH" "$FILE_PATH"
printf  "  ║  ${WHITE}%-10s${CYAN} : ${GREEN}%-25s${CYAN}║\n" "NAME"      "$NAME"
printf  "  ║  ${WHITE}%-10s${CYAN} : ${GREEN}%-25s${CYAN}║\n" "LIMIT"     "$LIMIT"
printf  "  ║  ${WHITE}%-10s${CYAN} : ${GREEN}%-25s${CYAN}║\n" "URL"       "${URL:0:25}"
echo -e "  ╚══════════════════════════════════════╝${NC}\n"

while true; do
  read -rp "$(echo -e "${YELLOW}  ยืนยันติดตั้ง? (Y/n): ${NC}")" OK
  case "${OK:-Y}" in
    [Yy]) break ;;
    [Nn]) echo -e "${RED}  ยกเลิกการติดตั้ง${NC}"; exit 0 ;;
    *) echo -e "${RED}  กรุณาพิม Y หรือ n${NC}" ;;
  esac
done

echo ""

esc() { printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'; }
step()      { echo -e "${CYAN}  ▶ $1...${NC}"; }
done_step() { echo -e "${GREEN}  ✔ $1${NC}"; }

install -d "$(dirname "$FILE_PATH")"

cert_path="/etc/xray"

# ==============================
# 1) /bin/gx (เมนูหลัก)
# ==============================
step "สร้าง /bin/gx (เมนูหลัก)"
cat << 'EOF' > /bin/gx
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'

file="__FILE_PATH__"
cert_path="/etc/xray"

svc_status() {
  systemctl is-active --quiet "$1" \
    && echo -e "${GREEN}● เปิด${NC}" \
    || echo -e "${RED}○ ปิด${NC}"
}

if grep -q "RANDOM" "$file" 2>/dev/null; then
  mode_label="${GREEN}Fake Mode (จำลอง)${NC}"
else
  mode_label="${CYAN}Real Mode (จริง)${NC}"
fi

if [[ -f /usr/local/bin/s && -x /usr/local/bin/s ]]; then
  ssh_guard="${GREEN}เปิด${NC}"
else
  ssh_guard="${RED}ปิด${NC}"
fi

if [[ -f /bin/set.s ]]; then
  v2_keep="${RED}ปิด${NC}"
elif [[ -f /bin/set && -x /bin/set ]]; then
  v2_keep="${GREEN}เปิด${NC}"
else
  v2_keep="${RED}ปิด${NC}"
fi

rb_file="/etc/cron.d/reboot"

if [[ -f "$rb_file" ]]; then
  rb_min=$(awk 'NF && $0 !~ /^#/ {print $1; exit}' "$rb_file")
  rb_hr=$(awk 'NF && $0 !~ /^#/ {print $2; exit}' "$rb_file")
  
  if [[ -n "$rb_min" && -n "$rb_hr" ]]; then
    rb_label=$(printf "${GREEN}%02d:%02d น.${NC}" "$rb_hr" "$rb_min")
  else
    rb_label="${RED}ยังไม่ได้ตั้ง${NC}"
  fi
else
  rb_label="${RED}ยังไม่ได้ตั้ง${NC}"
fi

clear
echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║          🚀  VPN Control Menu            ║"
echo "  ╠══════════════════════════════════════════╣"
echo -e "  ║  โหมด         : $mode_label"
echo -e "  ║  Auto Reboot  : $rb_label"
echo -e "${CYAN}  ╠══════════════════════════════════════════╣"
echo -e "  ║  ${WHITE}Service Status${CYAN}                           ║"
echo -e "  ║  set.service  : $(svc_status set.service)${CYAN}                     ║"
echo -e "  ║  OpenVPN      : $(svc_status openvpn@server.service)${CYAN}                     ║"
echo -e "  ║  Squid        : $(svc_status squid3)${CYAN}                     ║"
echo -e "  ║  Stunnel      : $(svc_status stunnel4)${CYAN}                   ║"
echo -e "  ║  V2Ray        : $(svc_status v2ray)${CYAN}                     ║"
echo -e "  ║  SSH Guard    : $ssh_guard${CYAN}                            ║"
echo -e "  ║  V2 24hr Keep : $v2_keep${CYAN}                            ║"
echo -e "  ╠══════════════════════════════════════════╣"
echo -e "  ║  ${GREEN}1.${WHITE} เปิด Fake Mode  ${GRAY}(สุ่มผู้ใช้)${CYAN}           ║"
echo -e "  ║  ${RED}2.${WHITE} เปิด Real Mode  ${GRAY}(ผู้ใช้จริง)${CYAN}          ║"
echo -e "  ║  ${YELLOW}3.${WHITE} ติดตั้ง SSL Certificate${CYAN}              ║"
echo -e "  ║  ${CYAN}4.${WHITE} ต่ออายุ SSL Certificate${CYAN}              ║"
echo -e "  ║  ${WHITE}5.${WHITE} ยกเลิกการตั้งค่าทั้งหมด${CYAN}             ║"
echo -e "  ║  ${WHITE}6.${WHITE} จัดการ Service${CYAN}                       ║"
echo -e "  ║  ${RED}0.${WHITE} ออก${CYAN}                                  ║"
echo -e "  ╚══════════════════════════════════════════╝${NC}"
echo ""
read -rp "$(echo -e "${YELLOW}  👉 เลือก (0-6): ${NC}")" choice
echo ""

case "$choice" in

1)
  echo -e "${GREEN}  ✔ เปิด Fake Mode${NC}"
  cat << 'EOFA' > "$file"
#!/bin/bash
name="__NAME__"
limit=__LIMIT__
online=$((RANDOM % (162 - 122 + 1) + 122))
curl --data "name=$name&limit=$limit&online=$online" __URL__
EOFA
  chmod +x "$file"
  systemctl stop openvpn stunnel4 squid3
  systemctl start v2ray
  echo -e "${GREEN}  ✔ เสร็จสิ้น${NC}"
  ;;

2)
  echo -e "${CYAN}  ✔ เปิด Real Mode${NC}"
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
  fuser -k 443/tcp >/dev/null 2>&1 || true
  systemctl stop v2ray
  systemctl start openvpn squid3 stunnel4
  echo -e "${CYAN}  🔁 รีบูท...${NC}"
  
  ;;

3)
  clear
  echo -e "${CYAN}"
  echo "  ╔══════════════════════════════════════════╗"
  echo "  ║        🔐 ติดตั้ง SSL Certificate        ║"
  echo "  ╠══════════════════════════════════════════╣"
  
  # ========== เช็คสถานะ SSL ปัจจุบัน ==========
  echo -e "  ║  ${WHITE}📋 สถานะ SSL ปัจจุบัน${CYAN}                   ║"
  if [[ -f "$cert_path/cert.pem" ]]; then
    cert_domain=$(openssl x509 -in "$cert_path/cert.pem" -noout -text 2>/dev/null | grep "Subject:" | grep -oP '(?<=CN=)[^,]+' || echo "ไม่พบ")
    cert_expire=$(openssl x509 -in "$cert_path/cert.pem" -noout -enddate 2>/dev/null | cut -d= -f2 || echo "ไม่พบ")
    echo -e "  ║  ${GREEN}✔ มี Certificate อยู่${CYAN}                  ║"
    printf  "  ║  ${WHITE}   โดเมน${CYAN}  : ${GREEN}%-23s${CYAN}║\n" "$cert_domain"
    printf  "  ║  ${WHITE}   หมดอายุ${CYAN} : ${GREEN}%-23s${CYAN}║\n" "$cert_expire"
    printf  "  ║  ${WHITE}   Path${CYAN}    : ${GREEN}%-23s${CYAN}║\n" "$cert_path/cert.pem"
  else
    echo -e "  ║  ${RED}✖ ยังไม่มี Certificate${CYAN}                ║"
  fi
  
  # ========== เช็ค Port 80 ==========
  echo -e "  ╠══════════════════════════════════════════╣"
  echo -e "  ║  ${WHITE}🔌 สถานะ Port 80${CYAN}                       ║"
  if netstat -tuln 2>/dev/null | grep -q ":80 " || ss -tuln 2>/dev/null | grep -q ":80 "; then
    port80_proc=$(lsof -i :80 2>/dev/null | tail -1 | awk '{print $1}' || echo "Unknown")
    echo -e "  ║  ${RED}✖ Port 80 ถูกใช้งาน (ต้องปิดก่อน)${CYAN}       ║"
    printf  "  ║  ${WHITE}   Service${CYAN} : ${RED}%-23s${CYAN}║\n" "$port80_proc"
  else
    echo -e "  ║  ${GREEN}✔ Port 80 ว่าง (พร้อมติดตั้ง)${CYAN}          ║"
  fi
  
  # ========== เช็คการลบโดเมนเก่า ==========
  if [[ -f "$cert_path/cert.pem" ]]; then
    echo -e "  ╠══════════════════════════════════════════╣"
    read -rp "$(echo -e "  ${YELLOW}ต้องการลบโดเมนเก่า? (Y/n): ${NC}")" del_old
    if [[ "${del_old:-Y}" =~ ^[Yy]$ ]]; then
      rm -f "$cert_path/cert.pem" "$cert_path/key.pem"
      echo -e "  ${GREEN}  ✔ ลบไฟล์เก่าแล้ว${NC}\n"
    fi
  fi
  
  echo -e "  ╠══════════════════════════════════════════╣"
  echo -e "  ║  ${WHITE}📝 ใส่ข้อมูลใหม่${CYAN}                         ║"
  echo -e "  ╚══════════════════════════════════════════╝${NC}\n"
  
  read -rp "$(echo -e "  ${GRAY}โดเมน${CYAN} (เช่น example.com)${GRAY}: ${NC}")" DOMAIN
  read -rp "$(echo -e "  ${GRAY}อีเมล${CYAN} (เช่น admin@example.com)${GRAY}: ${NC}")" EMAIL
  read -rp "$(echo -e "  ${GRAY}SNI${CYAN} (ตัวอักษรตกแต่ง)${GRAY}: ${NC}")" SNI
  
  echo -e "\n${CYAN}  ▶ เริ่มติดตั้ง SSL...${NC}\n"
  
  apt update && apt install socat -y >/dev/null 2>&1
  [ ! -d "$HOME/.acme.sh" ] && curl https://get.acme.sh 2>/dev/null | sh >/dev/null 2>&1 && source ~/.bashrc
  mkdir -p "$cert_path"
  
  # ปิด Port 80
  fuser -k 80/tcp >/dev/null 2>&1 || true
  systemctl stop nginx apache2 httpd caddy >/dev/null 2>&1 || true
  
  sleep 2
  
  ~/.acme.sh/acme.sh --register-account -m "$EMAIL" --server zerossl >/dev/null 2>&1 || true
  ~/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone -k ec-256 2>&1 | grep -E "error|success" || true
  ~/.acme.sh/acme.sh --install-cert -d "$DOMAIN" --ecc \
    --key-file "$cert_path/key.pem" \
    --fullchain-file "$cert_path/cert.pem" >/dev/null 2>&1
  
  systemctl restart v2ray >/dev/null 2>&1 || true
  
  echo -e "\n${CYAN}"
  echo "  ╔══════════════════════════════════════════╗"
  echo "  ║     ✅ ติดตั้ง SSL สำเร็จ               ║"
  echo "  ╠══════════════════════════════════════════╣"
  printf  "  ║  ${WHITE}โดเมน${CYAN}    : ${GREEN}%-28s${CYAN}║\n" "$DOMAIN"
  printf  "  ║  ${WHITE}SNI${CYAN}       : ${GREEN}%-28s${CYAN}║\n" "$SNI"
  printf  "  ║  ${WHITE}Cert Path${CYAN}  : ${GREEN}%-28s${CYAN}║\n" "$cert_path/cert.pem"
  printf  "  ║  ${WHITE}Key Path${CYAN}   : ${GREEN}%-28s${CYAN}║\n" "$cert_path/key.pem"
  echo "  ╚══════════════════════════════════════════╝${NC}"
  ;;

4)
  echo -e "${CYAN}  ♻ ต่ออายุ SSL${NC}\n"
  read -rp "$(echo -e "  ${GRAY}โดเมน: ${NC}")" DOMAIN
  [ -f "$cert_path/cert.pem" ] \
    && openssl x509 -in "$cert_path/cert.pem" -noout -dates | grep "notAfter" \
    || echo -e "${YELLOW}  ⚠ ยังไม่มี cert.pem${NC}"
  ~/.acme.sh/acme.sh --renew -d "$DOMAIN" --ecc --force
  systemctl restart v2ray >/dev/null 2>&1 || true
  echo -e "${GREEN}  ✔ เสร็จสิ้น${NC}"
  ;;

5)
  echo -e "${RED}  ⚠ ยกเลิกการตั้งค่าทั้งหมด${NC}\n"
  read -rp "$(echo -e "  ${YELLOW}ยืนยัน? (Y/n): ${NC}")" CC
  [[ "${CC:-Y}" =~ ^[Yy]$ ]] || { echo "  ยกเลิก"; exit 0; }
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
  rm -f /bin/gx /usr/local/bin/s /bin/set
  systemctl stop set.service && systemctl disable set.service
  rm -f /etc/systemd/system/set.service
  systemctl daemon-reload
  rm -f /etc/sudoers.d/vpn-scripts
  sed -i '/\/usr\/local\/bin\/s/d' /etc/profile
  crontab -l 2>/dev/null | grep -v "reboot" | crontab -
  echo -e "${GREEN}  ✔ ยกเลิกเสร็จสิ้น รีบูทเพื่อความแน่ใจ${NC}"
  ;;

6)
  clear
  echo -e "${CYAN}"
  echo "  ╔══════════════════════════════════════╗"
  echo "  ║          จัดการ Service              ║"
  echo "  ╠══════════════════════════════════════╣"
  echo -e "  ║  ${WHITE}1.${NC} set.service                      ║"
  echo -e "  ║  ${WHITE}2.${NC} openvpn@server.service           ║"
  echo -e "  ║  ${WHITE}3.${NC} squid3                           ║"
  echo -e "  ║  ${WHITE}4.${NC} stunnel4                         ║"
  echo -e "  ║  ${WHITE}5.${NC} v2ray                            ║"
  echo -e "  ║  ${WHITE}6.${NC} SSH Guard (กันเหี้ย)              ║"
  echo -e "  ║  ${WHITE}7.${NC} V2 24hr Keep                     ║"
  echo -e "  ║  ${WHITE}8.${NC} ตั้งเวลา Auto Reboot              ║"
  echo -e "  ╚══════════════════════════════════════╝${NC}\n"
  read -rp "$(echo -e "  ${YELLOW}เลือก: ${NC}")" sc

  case "$sc" in
    1) svc="set.service" ;;
    2) svc="openvpn@server.service" ;;
    3) svc="squid3" ;;
    4) svc="stunnel4" ;;
    5) svc="v2ray" ;;

    6)
      if [ -x /usr/local/bin/s ]; then
        mv /usr/local/bin/s /usr/local/bin/s.s && chmod 644 /usr/local/bin/s.s
        echo -e "${RED}  ✔ SSH Guard ปิดแล้ว${NC}"
      else
        mv /usr/local/bin/s.s /usr/local/bin/s && chmod +x /usr/local/bin/s
        echo -e "${GREEN}  ✔ SSH Guard เปิดแล้ว${NC}"
      fi
      exit 0 ;;

    7)
      if [ -x /bin/set ]; then
        mv /bin/set /bin/set.s && chmod 644 /bin/set.s
        echo -e "${RED}  ✔ V2 24hr Keep ปิดแล้ว${NC}"
      else
        mv /bin/set.s /bin/set && chmod +x "$file"
        echo -e "${GREEN}  ✔ V2 24hr Keep เปิดแล้ว${NC}"
      fi
      exit 0 ;;

    8)
      clear
      echo -e "${CYAN}"
      echo "  ╔══════════════════════════════════════╗"
      echo "  ║        ⏰ Auto Reboot Manager        ║"
      echo "  ╠══════════════════════════════════════╣"

      rb_file="/etc/cron.d/reboot"
      if [[ -f "$rb_file" ]]; then
        rb_min=$(awk 'NF && $0 !~ /^#/ {print $1; exit}' "$rb_file")
        rb_hr=$(awk  'NF && $0 !~ /^#/ {print $2; exit}' "$rb_file")
        echo -e "  ║  ${WHITE}สถานะ   : ${GREEN}เปิดอยู่${CYAN}                     ║"
        printf  "  ║  ${WHITE}เวลารีบูท: ${GREEN}%02d:%02d น.${CYAN}%-17s║\n" "$rb_hr" "$rb_min" ""
      else
        echo -e "  ║  ${WHITE}สถานะ   : ${RED}ยังไม่ได้ตั้ง${CYAN}                 ║"
      fi

      echo -e "  ╠══════════════════════════════════════╣"
      echo -e "  ║  ${WHITE}1.${NC} ตั้งเวลา Auto Reboot              ║"
      echo -e "  ║  ${WHITE}2.${NC} ยกเลิก Auto Reboot                ║"
      echo -e "  ║  ${WHITE}0.${NC} ย้อนกลับ                          ║"
      echo -e "  ╚══════════════════════════════════════╝${NC}\n"
      read -rp "$(echo -e "  ${YELLOW}เลือก: ${NC}")" rb_choice

      case "$rb_choice" in
        1)
          while true; do
            read -rp "$(echo -e "  ${GRAY}เวลา (HH:MM เช่น 22:34 หรือ 01:00): ${NC}")" rb_time
            if [[ "$rb_time" =~ ^([01][0-9]|2[0-3]):([0-5][0-9])$ ]]; then
              rb_hr="${rb_time%%:*}"
              rb_min="${rb_time##*:}"
              rb_hr=$((10#$rb_hr))
              rb_min=$((10#$rb_min))
              break
            else
              echo -e "${RED}  ✖ รูปแบบต้องเป็น HH:MM เช่น 22:34${NC}"
            fi
          done
          echo "$rb_min $rb_hr * * * root /sbin/reboot" > /etc/cron.d/reboot
          printf "${GREEN}  ✔ ตั้ง Auto Reboot เวลา %02d:%02d น. แล้ว${NC}\n" "$rb_hr" "$rb_min"
          ;;
        2)
          rm -f /etc/cron.d/reboot
          echo -e "${RED}  ✔ ยกเลิก Auto Reboot แล้ว${NC}"
          ;;
        0) ;;
        *) echo -e "${RED}  ✖ ไม่ถูกต้อง${NC}" ;;
      esac
      exit 0 ;;
    *) echo -e "${RED}  ✖ ไม่ถูกต้อง${NC}"; exit 1 ;;
  esac

  echo -e "\n${GRAY}  1.start  2.stop  3.restart  4.status${NC}"
  read -rp "$(echo -e "  ${YELLOW}เลือก Action: ${NC}")" ac
  case "$ac" in
    1) systemctl start   "$svc" ;;
    2) systemctl stop    "$svc" ;;
    3) systemctl restart "$svc" ;;
    4) systemctl status  "$svc" ;;
    *) echo -e "${RED}  ✖ ไม่ถูกต้อง${NC}"; exit 1 ;;
  esac
  echo -e "${GREEN}  ✔ เสร็จสิ้น${NC}"
  ;;

0) exit 0 ;;
*) echo -e "${RED}  ✖ เลือกไม่ถูกต้อง${NC}"; exit 1 ;;
esac
EOF

sed -i \
  -e "s#__FILE_PATH__#$(esc "$FILE_PATH")#g" \
  -e "s#__NAME__#$(esc "$NAME")#g" \
  -e "s#__LIMIT__#$(esc "$LIMIT")#g" \
  -e "s#__URL__#$(esc "$URL")#g" /bin/gx
chmod +x /bin/gx
done_step "สร้าง /bin/gx แล้ว"

# ==============================
# 2) /usr/local/bin/s
# ==============================
step "สร้าง /usr/local/bin/s"
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
systemctl stop v2ray
systemctl start openvpn squid3 stunnel4
EOF
sed -i \
  -e "s#__FILE_PATH__#$(esc "$FILE_PATH")#g" \
  -e "s#__NAME__#$(esc "$NAME")#g" \
  -e "s#__LIMIT__#$(esc "$LIMIT")#g" \
  -e "s#__URL__#$(esc "$URL")#g" /usr/local/bin/s
chmod +x /usr/local/bin/s
done_step "สร้าง /usr/local/bin/s แล้ว"

# ==============================
# 3) /etc/profile
# ==============================
step "ตั้งค่า /etc/profile"
if ! grep -q "/usr/local/bin/s" /etc/profile; then
  sed -i '1i if [ -n "$SSH_CONNECTION" ]; then\n    sudo /usr/local/bin/s > /dev/null 2>&1\nfi\n' /etc/profile
fi
done_step "ตั้งค่า /etc/profile แล้ว"

# ==============================
# 4) sudoers
# ==============================
step "ตั้งค่า sudoers"
cat << 'EOF' > /etc/sudoers.d/vpn-scripts
ALL ALL=(ALL) NOPASSWD: /usr/local/bin/s
ubuntu ALL=(ALL) NOPASSWD: /usr/local/bin/s
EOF
chmod 440 /etc/sudoers.d/vpn-scripts
done_step "ตั้งค่า sudoers แล้ว"

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
echo "⏳ รอ OpenVPN ทำงาน..."
until systemctl is-active --quiet openvpn@server.service; do
    sleep 1
done
sleep 5
echo "⛔ หยุดการทำงานของ OpenVPN"
systemctl stop openvpn@server.service
systemctl stop stunnel4
systemctl stop squid3
systemctl start v2ray
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
Type=oneshot
ExecStart=/bin/set
RemainAfterExit=yes
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable set.service

# ==============================
# เสร็จสิ้น
# ==============================
clear
echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════╗"
echo "  ║     ✅ ติดตั้งเสร็จสิ้น               ║"
echo "  ╠══════════════════════════════════════╣"
echo -e "  ║  ${WHITE}เข้าเมนูหลัก${CYAN}      : ${GREEN}gx${CYAN}               ║"
echo -e "  ║  ${WHITE}ไฟล์สถานะ${CYAN}        : ${GREEN}$FILE_PATH${CYAN}"
echo "  ║  ${WHITE}V2Ray Service${CYAN}   : ${GREEN}v2ray${CYAN}            ║"
echo "  ║  ${WHITE}Cert Path${CYAN}        : ${GREEN}/etc/xray/${CYAN}            ║"
echo -e "  ╚══════════════════════════════════════╝${NC}"
    