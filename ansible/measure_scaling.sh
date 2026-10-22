#!/bin/bash
# measure_scaling.sh
# Do thoi gian chay 1 playbook theo so thiet bi (dung --limit), lap nhieu lan.
#
# Cach dung (chay trong thu muc ansible/):
#   bash measure_scaling.sh deploy_config.yml 3 "leaf1" "leaf1,leaf2,spine1" "ceos"
#     - tham so 1: ten playbook
#     - tham so 2: so lan lap cho moi muc (nen >= 3 de lay trung binh)
#     - tu tham so 3: cac chuoi --limit (moi chuoi la 1 muc so thiet bi)
#
# Ket qua: ../results/scaling_<thoigian>.csv va log tung lan chay trong ../results/logs/

set -u

if [ "$#" -lt 3 ]; then
  echo "Thieu tham so. Xem huong dan o dau file measure_scaling.sh"
  exit 1
fi

PLAYBOOK="$1"
REPEAT="$2"
shift 2

STAMP=$(date +%Y%m%d_%H%M%S)
RESULT_DIR="../results"
LOG_DIR="$RESULT_DIR/logs"
CSV="$RESULT_DIR/scaling_$STAMP.csv"
mkdir -p "$LOG_DIR"

echo "limit,so_thiet_bi,lan,giay,trang_thai" > "$CSV"

K=0
for LIMIT in "$@"; do
  K=$((K + 1))

  # Dem so thiet bi that su khop voi --limit (hoi lai chinh ansible, khong dem tay)
  N=$(ansible "$LIMIT" --list-hosts 2>/dev/null | awk '/hosts \(/ {gsub(/[^0-9]/, "", $2); print $2}')
  if [ -z "$N" ] || [ "$N" = "0" ]; then
    echo "Bo qua: --limit \"$LIMIT\" khong khop thiet bi nao"
    continue
  fi

  # Doi dau phay thanh dau + de nhan trong file CSV khong bi vo cot
  LABEL=${LIMIT//,/+}

  for i in $(seq 1 "$REPEAT"); do
    LOG="$LOG_DIR/${STAMP}_muc${K}_${N}tb_lan${i}.log"

    START=$(date +%s.%N)
    ansible-playbook "$PLAYBOOK" --limit "$LIMIT" > "$LOG" 2>&1
    RC=$?
    END=$(date +%s.%N)

    SEC=$(awk -v s="$START" -v e="$END" 'BEGIN { printf "%.2f", e - s }')
    if [ "$RC" -eq 0 ]; then
      STATUS="OK"
    else
      STATUS="LOI(rc=$RC)"
    fi

    echo "$LABEL,$N,$i,$SEC,$STATUS" >> "$CSV"
    echo "  [$N thiet bi] lan $i: ${SEC}s - $STATUS"
  done
done

echo ""
echo "=== TOM TAT (chi tinh cac lan OK) ==="
printf "%-12s %-6s %-12s %-8s %-8s\n" "so_thiet_bi" "lan" "tb(giay)" "min" "max"
awk -F, 'NR > 1 && $5 == "OK" {
  n[$2]++; sum[$2] += $4
  if (!($2 in mn) || $4 < mn[$2]) mn[$2] = $4
  if (!($2 in mx) || $4 > mx[$2]) mx[$2] = $4
}
END {
  for (k in n) printf "%-12s %-6d %-12.2f %-8.2f %-8.2f\n", k, n[k], sum[k] / n[k], mn[k], mx[k]
}' "$CSV" | sort -n

echo ""
echo "Da luu: $CSV"
