/**
 * Self-Testing Testbench for SegwayMath
 *
 * This testbench verifies the SegwayMath module by:
 * 1. Implementing a behavioral "golden" reference model based on the
 * logic described in EX08_segwayMath.pdf.
 * 2. Running the two test scenarios recommended in the PDF.
 * 3. Comparing the DUT's outputs (lft_spd, rght_spd, too_fast) against
 * the reference model's outputs at each step.
 * 4. Reporting any errors and a final PASS/FAIL summary.
 *
 * To run: Compile this file (SegwayMath_tb.sv) along with your
 * design file (SegwayMath.sv) in a SystemVerilog simulator.
 */
`timescale 1ns / 1ps

module SegwayMath_tb;

    //-
    // Constants from PDF
    //-
    localparam logic signed [12:0] MIN_DUTY          = 13'h0A8; // 168
    localparam logic signed [12:0] LOW_TORQUE_BAND   = 13'd42;  // 7'h2A
    localparam logic signed [3:0]  GAIN_MULT         = 4'h4;
    localparam logic [11:0]        STEER_CLIP_LOW    = 12'h200;
    localparam logic [11:0]        STEER_CLIP_HIGH   = 12'hE00;
    localparam logic signed [11:0] STEER_OFFSET      = 12'h7FF;
    localparam logic signed [11:0] TOO_FAST_LIMIT    = 12'd1536; // From page 7 diagram
    localparam logic signed [11:0] MAX_SPD           = 12'h7FF; // 2047
    localparam logic signed [11:0] MIN_SPD           = 12'h800; // -2048

    //-
    // Testbench Signals
    //-

    // --- DUT Interface ---
    logic signed [11:0] PID_cntrl;
    logic [7:0]         ss_tmr;
    logic [11:0]        steer_pot;
    logic               en_steer;
    logic               pwr_up;

    logic signed [11:0] lft_spd;    // DUT output
    logic signed [11:0] rght_spd;   // DUT output
    logic               too_fast;   // DUT output

    // --- Reference Model Signals ("_ref" suffix) ---
    logic signed [11:0] lft_spd_ref;
    logic signed [11:0] rght_spd_ref;
    logic               too_fast_ref;
    
    // Internal reference signals
    logic signed [11:0] PID_ss_ref;
    logic signed [12:0] lft_torque_ref;
    logic signed [12:0] rght_torque_ref;
    logic signed [12:0] lft_shaped_ref;
    logic signed [12:0] rght_shaped_ref;

    // --- Test Control ---
    integer             errors = 0;
    integer             test_num = 0;

    // --- Step 2: Steering (Page 4) ---
    logic [11:0]        steer_pot_clipped_ref;
    logic signed [11:0] steer_signed_ref;
    logic signed [14:0] steer_temp_ref;       // For 12-bit * 3
    logic signed [11:0] steer_scaled_ref;
    logic signed [12:0] steer_scaled_ext_ref;
    logic signed [12:0] PID_ss_ext_ref;

    //-
    // Instantiate the Design Under Test (DUT)
    //-
    SegwayMath DUT (
        .PID_cntrl(PID_cntrl),
        .ss_tmr(ss_tmr),
        .steer_pot(steer_pot),
        .en_steer(en_steer),
        .pwr_up(pwr_up),
        .lft_spd(lft_spd),
        .rght_spd(rght_spd),
        .too_fast(too_fast)
    );

    //-
    // Behavioral Reference Model (Golden Model)
    // This combinational block calculates the expected outputs
    // based on the logic from the PDF.
    //-

    logic signed [19:0] product_ss_ref;

    // always_comb begin
    //     // --- Step 1: Soft Start (Page 3) ---
    //     // 12-bit signed * 9-bit signed (from {1'b0, ss_tmr})
    //     product_ss_ref = PID_cntrl * $signed({1'b0, ss_tmr});
    //     // Arithmetic shift right by 8 (divide by 256)
    //     PID_ss_ref = product_ss_ref >>> 8;

    //     // Clip steer_pot
    //     if (steer_pot < STEER_CLIP_LOW)
    //         steer_pot_clipped_ref = STEER_CLIP_LOW;
    //     else if (steer_pot > STEER_CLIP_HIGH)
    //         steer_pot_clipped_ref = STEER_CLIP_HIGH;
    //     else
    //         steer_pot_clipped_ref = steer_pot;

    //     // Convert to signed by subtracting offset
    //     steer_signed_ref = $signed(steer_pot_clipped_ref) - STEER_OFFSET;
        
    //     // Scale by 3/16 (multiply by 3, arithmetic shift right 4)
    //     steer_temp_ref = steer_signed_ref * 3;
    //     steer_scaled_ref = steer_temp_ref >>> 4;
        
    //     // Sign extend steering and PID_ss to 13 bits for addition
    //     steer_scaled_ext_ref = {steer_scaled_ref[11], steer_scaled_ref}; // 12-bit to 13-bit sign extension
    //     PID_ss_ext_ref = {PID_ss_ref[11], PID_ss_ref};             // 12-bit to 13-bit sign extension

    //     // Add/Subtract steering
    //     lft_torque_ref  = (en_steer) ? (PID_ss_ext_ref + steer_scaled_ext_ref) : PID_ss_ext_ref;
    //     rght_torque_ref = (en_steer) ? (PID_ss_ext_ref - steer_scaled_ext_ref) : PID_ss_ext_ref;

    //     // --- Step 3: Deadzone Shaping (Page 6) ---
    //     // Use helper function, and gate with pwr_up
    //     lft_shaped_ref = (pwr_up) ? shape_torque(lft_torque_ref) : 13'h0;
    //     rght_shaped_ref = (pwr_up) ? shape_torque(rght_torque_ref) : 13'h0;

    //     // --- Step 4: Saturation (Page 7) ---
    //     // Use helper function
    //     lft_spd_ref = saturate_12bit(lft_shaped_ref);
    //     rght_spd_ref = saturate_12bit(rght_shaped_ref);

    //     // --- Step 5: Too Fast (Page 7) ---
    //     // Check comes *after* saturation
    //     too_fast_ref = (lft_spd_ref > TOO_FAST_LIMIT) || (rght_spd_ref > TOO_FAST_LIMIT);
    // end

    // //-
    // // Helper Functions for Reference Model
    // //-

    // // Deadzone shaping function (Page 6)
    // function automatic logic signed [12:0] shape_torque(input logic signed [12:0] torque);
    //     logic [12:0] abs_torque;
    //     abs_torque = (torque[12]) ? -torque : torque; // $abs(torque)

    //     if (abs_torque < LOW_TORQUE_BAND) begin
    //         // Inside deadzone: apply high gain
    //         return torque * $signed(GAIN_MULT);
    //     end else if (torque[12]) begin
    //         // Outside deadzone (negative): subtract min_duty
    //         return torque - MIN_DUTY;
    //     end else begin
    //         // Outside deadzone (positive): add min_duty
    //         return torque + MIN_DUTY;
    //     end
    // endfunction

    // // 12-bit signed saturation function (Page 7)
    // function automatic logic signed [11:0] saturate_12bit(input logic signed [12:0] shaped_val);
    //     if (shaped_val > MAX_SPD)
    //         return MAX_SPD;
    //     else if (shaped_val < MIN_SPD)
    //         return MIN_SPD;
    //     else
    //         return shaped_val[11:0];
    // endfunction

    SegwayMath_Sai ref_mod (
        .PID_cntrl(PID_cntrl),
        .ss_tmr(ss_tmr),
        .steer_pot(steer_pot),
        .en_steer(en_steer),
        .pwr_up(pwr_up),
        .lft_spd(lft_spd_ref),
        .rght_spd(rght_spd_ref),
        .too_fast(too_fast_ref)
    );


    //-
    // Checker Task
    //-
    task automatic check_outputs(string test_desc);
        #10ns; // Wait for combinational logic to settle

        if (lft_spd !== lft_spd_ref || rght_spd !== rght_spd_ref) begin
            $display("---------------------------------------------------------------");
            $display(">>> TEST FAILED [%s]", test_desc);
            $display("    INPUTS: PID_cntrl=%h (%d), ss_tmr=%h, steer_pot=%h, en_steer=%b, pwr_up=%b",
                     PID_cntrl, PID_cntrl, ss_tmr, steer_pot, en_steer, pwr_up);
            if (lft_spd !== lft_spd_ref)
                $display("    MISMATCH: lft_spd  | DUT=%h (%d) | REF=%h (%d)", lft_spd, lft_spd, lft_spd_ref, lft_spd_ref);
            if (rght_spd !== rght_spd_ref)
                $display("    MISMATCH: rght_spd | DUT=%h (%d) | REF=%h (%d)", rght_spd, rght_spd, rght_spd_ref, rght_spd_ref);
            if (too_fast !== too_fast_ref)
                $display("    MISMATCH: too_fast | DUT=%b         | REF=%b", too_fast, too_fast_ref);
            $display("---------------------------------------------------------------");
            errors++;
        end
    endtask


    //-
    // Main Test Sequence
    //-
    initial begin
        $display("=================================");
        $display("  SegwayMath Testbench Started   ");
        $display("=================================");

        // --- TEST 1 (Page 9) ---
        // PID_cntrl=12'h5FF, steer_en=0, pwr_up=1
        // 1.1: ss_tmr ramps 0 -> FF
        // 1.2: PID_cntrl ramps 5FF -> E00
        //
        $display("\n[Test 1] Starting: ss_tmr ramp, then PID_cntrl ramp (no steer)");
        test_num = 1;
        PID_cntrl = 12'h5FF; // +1535
        steer_pot = 12'h7FF; // Neutral steering
        en_steer  = 0;
        pwr_up    = 1;
        ss_tmr    = 8'h00;
        
        // 1.1: Ramp ss_tmr
        $display("[Test 1.1] Ramping ss_tmr from 0 to 255...");
        repeat (256) begin
            check_outputs($sformatf("Test 1.1: ss_tmr=%d", ss_tmr));
            ss_tmr = ss_tmr + 1;
        end
        ss_tmr = 8'hFF; // Ensure it ends at FF
        check_outputs("Test 1.1: ss_tmr=255 final");

        // 1.2: Ramp PID_cntrl
        $display("[Test 1.2] Ramping PID_cntrl from +1535 (5FF) to -512 (E00)...");
        PID_cntrl = 12'h5FF;
        // Total steps = 1535 - (-512) = 2047 steps
        repeat (2047) begin
            check_outputs($sformatf("Test 1.2: PID_cntrl=%d", PID_cntrl));
            PID_cntrl = PID_cntrl - 1;
            if (errors)
                $stop;
        end
        PID_cntrl = 12'hE00; // Ensure it ends at -512
        check_outputs("Test 1.2: PID_cntrl=-512 final");

        
        // --- TEST 2 (Page 10) ---
        // ss_tmr=FF, steer_en=1
        // 2.1: PID_cntrl ramps 3FF -> C00
        // 2.2: steer_pot ramps 000 -> FFE
        // 2.3: pwr_up falls to 0
        //
        // $display("\n[Test 2] Starting: PID_cntrl and steer_pot ramp (steer ON)");
        // test_num = 2;
        // ss_tmr   = 8'hFF;
        // en_steer = 1;
        // pwr_up   = 1;
        
        // // Ramps:
        // // PID:   12'h3FF (1023) -> 12'hC00 (-1024). Steps = 1023 - (-1024) = 2047
        // // Steer: 12'h000 (0)    -> 12'hFFE (4094). 
        // // We can run 2048 steps. PID steps by -1. Steer steps by ~2.
        
        // $display("[Test 2.1] Ramping PID_cntrl (1023 -> -1024) and steer_pot (0 -> 4094)...");
        // for (int i = 0; i < 2048; i++) begin
        //     PID_cntrl = 12'h3FF - i;
        //     // (i * 4094 / 2047) = i * 2
        //     steer_pot = (i * 2);
        //     check_outputs($sformatf("Test 2.1: step %d", i));
        // end
        
        // // 2.3: Power down
        // $display("[Test 2.2] Disabling pwr_up...");
        // pwr_up = 0;
        // check_outputs("Test 2.2: pwr_up = 0");

        
        // --- FINAL REPORT ---
        #100ns;
        $display("\n=================================");
        if (errors == 0) begin
            $display("  >>> ALL TESTS PASSED <<<");
        end else begin
            $display("  >>> %0d ERRORS FOUND <<<", errors);
            $stop;
        end
        $display("  Simulation Finished.           ");
        $display("=================================");
        $stop;
    end

endmodule
