package tb_tasks;

    ////// Local Parameters  ///////////
    localparam G = 8'h47; // G value
    localparam S = 8'h53; // S value
    localparam BAUD_CNT = 13'd5207; // number of clock cycles that make one baud 
    localparam BATT_THRES = 12'h800;
    localparam BATT_MIN = 12'h900;
    localparam MIN_RIDER_WEIGHT = 'h200;
    //------------------------------//
    localparam [14:0] G6_freq = 15'd31888;
    localparam [14:0] C7_freq = 15'd23890;
    localparam [14:0] E7_freq = 15'd18961;
    localparam [14:0] G7_freq = 15'd15944;

    typedef enum int {PIEZO_IDLE  = 0, PIEZO_G6 = 1, PIEZO_C7 = 2, PIEZO_E7_1 = 3, PIEZO_G7_1 = 4, PIEZO_E7_2 = 5, PIEZO_G7_2 = 6} piezo_state_e;

    ////////////////////////////////////
    //// 	Tasks for testbench 	///
    ///////////////////////////////////

    ///// Integers and Other Variables for Tasks ///////////
    integer i, j;
    integer count;


    task automatic reset_dut (ref clk, RST_n);  // A task to : Reset the DUT module 
        RST_n = 1'b0;
        repeat (2)
            @(negedge clk);
        RST_n = 1'b1;
        $display("The iDUT has been reset \n");
    endtask

    // Task To : Initialising 
    task automatic init (ref clk, RST_n, send_cmd, OVR_I_rght, OVR_I_lft, ref [7:0] cmd, 
                        ref signed [15:0] rider_lean, ref [11:0] ld_cell_lft, ref [11:0] ld_cell_rght, ref [11:0] steerPot, ref [11:0] batt);
        //clk = 0;  --> Will just add it in the initial block --> creates more flexibility for using init that way
        RST_n = 1; // Just to make sure the reset DUT can happen
        cmd = 0;
        send_cmd = 0;
        // The motors are A-OK
        OVR_I_lft = 0;
        OVR_I_rght = 0;
        rider_lean = 0; // The rider doesn't lean forward or backward
        // Something that maintains the status quo 
        ld_cell_lft = 0;
        ld_cell_rght = 0;
        steerPot = 12'h7ff; 
        batt = $urandom_range((BATT_THRES+100), 4095); // A bit over the Minimum Battery threshold and full value 
    endtask

    // Task to : Insert value into UART TX module and then wait till its done
    task automatic Auth_blk_transmit (input [7:0] data, ref clk, ref send_cmd, ref [7:0] cmd, ref cmd_sent);
        send_cmd = 1'b0;
        repeat(2)
            @(negedge clk);

        send_cmd = 1'b1;
        cmd = data;
        @(negedge clk);
        send_cmd = 1'b0;

        i = 0;
        while(!cmd_sent) begin
            @(negedge clk);
            i = i+1;
            if (i > 11*BAUD_CNT) begin // 10 bau cycles to send data hence wait for a bit more than that 
                $error("UART TX is taking too long to send the data to the DUT");
                $stop;
            end
        end

    endtask  // start transmission 

    task automatic step_input (ref clk, ref signed [15:0] rider_lean, input [13:0] repeat_times, input sum_or_sub);
        repeat (repeat_times) begin
            @(negedge clk);
            rider_lean = sum_or_sub ? rider_lean + 1'b1 : rider_lean - 1'b1;
        end            
    endtask

    // Helper to print PASS/FAIL
    task automatic check_signal(input logic condition, input string msg);
    assert(condition)
    else begin
        $error("TEST FAIL: %s", msg);
        $stop(); // Stop simulation immediately on failure
    end

    $display("TEST PASS: %s", msg);
    
    endtask

    // Wait task function
    task automatic wait_cycles(ref clk, input integer t);
        repeat(t)
            @(negedge clk);
    endtask

    //piezo octave note check
    task automatic piezo_tune_check(ref clk, ref piezo, ref piezo_n, input [14:0] octave);
        count = 0;
        for (j=0; j<octave; j++) begin
            if (piezo && !piezo_n) 
                count += 1;
        end
        if (count > octave/2)
            $error("SOUND FAIL : Octave sounds weird  \n");
    endtask

    task automatic reduce_batt (ref [11:0] batt, input [11:0] reduce);
        batt = batt - reduce;
    endtask

    // Task to change the weight of the person
    // Time to lose and gain a few pounds in a matter of seconds kinda task
    task automatic reset_weight_eqdistirbution(ref [11:0] ld_cell_lft, ref [11:0] ld_cell_rght, input [12:0] weight);
        ld_cell_lft = weight/2;
        ld_cell_rght = weight/2;
    endtask

    // Task to --> Turn Right
    task automatic turn_right (ref [11:0] ld_cell_lft, ref [11:0] ld_cell_rght, input [11:0] diff_wt, ref [11:0] steerPot);
        ld_cell_lft -= diff_wt;
        ld_cell_rght += diff_wt;
        steerPot += 12'h300;
    endtask

    // Task to --> Turn Leftt
    task automatic turn_left (ref [11:0] ld_cell_lft, ref [11:0] ld_cell_rght, input [11:0] diff_wt, ref [11:0] steerPot);
        ld_cell_lft += diff_wt;
        ld_cell_rght -= diff_wt;
        steerPot -= 12'h300;
    endtask

    // Task to monitor the theta
    // theta convergence Task, woop woop will it be 0?
    task automatic check_theta_platform (ref clk, ref signed [15:0] theta_platform, input integer count_cycles, input string msg, input int tolerance);
        integer conv_count;
        repeat (count_cycles) begin
            if ((theta_platform <= tolerance) || (theta_platform >= -tolerance)) begin
                conv_count += 1;
                if (conv_count >= 10000)
                    break;
            end
            else
                conv_count = 0;
            @(negedge clk);
        end
        check_signal ((theta_platform <= tolerance) || (theta_platform >= -tolerance), msg);
    endtask

    // Task to check speed, lets say here 
    // input as 00 is stop, 11 is straigh, 10 is left and 01 is right
    task automatic check_speed_and_direction(ref clk, ref signed [11:0] lft_spd, ref signed [11:0] rght_spd, input logic [1:0] direction, input integer tolerance, input integer count_cycles);

        repeat (count_cycles) begin
            if (direction == 2'b00) begin
                assert(((lft_spd <= tolerance)||(lft_spd >= -tolerance))&&((rght_spd <= tolerance)||(rght_spd >= -tolerance)))
                else begin
                    $error("The speed is not 0 +/- tolerance amount");
                    $stop();
                end
            end

            else if (direction == 2'b11) begin
                assert(((lft_spd >= tolerance)||(lft_spd <= -tolerance))&&((rght_spd >= tolerance)||(rght_spd <= -tolerance)) && (lft_spd === rght_spd))
                else begin
                    $error("The speed is not moving front or straight with tolerance amount");
                    $stop();
                end
            end

            else if (direction == 2'b10) begin
                assert(((rght_spd >= tolerance)||(rght_spd <= -tolerance)) && (lft_spd < rght_spd))
                else begin
                    $error("The speed is not moving left or at all with tolerance amount");
                    $stop();
                end
            end

            else begin
                assert(((lft_spd >= tolerance)||(lft_spd <= -tolerance)) && (lft_spd > rght_spd))
                else begin
                    $error("The speed is not moving right or at all with tolerance amount");
                    $stop();
                end
            end
        end

    endtask

    // Wait for a specific piezo state to appear (helper for BUZZ testing)
    task automatic wait_for_piezo_state(ref clk, ref logic [2:0] piezo_state, input piezo_state_e expected_state, input string msg, input int max_cycles);
        int cycles;
        cycles = 0;
        while ((piezo_state != expected_state) && (cycles < max_cycles)) begin
            @(posedge clk);
            cycles++;
        end
        check_signal(piezo_state == expected_state, msg);
    endtask

    task automatic check_pwm_pair(
        ref clk,
        ref logic PWM1,
        ref logic PWM2,
        input [10:0] duty,
        input int NONOVERLAP,
        input int tolerance,
        input string label,
        ref logic PWM_synch
    );
        int pwm1_high, pwm2_high, cycle;
        int period;
        int expected_pwm1_high, expected_pwm2_high;
        period = 2048;
        pwm1_high = 0;
        pwm2_high = 0;
        expected_pwm1_high = duty-NONOVERLAP;
        expected_pwm2_high = period - duty - NONOVERLAP;
        cycle = 0;

        $display("Checking %s PWM pair: duty=%0d, expected PWM1 high=%0d, expected PWM2 high=%0d", label, duty, expected_pwm1_high, expected_pwm2_high);
        // Wait for PWM_synch rising edge (start of PWM period)
        @(posedge PWM_synch);
        
        $display("PWM Synch detected, starting check for %s", label);
        repeat (period) begin
            @(posedge clk);
            if (PWM1) pwm1_high = pwm1_high + 1;
            if (PWM2) pwm2_high = pwm2_high + 1;
            @(negedge clk);
            cycle = cycle + 1;
        end
        
        if ((pwm1_high >= expected_pwm1_high-tolerance) && (pwm1_high <= expected_pwm1_high+tolerance)) begin
            $display("TEST PASS: %s PWM1 high duration matches expected (%0d cycles)", label, pwm1_high);
        end else begin
            $error("%s PWM1 high duration mismatch: got %0d, expected %0d +/- %0d", label, pwm1_high, expected_pwm1_high, tolerance);
            $stop;
        end
        if ((pwm2_high >= expected_pwm2_high-tolerance) && (pwm2_high <= expected_pwm2_high+tolerance)) begin
            $display("TEST PASS: %s PWM2 high duration matches expected (%0d cycles)", label, pwm2_high);
        end else begin
            $error("%s PWM2 high duration mismatch: got %0d, expected %0d +/- %0d", label, pwm2_high, expected_pwm2_high, tolerance);
            $stop;
        end
        // Check complementary property
        if ((pwm1_high + pwm2_high) > period + tolerance + 2*NONOVERLAP || (pwm1_high + pwm2_high + 2*NONOVERLAP) < period - tolerance) begin
            $error("%s PWM1+PWM2 high time not complementary: sum=%0d, period=%0d", label, pwm1_high + pwm2_high, period);
            $stop;
        end else begin
            $display("TEST PASS: %s PWM1+PWM2 high time is complementary accounting for nonoverlap (sum=%0d)", label, pwm1_high + pwm2_high);
        end
    endtask




endpackage