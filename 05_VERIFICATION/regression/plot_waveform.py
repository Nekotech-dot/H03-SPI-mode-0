#!/usr/bin/env python3
"""Ve waveform co chu thich tu VCD cua regression (transaction mau TX=0x96, slave=0x3A).
Moi moc thoi gian tren hinh deu doc tu VCD, khong ve tay.
Dung: python3 plot_waveform.py logs/h03_waveform_hc2.vcd logs/h03_waveform_hc2.png
"""
import sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

plt.rcParams["font.family"] = "DejaVu Sans"
vcd, out = sys.argv[1], sys.argv[2]
WANT = ["clk", "start", "cs_n", "sclk", "mosi", "miso", "rx_data", "done"]

# ---------------------------------------------------------------- parse VCD
ids, scale, t, on = {}, 1.0, 0, False
ch = {n: [] for n in WANT}
with open(vcd) as f:
    lines = f.read().split("\n")
i = 0
while i < len(lines):
    s = lines[i].strip()
    if s.startswith("$timescale"):
        j = i
        txt = ""
        while "$end" not in lines[j]:
            txt += lines[j]; j += 1
        txt += lines[j]
        unit = txt.replace("$timescale", "").replace("$end", "").strip()
        scale = {"1ps": 1e-3, "1ns": 1.0, "10ps": 1e-2, "100ps": 1e-1}.get(unit.replace(" ", ""), 1.0)
    elif s.startswith("$scope module dut"):
        # dung tin hieu o cap TB, bo qua scope DUT
        while not lines[i].strip().startswith("$upscope"):
            i += 1
    elif s.startswith("$var"):
        p = s.split()
        name = p[4]
        if name in WANT and p[3] not in ids:
            ids[p[3]] = name
    elif s.startswith("#"):
        t = int(s[1:]) * scale
    elif s == "$dumpon":
        on = True
    elif s == "$dumpoff":
        on = False
    elif s and s[0] in "01xzXZ" and s[1:] in ids:
        ch[ids[s[1:]]].append((t, s[0]))
    elif s and s[0] == "b":
        v, k = s[1:].split()
        if k in ids:
            ch[ids[k]].append((t, v))
    i += 1

def edges(name, val):
    return [tt for k, (tt, v) in enumerate(ch[name]) if v == val and k > 0 and ch[name][k-1][1] != val]

T0 = ch["clk"][1][0] if len(ch["clk"]) > 1 else 0
cs_fall = edges("cs_n", "0")[0]
cs_rise = [x for x in edges("cs_n", "1") if x > cs_fall][0]
rises = [x for x in edges("sclk", "1") if cs_fall < x < cs_rise]
falls = [x for x in edges("sclk", "0") if cs_fall < x <= cs_rise]
done_r = [x for x in edges("done", "1") if x > cs_fall][0]
first_t = min(x for n in WANT for (x, _) in ch[n][1:2]) if any(len(ch[n]) > 1 for n in WANT) else 0
t_start = max(cs_fall - 25, first_t + 0.5)
t_end = done_r + 30
assert len(rises) == 8 and len(falls) == 8, (len(rises), len(falls))

def val_at(name, tt):
    v = None
    for (x, val) in ch[name]:
        if x <= tt: v = val
        else: break
    return v

# ---------------------------------------------------------------- ve
rows = ["clk", "start", "cs_n", "sclk", "mosi", "miso", "rx_data", "done"]
labels = {"clk": "clk (100 MHz)", "start": "start", "cs_n": "cs_n", "sclk": "sclk",
          "mosi": "mosi", "miso": "miso (slave)", "rx_data": "rx_data[7:0]", "done": "done"}
Y = {n: (len(rows) - 1 - k) * 1.5 for k, n in enumerate(rows)}
H = 0.9
fig, ax = plt.subplots(figsize=(15, 8.2), dpi=170)
BLUE, RED, GREEN, GREY = "#1f4e79", "#c0392b", "#1e7b34", "#8a8a8a"

def draw_bit(name):
    y0 = Y[name]
    pts = [(t_start, val_at(name, t_start))] + [(x, v) for x, v in ch[name] if t_start < x < t_end] + [(t_end, None)]
    for k in range(len(pts) - 1):
        x0, v = pts[k]; x1 = pts[k+1][0]
        if v in ("x", "X"):
            ax.fill_between([x0, x1], y0, y0 + H, color="#f2b8b5", hatch="////", edgecolor=RED, lw=0, alpha=0.6)
        else:
            yy = y0 + (H if v == "1" else 0)
            ax.plot([x0, x1], [yy, yy], color=BLUE, lw=1.6)
            if k + 1 < len(pts) - 1:
                v2 = pts[k+1][1]
                if v2 in ("0", "1") and v2 != v:
                    ax.plot([x1, x1], [y0, y0 + H], color=BLUE, lw=1.6)

