module Segway_tb();

import tb_tasks::*;

//// Interconnects to DUT/support defined as type wire /////
wire SS_n,SCLK,MOSI,MISO,INT;			// to inertial sensor
wire A2D_SS_n,A2D_SCLK,A2D_MOSI,A2D_MISO;	// to A2D converter
wire RX_TX;
wire PWM1_rght, PWM2_rght, PWM1_lft, PWM2_lft;
wire piezo,piezo_n;
logic cmd_sent;
wire rst_n;				// synchronized global reset

////// Stimulus is declared as type reg ///////
reg clk, RST_n;
reg [7:0] cmd;			// command host is sending to DUT
reg send_cmd;			// asserted to initiate sending of command
logic signed [15:0] rider_lean;
logic [11:0] ld_cell_lft, ld_cell_rght,steerPot,batt;	// A2D values
reg OVR_I_lft, OVR_I_rght;
logic [2:0] piezo_state;
logic rider_off_mon;
assign piezo_state = iDUT.iBUZZ.state;
always_comb rider_off_mon = iDUT.rider_off;

logic pwm_synch_logic;
logic pwm1_lft_logic, pwm2_lft_logic;
logic pwm1_rght_logic, pwm2_rght_logic;

assign pwm_synch_logic = iDUT.iDRV.iPWM_lft.PWM_synch;
assign pwm1_lft_logic = iDUT.PWM1_lft;
assign pwm2_lft_logic = iDUT.PWM2_lft;
assign pwm1_rght_logic = iDUT.PWM1_rght;
assign pwm2_rght_logic = iDUT.PWM2_rght;


///// Internal registers for testing purposes??? /////////


///// Integers and Other Variables for Tasks ///////////
integer i, j;
integer count;

////////////////////////////////////////////////////////////////
// Instantiate Physical Model of Segway with Inertial sensor //
//////////////////////////////////////////////////////////////	
SegwayModel iPHYS(.clk(clk),.RST_n(RST_n),.SS_n(SS_n),.SCLK(SCLK),
                  .MISO(MISO),.MOSI(MOSI),.INT(INT),.PWM1_lft(PWM1_lft),
		  .PWM2_lft(PWM2_lft),.PWM1_rght(PWM1_rght),
		  .PWM2_rght(PWM2_rght),.rider_lean(rider_lean));		  

/////////////////////////////////////////////////////////
// Instantiate Model of A2D for load cell and battery //
///////////////////////////////////////////////////////
ADC128S_FC iA2D(.clk(clk),.rst_n(RST_n),.SS_n(A2D_SS_n),.SCLK(A2D_SCLK),
             .MISO(A2D_MISO),.MOSI(A2D_MOSI),.ld_cell_lft(ld_cell_lft),.ld_cell_rght(ld_cell_rght),
		 .steerPot(steerPot),.batt(batt));			
 	
////// Instantiate DUT ////////
Segway iDUT(.clk(clk),.RST_n(RST_n),.INERT_SS_n(SS_n),.INERT_MOSI(MOSI),
            .INERT_SCLK(SCLK),.INERT_MISO(MISO),.INERT_INT(INT),.A2D_SS_n(A2D_SS_n),
		.A2D_MOSI(A2D_MOSI),.A2D_SCLK(A2D_SCLK),.A2D_MISO(A2D_MISO),
		.PWM1_lft(PWM1_lft),.PWM2_lft(PWM2_lft),.PWM1_rght(PWM1_rght),
		.PWM2_rght(PWM2_rght),.OVR_I_lft(OVR_I_lft),.OVR_I_rght(OVR_I_rght),
		.piezo_n(piezo_n),.piezo(piezo),.RX(RX_TX));

//// Instantiate UART_tx (mimics command from BLE module) //////
UART_tx iTX(.clk(clk),.rst_n(rst_n),.TX(RX_TX),.trmt(send_cmd),.tx_data(cmd),.tx_done(cmd_sent));

/////////////////////////////////////
// Instantiate reset synchronizer //
///////////////////////////////////
rst_synch iRST(.clk(clk),.RST_n(RST_n),.rst_n(rst_n));



// ////////////////////////////////////
// //// 	Tasks for testbench 	///
// ///////////////////////////////////

