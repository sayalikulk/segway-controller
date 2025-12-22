module SPI_mnrch (
    input logic clk,
    input logic rst_n,
    input logic wrt,
    input logic [15:0] wt_data,
    input logic MISO,
    output logic MOSI,
    output logic SCLK,
    output logic SS_n,
    output logic [15:0] rd_data,
    output logic done
);

    // Control Signals --- FSM
    logic init, shft, ld_SCLK, set_done;

    // production of SCLK
    logic [3:0] clk_reg;

    always_ff @(posedge clk or negedge rst_n) begin 
        if (!rst_n)
            clk_reg <= 4'b1011; // preset
        else if (ld_SCLK)
            clk_reg <= 4'b1011;
        else 
            clk_reg <= clk_reg + 1'd1; // increment the counter
    end

    assign SCLK = clk_reg[3];

    // Fall and rise of SCLK related signals 
    logic smpl, shift_im;
    assign smpl = ~SCLK && (&clk_reg[2:0]);
    assign shift_im = &clk_reg;

    // MISO double flop
    logic MISO_ff1, MISO_ff2;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            MISO_ff1 <= 1'b1;
            //MISO_ff2 <= 1'b1;
        end
        else begin
            MISO_ff1 <= MISO;
            //MISO_ff2 <= MISO_ff1;
        end
    end

    // MISO Sampling  
    logic MISO_smpl;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            MISO_smpl <= 1'b0;
        else if (smpl) 
            MISO_smpl <= MISO_ff1;
    end

    // 16 bit Shift Register 
    logic [15:0] shft_reg, shft_reg_c; // The reg for shift register and its combinational input 

    assign shft_reg_c = init ? wt_data : (shft ? {shft_reg[14:0], MISO_smpl} : shft_reg);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            shft_reg <= 16'h0000;
        else 
            shft_reg <= shft_reg_c;
    end
    
    // Bit counter 
    logic [3:0] bit_cntr, bit_cntr_c;
    logic done15;

    assign bit_cntr_c = init ? 4'b0000 : (shft ? bit_cntr + 1'd1 : bit_cntr);
    
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)  
            bit_cntr <= 4'b0000;
        else 
            bit_cntr <= bit_cntr_c;
    end

    assign done15 = &bit_cntr;

    // FSM LOGIC 
    // STATES --> IDLE or TRANSMIT

    typedef enum logic [1:0] {IDLE,FRONT_PORCH, TRANSMIT, BACK_PORCH} state_t;
    state_t state, nxt_state;

    logic clr_set, SS_c, MOSI_c;

    always_comb begin

        shft = 0;
        ld_SCLK = 0;
        init = 0;
        set_done = 0;
        nxt_state = state;
        SS_c = 1'b0;
	    MOSI_c = 0;

        case (state) 
            IDLE : begin
                    ld_SCLK = 1'b1;
                    init = wrt;
                    nxt_state = init ? FRONT_PORCH : IDLE;
                    SS_c = ~wrt;
            end

	       FRONT_PORCH : begin
		          nxt_state = shift_im ? TRANSMIT : FRONT_PORCH;
			      MOSI_c = shft_reg[15];
		   end 

            TRANSMIT : begin
                        shft = shift_im;
                        nxt_state = done15 ? BACK_PORCH : TRANSMIT;
			            MOSI_c = shft_reg[15];
            end

            BACK_PORCH : begin
                          shft = shift_im;
                          ld_SCLK = shift_im;
                          nxt_state = shift_im ? IDLE : BACK_PORCH;
                          set_done = shift_im;
                          SS_c = shift_im;
            end

            default : begin
                        nxt_state = IDLE;
            end


        endcase

        clr_set = init ? 1'b0 : (set_done ? 1'b1 : done);

    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done  <= 0;
            SS_n  <= 1;
	    MOSI  <= 0;
        end

        else begin
            state <= nxt_state;
            done  <= clr_set;
            SS_n <= SS_c;
	    MOSI <= MOSI_c; 
        end
    end    

    assign rd_data = shft_reg;


endmodule 
