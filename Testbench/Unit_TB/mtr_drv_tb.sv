module mtr_drv_tb();

	// Inputs to the DUT
	logic clk, rst_n;
	logic [11:0] lft_spd, rght_spd;
	logic OVR_I_lft, OVR_I_rght;

	// Outputs to the DUT
	logic PWM1_lft, PWM2_lft, PWM1_rght, PWM2_rght;
	logic OVR_I_shtdwn;

	// Instantiating the DUT
	mtr_drv iDUT( .clk(clk), .rst_n(rst_n), .lft_spd(lft_spd), .rght_spd(rght_spd), .OVR_I_lft(OVR_I_lft), .OVR_I_rght(OVR_I_rght), 
		      .PWM1_lft(PWM_lft), .PWM1_rght(PWM1_rght), .PWM2_lft(PWM2_lft), .PWM2_rght(PWM2_rght), .OVR_I_shtdwn(OVR_I_shtdwn));

	// Clock driver
	always 
		#5 clk = ~clk;

	integer random_count; // Random count that changes the number of cycles to test
	integer i, pwm_cycles;
	bit [31:0] rand_duty;
	
	initial begin
		clk = 0;
		rst_n = 0;
		lft_spd = 0;
		rght_spd = 0;
		OVR_I_lft = 0;
		OVR_I_rght = 0;
		
		repeat (2)
		@(negedge clk);

		rst_n = 1;

		// Check whether all is okay at reset
		assert (OVR_I_shtdwn === 1'b0) $display("All okay at Reset \n");
		else begin
			$error("ERROR : Module SHUTDOWN after reset");
			$stop();
		end
		
		$display ("TEST 1 \n");
		// Running for 5 random values of speed and count
		for (i = 0; i<6; i+=1) begin
			// Assigning random value to lft and rght speed. 
			// Since we only consider the lft PWM, we shall send the same
			// signal to both to maintain uniformity
			if (i<2)
				rand_duty   = $urandom_range(200, 700); // Duty cycle random generation, can at max be only 2047 this is for LOW end  
			else if (i<4)
				rand_duty   = $urandom_range(710, 1400); // MED Duty cycl range
			else 
				rand_duty   = $urandom_range(1410, 1919); // HIGH Duty Cycle range
			random_count = $urandom_range(41, 80); // Generate a random value between 40 to 80

			lft_spd = rand_duty[11:0];
			rght_spd = rand_duty[11:0];

			$display("Test 1 -- Sub-Case %d : number of PWM cycles = %d  || Duty Cycle given = %d", (i+1), random_count, rand_duty);

			repeat (random_count) begin
				fork
					begin : timeout
						repeat (5000) 
							@(posedge clk);
						$error ("ERROR : PWM_synch taking too much time to arrive");
						$stop();
					end

					begin : driver_block
						@(posedge iDUT.ovr_I_blank);
						OVR_I_lft = 1;
						@(negedge iDUT.ovr_I_blank);
						OVR_I_lft = 0;
						@(posedge iDUT.ovr_I_blank);
						OVR_I_rght = 1;
						@(negedge iDUT.ovr_I_blank);
						OVR_I_rght = 0;
						@(negedge iDUT.PWM_synch);
						disable timeout;
						disable assertion_check;
					end
					
					// Since assert property is not
					// present in ModelSim, we tried
					// a different approach
					begin : assertion_check
						repeat (3000) begin
							assert (~OVR_I_shtdwn)
							else begin
							$error("ERROR : Module shutting down during blanking period");
							$stop();
							end
							@(negedge clk);
						end
					end


				join
			end

			$display("----------Passed----------");
		end

	
		repeat (2040)
			@(negedge clk);	
		$display ("TEST 2 \n");
		// Running for 5 random values of speed and count
		for (i = 0; i<6; i+=1) begin
			// Assigning random value to lft and rght speed. 
			// Since we only consider the lft PWM, we shall send the same
			// signal to both to maintain uniformity
			if (i < 2)
				rand_duty   = $urandom_range(200, 700); // LOW Duty cycle range
			else if (i<4)
				rand_duty   = $urandom_range(710, 1400); //MED duty cycle range
			else 
				rand_duty   = $urandom_range(1400, 1919); //HIGH duty cycle range
			random_count = $urandom_range(40, 80); // Generate a random value between 40 to 80

			//@(posedge iDUT.PWM_synch);
			lft_spd = rand_duty[11:0];
			rght_spd = rand_duty[11:0];

			pwm_cycles = 0;

			$display("Test 2 -- Sub-Case %d : number of PWM cycles = %d  || Duty Cycle given = %d", (i+1), random_count, rand_duty);
			
			repeat (random_count) begin
				fork
					begin : timeout_2
						repeat (5000) 
							@(posedge clk);
						$error ("ERROR : PWM_synch taking too much time to arrive");
						$stop();
					end

					begin : driver_block_2
						@(negedge iDUT.ovr_I_blank);
						OVR_I_lft = 1;
						repeat(2)
						@(negedge clk);
						OVR_I_lft = 0;
						@(negedge iDUT.ovr_I_blank);
						OVR_I_rght = 1;
						repeat(2)
						@(negedge clk);
						OVR_I_rght = 0;
						@(negedge iDUT.PWM_synch);
						disable timeout_2;
						//disable assertion_check_2;
						disable assertion_check_3;
					end
					
					
					begin : assertion_check_3
						pwm_cycles += 1;
						if (pwm_cycles >= 40) begin
						       while(1) begin
							assert (OVR_I_shtdwn)
							else begin
								$error("ERROR : SHUTDOWN NOT INITIATED!");
								$stop();
							end
							@(negedge clk);
						       end
						end
						else if (pwm_cycles < 17) begin
							while (1) begin
								assert(!OVR_I_shtdwn)
								else begin
									$error("ERROR : Shutdown initiated too quick");
								end
								@(negedge clk);
							end
						end

					end	

				join

				if (OVR_I_shtdwn) begin
					$display("----------Passed----------");
					repeat (2)
						@(negedge clk);
					$display("------trigerring reset-----");
					rst_n = 0;
					@(negedge clk);
					rst_n = 1;
					break;
				end

				
			end
		end
			

		$display("ALL TEST CASES PASSED!");	

		$stop();	
	end

	// Since I don't have an option of actually using assert property in ModelSim
	// I have shortcut the approach by using a forever block
	always begin
		forever begin
			// Property Assertions to ensure no anomaly within the PWM module	
		// asserting that the PWM1 and PWM2 of each of the PWM module
		// can not be on at the same time
			if (rst_n === 1) begin
				assert (!(iDUT.PWM_lft && iDUT.PWM_lft_n))
				else begin
					$error ("PWM signal for left module has asserted PWM and PWM_n at the same time");
					$stop();
				end
				
				assert (!(iDUT.PWM_rght && iDUT.PWM_rght_n))
				else begin
					$error ("PWM signal for right module has asserted PWM and PWM_n at the same time");
					$stop();
				end
				@(negedge clk);
			end

			else 
				@(negedge clk);
		end
	end

endmodule 	