initial begin
  
	/// Your magic goes here ///

	///// INITIALISE AND INITALISATION /////
	clk = 0; 
	init (clk, RST_n, send_cmd, OVR_I_rght, OVR_I_lft, cmd, rider_lean, ld_cell_lft, ld_cell_rght, steerPot, batt); // Initialisation of signals
	reset_dut (clk, RST_n); // Reset 
	/////////////-----  Self Test at INIT -----////////////
	check_signal(!iDUT.pwr_up, "The Segway being switched OFF at reset");
	check_signal((iDUT.batt === 0)&&(iDUT.steer_pot===0)&&(iDUT.lft_ld===0)&&(iDUT.rght_ld===0)&&(piezo===0)&&(SS_n === 1)&&(A2D_SS_n === 1)&&(iDUT.rider_off === 1), "All Okay at reset");
	///////////////////////////////////////
	Auth_blk_transmit(G, clk, send_cmd, cmd, cmd_sent); // Send G to connect to bluetooth model
	wait_cycles(clk, 2000); //Waiting for the SegWay to switch on
	check_signal(iDUT.pwr_up, "The Segway switched ON after sending G");
	wait_cycles(clk, 70000); //Waiting for the SegWay to switch on
	////// ------------- Check whether all the values are good after switch ON and a few cycles to let the values come in -----------------///////
	check_signal((iDUT.batt === batt) && (iDUT.steer_pot === steerPot) && (iDUT.lft_ld === ld_cell_lft) && (iDUT.rght_ld === ld_cell_rght), "Segway values has reset to right value --> also recieved the right value from A2D");
	//   check_signal((iDUT.steer_pot == steerPot), "Segwat SteerPot value has reset to right value --> also recieved the right value from A2D");
	//   check_signal((iDUT.lft_ld == ld_cell_lft), "Segwat Left load value has reset to right value --> also recieved the right value from A2D");
	//   check_signal((iDUT.rght_ld == ld_cell_rght), "Segwat Right load value has reset to right value --> also recieved the right value from A2D");

	/// No rider on, lets switch it off, and hope for the best ///
	Auth_blk_transmit(S, clk, send_cmd, cmd, cmd_sent); // Send S to connect to bluetooth model
	wait_cycles(clk, 2000); //Waiting for the SegWay to switch on
	reduce_batt(batt, 20);
	check_signal(!iDUT.pwr_up, "The Segway switched OFF after sending S");

	// Okay lets switch it back on and wait for a few cycles 
	Auth_blk_transmit(G, clk, send_cmd, cmd, cmd_sent); // Send G to connect to bluetooth model
	wait_cycles(clk, 2000); //Waiting for the SegWay to switch on
	check_signal(iDUT.pwr_up, "The Segway switched BACK ON after sending G");
	// The rider gets on 
	reset_weight_eqdistirbution(ld_cell_lft, ld_cell_rght, 13'h0400);
	wait_cycles(clk, 70000);
	check_signal(iDUT.batt == batt, "New battery value updated");
	/// --------- Okay the Segway switches on and off, thats good, so now lets try weight -----///
	check_signal((iDUT.lft_ld === ld_cell_lft) && (iDUT.rght_ld === ld_cell_rght), "The weight has been recognised by the sensor / into the Segway");
	check_signal((iDUT.rider_off === 0), "The Rider is On and recognised by the Segway");
	/// ---------- Lets switch off the Segway and see what happens ----------////
	Auth_blk_transmit(S, clk, send_cmd, cmd, cmd_sent); // Send S to connect to bluetooth model
	wait_cycles(clk, 2000); //Waiting for the SegWay to switch on
	reduce_batt(batt, 20);
	check_signal(iDUT.pwr_up, "The Segway did not switch OFF after sending S even though rider was ON, danger averted!?!");
	reset_weight_eqdistirbution(ld_cell_lft, ld_cell_rght, 13'h0000); // Get the rider to get off 
	wait_cycles(clk, 50000);
	check_signal(!iDUT.pwr_up, "The Segway is switched OFF after sending S and the rider is off"); // Now to switch it back ON
	Auth_blk_transmit(G, clk, send_cmd, cmd, cmd_sent); // Send G to connect to bluetooth model
	wait_cycles(clk, 2000); //Waiting for the SegWay to switch on
	check_signal(iDUT.pwr_up, "The Segway switched BACK ON after sending G --> The second time"); // Jeez, I am just switching this on and off like a phone
	reset_weight_eqdistirbution(ld_cell_lft, ld_cell_rght, 13'h0400);
	// Wait for sometime before putting on RIDER LEAN, we wait for 100K cycles
	wait_cycles(clk, 1000000);
	// Step function --> RAMP UP the rider_lean to go up till fff
	step_input (clk, rider_lean, 14'h0fff, 1);
	rider_lean = 14'h0fff;
	check_theta_platform (clk, iPHYS.theta_platform, 1000000, "thetha of the platform converged towards 0 after a positive rider lean", 350);
	rider_lean = 14'h0fff;
	wait_cycles(clk, 100);
	step_input (clk, rider_lean, 14'h00ff, 1);
	fork 
		begin : theta_conv
		    disable speed_direction;
			check_theta_platform (clk, iPHYS.theta_platform, 1000000, "thetha of the platform converged towards 0 after a positive rider lean", 350);
			disable speed_direction;
		end

		begin : speed_direction
			check_speed_and_direction(clk, iDUT.lft_spd, iDUT.rght_spd, 2'b11, 2, 1000000); // Tolerance low since slow start timer
		end
	join 
	check_theta_platform (clk, iPHYS.theta_platform, 1000000, "thetha of the platform converged towards 0 after a positive rider lean", 350);

	rider_lean = 13'h0000;
	// Save me some time so I will break out if I reach the point 
	// Let us go the opposite direction now, slowly go negative 
	wait_cycles(clk, 10000);
	//--------------------- Directional Test Cases ----------------------//
	step_input (clk, rider_lean, 14'h07ff, 1); // Move forward
	turn_left(ld_cell_lft, ld_cell_rght, 12'h1e0, steerPot); // Turn Left
	wait_cycles(clk, 70000);
	check_signal((iDUT.steer_pot === steerPot), "Steer value is updated into the registers to turn left");
	check_signal((iDUT.en_steer), "Steering is Enabled, and hopefully the direction we want");
	wait_cycles(clk, 100);
	fork 
		begin : theta_conv3
			check_theta_platform (clk, iPHYS.theta_platform, 1000000, "thetha of the platform converged towards 0 after a postive rider lean", 350);
			disable speed_direction3;
		end

		begin : speed_direction3
			check_speed_and_direction(clk, iDUT.lft_spd, iDUT.rght_spd, 2'b10, 20, 1000000); // Tolerance low since slow start timer
		end
	join 
	$display("TEST PASS : The Segway is turning Left");
	// Now to go back to straight I will turn right by the same amount, basically recorrecting values
	turn_right(ld_cell_lft, ld_cell_rght, 12'h1e0, steerPot); // Turn right
	$display("--------Straightening the Segway----------");
	wait_cycles(clk, 100000);
	check_signal((!iDUT.en_steer), "Steering is Not Enabled, after straightening it out");
	fork 
		begin : theta_conv4
			check_theta_platform (clk, iPHYS.theta_platform, 1000000, "thetha of the platform converged towards 0 after a negative rider lean", 350);
			disable speed_direction4;
		end

		begin : speed_direction4
			check_speed_and_direction(clk, iDUT.lft_spd, iDUT.rght_spd, 2'b11, 20, 1000000); // Tolerance low since slow start timer
		end
	join 

	turn_right(ld_cell_lft, ld_cell_rght, 12'h1e0, steerPot); // Turn right
	wait_cycles(clk, 70000);
	check_signal((iDUT.steer_pot === steerPot), "Steer value is updated into the registers to turn right");
	check_signal((iDUT.en_steer), "Steering is Enabled, and hopefully the direction we want");
	fork 
		begin : theta_conv5
			check_theta_platform (clk, iPHYS.theta_platform, 1000000, "thetha of the platform converged towards 0 after a negative rider lean", 350);
			disable speed_direction5;
		end

		begin : speed_direction5
			check_speed_and_direction(clk, iDUT.lft_spd, iDUT.rght_spd, 2'b01, 2, 1000000); // Tolerance low since slow start timer
		end
	join 

	$display("TEST PASS : The Segway is turning Right");
	// Now to go back to straight I will turn left by the same amount, basically recorrecting values
	turn_left(ld_cell_lft, ld_cell_rght, 12'h1e0, steerPot); // Turn right
	$display("--------Straightening the Segway----------");
	wait_cycles(clk, 100000);
	check_signal((!iDUT.en_steer), "Steering is Not Enabled, after straightening it out");
	fork 
		begin : theta_conv6
			check_theta_platform (clk, iPHYS.theta_platform, 1000000, "thetha of the platform converged towards 0 after a turning", 350);
			disable speed_direction6;
		end

		begin : speed_direction6
			check_speed_and_direction(clk, iDUT.lft_spd, iDUT.rght_spd, 2'b11, 20, 1000000); // Tolerance low since slow start timer
		end
	join 

	// Let the Segway slow down itself 
	// rider_lean = 0;
	// wait_cycles(clk, 100000);
	// fork 
	// 	begin : theta_conv7
	// 		check_theta_platform (clk, iPHYS.theta_platform, 1000000, "thetha of the platform converged towards 0 after a positve rider lean", 350);
	// 		disable speed_direction7;
	// 	end

	// 	begin : speed_direction7
	// 		check_speed_and_direction(clk, iDUT.lft_spd, iDUT.rght_spd, 2'b00, 20, 1000000); // Tolerance low since slow start timer
	// 	end
	// join 

	$display("-------------------Speeding the Segway------------------");
	repeat (7) begin
	step_input (clk, rider_lean, 14'h0fff, 1);
	fork 
		begin : theta_conv8
			check_theta_platform (clk, iPHYS.theta_platform, 1000000, "thetha of the platform converged towards 0 after a positive rider lean", 350);
			disable speed_direction8;
		end

		begin : speed_direction8
			check_speed_and_direction(clk, iDUT.lft_spd, iDUT.rght_spd, 2'b11, 20, 1000000); // Tolerance low since slow start timer
		end
	join 
	end
	rider_lean = 16'h7fff;
	check_theta_platform (clk, iPHYS.theta_platform, 1000000, "thetha of the platform converged towards 0 after a negative rider lean", 350);
	wait_cycles(clk, 1000000);
	// rider_lean = 13'h0000;
	// check_theta_platform (clk, iPHYS.theta_platform, 1000000, "thetha of the platform converged towards 0 after a 0 rider lean", 350);

	// Safety: rider falls off while moving
	// $display("Checking safety: rider falls off mid-ride");
	// step_input (clk, rider_lean, 14'h0200, 1); // get moving again
	// wait_cycles(clk, 200000);
	// check_signal(((iDUT.lft_spd != 0) || (iDUT.rght_spd != 0)), "Segway moving before rider fall-off check");
	// reset_weight_eqdistirbution(ld_cell_lft, ld_cell_rght, 13'h0000); // rider steps off
	// rider_lean = 16'h0000;
	// wait_for_signal_high(clk, rider_off_mon, "rider_off asserted when weight removed", 200000);
	// check_signal(!iDUT.en_steer, "Steering disabled when rider is off");
	// wait_for_speed_idle(clk, iDUT.lft_spd, iDUT.rght_spd, 20, 400000, "Wheel speeds ramp down after rider falls off");
	// reset_weight_eqdistirbution(ld_cell_lft, ld_cell_rght, 13'h0400); // rider gets back on for remaining tests
	// wait_cycles(clk, 50000);

	// Too_fast should assert when speeds exceed threshold
	// check_signal(!iDUT.iBAL.too_fast, "too_fast deasserted before overspeed");
	// force iDUT.iBAL.segway.lft_spd = 12'sd1700;
	// force iDUT.iBAL.segway.rght_spd = 12'sd1700;
	// wait_cycles(clk, 100);
	// check_signal(iDUT.iBAL.too_fast, "too_fast asserted when speed exceeds threshold");
	// release iDUT.iBAL.segway.lft_spd;
	// release iDUT.iBAL.segway.rght_spd;
	// wait_cycles(clk, 100);
	// check_signal(!iDUT.iBAL.too_fast, "too_fast deasserts after speed reduced");

	// Piezo response for too_fast (force net to avoid long run)
	repeat (1000) begin
		if ((iDUT.lft_spd > $signed(12'd1536)) | (iDUT.rght_spd > $signed(12'd1536)) ) begin
			if (iDUT.too_fast)
				$display("Too Fast Asserted");
			else 
				$display("%d %d %b", iDUT.lft_spd, iDUT.rght_spd, iDUT.too_fast);
			$display("Checking PIEZO state order for too fast");
			//force iDUT.too_fast = 1'b1;
			wait_for_piezo_state(clk, piezo_state, PIEZO_G6, "Piezo plays G6 when too_fast asserted", 25'h1ffffff);
			wait_for_piezo_state(clk, piezo_state, PIEZO_C7, "Piezo plays G6 when too_fast asserted", 25'h1ffffff);
			wait_for_piezo_state(clk, piezo_state, PIEZO_E7_1, "Piezo plays G6 when too_fast asserted", 25'h1ffffff);
			wait_cycles(clk, 50000);
			break;
		//release iDUT.too_fast;
		end
		@(posedge clk);
	end
	repeat (7) begin
		step_input (clk, rider_lean, 14'h0fff, 0);
		check_theta_platform (clk, iPHYS.theta_platform, 1000000, "thetha of the platform converged towards 0 after a positive rider lean", 350);
	end
	rider_lean = 0;
	$display("Waiting for Segway to slow down");
	wait_cycles(clk, 100000);
	check_signal((iDUT.lft_spd <= $signed(12'd100))&&(iDUT.rght_spd <= $signed(100)), "The segway successfully slowed down");
	$display("---------------Moving Backwards---------------");
	step_input (clk, rider_lean, 14'h0fff, 0); // Move backward
	fork 
		begin : theta_conv_rev
			check_theta_platform (clk, iPHYS.theta_platform, 1000000, "thetha of the platform converged towards 0 after a negative rider lean", 350);
			disable speed_direction_rev;
		end

		begin : speed_direction_rev
			check_speed_and_direction(clk, iDUT.lft_spd, iDUT.rght_spd, 2'b11, 20, 1000000); // Tolerance low since slow start timer
		end
	join 
	check_signal((iDUT.lft_spd <= $signed(12'd0))&&(iDUT.rght_spd <= $signed(12'd0)), "The segway successfully reversed");
	// // Battery-low piezo checks
	// // 1) Verify note order via state sequence
	// reduce_batt(batt, 12'h700); // force well below BATT_THRES so batt_low asserts
	// wait_cycles(clk, 200000); // allow A2D + piezo_drv to see the low battery
	// $display("Checking PIEZO state order for battery low");
	// wait_for_piezo_state(clk, piezo_state, PIEZO_G7_2, "Piezo state G7_2 (first batt_low note)", 25'h1ffffff*2);
	// wait_for_piezo_state(clk, piezo_state, PIEZO_E7_2, "Piezo state E7_2 (second batt_low note)", 25'h1ffffff*2);
	// wait_for_piezo_state(clk, piezo_state, PIEZO_G7_1, "Piezo state G7_1 (third batt_low note)", 25'h1ffffff*2);
	// wait_for_piezo_state(clk, piezo_state, PIEZO_E7_1, "Piezo state E7_1 (fourth batt_low note)", 25'h1ffffff*2);
	// wait_for_piezo_state(clk, piezo_state, PIEZO_C7,   "Piezo state C7 (fifth batt_low note)",    25'h1ffffff*2);
	// wait_for_piezo_state(clk, piezo_state, PIEZO_G6,   "Piezo state G6 (sixth batt_low note)",    25'h1ffffff*2);

	// wait_cycles(clk, 100);
	// $display("Checking PWM outputs for correct high time... (LEFT) - duty: %0d, time: %t", iDUT.iDRV.iPWM_lft.duty, $time);
	// check_pwm_pair(clk, pwm1_lft_logic, pwm2_lft_logic, iDUT.iDRV.iPWM_lft.duty, 64, 2, "LEFT", pwm_synch_logic);
	// wait_cycles(clk, 100);
	// $display("Checking PWM outputs for correct high time... (RIGHT) - duty: %0d", iDUT.iDRV.iPWM_rght.duty);
	// check_pwm_pair(clk, pwm1_rght_logic, pwm2_rght_logic, iDUT.iDRV.iPWM_rght.duty, 64, 2, "RIGHT", pwm_synch_logic);



	$stop();
end

always
  #10 clk = ~clk;

endmodule	

