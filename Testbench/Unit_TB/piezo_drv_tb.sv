`timescale 1ns/1ns
module piezo_drv_tb();

    logic clk, rst_n, en_steer, too_fast, batt_low, piezo, piezo_n;

    piezo_drv #(.fastSim(1)) iDUT(.clk(clk), .rst_n(rst_n), .en_steer(en_steer), .too_fast(too_fast), .batt_low(batt_low), .piezo(piezo), .piezo_n(piezo_n));

    always
        #10 clk = ~clk;

    task automatic wait_a_second (ref clk);

        // 20ns * 50,000,000 = 1s
        repeat (2500000) 
            @(negedge clk);

    endtask

    initial begin
        clk = 0;
        rst_n = 0;
        en_steer = 0;
        too_fast = 0;
        batt_low = 0;
        repeat (2)
            @(negedge clk);
        rst_n = 1;
        // check whether anything happens 
        wait_a_second(clk);

        en_steer = 1'b1;

        repeat(10)
            wait_a_second(clk);
        
        too_fast = 1;
        repeat(3)
            wait_a_second(clk);

        too_fast = 0;
        repeat(2)
            wait_a_second(clk);
        batt_low = 1;
        repeat(10)
            wait_a_second(clk);
        
        too_fast = 1;
        repeat(4)
            wait_a_second(clk);

        too_fast = 0;
        batt_low = 0;
        en_steer = 0;

        repeat (6)
            wait_a_second(clk);

        $stop;
    end

endmodule