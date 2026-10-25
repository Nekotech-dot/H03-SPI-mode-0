#!/usr/bin/env bash
# H03 - chay regression voi HALF_CYCLES = 1, 2, 4 tren RTL GOC (khong sua).
# Dung: bash 05_VERIFICATION/regression/run_regression.sh   (chay tu thu muc goc H03)
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
RTL="${RTL:-$ROOT/04_IMPLEMENTATION/rtl/h03_spi_master.sv}"
TB="$HERE/h03_spi_master_regression_tb.sv"
OUT="$HERE/logs"
mkdir -p "$OUT"

echo "Icarus: $(iverilog -V 2>&1 | head -1)"
echo "RTL   : $RTL"
echo "sha256: $(sha256sum "$RTL" | cut -d' ' -f1)"
fail=0
: > "$OUT/results.csv"
for HC in 1 2 4; do
    iverilog -g2012 -P h03_spi_master_regression_tb.HC=$HC -o "$OUT/sim_hc$HC.vvp" "$RTL" "$TB" \
        > "$OUT/compile_hc$HC.log" 2>&1 || { echo "HC=$HC: LOI BIEN DICH"; cat "$OUT/compile_hc$HC.log"; fail=1; continue; }
    vvp -n "$OUT/sim_hc$HC.vvp" +vcd="$OUT/h03_waveform_hc$HC.vcd" > "$OUT/sim_hc$HC.log" 2>&1
    rc=$?
    grep '^RESULT' "$OUT/sim_hc$HC.log" | { if [ "$HC" = 1 ]; then cat; else grep -v '^RESULT,HC,'; fi; } >> "$OUT/results.csv"
    echo "HC=$HC: $(grep -E 'ALL H03 TESTS PASS|REGRESSION FAIL|WATCHDOG' "$OUT/sim_hc$HC.log" | head -1)"
    grep '^INFO' "$OUT/sim_hc$HC.log" | sed 's/^/       /'
    [ $rc -ne 0 ] && fail=1
done
sed -i 's/^RESULT,//' "$OUT/results.csv"
echo "Bang ket qua: $OUT/results.csv"
exit $fail
