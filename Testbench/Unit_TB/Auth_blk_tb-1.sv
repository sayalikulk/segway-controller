module Auth_blk_tb();

    logic clk, rst_n, RX, rider_off; // Inputs to the iDUT
    logic pwr_up; // Output to iDUT

    // UART TX signals 
    logic tmrt, tx_done;
    logic [7:0] tx_data;

    // Instatiation of the iDUT
    Auth_blk iDUT (.clk(clk), .rst_n(rst_n), .RX(RX), .rider_off(rider_off), .pwr_up(pwr_up));

    // Instatiation of the UART TX module
    UART_tx  uart_tx(.clk(clk), .rst_n(rst_n), .trmt(tmrt), .tx_done(tx_done), .TX(RX), .tx_data(tx_data));

    // Clock driver 
    always 
        #5 clk = ~clk;

    // Local Parameters
    localparam G = 8'h47; // G value
    localparam S = 8'h53; // S value
    localparam baud_cnt = 13'd5207; // number of clock cycles that make one baud 

    integer i = 0;

    // Insert value into UART TX module and then wait till its done
    task automatic start_transmission(input [7:0] data, ref clk, tmrt, tx_done, ref [7:0] tx_data);
        tmrt = 1'b0;
        repeat(2)
            @(negedge clk);

        tmrt = 1'b1;
        tx_data = data;
        @(negedge clk);
        tmrt = 1'b0;

        i = 0;
        while(!tx_done) begin
            @(negedge clk);
            i = i+1;
            if (i > 11*baud_cnt) begin
                $display("Error : UART TX is taking too long to send the data");
                $stop;
            end
        end

    endtask  // start transmission 

    // CONDITIONS TO CHECK FOR : 
    // 1. A normal case of rider_off = 1; Then beginning and ending of transaction when rider gets on and gets off after a few cycles 
    //    of sending disconnect (normal behaviour with power off when rider is only off)
    // 2. Rider gets on before switch the Segway on, hence Rider off is 0 from the start
    // 3. When rider never gets on but the BLE module connects and disconnect ---> Segway should power on and safely switch off right after S is recieved 
    // 4. Send a S first (should trigger no power up) and then send G and then a S (checking with rider is on condition)

    initial begin
        clk = 0;
        rst_n = 0; // trigger a reset 
        rider_off = 1;
        tmrt = 0;
        tx_data = 0;
        repeat(20)
            @(negedge clk);
        rst_n = 1;

        // Check for everything in rst_n
        if (pwr_up !== 1'b0) begin
            $error("ERROR : The pwr_up is not LOW at reset");
            $stop;
        end

        $display("-----Test Case 0-------");
        $display("All okay at reset \n");

        $display("------ Test Case 1 -------");
        start_transmission(G, clk, tmrt, tx_done, tx_data); // Pushing G into UART TX and forcing it to transmit 

        i = 0;

        // Checking whether the power goes up 
        while (!pwr_up) begin
            @(negedge clk)
            i = i+1;
            if (i > 2000) begin
                $error("ERROR : The pwr_up is not HIGH even though G is sent / taking too many cycles");
                $stop;
            end
        end

        // Although the power goes up, we would need to slightly monitor number of cycles it takes 
        $display("Test case 1.1 : Segway is powered on when G is pushed at %d cycles after completion of transmission", i);

        rider_off = 1'b0; // Rider gets on

        // Checking for unexpected working
        repeat (200) begin
            @(negedge clk);
            if (pwr_up !== 1'b1) begin
                $error("ERROR : Power turned off when rider is ON the SegWay");
                $stop;
            end
        end
        $display("Test case 1.2 : Rider is on and no issues, pushing S");
        // Push S into RX using UART_TX module 
        start_transmission(S, clk, tmrt, tx_done, tx_data);

        // try to make sure the Segway doesn't power off
        while (!pwr_up) begin
            @(negedge clk)
            i = i+1;
            if (i > 2000) begin
                $error("ERROR : Power turned off when rider is ON the SegWay even though S is pushed / Too many cycles");
                $stop;
            end
        end

        rider_off = 1'b1; //The rider steps
        
        // Checking for immediate power off 
        repeat (2)
            @(negedge clk);
        if (pwr_up !== 1'b0) begin
            $error("ERROR : Power switched isn't switched off even though Rider is stepped off");
            $stop;
        end

        $display("~~~~~~~ Test Case 1 Passed ~~~~~~~~ \n\n");

        repeat(20)
            @(negedge clk);

        $display("------ Test Case 2 -------");

        // rider is ON before we even switch on the Segway
        rider_off = 1'b0;

        start_transmission(G, clk, tmrt, tx_done, tx_data); // switch on the Segway

        i = 0;

        // Check whether the Segway powers on 
        while (!pwr_up) begin
            @(negedge clk)
            i = i+1;
            if (i > 2000) begin
                $error("ERROR : The pwr_up is not HIGH even though G is sent / taking too many cycles");
                $stop;
            end
        end

        $display("Test case 2.1 : Segway is powered on when G is pushed at %d cycles after completion of transmission", i);
        
        // Anamoly situation 
        repeat (20) begin
            @(negedge clk);
            if (pwr_up !== 1'b1) begin
                $error("ERROR : Power turned off when rider is ON the SegWay");
                $stop;
            end
        end
        $display("Test case 2.2 : Rider is on and no issues, pushing S");
        // Push S into RX
        start_transmission(S, clk, tmrt, tx_done, tx_data);
        // try to make sure the Segway doesn't power off
        while (!pwr_up) begin
            @(negedge clk)
            i = i+1;
            if (i > 2000) begin
                $error("ERROR : Power turned off when rider is ON the SegWay even though S is pushed / Too many cycles");
                $stop;
            end
        end

        rider_off = 1'b1; //The rider steps off
        
        repeat (2)
            @(negedge clk);
        if (pwr_up !== 1'b0) begin
            $error("ERROR : Power switched isn't switched off even though Rider is stepped off");
            $stop;
        end

        $display("~~~~~~~ Test Case 2 Passed ~~~~~~~~ \n \n");

        $display("------ Test Case 3 -------");
        start_transmission(G, clk, tmrt, tx_done, tx_data); // switch the Segway ON

        i = 0;

        // Checking whether it switched ON 
        while (!pwr_up) begin
            @(negedge clk)
            i = i+1;
            if (i > 2000) begin
                $error("ERROR : The pwr_up is not HIGH even though G is sent / taking too many cycles");
                $stop;
            end
        end

        $display("Test case 3.1 : Segway is powered on when G is pushed at %d cycles after completion of transmission", i);

        // Powered turned off? Problemmmm
        repeat (20) begin
            @(negedge clk);
            if (pwr_up !== 1'b1) begin
                $error("ERROR : Power turned off in the SegWay");
                $stop;
            end
        end
        $display("Test case 3.2 : Rider is still off and no issues, pushing S");
        // Push S into RX
        start_transmission(S, clk, tmrt, tx_done, tx_data);
        // try to make sure the Segway doesn't power off
        while (pwr_up) begin
            @(negedge clk)
            i = i+1;
            if (i > 2000) begin
                $error("ERROR : Power turned ON when rider is OFF the SegWay even though S is pushed / Too many cycles");
                $stop;
            end
        end

        // Power should be switched off by now, if not then OOOOPPS
        if (pwr_up !== 1'b0) begin
            $error("ERROR : Power switched isn't switched off even though Rider is stepped off");
            $stop;
        end

        $display("~~~~~~~ Test Case 3 Passed ~~~~~~~~ \n \n");

        $display("------ Test Case 4 -------");

        start_transmission(S, clk, tmrt, tx_done, tx_data); // dummy check, what if something random is sent?

        // Checking whether it turns ON 
        repeat (200) begin
            @(negedge clk);
            if (pwr_up !== 1'b0) begin
                $error ("ERROR : Power went up even though it shouldn't");
                $stop;
            end
        end

        start_transmission(G, clk, tmrt, tx_done, tx_data); // Now switching it ON 

        i = 0;

        // Check whether it switches on 
        while (!pwr_up) begin
            @(negedge clk)
            i = i+1;
            if (i > 2000) begin
                $error("ERROR : The pwr_up is not HIGH even though G is sent / taking too many cycles");
                $stop;
            end
        end

        $display("Test case 4.1 : Segway is powered on when G is pushed at %d cycles after completion of transmission", i);

        // CHECK FOR NORMAL BEHAVIOR HENCE FORTH, SAME AS TEST CASE 1
        rider_off = 1'b0; // Rider gets on
        repeat (20) begin
            @(negedge clk);
            if (pwr_up !== 1'b1) begin
                $error("ERROR : Power turned off when rider is ON the SegWay");
                $stop;
            end
        end
        $display("Test case 4.2 : Rider is on and no issues, pushing S");
        // Push S into RX
        start_transmission(S, clk, tmrt, tx_done, tx_data);
        // try to make sure the Segway doesn't power off
        while (!pwr_up) begin
            @(negedge clk)
            i = i+1;
            if (i > 2000) begin
                $error("ERROR : Power turned off when rider is ON the SegWay even though S is pushed / Too many cycles");
                $stop;
            end
        end

        rider_off = 1'b1; //The rider steps
        
        repeat (2)
            @(negedge clk);
        if (pwr_up !== 1'b0) begin
            $error("ERROR : Power switched isn't switched off even though Rider is stepped off");
            $stop;
        end

        $display("~~~~~~~ Test Case 4 Passed ~~~~~~~~");

        $display("\n YAY! ALL TEST CASES PASSED");
        $stop;

    end

endmodule