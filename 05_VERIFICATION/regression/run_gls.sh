#!/usr/bin/env bash
# H03 - L4 Gate-level simulation (zero-delay, model FUNCTIONAL cua sky130_fd_sc_hd)
# Chay chinh regression TB tren netlist that cua LibreLane:
#   (a) netlist sau tong hop  : runs/<RUN>/06-yosys-synthesis/h03_spi_master.nl.v
#   (b) netlist sau P&R       : runs/<RUN>/final/nl/h03_spi_master.nl.v
# Dung: CELL_LIB=<thu muc skywater-pdk-libs-sky130_fd_sc_hd> bash run_gls.sh [RUN_DIR]
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
RUN="${1:-$(ls -d "$ROOT"/04_IMPLEMENTATION/scripts/runs/RUN_* | sort | tail -1)}"
LIBDIR="${CELL_LIB:?Dat CELL_LIB tro toi repo skywater-pdk-libs-sky130_fd_sc_hd}"
TB="$HERE/h03_spi_master_regression_tb.sv"
OUT="$HERE/logs/gls"; mkdir -p "$OUT"
HC=4   # netlist tong hop voi HALF_CYCLES mac dinh = 4

declare -A NL=( [synth]="$RUN/06-yosys-synthesis/h03_spi_master.nl.v"
                [postpnr]="$RUN/final/nl/h03_spi_master.nl.v" )
echo "RUN   : $(basename "$RUN")"
fail=0
for k in synth postpnr; do
    nl="${NL[$k]}"
    # tao file include cho dung cac cell co trong netlist
    inc="$OUT/cells_$k.v"; : > "$inc"; incdirs=()
    for c in $(grep -ohE 'sky130_fd_sc_hd__[a-z0-9_]+' "$nl" | sort -u); do
        base=$(echo "$c" | sed -E 's/sky130_fd_sc_hd__//; s/_[0-9]+$//')
        echo "\`include \"$c.v\"" >> "$inc"
        incdirs+=("-I$LIBDIR/cells/$base")
    done
    ncell=$(grep -cE '^\s*sky130_fd_sc_hd__' "$nl")
    nff=$(grep -cE '^\s*sky130_fd_sc_hd__df' "$nl")
    iverilog -g2012 -DGLS -DFUNCTIONAL -I"$LIBDIR/models" "${incdirs[@]}" \
        -P h03_spi_master_regression_tb.HC=$HC -o "$OUT/gls_$k.vvp" "$inc" "$nl" "$TB" \
        > "$OUT/compile_$k.log" 2>&1 || { echo "[$k] LOI BIEN DICH"; tail -20 "$OUT/compile_$k.log"; fail=1; continue; }
    vvp -n "$OUT/gls_$k.vvp" +vcd="$OUT/gls_$k.vcd" > "$OUT/sim_$k.log" 2>&1 || fail=1
    printf "[%-7s] %4s instance, %2s flip-flop | %s\n" "$k" "$ncell" "$nff" \
        "$(grep -E 'ALL H03 TESTS PASS|REGRESSION FAIL|WATCHDOG' "$OUT/sim_$k.log" | head -1)"
    grep '^RESULT' "$OUT/sim_$k.log" | sed "s/^RESULT,/$k,/" > "$OUT/results_$k.csv"
done
exit $fail
