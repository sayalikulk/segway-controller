module steer_en #(
    parameter fast_sim = 1
) (
    input logic clk,
    input logic rst_n,
    input logic [11:0] lft_ld,
    input logic [11:0] rght_ld,
    output logic rider_off,
    output logic en_steer
);

    localparam MIN_RIDER_WEIGHT = 'h200;
    localparam WT_HYSTERESIS = 'h40;

    logic signed [12:0] sum;
    logic signed [11:0] diff;
    logic sum_gt_min;
    logic sum_lt_min;
    logic diff_gt_1_4;
    logic diff_gt_15_16;

    logic signed [12:0] sum_scale_1_4;
    logic signed [12:0] sum_scale_15_16;
    logic [11:0] abs_diff;

    logic clr_tmr;
    logic tmr_full;
    logic [25:0] timer;


    assign sum = lft_ld + rght_ld;
    assign diff = lft_ld - rght_ld;
    assign sum_scale_1_4 = (sum >>> 2);
    assign sum_scale_15_16 = sum - (sum >>> 4);

    assign abs_diff = (diff[11]) ? ((~diff) + 12'b1) : (diff);


    assign sum_lt_min = (MIN_RIDER_WEIGHT-WT_HYSTERESIS) > sum;
    assign sum_gt_min = (MIN_RIDER_WEIGHT+WT_HYSTERESIS) < sum;

    assign diff_gt_1_4 = sum_scale_1_4 > abs_diff;
    assign diff_gt_15_16 = sum_scale_15_16 > abs_diff;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            timer <= 0;
        end else begin
            if (clr_tmr) begin
                timer <= 0;
            end else if (!tmr_full) begin
                timer <= timer + 1;
            end
        end
    end

    generate
        if(fast_sim) begin
            assign tmr_full = &timer[14:0];
        end else begin
            assign tmr_full = (timer == 26'd67_000_000); 
        end
    endgenerate

    steer_en_SM steerEnSMDUT (
        .clk(clk),
        .rst_n(rst_n),
        .sum_gt_min(sum_gt_min),
        .sum_lt_min(sum_lt_min),
        .diff_gt_1_4(diff_gt_1_4),
        .diff_gt_15_16(diff_gt_15_16),
        .tmr_full(tmr_full),
        .rider_off(rider_off),
        .en_steer(en_steer),
        .clr_tmr(clr_tmr)
    );

endmodule