def draw_bus(name):
    y0 = Y[name]
    pts = [(t_start, val_at(name, t_start))] + [(x, v) for x, v in ch[name] if t_start < x < t_end] + [(t_end, None)]
    for k in range(len(pts) - 1):
        x0, v = pts[k]; x1 = pts[k+1][0]; s = 0.8
        xs = [x0, x0+s, x1-s, x1, x1-s, x0+s, x0]; ys = [y0+H/2, y0+H, y0+H, y0+H/2, y0, y0, y0+H/2]
        ax.fill(xs, ys, color="#dbe8f5" if k else "#eeeeee"); ax.plot(xs, ys, color=BLUE, lw=1.2)
        ax.text((x0+x1)/2, y0+H/2, f"0x{int(v, 2):02X}" if v and set(v) <= {"0", "1"} else str(v),
                ha="center", va="center", fontsize=10, fontweight="bold")

for n in rows:
    (draw_bus if n == "rx_data" else draw_bit)(n)
    ax.text(t_start - 3, Y[n] + H/2, labels[n], ha="right", va="center", fontsize=10, fontweight="bold")

# bit labels on MOSI / MISO
mosi_ref = [cs_fall] + falls[:7]
for k in range(8):
    x0 = mosi_ref[k]; x1 = falls[k]
    ax.text((x0 + rises[k]) / 2 if k == 0 else (x0 + x1)/2, Y["mosi"] + H + 0.12, f"b{7-k}={val_at('mosi', rises[k])}",
            ha="center", fontsize=8, color=BLUE)
    ax.text((x0 + rises[k]) / 2, Y["miso"] - 0.32, f"b{7-k}={val_at('miso', rises[k]-0.01)}",
            ha="center", fontsize=8, color=BLUE)

# sample markers at rising edges
for k, r in enumerate(rises):
    ax.plot([r, r], [Y["miso"] - 0.1, Y["sclk"] + H], color=RED, ls=":", lw=0.9)
    ax.text(r, Y["sclk"] + H + 0.12, f"↑{k+1}", ha="center", fontsize=8.5, color=RED)

def span(x0, x1, y, txt, col=GREEN):
    ax.annotate("", xy=(x0, y), xytext=(x1, y), arrowprops=dict(arrowstyle="<->", color=col, lw=1.3))
    ax.text((x0 + x1)/2, y + 0.1, txt, ha="center", va="bottom", fontsize=9, color=col, fontweight="bold")

yA = Y["cs_n"] + H + 0.25
span(cs_fall, rises[0], yA, f"t_lead = {rises[0]-cs_fall:.0f} ns")
span(falls[7], cs_rise, yA, f"t_lag = {cs_rise-falls[7]:.0f} ns")
yS = Y["mosi"] - 0.32
span(cs_fall, rises[0], yS, f"setup bit đầu = {rises[0]-cs_fall:.0f} ns")
span(falls[2], rises[3], yS, f"setup = {rises[3]-falls[2]:.0f} ns")
span(falls[5], rises[6], yS, f"setup = {rises[6]-falls[5]:.0f} ns")
XN = t_end + 4
ax.text(XN, Y["cs_n"] + 0.1, "CS bao trọn 8 xung:\nxuống TRƯỚC ↑1,\nlên SAU sườn xuống #8", fontsize=8.5, color="#333")
ax.text(XN, Y["miso"] - 0.1, "slave chỉ giữ MISO 1 ns\nsau ↑, rồi MISO = X\n(vùng gạch đỏ): lấy mẫu\nsai thời điểm sẽ thu X", fontsize=8.5, color=RED)
ax.text(XN, Y["rx_data"] - 0.6, f"rx_data = 0x{int(val_at('rx_data', done_r), 2):02X}\ncập nhật đúng chu kỳ\ndone = 1", fontsize=8.5, color="#333")

ax.set_xlim(t_start - 48, t_end + 62)
ax.set_ylim(Y["done"] - 0.5, Y["clk"] + H + 0.6)
ax.set_yticks([])
for sp in ["left", "right", "top"]: ax.spines[sp].set_visible(False)
ax.set_xlabel("thời gian mô phỏng (ns)")
ax.set_title("H03 · SPI Mode 0 · TX = 0x96, slave trả 0x3A · HALF_CYCLES = 2, Tclk = 10 ns · "
             "RTL gốc, Icarus Verilog 12.0", loc="left", fontsize=11)
plt.tight_layout()
plt.savefig(out, bbox_inches="tight")
print("da ghi", out, "| t_lead", rises[0]-cs_fall, "| t_lag", cs_rise-falls[7],
      "| setup min", min([rises[0]-cs_fall] + [rises[k+1]-falls[k] for k in range(7)]))
