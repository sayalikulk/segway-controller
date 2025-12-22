module Auth_blk( 
    input logic clk,
    input logic rst_n,
    input logic RX,
    input logic rider_off,
    output logic pwr_up
);

    // Inter module communication signals
    logic rx_rdy, clr_rx_rdy;
    logic [7:0] rx_data;

    // Instatiating State Machine 
    Auth_SM SM (.clk(clk), .rst_n(rst_n), .rx_data(rx_data), .rx_rdy(rx_rdy), .rider_off(rider_off), .clr_rx_rdy(clr_rx_rdy), .pwr_up(pwr_up));

    // Instatiating UART RX module
    UART_rx uart_rx (.clk(clk), .rst_n(rst_n), .RX(RX), .clr_rdy(clr_rx_rdy), .rx_data(rx_data), .rdy(rx_rdy));

endmodule


module Auth_SM(
    input logic clk,
    input logic rst_n,
    input logic [7:0] rx_data,
    input logic rx_rdy,
    input logic rider_off,
    output logic clr_rx_rdy,
    output logic pwr_up
);

    // Localparameters to make G and S parameterized
    localparam G = 8'h47;
    localparam S = 8'h53;

    // ENUM for the state machine's states
    typedef enum logic [1:0] {IDLE, RCVD_G, RCVD_S} state_t;
    state_t state, nxt_state;

    /* CASE WHERE WE POWER DOWN IF THE RIDER GETS OFF ABRUPTLY --> SAFTEY CASE --> IF NECESSARY
    // Register to hold memory of rider getting on
    reg rider_got_on;
    // Reasoning begind a flop as such. 
    // When the rider switches on the Segway before getting on to it, the Segway will enter the RCVD_G state
    // Now to switch off the Segway before the rider even gets on due to rider_off being HIGH, I need to know whether the rider gets on, to make a memory to know
    // Hence such a flop
    // Question : Why did i not just use a seperate state in the FSM for this?
    // Although the FSM already uses two bits, this could reduce the need for an extra flop, but my reasoning is :
    // The amount of muxing logic that would take up the space and driving power during synthesis would be arguably more than a single extra flop
    */

    always_comb begin : nxt_state_assignment
        // Defaulting signals
        clr_rx_rdy = 1'b0;
        pwr_up     = 1'b0;
        nxt_state  = state;

        case (state)
            IDLE : begin
                    // the if block checks for whether the rider is not off and signal G comes in
                    if (rx_rdy && (rx_data == G)) begin
                        nxt_state = RCVD_G; // Go and wait for 
                        pwr_up    = 1'b1; // start the power up since G has been recieved 
                        // TODO : check whether necessary : mostly is, cause how else would you get S
                        clr_rx_rdy = 1; // clear rdy to wait for S to come in
                    end
            end

            RCVD_G : begin
                     pwr_up = 1'b1;
                     
                     /* SAFTY CASE
                     if (rider_off & rider_got_on) // checks the condition where the rider gets on and then gets off 
                        nxt_state = IDLE;
                     else */
                     if (rx_rdy && (rx_data == S)) begin
                        // Get to the state that waits for RIDER to be off, but if rider is off now, get to IDLE
                        nxt_state = RCVD_S;  
                        clr_rx_rdy   = 1'b1;  // Clear the rdy signal once we recieve S 
                     end
            end

            RCVD_S : begin
                     pwr_up = !rider_off; // Keep power on until rider is totally off
                     if (rider_off)
                        nxt_state = IDLE; // go back to IDLE once rider is off
            end

            default : nxt_state = IDLE; // Go back to IDLE in case of anamoly 2'b11 state

        endcase                  

    end

    // State Assignment & Safety Case --> Flop to understand if rider ever got on
    always_ff @(posedge clk or negedge rst_n) begin : state_ff
        if (!rst_n) begin
            state <= IDLE; // At reset back to IDLE
            /* SAFTY CASE
            rider_got_on <= 0;
            */
        end
        else begin
            state <= nxt_state; // next state 
            /* SAFETY CASE
            rider_got_on <= !rider_off; // If rider ever gets on, go HIGH, when rider gets off, go LOW
            */
        end
    end

endmodule