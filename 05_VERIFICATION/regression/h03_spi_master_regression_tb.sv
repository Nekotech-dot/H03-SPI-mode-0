`timescale 1ns/1ps
// =============================================================================
// H03 - SPI Master Mode 0 : REGRESSION TESTBENCH
//
// DUT  : 04_IMPLEMENTATION/rtl/h03_spi_master.sv  (RTL goc cua thay, KHONG sua)
// Chay : xem run_regression.sh  (HALF_CYCLES = 1, 2, 4)
//
// Nhom A - Du lieu      : 6 cap TX/slave, gom 0x00, 0xFF, 0xA5 (Charter muc 8)
//                         va cac byte bat doi xung (bat loi thu tu bit)
// Nhom B - Timing mode 0: 8 suon len + 8 suon xuong trong cua so CS,
//                         MOSI chi doi o suon xuong, MISO = X ngoai cua so
//                         quanh suon len, do t_lead / t_lag / setup
// Nhom C - Ca bien      : reset giua transaction, START giu muc 1,
//                         (thong tin) ep FSM vao ma 2'b11
// Nhom D - Waveform     : mot transaction sach TX=0x96, slave=0x3A -> VCD
// =============================================================================
module h03_spi_master_regression_tb;

    parameter int  HC   = 2;          // HALF_CYCLES, dat bang -P khi bien dich
    localparam real TCLK = 10.0;      // ns, clock he thong 100 MHz
    localparam real T_HOLD_SLAVE = 1.0; // ns, slave chi giu MISO 1 ns sau suon len

    // ---------------------------------------------------------------- DUT
    logic       clk = 1'b0, rst_n = 1'b0, start = 1'b0;
    logic [7:0] tx_data = 8'h00;
    logic       miso = 1'b0;
    logic       mosi, sclk, cs_n, busy, done;
    logic [7:0] rx_data;

`ifdef GLS
    // Gate-level: netlist da tong hop voi tham so mac dinh (HALF_CYCLES = 4,
    // MSB_FIRST = 1), khong con tham so -> chay TB voi -P ...HC=4
    h03_spi_master dut (
`else
    h03_spi_master #(.HALF_CYCLES(HC), .MSB_FIRST(1'b1)) dut (
`endif
        .clk(clk), .rst_n(rst_n), .start(start), .tx_data(tx_data),
        .miso(miso), .mosi(mosi), .sclk(sclk), .cs_n(cs_n),
        .rx_data(rx_data), .busy(busy), .done(done));

    always #(TCLK/2) clk = ~clk;

    // ---------------------------------------------------------------- dem loi
    integer n_checks = 0, n_errors = 0;
    string  cur_case = "";

    task automatic chk(input bit ok, input string what);
        n_checks++;
        if (!ok) begin
            n_errors++;
            $display("    [FAIL] %s : %s  (t=%0t)", cur_case, what, $time);
        end
    endtask

    // ---------------------------------------------------------------- mo hinh SPI slave mode 0
    // - Bit dau tien co mat ngay khi CS xuong
    // - Doi bit tai suon XUONG
    // - Lay mau MOSI tai suon LEN
    // - Chi giu MISO them T_HOLD_SLAVE sau suon len, sau do MISO = X
    //   => master lay mau sai thoi diem se thu X va bi bat
    logic [7:0] slave_tx = 8'h00;   // byte slave gui
    logic [7:0] slave_rx;           // byte slave nhan duoc tren MOSI
    integer     miso_idx;
    bit         in_txn = 0;         // dang trong cua so CS = 0

    // monitor / do dac
    integer  rise_cnt, fall_cnt, done_cycles;
    realtime t_cs_fall, t_cs_rise, t_first_rise, t_last_rise, t_last_fall;
    realtime t_ref;                 // thoi diem gan nhat MOSI DUOC PHEP doi
    realtime t_mosi_chg = 0;        // thoi diem MOSI thuc su doi
    realtime setup_min_case, setup_min_all = 1.0e9;
    integer  mosi_phase_err, busy_err, rx_early_err;
    logic [7:0] rx_before;

    always @(mosi) t_mosi_chg = $realtime;

    always @(negedge cs_n) begin
        in_txn       = 1;
        t_cs_fall    = $realtime;
        t_ref        = $realtime;
        rise_cnt     = 0;
        fall_cnt     = 0;
        slave_rx     = 8'h00;
        miso_idx     = 7;
        miso         = slave_tx[7];
        setup_min_case = 1.0e9;
        mosi_phase_err = 0;
        busy_err       = 0;
        rx_early_err   = 0;
        rx_before      = rx_data;
    end

    always @(posedge sclk) if (in_txn) begin
        rise_cnt++;
        if (rise_cnt == 1) t_first_rise = $realtime;
        t_last_rise = $realtime;
        // khoang setup ma slave duoc huong cho bit nay
        if (($realtime - t_ref) < setup_min_case) setup_min_case = $realtime - t_ref;
        // MOSI khong duoc doi trong pha SCLK thap (ngoai thoi diem cho phep t_ref)
        if (t_mosi_chg > t_ref && t_mosi_chg < $realtime) mosi_phase_err++;
        slave_rx = {slave_rx[6:0], mosi};
        if (busy !== 1'b1) busy_err++;
        if (rx_data !== rx_before) rx_early_err++;
        #(T_HOLD_SLAVE) if (in_txn) miso = 1'bx;
    end

    always @(negedge sclk) if (in_txn) begin
        fall_cnt++;
        t_last_fall = $realtime;
        // MOSI khong duoc doi trong pha SCLK cao (tinh ca dung tai suon len)
        if (t_mosi_chg >= t_last_rise && t_mosi_chg < $realtime) mosi_phase_err++;
        t_ref = $realtime;
        if (miso_idx > 0) begin
            miso_idx--;
            miso = slave_tx[miso_idx];
        end
    end

    always @(posedge cs_n) if (in_txn) begin
        in_txn    = 0;
        t_cs_rise = $realtime;
        miso      = 1'b0;
    end

    always @(posedge clk) #(TCLK/10) if (done === 1'b1) done_cycles++;

    // ---------------------------------------------------------------- bang ket qua
    initial $display("RESULT,HC,case,tx,slave,mosi_thu,rx,rise,fall,t_lead_ns,t_lag_ns,setup_min_ns,ket_qua");

    // ---------------------------------------------------------------- task
    task automatic reset_dut();
        @(negedge clk) rst_n = 1'b0;
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        repeat (2) @(negedge clk);
    endtask

    task automatic pulse_start(input logic [7:0] tx);
        @(negedge clk);
        tx_data = tx;
        start   = 1'b1;
        @(negedge clk);
        start   = 1'b0;
    endtask

    // Mot transaction day du + kiem tra
    task automatic run_case(input string name, input logic [7:0] tx, input logic [7:0] srx);
        integer e0, w;
        realtime lead, lag;
        cur_case    = name;
        e0          = n_errors;
        slave_tx    = srx;
        done_cycles = 0;

        pulse_start(tx);
        // cho done (co gioi han thoi gian; done la xung 1 chu ky nen lay mau o suon xuong clk)
        for (w = 0; w < 16*HC + 20 && done !== 1'b1; w++) @(negedge clk);
        chk(done === 1'b1, "khong thay done trong thoi gian cho phep");
        repeat (3) @(negedge clk);

        lead = t_first_rise - t_cs_fall;
        lag  = t_cs_rise    - t_last_fall;

        // Nhom A - du lieu
        chk(!$isunknown(slave_rx) && slave_rx === tx,  $sformatf("MOSI: ky vong 0x%02h, slave thu 0x%02h", tx, slave_rx));
        chk(!$isunknown(rx_data)  && rx_data  === srx, $sformatf("RX: ky vong 0x%02h, DUT thu 0x%02h", srx, rx_data));
        // Nhom B - timing mode 0
        chk(rise_cnt == 8,          $sformatf("so suon len trong cua so CS = %0d", rise_cnt));
        chk(fall_cnt == 8,          $sformatf("so suon xuong trong cua so CS = %0d", fall_cnt));
        chk(mosi_phase_err == 0,    $sformatf("MOSI doi sai pha %0d lan", mosi_phase_err));
        chk(lead == HC*TCLK,        $sformatf("t_lead = %0.1f ns (dac ta: HC x Tclk = %0.1f)", lead, HC*TCLK));
        chk(lag  == TCLK,           $sformatf("t_lag = %0.1f ns (dac ta: 1 x Tclk)", lag));
        chk(setup_min_case == HC*TCLK, $sformatf("setup_min = %0.1f ns (ky vong %0.1f)", setup_min_case, HC*TCLK));
        // Hanh vi khac theo dac ta cua thay
        chk(busy_err == 0,          "busy phai = 1 khi CS = 0 (INV-1)");
        chk(rx_early_err == 0,      "rx_data doi truoc khi xong transaction (INV-8)");
        chk(done_cycles == 1,       $sformatf("done rong %0d chu ky, phai la xung 1 chu ky (INV-7)", done_cycles));
        chk(cs_n === 1'b1 && sclk === 1'b0 && busy === 1'b0, "sau transaction: CS=1, SCLK=0, busy=0 (INV-4)");

        if (setup_min_case < setup_min_all) setup_min_all = setup_min_case;
        $display("RESULT,%0d,%s,0x%02h,0x%02h,0x%02h,0x%02h,%0d,%0d,%0.1f,%0.1f,%0.1f,%s",
                 HC, name, tx, srx, slave_rx, rx_data, rise_cnt, fall_cnt, lead, lag, setup_min_case,
                 (n_errors == e0) ? "PASS" : "FAIL");
        repeat (2) @(negedge clk);
    endtask

    // ---------------------------------------------------------------- Nhom C
    // C1: reset giua transaction (sau suon len thu 4)
    task automatic test_reset_mid_transfer();
        integer e0;
        cur_case = "C1_reset_giua_transaction";
        e0 = n_errors;
        slave_tx = 8'hB4;
        pulse_start(8'h3A);
        wait (rise_cnt == 4);
        @(negedge clk) rst_n = 1'b0;
        @(posedge clk); #(TCLK/10);           // canh clock dau tien lay mau rst_n = 0
        chk(cs_n === 1'b1, "reset: CS phai nha ngay o canh clock dau tien");
        chk(sclk === 1'b0, "reset: SCLK phai ve 0 (CPOL = 0)");
        chk(busy === 1'b0 && done === 1'b0, "reset: busy = done = 0");
        chk(rx_data === 8'h00, "reset: rx_data = 0x00");
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        repeat (3) @(negedge clk);
        $display("RESULT,%0d,%s,0x3a,0xb4,-,0x%02h,%0d,%0d,-,-,-,%s", HC, cur_case, rx_data, rise_cnt, fall_cnt,
                 (n_errors == e0) ? "PASS" : "FAIL");
        // Phuc hoi: transaction binh thuong ngay sau reset
        run_case("C1b_sau_reset", 8'h3A, 8'hB4);
    endtask

    // C2: START giu muc 1 qua 3 transaction lien tiep
    task automatic test_start_held_high();
        integer e0, k;
        realtime cs_fall_t[0:2], cs_rise_t[0:2];
        logic [7:0] got_slave[0:2], got_rx[0:2];
        cur_case = "C2_start_giu_muc_1";
        e0 = n_errors;
        slave_tx = 8'h3A;
        @(negedge clk);
        tx_data = 8'hB4;
        start   = 1'b1;
        for (k = 0; k < 3; k++) begin
            @(negedge cs_n); cs_fall_t[k] = $realtime;
            @(posedge cs_n); cs_rise_t[k] = $realtime;
            @(negedge clk);
            got_slave[k] = slave_rx;
            got_rx[k]    = rx_data;
            if (k == 2) start = 1'b0;          // tha START ngay sau transaction thu 3
        end
        repeat (16*HC + 10) @(negedge clk);
        for (k = 0; k < 3; k++) begin
            chk(got_slave[k] === 8'hB4 && got_rx[k] === 8'h3A,
                $sformatf("transaction %0d: slave thu 0x%02h, DUT thu 0x%02h", k, got_slave[k], got_rx[k]));
        end
        for (k = 0; k < 2; k++) begin
            chk(cs_fall_t[k+1] - cs_fall_t[k] == (16*HC + 2) * TCLK,
                $sformatf("chu ky lap = %0.1f ns (dac ta: (16*HC+2) x Tclk = %0.1f)", cs_fall_t[k+1]-cs_fall_t[k], (16*HC+2)*TCLK));
            chk(cs_fall_t[k+1] - cs_rise_t[k] == TCLK,
                $sformatf("CS o muc 1 giua 2 transaction = %0.1f ns (dac ta: 1 x Tclk)", cs_fall_t[k+1]-cs_rise_t[k]));
        end
        chk(cs_n === 1'b1, "sau khi tha START khong co transaction thu 4");
        $display("RESULT,%0d,%s,0xb4,0x3a,0x%02h,0x%02h,8,8,-,-,-,%s (chu ky lap %0.0f ns; CS cao giua 2 lan %0.0f ns)",
                 HC, cur_case, got_slave[2], got_rx[2], (n_errors == e0) ? "PASS" : "FAIL",
                 cs_fall_t[1]-cs_fall_t[0], cs_fall_t[1]-cs_rise_t[0]);
    endtask

`ifndef GLS
    // C3 (THONG TIN, khong tinh vao PASS/FAIL): ep FSM vao ma thua 2'b11
    task automatic info_fsm_illegal_state();
        integer k; bit escaped;
        integer nscan;
        // Nap thang ma 2'b11 vao thanh ghi state (khong qua kiem tra kieu enum);
        // dung $sscanf de chay duoc tren ca Icarus 12 lan Icarus 13+ (13+ cam gan so vao enum).
        @(negedge clk) nscan = $sscanf("11", "%b", dut.state);
        escaped = 0;
        for (k = 0; k < 200; k++) begin
            @(negedge clk);
            if (dut.state !== 2'b11) escaped = 1;
        end
        pulse_start(8'h55);
        repeat (16*HC + 5) @(negedge clk);
        $display("INFO,%0d,C3_fsm_ma_2b11,FSM %s sau 200 chu ky; START sau do %s",
                 HC, escaped ? "DA TU THOAT" : "KET o 2'b11",
                 (cs_n === 1'b1) ? "KHONG duoc nhan (khoi chet cho toi khi reset)" : "duoc nhan");
        reset_dut();
    endtask
`endif

    // ---------------------------------------------------------------- chuong trinh chinh
    initial begin
        string vcd;
        if (!$value$plusargs("vcd=%s", vcd)) vcd = "h03_regression.vcd";
        $dumpfile(vcd);
        $dumpvars(0, h03_spi_master_regression_tb);
        $dumpoff;

        reset_dut();

        // Nhom D - transaction mau de ve waveform (chi phan nay duoc ghi VCD)
        $dumpon;
        run_case("D_waveform_mau", 8'h96, 8'h3A);
        $dumpoff;

        // Nhom A (+ kiem tra nhom B trong tung ca)
        run_case("A1_tx00_rxFF", 8'h00, 8'hFF);
        run_case("A2_txFF_rx00", 8'hFF, 8'h00);
        run_case("A3_txA5_rx3A", 8'hA5, 8'h3A);
        run_case("A4_txB4_rx3A", 8'hB4, 8'h3A);
        run_case("A5_tx01_rx80", 8'h01, 8'h80);
        run_case("A6_tx80_rx01", 8'h80, 8'h01);

        // Nhom C
        test_reset_mid_transfer();
        test_start_held_high();
`ifndef GLS
        info_fsm_illegal_state();      // can ten tin hieu noi bo dut.state, chi co o RTL
`endif

        $display("SUMMARY,HC=%0d,checks=%0d,errors=%0d,setup_min_tat_ca_ca=%0.1f ns", HC, n_checks, n_errors, setup_min_all);
        if (n_errors == 0) $display("ALL H03 TESTS PASS (HC=%0d, %0d checks)", HC, n_checks);
        else               $fatal(1, "H03 REGRESSION FAIL (HC=%0d): %0d / %0d checks loi", HC, n_errors, n_checks);
        $finish;
    end

    // watchdog
    initial begin
        #(TCLK * (16*HC + 20) * 40);
        $fatal(1, "WATCHDOG: mo phong qua lau (HC=%0d)", HC);
    end

endmodule
