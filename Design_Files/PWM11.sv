module PWM11 (
    input logic        clk, // 50MHz system clk
    input logic        rst_n,
    input logic [10:0] duty,
    output logic       PWM1,
    output logic       PWM2,
    output logic       PWM_synch,
    output logic       ovr_I_blank
);

    localparam NONOVERLAP = 11'h040; // local paramater to determine the buffer between PWM1&2

    logic [10:0] cnt; // Counter 

    logic set_pwm1, reset_pwm1; // Set and reset signals for the PWM1 flip flop
    logic set_pwm2, reset_pwm2; // Set and reset signals for the PWM2 flip flop

    assign set_pwm1 = cnt >= NONOVERLAP; // Need to set PWM1 to 1 when greater than NONOVERLAP
    assign reset_pwm1 = cnt >= duty; // Need to reset it once cnt crosses duty value

    assign set_pwm2 = cnt >= (duty + NONOVERLAP); // Need to set PWM1 to 1 when greater than NONOVERLAP + duty
    assign reset_pwm2 = &cnt; // Need to reset it once cnt hits 2047

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= 11'd0;
            PWM1 <= 1'b0;
            PWM2 <= 1'b0;
        end

        else begin 
            cnt <= cnt + 1'b1; // Incremement the counter every cycle 
            PWM1 <= set_pwm1 & ~reset_pwm1; // Setting or resetting the PWM1
            PWM2 <= set_pwm2 & ~reset_pwm2; // Setting or resetting the PWM2
        end
    end

    // Output signals assignment 

    assign PWM_synch = ~|cnt;
    assign ovr_I_blank = ((cnt > NONOVERLAP) & (cnt < NONOVERLAP + 11'd128)) | ((cnt > NONOVERLAP+duty) & (cnt < NONOVERLAP + duty + 11'd128));


endmodule 