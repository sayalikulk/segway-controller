module rst_synch (
    input logic RST_n, 
    input logic clk,
    output logic rst_n
);

    logic q1;

    always_ff @(negedge clk or negedge RST_n) begin 
        if (!RST_n) begin 
            q1 <= 0;
            rst_n <= 0;
        end 

        else begin 
            q1 <= 1'b1;
            rst_n <= q1;
        end
    end 

endmodule