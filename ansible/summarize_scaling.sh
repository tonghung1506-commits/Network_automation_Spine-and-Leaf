#!/bin/bash
# summarize_scaling.sh
# Tom tat file CSV do thoi gian theo TUNG chuoi --limit (khong gop theo so thiet bi).
# Cach dung (trong thu muc ansible/):
#   bash summarize_scaling.sh ../results/scaling_A.csv [../results/scaling_B.csv ...]
# Nhieu file se duoc gop chung theo nhan limit. Chi tinh cac lan OK.

if [ "$#" -lt 1 ]; then
  echo "Thieu tham so: can it nhat 1 file CSV"
  exit 1
fi

printf "%-26s %-4s %-3s %-9s %-9s %-9s %-7s %-7s %-4s\n" \
  "limit" "tb" "n" "lan_dau" "tu_lan_2" "trung_vi" "min" "max" "loi"

# Lay danh sach nhan limit theo thu tu xuat hien (bo dong tieu de)
LABELS=$(awk -F, '$1 != "limit" && !seen[$1]++ {print $1}' "$@")

for L in $LABELS; do
  # Cac gia tri OK cua nhan nay, da sap xep de lay trung vi
  VALS=$(awk -F, -v l="$L" '$1 == l && $5 == "OK" {print $4}' "$@" | sort -n)
  if [ -z "$VALS" ]; then
    # nhan nay khong co lan OK nao
    NLOI=$(awk -F, -v l="$L" '$1 == l' "$@" | wc -l)
    printf "%-26s %-4s %-3s %-9s %-9s %-9s %-7s %-7s %-4s\n" "$L" "-" "0" "-" "-" "-" "-" "-" "$NLOI"
    continue
  fi
  TB=$(awk -F, -v l="$L" '$1 == l {print $2; exit}' "$@")
  NLOI=$(awk -F, -v l="$L" '$1 == l && $5 != "OK"' "$@" | wc -l)
  # Trung binh lan dau (lan 1) va cac lan sau (lan >= 2)
  COLD_WARM=$(awk -F, -v l="$L" '
    $1 == l && $5 == "OK" {
      if ($3 == 1) { c += $4; nc++ } else { w += $4; nw++ }
    }
    END {
      printf "%s %s", (nc ? sprintf("%.2f", c / nc) : "-"), (nw ? sprintf("%.2f", w / nw) : "-")
    }' "$@")
  echo "$VALS" | awk -v l="$L" -v tb="$TB" -v loi="$NLOI" -v cw="$COLD_WARM" '
    { a[NR] = $1 }
    END {
      n = NR
      med = (n % 2) ? a[(n + 1) / 2] : (a[n / 2] + a[n / 2 + 1]) / 2
      split(cw, x, " ")
      printf "%-26s %-4s %-3d %-9s %-9s %-9.2f %-7.2f %-7.2f %-4d\n", l, tb, n, x[1], x[2], med, a[1], a[n], loi
    }'
done
