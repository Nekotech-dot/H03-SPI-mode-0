# H03 SPI Master Mode 0 - Results Package

## 1. Source RTL

Top module:

h03_spi_master

Source commit used for the regenerated physical implementation:

320949baa20512df1d22b7776944304bf506683d

RTL SHA-256:

1b352c9de67b27acae6aeaa1581375e3670738bcc931300566ccb329e119ebf8


## 2. RTL Verification

Regression result:

- HALF_CYCLES = 1: 116 checks PASS
- HALF_CYCLES = 2: 116 checks PASS
- HALF_CYCLES = 4: 116 checks PASS
- Total: 348/348 checks PASS

Selected waveform:

07_RESULTS/waveform/h03_waveform_hc2.vcd

Waveform configuration:

- HALF_CYCLES = 2
- Tclk = 10 ns
- TX = 0x96
- RX = 0x3A


## 3. Official Verification Evidence

Official evidence file:

07_RESULTS/logs/evidence_RUN_2026-10-18_13-37-21.txt

Associated official LibreLane run:

RUN_2026-10-18_13-37-21

This evidence file is retained as the official result used in the report.


## 4. Regenerated GDS

A fresh LibreLane run was performed from the Git-tracked source for reproducibility.

LibreLane run:

RUN_2026-10-28_05-12-11

GDS file:

07_RESULTS/gds/h03_spi_master.gds

GDS SHA-256:

14e9adaec800bf3ac995cad2ab33ea4afbc53445f223ccd98888a2302fc5f86b

Source commit:

320949baa20512df1d22b7776944304bf506683d


## 5. Traceability

Official verification evidence
    |
    +--> evidence_RUN_2026-10-18_13-37-21.txt

Git source commit
    |
    +--> RTL regression: 348/348 PASS
    |
    +--> h03_waveform_hc2.vcd
    |
    v
LibreLane RUN_2026-10-28_05-12-11
    |
    v
h03_spi_master.gds
