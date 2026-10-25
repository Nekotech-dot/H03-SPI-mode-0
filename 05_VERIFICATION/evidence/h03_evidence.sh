#!/usr/bin/env bash
# H03 - Gom MOI bang chung cho bao cao vao MOT log (doc thang tu report cua run).
# Dung (tu thu muc goc H03, trong nix-shell neu can iverilog):
#   CELL_LIB=<repo skywater-pdk-libs-sky130_fd_sc_hd> bash 05_VERIFICATION/evidence/h03_evidence.sh [RUN_DIR]
# Bo CELL_LIB thi bo qua buoc GLS (chi in log GLS cu neu co).
# Ket qua: 05_VERIFICATION/evidence/evidence_<RUN>.txt  (commit file nay vao repo)
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
RUN="${1:-$(ls -d "$ROOT"/04_IMPLEMENTATION/scripts/runs/RUN_* | sort | tail -1)}"
RUN="$(cd "$RUN" && pwd)"; R="$(basename "$RUN")"
REG="$ROOT/05_VERIFICATION/regression"
OUTF="$HERE/evidence_$R.txt"
STA=$(ls -d "$RUN"/*-openroad-stapostpnr | tail -1)
SYN=$(ls -d "$RUN"/*-yosys-synthesis | head -1)
CTS=$(ls -d "$RUN"/*-openroad-cts | head -1)
M="$RUN/final/metrics.json"
met() { grep -oE "\"$1\": *[^,}]+" "$M" | head -1 | sed -E 's/.*: *//'; }   # doc 1 metric
hdr() { printf '\n==================== %s ====================\n' "$1"; }
first_path() { awk '/^Startpoint/{n++} n==1' "$1"; }

{
hdr "0. THONG TIN TAI LAP"
echo "Ngay chay script : $(date '+%Y-%m-%d %H:%M %z')"
echo "Thu muc H03      : $ROOT"
if git -C "$ROOT" rev-parse HEAD >/dev/null 2>&1; then
  echo "Git remote       : $(git -C "$ROOT" remote get-url origin 2>/dev/null || echo '(chua co remote)')"
  echo "Git commit       : $(git -C "$ROOT" rev-parse HEAD)"
  echo "So commit        : $(git -C "$ROOT" rev-list --count HEAD)"
  echo "Trang thai       : $(git -C "$ROOT" status --porcelain | wc -l) file chua commit"
else echo "Git              : (thu muc nay KHONG phai git repo)"; fi
echo "RUN              : $R"
echo "LibreLane        : $(grep -oE '"librelane_version": *"[^"]+"' "$RUN/resolved.json" | cut -d'"' -f4)"
echo "PDK              : $(grep -oE '"PDK": *"[^"]+"' "$RUN/resolved.json" | cut -d'"' -f4)  (PDK_ROOT: $(grep -oE '"PDK_ROOT": *"[^"]+"' "$RUN/resolved.json" | cut -d'"' -f4))"
echo "Thu vien cell    : $(grep -oE '"STD_CELL_LIBRARY": *"[^"]+"' "$RUN/resolved.json" | cut -d'"' -f4)"
echo "CLOCK_PERIOD     : $(grep -oE '"CLOCK_PERIOD": *[0-9.]+' "$RUN/resolved.json" | sed -E 's/.*: *//') ns (gia dinh phan tich)"
echo "SDC              : $(grep -vE '^\s*(#|$)' "$ROOT/04_IMPLEMENTATION/constraints/design.sdc" | tr '\n' ';')"
echo "Icarus           : $(iverilog -V 2>&1 | head -1)"
echo "SHA-256 RTL      : $(sha256sum "$ROOT/04_IMPLEMENTATION/rtl/h03_spi_master.sv" | cut -c1-16)…"
echo "SHA-256 nl synth : $(sha256sum "$SYN/h03_spi_master.nl.v" | cut -c1-16)…"
echo "SHA-256 nl final : $(sha256sum "$RUN/final/nl/h03_spi_master.nl.v" | cut -c1-16)…"
echo "SHA-256 DEF final: $(sha256sum "$RUN/final/def/h03_spi_master.def" | cut -c1-16)…"

hdr "1. RTL REGRESSION (lenh: bash 05_VERIFICATION/regression/run_regression.sh)"
bash "$REG/run_regression.sh" 2>&1 | grep -E 'Icarus|HC=|SUMMARY'
grep -h SUMMARY "$REG"/logs/sim_hc*.log

hdr "2. GATE-LEVEL SIMULATION (lenh: CELL_LIB=... bash 05_VERIFICATION/regression/run_gls.sh RUN)"
if [ -n "${CELL_LIB:-}" ]; then bash "$REG/run_gls.sh" "$RUN" 2>&1
else echo "(CELL_LIB chua dat - in ket qua GLS cu)"; grep -hE 'ALL H03|FAIL' "$REG"/logs/gls/sim_*.log 2>/dev/null; fi

hdr "3. TONG HOP ($(basename "$SYN")/reports/stat.rpt)"
grep -E '[0-9]+ +[0-9.E+]+ +cells$|dfxtp' "$SYN/reports/stat.rpt" | head -3
grep -m1 'mapping auto encoding' "$SYN/yosys-synthesis.log"

hdr "4. STA SAU DINH TUYEN ($(basename "$STA")/summary.rpt)"
grep -E 'Corner|Overall|nom_|min_|max_' "$STA/summary.rpt" | cut -c1-140 | head -12
echo "metrics: setup WS = $(met timing__setup__ws) ns | hold WS = $(met timing__hold__ws) ns | setup vio = $(met timing__setup_vio__count) | hold vio = $(met timing__hold_vio__count)"

hdr "5. DUONG TOI HAN SETUP (max_ss_100C_1v60/max.rpt, duong dau tien)"
first_path "$STA/max_ss_100C_1v60/max.rpt" | grep -E 'Startpoint|Endpoint|/Q |/X |/D |\(net\)$|library setup|data arrival|data required|slack' | grep -v 'clk (net)\|clknet' | head -30
hdr "5b. DUONG TOI HAN HOLD (min_ff_n40C_1v95/min.rpt)"
first_path "$STA/min_ff_n40C_1v95/min.rpt" | grep -E 'Startpoint|Endpoint|/Q |/X |/D |slack' | head -10
echo "Ten FF trong netlist final:"
for ff in $(first_path "$STA/max_ss_100C_1v60/max.rpt" | grep -oE '^(Startpoint|Endpoint): _[0-9]+_' | awk '{print $2}') \
          $(first_path "$STA/min_ff_n40C_1v95/min.rpt" | grep -oE '^Startpoint: _[0-9]+_' | awk '{print $2}'); do
  q=$(grep -A3 " $ff (" "$RUN/final/nl/h03_spi_master.nl.v" | grep -oE '\.Q\([^)]*\)' | head -1)
  echo "  $ff -> $q"
done

hdr "6. CTS ($(basename "$CTS")/openroad-cts.log) + SKEW"
grep -E 'Created [0-9]+ clock buffers|number of buffers in the clock path|Dummy loads' "$CTS/openroad-cts.log"
echo "clock_buffer = $(met 'design__instance__count__class:clock_buffer') | clock_inverter = $(met 'design__instance__count__class:clock_inverter')"
echo "skew worst setup = $(met clock__skew__worst_setup) ns | skew worst hold = $(met clock__skew__worst_hold) ns"

hdr "7. CONG SUAT UOC LUONG (nom_tt_025C_1v80/power.rpt; hoat dong mac dinh cua OpenSTA)"
grep -E '^(Sequential|Combinational|Clock|Total) ' "$STA/nom_tt_025C_1v80/power.rpt"

hdr "8. VAT LY ($(basename "$RUN")/final/metrics.json)"
echo "instance tong = $(met design__instance__count) | stdcell = $(met design__instance__count__stdcell)"
for c in sequential_cell multi_input_combinational_cell inverter timing_repair_buffer clock_buffer clock_inverter tap_cell fill_cell; do
  printf '  %-32s %s\n' "$c" "$(met "design__instance__count__class:$c")"; done
echo "core area = $(met design__core__area) um^2 | utilization = $(met design__instance__utilization)"
echo "DRC magic = $(met magic__drc_error__count) | DRC klayout = $(met klayout__drc_error__count) | LVS error = $(met design__lvs_error__count) | antenna nets = $(met antenna__violating__nets)"
ls -l "$RUN/final/gds/"*.gds
} 2>&1 | tee "$OUTF"
echo; echo ">>> Da ghi: $OUTF"
