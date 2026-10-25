`timescale 1ns/1ps

module h03_spi_master_tb;

    localparam int HC = 2;

    logic clk   = 1'b0;
    logic rst_n = 1'b0;
    logic start = 1'b0;

    logic [7:0] tx_data = 8'h96;
    logic       miso    = 1'b0;

    logic       mosi;
    logic       sclk;
    logic       cs_n;
    logic [7:0] rx_data;
    logic       busy;
    logic       done;

    // ============================================================
    // DUT
    // ============================================================
    h03_spi_master #(
        .HALF_CYCLES(HC),
        .MSB_FIRST  (1'b1)
    ) dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .start   (start),
        .tx_data (tx_data),
        .miso    (miso),
        .mosi    (mosi),
        .sclk    (sclk),
        .cs_n    (cs_n),
        .rx_data (rx_data),
        .busy    (busy),
        .done    (done)
    );

    // 100 MHz system clock: T = 10 ns
    always #5 clk = ~clk;

    // ============================================================
    // SPI SLAVE MODEL
    // Slave sends 0x3C = 0011_1100 (MSB-first)
    // Mode 0:
    //   - Data must be valid BEFORE rising edge.
    //   - Rising edge: receiver samples.
    //   - Falling edge: transmitter prepares next bit.
    // ============================================================
    logic [7:0] slave_bits = 8'h3C;
    integer     miso_idx    = 7;

    integer     rise_count  = 0;
    integer     fall_count  = 0;
    logic [7:0] mosi_seen   = 8'h00;

    // First MISO bit must already be valid when CS becomes active.
    always @(negedge cs_n) begin
        miso_idx = 7;
        miso     = slave_bits[7];
    end

    // Slave changes/prepares the NEXT MISO bit on each falling edge.
    always @(negedge sclk) begin
        if (!cs_n) begin
            fall_count = fall_count + 1;

            if (miso_idx > 0) begin
                miso_idx = miso_idx - 1;
                miso     = slave_bits[miso_idx];
            end
        end
    end

    // Slave samples MOSI on each rising edge.
    // DUT also samples MISO on these same rising edges.
    always @(posedge sclk) begin
        if (!cs_n) begin
            rise_count = rise_count + 1;
            mosi_seen  = {mosi_seen[6:0], mosi};
        end
    end

    // ============================================================
    // TEST
    // ============================================================
    initial begin
        // Waveform for GTKWave
        $dumpfile("h03_spi_master.vcd");
        $dumpvars(0, h03_spi_master_tb);

        // Reset
        repeat (2) @(posedge clk);
        rst_n = 1'b1;

        // Generate one START pulse
        @(negedge clk);
        start = 1'b1;

        @(negedge clk);
        start = 1'b0;

        // Wait for transaction completion
        wait (done == 1'b1);
        #1;

        $display("");
        $display("================================");
        $display("H03 SPI MASTER MODE 0 - RESULTS");
        $display("================================");
        $display("TX DATA      = 0x%02h", tx_data);
        $display("MOSI CAPTURE = 0x%02h", mosi_seen);
        $display("SLAVE TX     = 0x%02h", slave_bits);
        $display("RX DATA      = 0x%02h", rx_data);
        $display("RISE COUNT   = %0d", rise_count);
        $display("FALL COUNT   = %0d", fall_count);
        $display("CS_n         = %0b", cs_n);
        $display("================================");

        // Checks
        assert (rise_count == 8)
            else $fatal(1, "Expected 8 rising edges, got %0d", rise_count);

        assert (fall_count == 8)
            else $fatal(1, "Expected 8 falling edges, got %0d", fall_count);

        assert (mosi_seen == tx_data)
            else $fatal(1,
                "MOSI wrong: expected 0x%02h, got 0x%02h",
                tx_data, mosi_seen);

        assert (rx_data == slave_bits)
            else $fatal(1,
                "RX wrong: expected 0x%02h, got 0x%02h",
                slave_bits, rx_data);

        assert (cs_n == 1'b1)
            else $fatal(1, "CS_n was not released after transaction");

        $display("H03 TB PASS");
        $display("");

        #20;
        $finish;
    end

endmodule
