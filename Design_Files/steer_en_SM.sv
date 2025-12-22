module steer_en_SM(clk,rst_n,tmr_full,sum_gt_min,sum_lt_min,diff_gt_1_4,
                   diff_gt_15_16,clr_tmr,en_steer,rider_off);

  input clk;				// 50MHz clock
  input rst_n;				// Active low asynch reset
  input tmr_full;			// asserted when timer reaches 1.3 sec
  input sum_gt_min;			// asserted when left and right load cells together exceed min rider weight
  input sum_lt_min;			// asserted when left_and right load cells are less than min_rider_weight

  /////////////////////////////////////////////////////////////////////////////
  // HEY HOFFMAN...you are a moron.  sum_gt_min would simply be ~sum_lt_min. 
  // Why have both signals coming to this unit??  ANSWER: What if we had a rider
  // (a child) who's weigth was right at the threshold of MIN_RIDER_WEIGHT?
  // We would enable steering and then disable steering then enable it again,
  // ...  We would make that child crash(children are light and flexible and 
  // resilient so we don't care about them, but it might damage our Segway).
  // We can solve this issue by adding hysteresis.  So sum_gt_min is asserted
  // when the sum of the load cells exceeds MIN_RIDER_WEIGHT + HYSTERESIS and
  // sum_lt_min is asserted when the sum of the load cells is less than
  // MIN_RIDER_WEIGHT - HYSTERESIS.  Now we have noise rejection for a rider
  // who's weight is right at the threshold.  This hysteresis trick is as old
  // as the hills, but very handy...remember it.
  //////////////////////////////////////////////////////////////////////////// 

  input diff_gt_1_4;		// asserted if load cell difference exceeds 1/4 sum (rider not situated)
  input diff_gt_15_16;		// asserted if load cell difference is great (rider stepping off)
  output logic clr_tmr;		// clears the 1.3sec timer
  output logic en_steer;	// enables steering (goes to balance_cntrl)
  output logic rider_off;	// held high in intitial state when waiting for sum_gt_min
  
  // You fill out the rest...use good SM coding practices ///

  // State encoding for the steering enable state machine
  typedef enum logic [1:0] {
    IDLE,   
    BAL,    
    STEER
  } state_t;

  // State registers
  state_t state, nxt_state;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= nxt_state;
    end
  end

  // state machine logic
  always_comb begin
    // Defaults
    nxt_state   = state;
    clr_tmr   = 1'b1; 
    en_steer  = 1'b0;
    // rider_off should be asserted whenever rider is not known to exceed min weight req
    rider_off = sum_lt_min;

    case (state)
      IDLE: begin
        rider_off = 1'b1;
        clr_tmr   = 1'b1; 
        en_steer  = 1'b0;

        if (sum_gt_min) begin
          nxt_state = BAL;
        end
      end

      BAL: begin
        if (sum_lt_min) begin
          nxt_state = IDLE;
          clr_tmr = 1'b1;
        end else begin
          // start timer only when centered, rider clearly on, and not stepping off
          if (!diff_gt_1_4 && sum_gt_min && !diff_gt_15_16) begin
            clr_tmr = 1'b0; 
            if (tmr_full) begin
              nxt_state = STEER;
              clr_tmr = 1'b1; 
            end
          end else begin
            clr_tmr = 1'b1;
            // Not stable: keep timer cleared and remain in BAL
          end
        end
      end

      STEER: begin
        en_steer  = 1'b1;
        rider_off = sum_lt_min; // assert immediately if rider fully off
        clr_tmr   = 1'b1;

        if (sum_lt_min) begin
          nxt_state = IDLE;
        end else if (diff_gt_15_16) begin
          nxt_state = BAL;
        end else begin
          // Ignore anything else, stay here otherwise
        end
      end

      default: begin
        nxt_state = IDLE;
      end
    endcase
  end
  
endmodule