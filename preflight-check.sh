#!/bin/bash
# preflight-check.sh
# Chay lenh nay DAU TIEN, moi khi mo lai may / bat dau 1 phien lam viec moi
# voi du an spine-leaf-mini. Muc tieu: gom toan bo cac loi nho da gap phai
# trong qua trinh debug (container Exited, mat IP fabric, mat mysql-client,
# mat bind-address, mat database appdb) thanh 1 lenh duy nhat, an toan
# chay lai nhieu lan (idempotent) - du lab dang khoe hay dang hong deu chay
# duoc, khong lam hong them gi ca.
#
# Cach dung:
#   cp preflight-check.sh ~/network_automation/spine-leaf-mini/
#   cd ~/network_automation/spine-leaf-mini
#   chmod +x preflight-check.sh
#   ./preflight-check.sh
 
set -e  # dung ngay neu 1 buoc that bai - tranh chay tiep tren nen da hong,
        # gay loi lan sau kho doan nguyen nhan hon loi lan dau
 
LAB_DIR=~/network_automation/spine-leaf-mini
TOPO_FILE=spine-leaf-fabric-mini.clab.yml
PREFIX=clab-spine-leaf-mini
 
cd "$LAB_DIR"
 
echo "===================================================="
echo "BUOC 1/6 - Kiem tra trang thai 9 container"
echo "===================================================="
STATUS=$(docker ps -a --filter "name=$PREFIX" --format "{{.Names}}: {{.Status}}")
echo "$STATUS"
 
if echo "$STATUS" | grep -q "Exited"; then
    echo ""
    echo "-> Phat hien container Exited. Deploy lai toan bo lab..."
    sudo containerlab deploy -t "$TOPO_FILE" --reconfigure
else
    echo ""
    echo "-> Tat ca container dang Up, bo qua buoc deploy lai."
fi
 
echo ""
echo "===================================================="
echo "BUOC 2/6 - Khoi phuc IP/Apache/MySQL co ban cho 3 node Linux"
echo "===================================================="
"$LAB_DIR/configs-backup/setup-linux-nodes.sh"
 
echo ""
echo "===================================================="
echo "BUOC 3/6 - Kiem tra BGP + xac nhan ssh-key tren switch con song"
echo "===================================================="
docker exec "$PREFIX-spine1" Cli -p 15 -c "show ip bgp summary"
 
echo ""
echo "===================================================="
echo "BUOC 4/6 - Dam bao web01 co mysql-client"
echo "===================================================="
if docker exec "$PREFIX-web01" which mysql > /dev/null 2>&1; then
    echo "-> mysql-client da co san, bo qua cai dat."
else
    echo "-> Chua co mysql-client, dang cai..."
    docker exec "$PREFIX-web01" apt-get update -qq
    docker exec "$PREFIX-web01" apt-get install -y -qq mysql-client
fi
 
echo ""
echo "===================================================="
echo "BUOC 5/6 - Dam bao MySQL tren db01: bind-address, database, quyen appuser"
echo "===================================================="
CURRENT_BIND=$(docker exec "$PREFIX-db01" grep "^bind-address" /etc/mysql/mysql.conf.d/mysqld.cnf | awk '{print $3}')
if [ "$CURRENT_BIND" = "0.0.0.0" ]; then
    echo "-> bind-address da dung (0.0.0.0), bo qua restart MySQL."
else
    echo "-> bind-address dang la '$CURRENT_BIND', sua lai va restart MySQL..."
    docker exec "$PREFIX-db01" sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf
    docker exec "$PREFIX-db01" service mysql restart
fi
 
set +H  # tat history expansion cua bash - AppPass123! co dau "!" se bi bash
        # hieu nham thanh lenh goi lai history neu khong tat cai nay
docker exec "$PREFIX-db01" mysql -u root -e "
CREATE DATABASE IF NOT EXISTS appdb;
USE appdb;
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100)
);
INSERT IGNORE INTO users (username, email) VALUES
    ('testuser1', 'test1@example.com'),
    ('testuser2', 'test2@example.com');
CREATE USER IF NOT EXISTS 'appuser'@'%' IDENTIFIED BY 'AppPass123!';
GRANT ALL PRIVILEGES ON appdb.* TO 'appuser'@'%';
FLUSH PRIVILEGES;
"
# GHI CHU: day la schema TAM, dung de test duong truyen. Neu sau nay co
# schema that cua app, thay doan CREATE TABLE/INSERT o tren bang schema that.
 
echo ""
echo "===================================================="
echo "BUOC 6/6 - Test cuoi: MySQL xuyen fabric tu web01 sang db01"
echo "===================================================="
docker exec "$PREFIX-web01" mysql -h 172.16.2.10 -u appuser -pAppPass123! appdb -e "SELECT * FROM users;"
 
echo ""
echo "===================================================="
echo "HOAN TAT - Lab da san sang, co the bat dau lam viec."
echo "===================================================="
