//---------------------------------------------------------------------------------------------//
// Team Members:
// 1. Sayali Kulkarni
// 2. Dharaneedaran Kalyanam Sendhil
// 3. Sai Tadinada
//---------------------------------------------------------------------------------------------//

module inertial_integrator (
    //------------------- Ports -------------------
    input logic clk,                  
    input logic rst_n,              
    input logic vld,                  
    input logic signed [15:0] ptch_rt, 
    input logic signed [15:0] AZ,     
    output logic signed [15:0] ptch  
);
    //------------------- Local Parameters -------------------
    // Offset values used to remove bias from raw sensor readings.
    localparam PTCH_RT_OFFSET = 16'h0050; // Bias offset for pitch rate gyro
    localparam AZ_OFFSET = 16'h00A0;      // Bias offset for Z-axis accelerometer

    //------------------- Internal Signals -------------------
    logic signed [26:0] ptch_int;           // 27-bit accumulator for pitch integration 
    logic signed [26:0] fusion_ptch_offset; // Correction offset added/subtracted for sensor fusion
    logic signed [15:0] ptch_rt_comp;       // Bias-compensated pitch rate 
    logic signed [15:0] AZ_comp;            // Bias-compensated Z-axis acceleration 
    logic signed [25:0] ptch_acc_product;   // Intermediate product for calculating accel-based pitch 
    logic signed [15:0] ptch_acc;           // Pitch angle as calculated from the accelerometer only 
    
    //------------------- Combinational Logic -------------------

    // Compensate raw sensor readings 
    // Remove the known bias offset from the raw sensor inputs.
    assign ptch_rt_comp = ptch_rt - PTCH_RT_OFFSET;
    assign AZ_comp = AZ - AZ_OFFSET;               

    // Calculate Pitch from Accelerometer (for fusion) ==
    // For small angles, pitch is directly proportional to AZ
    // ptch_acc = AZ_comp * 327 (fudge factor)
    //assign ptch_acc_product = AZ_comp * $signed (327) ; 
    //logic signed [25:0] ptch_acc_product_new; 
    assign ptch_acc_product = $signed({AZ_comp, 8'b0}) + $signed({AZ_comp, 6'b0}) + $signed({AZ_comp, 3'b0}) - AZ_comp;
    // Scale the result by dividing by 2^13 and sign-extend to 16 bits
    assign ptch_acc = {{3{ptch_acc_product[25]}},ptch_acc_product[25:13]}; 

    // Determine Fusion Offset
    // Compare the accelerometer-derived pitch (ptch_acc) to the gyro-derived
    // pitch (ptch). This determines the "leak" direction.
    // The fusion_ptch_offset is a 27-bit value to match the ptch_int accumulator.
    //assign fusion_ptch_offset = (ptch_acc > ptch) ? (27'd1024 - {{11{ptch_rt_comp[15]}}, ptch_rt_comp}) : (-27'd1024-{{11{ptch_rt_comp[15]}}, ptch_rt_comp}); 
    assign fusion_ptch_offset = (ptch_acc > ptch) ? (ptch_int + 27'd1024 - {{11{ptch_rt_comp[15]}}, ptch_rt_comp}) : (ptch_int -27'd1024-{{11{ptch_rt_comp[15]}}, ptch_rt_comp}); 

    // Final Pitch Output
    // The final 16-bit pitch output is the upper 16 bits of the 27-bit
    // accumulator, which is an effective division by 2^11 (2048)
    assign ptch = ptch_int[26:11]; 

    //------------------- Sequential Logic -------------------
    
    // This block is the core integrator. It accumulates the pitch rate on
    // every valid sensor reading and applies the fusion correction.
    always_ff @( posedge clk, negedge rst_n ) begin 
        if(!rst_n)
            // Asynchronous active-low reset: clear the accumulator.
            ptch_int <= 27'd0;
        else if(vld) // Only update when new data is valid
            // The integration equation:
            // 1. Subtract the pitch rate (due to sensor orientation).
            //    The 16-bit ptch_rt_comp is sign-extended to 27 bits for the subtraction.
            // 2. Add the fusion_ptch_offset to "leak" the accumulator
            //    towards the accelerometer's reading.
            //ptch_int <= ptch_int - {{11{ptch_rt_comp[15]}}, ptch_rt_comp} + fusion_ptch_offset;
            //ptch_int <= ptch_int - fusion_ptch_offset;
            ptch_int <= fusion_ptch_offset;
    end

endmodule