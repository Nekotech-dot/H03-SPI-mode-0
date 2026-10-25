#!/usr/bin/env python3
"""H03 - Mutation test: kiem tra chinh TESTBENCH.

Tao cac ban sao RTL bi cai loi co chu dich (RTL goc KHONG bi sua), roi chay
ba testbench tren tung ban:
  1. testbench goc cua thay   (05_VERIFICATION/testbench/h03_spi_master_tb.sv)
  2. testbench da sua slave   (ref/h03_spi_master_tb_sua_slave.sv)
  3. testbench regression     (h03_spi_master_regression_tb.sv, HC = 1 va 2)
Mot testbench "giet" (kill) duoc mutant neu no bao FAIL.
Dung: python3 05_VERIFICATION/regression/run_mutation.py   (tu thu muc goc H03)
"""
import pathlib, subprocess, sys, tempfile

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent
RTL = ROOT / "04_IMPLEMENTATION/rtl/h03_spi_master.sv"
TB_THAY = ROOT / "05_VERIFICATION/testbench/h03_spi_master_tb.sv"
TB_SUA = HERE / "ref/h03_spi_master_tb_sua_slave.sv"
TB_REG = HERE / "h03_spi_master_regression_tb.sv"

RISE_SAMPLE = """                            rx_shift <= MSB_FIRST
                                      ? {rx_shift[6:0],miso}
                                      : {miso,rx_shift[7:1]};
"""
FALL_UPDATE = """                                if (MSB_FIRST) begin
                                    tx_shift <= {tx_shift[6:0],1'b0};
                                    mosi <= tx_shift[6];
                                end else begin"""

# (ma, mo ta loi, [(chuoi goc, chuoi thay)])
MUTANTS = [
    ("M1", "Ghep bit nhan theo LSB-first (sai thu tu bit RX)",
     [("? {rx_shift[6:0],miso}", "? {miso,rx_shift[7:1]}")]),
    ("M2", "Lay mau MISO o suon XUONG thay vi suon len (rui ro Charter muc 10)",
     [(RISE_SAMPLE, ""),
      ("                            sclk <= 1'b0;\n",
       "                            sclk <= 1'b0;\n                            rx_shift <= {rx_shift[6:0],miso};\n")]),
    ("M3", "Doi MOSI o suon LEN thay vi suon xuong",
     [("                                    tx_shift <= {tx_shift[6:0],1'b0};\n                                    mosi <= tx_shift[6];\n", ""),
      ("                            edge_count <= edge_count + 1'b1;\n",
       "                            edge_count <= edge_count + 1'b1;\n"
       "                            if (edge_count != 0) begin tx_shift <= {tx_shift[6:0],1'b0}; mosi <= tx_shift[6]; end\n")]),
    ("M4", "Phat 9 xung SCLK thay vi 8",
     [("if (edge_count == 8) begin", "if (edge_count == 9) begin")]),
    ("M5", "Nha CS cung luc voi suon xuong thu 8 (CS khong bao tron)",
     [("                                state <= FINISH;\n",
       "                                state <= FINISH;\n                                cs_n <= 1'b1;\n")]),
    ("M6", "Khong dua bit dau len MOSI khi CS xuong (sai CPHA = 0)",
     [("mosi <= MSB_FIRST ? tx_data[7] : tx_data[0];", "mosi <= 1'b0;")]),
    ("M7", "rx_data cap nhat tung bit trong khi dang truyen",
     [("                            edge_count <= edge_count + 1'b1;\n",
       "                            edge_count <= edge_count + 1'b1;\n                            rx_data <= {rx_shift[6:0],miso};\n")]),
    ("M8", "Bo chia sai 1 (half_tick lech mot chu ky)",
     [("(half_count == HALF_CYCLES-1)", "(half_count == HALF_CYCLES)")]),
    ("M9", "done khong tu xoa (ket muc 1; khong con la xung)",
     [("            done <= 1'b0;\n", "")]),
]


def run(cmd, cwd, timeout=20):
    try:
        p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout)
        return p.returncode, p.stdout + p.stderr
    except subprocess.TimeoutExpired:
        return None, "TIMEOUT: mo phong khong ket thuc"


def verdict(tb, rtl, work, hc=None):
    out_bin = work / "a.out"
    cmd = ["iverilog", "-g2012", "-o", str(out_bin)]
    if hc is not None:
        cmd += ["-P", f"h03_spi_master_regression_tb.HC={hc}"]
    rc, log = run(cmd + [str(rtl), str(tb)], work)
    if rc != 0:
        return "LOI BIEN DICH", log
    rc, log = run(["vvp", "-n", str(out_bin), f"+vcd={work/'x.vcd'}"], work)
    if rc is None:
        return "TREO (khong ket luan)", log
    passed = rc == 0 and ("H03 TB completed" in log or "H03 TB PASS" in log or "ALL H03 TESTS PASS" in log) \
        and "FATAL" not in log and "Assertion" not in log
    return ("PASS (khong bat)" if passed else "FAIL (da bat)"), log


def main():
    src = RTL.read_text()
    rows = []
    (HERE / "logs").mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=HERE / "logs") as td:
        work = pathlib.Path(td)
        benches = [("TB goc cua thay", TB_THAY, None), ("TB sua slave", TB_SUA, None),
                   ("Regression HC=1", TB_REG, 1), ("Regression HC=2", TB_REG, 2)]
        # RTL goc: moi TB phai PASS
        base = [verdict(tb, RTL, work, hc)[0] for _, tb, hc in benches]
        rows.append(("M0", "RTL goc (khong loi)", base))
        for mid, desc, edits in MUTANTS:
            m = src
            for old, new in edits:
                if m.count(old) != 1:
                    sys.exit(f"{mid}: khong tim thay dung 1 cho de cai loi: {old[:50]!r}")
                m = m.replace(old, new)
            mf = work / f"{mid}.sv"
            mf.write_text(m)
            res = []
            for name, tb, hc in benches:
                v, log = verdict(tb, mf, work, hc)
                res.append(v)
                (HERE / "logs").mkdir(exist_ok=True)
                (HERE / "logs" / f"mutation_{mid}_{name.replace(' ', '_').replace('=', '')}.log").write_text(log)
            rows.append((mid, desc, res))

    hdr = ["Ma", "Loi cai vao"] + [b[0] for b in benches]
    lines = [",".join(hdr)] + [",".join([r[0], r[1]] + r[2]) for r in rows]
    (HERE / "logs" / "mutation_results.csv").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))
    kills = [sum(1 for r in rows[1:] if r[2][i].startswith("FAIL")) for i in range(len(benches))]
    print("\nSo mutant bi bat / tong:", ", ".join(f"{b[0]}: {k}/{len(MUTANTS)}" for b, k in zip(benches, kills)))
    union = sum(1 for r in rows[1:] if r[2][2].startswith("FAIL") or r[2][3].startswith("FAIL"))
    print(f"Regression (HC=1 hoac HC=2 bat): {union}/{len(MUTANTS)}")
    ok = all(v.startswith("PASS") for v in rows[0][2]) and union == len(MUTANTS)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
