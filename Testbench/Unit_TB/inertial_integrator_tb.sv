module inertial_integrator_tb();

    logic clk, rst_n;
    logic vld;
    logic signed [15:0] ptch_rt;
    logic signed [15:0] AZ;
    logic signed [15:0] ptch;
    logic signed [15:0] ptch_act;

    // Instantiating the DUT

    intertial_integrator_x iDUT (
        .clk(clk),
        .rst_n(rst_n),
        .vld(vld),
        .ptch_rt(ptch_rt),
        .AZ(AZ),
        .ptch(ptch)
    );

    inertial_integrator iDUT2 (
        .clk(clk),
        .rst_n(rst_n),
        .vld(vld),
        .ptch_rt(ptch_rt),
        .AZ(AZ),
        .ptch(ptch_act)
    );

    localparam PTCH_RT_OFFSET = 16'h0050;

    initial begin
        clk = 0;
        rst_n = 1;
        vld = 0;
        ptch_rt = 0;
        AZ = 0;

        
        // Hold reset for one clock cycle
        @(negedge clk);
        rst_n = 0; // De-assert reset

        @(negedge clk);
        rst_n = 1;

        
        // Let the design settle for a few cycles after reset
        repeat (5) @(posedge clk);
        
        ptch_rt = 16'h1000 + PTCH_RT_OFFSET;
        AZ = 16'h0000;
        vld = 1;

        repeat(500) @(posedge clk);

        ptch_rt = PTCH_RT_OFFSET;

        repeat(1000) @(posedge clk);
        
        ptch_rt = PTCH_RT_OFFSET - 16'h1000;

        repeat(500) @(posedge clk);

        ptch_rt = PTCH_RT_OFFSET;

        repeat(1000) @(posedge clk);

        AZ = 16'h0800;

        repeat(500) @(posedge clk);

        $stop;

    end

    always
        #5 clk = ~clk;

endmodule