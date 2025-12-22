module SegwayMath (
    input logic signed [11:0] PID_cntrl,
    input logic        [7:0]  ss_tmr,
    input logic        [11:0] steer_pot,
    input logic               en_steer,
    input logic               pwr_up,
    output logic signed [11:0] lft_spd,
    output logic signed [11:0] rght_spd,
    output logic               too_fast
);
    localparam MIN_DUTY = 12'h0a8; 
    localparam LOW_TORQUE_BAND = 7'h2a;
    localparam GAIN_MULT = 4'h4;

    // Scaling with a soft start
    logic signed [8:0] signed_ss_tmr; // signed value of ss_tmr
    logic signed [20:0] prod;
    logic signed [11:0] PID_ss;

    //assign signed_ss_tmr = $signed({1'b0, ss_tmr});
    assign prod   = ($signed(PID_cntrl) * $signed({1'b0, ss_tmr})); // Multiply the inputs and divide it by 256
    assign PID_ss = prod >>> 8; 

    // Steering Input 
    logic [11:0] clipped_steer_pot;
    logic signed [12:0] signed_steer_pot, ratio_steer_pot;
    logic signed [12:0] lft_torque, rght_torque;

    // clipping the steer pot value between E00 and 200
    assign clipped_steer_pot = (steer_pot > 12'he00) ? 12'he00 :
                               (steer_pot < 12'h200) ? 12'h200 : steer_pot;

    // Making it signed by adding
    assign signed_steer_pot = $signed(clipped_steer_pot) - 12'h7ff;

    // Multiply it by 3/16 = 2/16 + 1/16 = 1/8 + 1/16
    assign ratio_steer_pot = (signed_steer_pot >>> 3) + (signed_steer_pot >>> 4);

    // assigning the left and right torque values 
    assign lft_torque = en_steer ? {PID_ss[11], PID_ss} + ratio_steer_pot : {PID_ss[11], PID_ss};
    assign rght_torque = en_steer ? {PID_ss[11], PID_ss} - ratio_steer_pot : {PID_ss[11], PID_ss};

    // DeadZone Shaping 
    logic signed [12:0] lft_shaped, rght_shaped;
    // Module instantiated for the left and right side since the logic is to
    // be replicated
    deadzone_shaping #(.MIN_DUTY(MIN_DUTY), .LOW_TORQUE_BAND(LOW_TORQUE_BAND), .GAIN_MULT(GAIN_MULT)) right(.torque(rght_torque), .pwr_up(pwr_up), .shaped(rght_shaped));
    deadzone_shaping #(.MIN_DUTY(MIN_DUTY), .LOW_TORQUE_BAND(LOW_TORQUE_BAND), .GAIN_MULT(GAIN_MULT)) left (.torque(lft_torque), .pwr_up(pwr_up), .shaped(lft_shaped));

    // Final saturation and over speed detection 
    // If the first two bits of the shaped value are dis-similar, this
    // indictaes that the number is too negative or too positive and is hence
    // saturated
    assign lft_spd = lft_shaped[12] ? (lft_shaped[11] ? lft_shaped[11:0] : 12'h800) : (lft_shaped[11] ? 12'h7ff : lft_shaped[11:0]);
    assign rght_spd = rght_shaped[12] ? (rght_shaped[11] ? rght_shaped[11:0] : 12'h800) : (rght_shaped[11] ? 12'h7ff : rght_shaped[11:0]);
    // assign lft_spd = (~lft_shaped[12] & lft_shaped[11]) ? 12'h7FF:
    //                         (lft_shaped[12] & ~lft_shaped[11]) ? 12'h800:
    //                         lft_shaped[11:0];
    // assign rght_spd = (~rght_shaped[12] & rght_shaped[11]) ? 12'h7FF:
    //                         (rght_shaped[12] & ~rght_shaped[11]) ? 12'h800:
    //                         rght_shaped[11:0];
    assign too_fast = (lft_spd > $signed(12'd1536)) | (rght_spd > $signed(12'd1536));


endmodule

module deadzone_shaping #(parameter MIN_DUTY = 12'h0a8, 
         parameter LOW_TORQUE_BAND = 7'h2a,
         parameter GAIN_MULT = 4'h4) (
    input logic signed [12:0] torque,
    input logic               pwr_up,
    output logic signed [12:0] shaped
); // Module to perform deadzone shaping

    logic signed [12:0] torque_comp, sel_torque_comp, mult_torque;
    logic [12:0] unsigned_torque;
    logic sel_logic_1;

    // First MUX to chose between subtratcting or adding 
    assign torque_comp = torque[12] ? torque - MIN_DUTY : torque + MIN_DUTY;
    // Gain multiplied torque 
    assign mult_torque = $signed(GAIN_MULT) * torque;

    // Unsigned torque 
    assign unsigned_torque = torque[12] ? (~torque + 13'd1) : torque;
    // Select line logic for the second mux
    assign sel_logic_1     = unsigned_torque > LOW_TORQUE_BAND;

    assign sel_torque_comp = sel_logic_1 ? torque_comp : mult_torque; // second mux 

    assign shaped = pwr_up ? sel_torque_comp : 13'h0000; 

endmodule

    

