#!/bin/bash
# benchmark_render.sh
# Do thoi gian SINH cau hinh (render) tu template khi so thiet bi tang.
# KHONG ket noi toi thiet bi nao: script tu sinh inventory tam, chay
# render_configs.yml roi xoa ket qua tam. Chi do toc do sinh cau hinh,
# KHONG phai toc do day cau hinh len thiet bi that.
#
# Cach dung (chay trong thu muc ansible/):
#   bash benchmark_render.sh <so_lan_lap> <tong_tb_1> [<tong_tb_2> ...]
#   vd: bash benchmark_render.sh 3 20 100 250
# Bien moi truong tuy chon:
#   FORKS=20   so tien trinh song song cua Ansible (mac dinh 5)
#   SPINES=4   so spine trong fabric gia lap (mac dinh 4, phan con lai la leaf)
# Ket qua: ../results/render_bench_<thoigian>.csv

set -u

if [ "$#" -lt 2 ]; then
  echo "Thieu tham so. Xem huong dan o dau file benchmark_render.sh"
  exit 1
fi

REPEAT="$1"
shift
FORKS="${FORKS:-5}"
SPINES="${SPINES:-4}"

STAMP=$(date +%Y%m%d_%H%M%S)
RESULT_DIR="../results"
LOG_DIR="$RESULT_DIR/logs"
CSV="$RESULT_DIR/render_bench_$STAMP.csv"
mkdir -p "$LOG_DIR"

echo "tong_tb,spine,leaf,forks,lan,giay,so_file,tong_dong,dia_chi_hop_le,trang_thai" > "$CSV"

for N in "$@"; do
  LEAVES=$((N - SPINES))
  if [ "$LEAVES" -lt 1 ]; then
    echo "Bo qua: tong $N thiet bi qua nho so voi $SPINES spine"
    continue
  fi

  # Scheme dia chi 10.<spine>.<leaf>.x va 10.255.1.<leaf> chi chua duoc toi da 255 leaf
  if [ "$LEAVES" -le 255 ] && [ "$SPINES" -le 255 ]; then
    VALID="co"
  else
    VALID="khong"
  fi

  for i in $(seq 1 "$REPEAT"); do
    TMP=$(mktemp -d)
    INV="$TMP/hosts.ini"
    LOG="$LOG_DIR/${STAMP}_render_${N}tb_lan${i}.log"

    # Sinh inventory tam: moi thiet bi mang san spine_id / leaf_id ngay tren dong khai bao
    {
      echo "[spine]"
      for s in $(seq 1 "$SPINES"); do echo "spine$s spine_id=$s"; done
      echo "[leaf]"
      for l in $(seq 1 "$LEAVES"); do echo "leaf$l leaf_id=$l"; done
      echo "[ceos:children]"
      echo "spine"
      echo "leaf"
    } > "$INV"

    START=$(date +%s.%N)
    # Truyen bien dang JSON de spine_count/leaf_count la SO (dang key=value se thanh chuoi
    # va template bi loi khi cong tru). -e co do uu tien cao nhat nen de len group_vars/all.yml
    ansible-playbook render_configs.yml -i "$INV" -f "$FORKS" \
      -e "{\"spine_count\": $SPINES, \"leaf_count\": $LEAVES, \"render_dir\": \"$TMP/out\"}" > "$LOG" 2>&1
    RC=$?
    END=$(date +%s.%N)

    SEC=$(awk -v s="$START" -v e="$END" 'BEGIN { printf "%.2f", e - s }')
    NFILE=$(find "$TMP/out" -name '*.cfg' 2>/dev/null | wc -l)
    NLINE=$(find "$TMP/out" -name '*.cfg' -exec cat {} + 2>/dev/null | wc -l)
    if [ "$RC" -eq 0 ]; then STATUS="OK"; else STATUS="LOI(rc=$RC)"; fi

    echo "$N,$SPINES,$LEAVES,$FORKS,$i,$SEC,$NFILE,$NLINE,$VALID,$STATUS" >> "$CSV"
    echo "  [$N thiet bi, forks=$FORKS] lan $i: ${SEC}s - $NFILE file, $NLINE dong - $STATUS"

    rm -rf "$TMP"
  done
done

echo ""
echo "=== TOM TAT (chi tinh cac lan OK) ==="
printf "%-8s %-6s %-4s %-10s %-8s %-8s %-12s %-10s\n" "tong_tb" "forks" "n" "trung_vi" "min" "max" "giay/tb" "dia_chi"
for N in $(awk -F, 'NR > 1 && $10 == "OK" && !seen[$1]++ {print $1}' "$CSV"); do
  VALS=$(awk -F, -v n="$N" '$1 == n && $10 == "OK" {print $6}' "$CSV" | sort -n)
  VALID=$(awk -F, -v n="$N" '$1 == n {print $9; exit}' "$CSV")
  echo "$VALS" | awk -v n="$N" -v f="$FORKS" -v v="$VALID" '
    { a[NR] = $1 }
    END {
      c = NR
      med = (c % 2) ? a[(c + 1) / 2] : (a[c / 2] + a[c / 2 + 1]) / 2
      printf "%-8s %-6s %-4d %-10.2f %-8.2f %-8.2f %-12.3f %-10s\n", n, f, c, med, a[1], a[c], med / n, v
    }'
done

echo ""
echo "Da luu: $CSV"
