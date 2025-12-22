module balance_cntrl #(
    parameter fast_sim = 1
) (
    input logic clk,
    input logic rst_n,
    input logic vld,
    input logic [15:0] ptch,
    input logic [15:0] ptch_rt,
    input logic pwr_up,
    input logic rider_off,
    input logic [11:0] steer_pot,
    input logic en_steer,
    output logic [11:0] lft_spd,
    output logic [11:0] rght_spd,
    output logic too_fast
);

    logic [11:0] PID_cntrl;
    logic [7:0]  ss_tmr;
    
    // Instatiation of Segway Math 
    SegwayMath segway (.clk(clk), .rst_n(rst_n), .PID_cntrl(PID_cntrl), .ss_tmr(ss_tmr), .steer_pot(steer_pot), .en_steer(en_steer),
                        .pwr_up(pwr_up), .lft_spd(lft_spd), .rght_spd(rght_spd), .too_fast(too_fast));
    
    // Instatiation of PID ---> Conditional 
    generate
        if (fast_sim)
            PID_fastsim PID_mod(.clk(clk), .rst_n(rst_n), .vld(vld), .pwr_up(pwr_up), .rider_off(rider_off),
                            .ptch(ptch), .ptch_rt(ptch_rt), .ss_tmr(ss_tmr), .PID_cntrl(PID_cntrl));
        
        else 
            PID PID_mod(.clk(clk), .rst_n(rst_n), .vld(vld), .pwr_up(pwr_up), .rider_off(rider_off),
                            .ptch(ptch), .ptch_rt(ptch_rt), .ss_tmr(ss_tmr), .PID_cntrl(PID_cntrl));
    endgenerate

    // PID_Sayali #(.fast_sim(fast_sim)) PID_mod(.clk(clk), .rst_n(rst_n), .vld(vld), .pwr_up(pwr_up), .rider_off(rider_off),
    //                          .ptch(ptch), .ptch_rt(ptch_rt), .ss_tmr(ss_tmr), .PID_cntrl(PID_cntrl));
    
endmodule
