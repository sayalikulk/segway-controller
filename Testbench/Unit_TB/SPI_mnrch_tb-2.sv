module SPI_mnrch_tb ();

    logic SS_n,SCLK,MISO,MOSI,INT;
    logic clk, rst_n, wrt, done;
    logic [15:0] wt_data, rd_data;

    SPI_mnrch iDUT (.clk(clk), .rst_n(rst_n), .wt_data(wt_data), .wrt(wrt), .rd_data(rd_data), .done(done),
                        .SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO));
    
    SPI_iNEMO1 driven(.SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO), .INT(INT));

    always
	   #5 clk = ~clk;

    integer i;

    initial begin
	  clk = 0;
	  rst_n = 0;
	  wrt = 0;
	  wt_data = 16'b0;
	  @(negedge clk);

	  rst_n = 1;

	  @(posedge clk);

	  // At reset, check for initial conditions
	  if ((SS_n !== 1) & (SCLK !== 1)) begin
		  $display ("ERROR : AT reset, SS_n should be high and SCLK should be high \n");
		  $display ("SS_n = %b SCLK = %b" ,SS_n, SCLK);
		  $stop;
	  end

	  else 
		  $display("Test 1 : Pass --> All okay at reset!");
	  @(negedge clk);

	  // Read into register 0x8F
	  wrt = 1;
	  wt_data = 16'h8f00; 

	  @(negedge clk);
	  wrt = 0;

	  @(posedge clk);
	  // Need to check whether SS_n is asserted LOW
	  if (SS_n === 1) begin
		  $display ("ERROR : SS_n not 0");
		  $stop;
	  end

	  i = 0;

	  // Wait for multiple cycle for done to be asserted from the module
	  while (!done) begin
		@(negedge clk);
	        i = i+1;
		if (i >= 300) begin
			$display("ERROR : Too many cycles");
			$stop;
		end
	  end

	  // Check for the read data
	  if (rd_data[7:0] !== 8'h6A) begin
		$display("ERROR : wrong output read from WHO_AM_I register");
      		$stop;
	  end

	  else 
		$display("Test 2 : Pass ---> Correct Value read from WHO_AM_I register");	  

	  i = 0;
	  // Check whether the chip select signal has been deasserted, i.e. SS_n = 1
	  while (SS_n !== 1) begin
		@ (negedge clk);
      		if (i >= 8) begin
			$display ("ERROR : Back Porch is taking too many cycles to come back up");
			$stop;
		end
		i = i+1;
	  end

	  // Checking whether SCLK is stuck at 1 and not toggling
	  if (SCLK !== 1) begin
		$display ("ERROR : SCLK is not back up");
      		$stop;
	  end

	  @(negedge clk);
	  wrt = 1;
	  wt_data = 16'h0d02; // write data 02 into register 0d
	
	  @(negedge clk);
	  wrt = 0;
	  
	  //SS_n is not asserted, i.e. the chip is deselected
	  if (SS_n === 1) begin
		  $display ("ERROR : SS_n not 0");
		  $stop;
	  end

	  i = 0;
	  // Checking for the NEMO_setup in the module to be 1 --> to indicate that INT will be asserted soon
	  while (driven.NEMO_setup !== 1'b1) begin
		 @(negedge clk);
		 // If too many cycles then error out
		 if (i >= 300) begin
			$display("Error : Too many cycles");
			$stop;
		end

		i = i+1;
	end


	// Since we know that INT will be asserted for sure then we wait for INT to be asserted 
	while (!INT) begin
		@(negedge clk);
	end

	$display ("Test 3: Pass --> INT asserted successfully first time");

	// Checking whether register is written appropriately 
	if (driven.registers[13] !== 8'h02) begin
		$display ("ERROR : Register 0X0D not written to properly");
		$stop;
	end

	$display ("Test 4: Pass --> Correct value written to register 0x0D");

	// Wait for 2 SCLK clock cycles
	repeat (16)
		@(negedge clk);

	// Making sure the chip is deselected and SCLK is at 1
	if ((SS_n !== 1) & (SCLK !== 1)) begin
		  $display ("ERROR : Not at IDLE state \n");
		  $display ("SS_n = %b SCLK = %b" ,SS_n, SCLK);
		  $stop;
	end

	@(negedge clk);
	  wrt = 1;
	  wt_data = 16'hA200; // Trying to read into register A2

	  @(negedge clk);
	  wrt = 0;

	  @(posedge clk);
	  // Need to check whether SS_n is asserted LOW
	  if (SS_n === 1) begin
		  $display ("ERROR : SS_n not 0");
		  $stop;
	  end

	  i = 0;
	  while (!done) begin
		@(negedge clk);
	        i = i+1;
		// Too many cycles then Error out
		if (i >= 300) begin
			$display("ERROR : Too many cycles");
			$stop;
		end
	  end

	  if (rd_data[7:0] !== 8'h63) begin
		$display("ERROR : wrong output read from 0x22 pitchL Register");
      		$stop;
	  end

	  else 
		$display("Test 5 : Pass ---> Correct Value read from 0x22 pitchL Register");	

	  // Waiting for 2 SCLK cycles 
	  repeat (32)
	  	@(negedge clk);
	  wrt = 1;
	  wt_data = 16'hA300; // Reading into register A3

	  @(negedge clk);
	  wrt = 0;

	  @(posedge clk);
	  // Need to check whether SS_n is asserted LOW
	  if (SS_n === 1) begin
		  $display ("ERROR : SS_n not 0");
		  $stop;
	  end

	  i = 0;
	  while (!done) begin
		@(negedge clk);
	        i = i+1;
		// Too many cycles then Error out
		if (i >= 300) begin
			$display("ERROR : Too many cycles");
			$stop;
		end
	  end
	  
	  // Cross check the value read 
	  if (rd_data[7:0] !== 8'h56) begin
		$display("ERROR : wrong output read from 0x22 pitchL Register");
      		$stop;
	  end

	  else 
		$display("Test 6 : Pass ---> Correct Value read from 0x22 pitchH Register");
	
	// Wait for INT to be asserted another time 
	while (!INT) begin
		@(negedge clk);
	end

	$display ("INT asserted successfully 2nd time");

	// Wait for one SCLK clock cycle 
	repeat (16)
		@(negedge clk);

	// Making sure the chip is deselected and SCLK is at 1
	if ((SS_n !== 1) & (SCLK !== 1)) begin
		  $display ("ERROR : Not at IDLE state \n");
		  $display ("SS_n = %b SCLK = %b" ,SS_n, SCLK);
		  $stop;
	end

	@(negedge clk);
	  wrt = 1;
	  wt_data = 16'hA200; // Reading into register A2 again 

	  @(negedge clk);
	  wrt = 0;

	  @(posedge clk);
	  // Need to check whether SS_n is asserted LOW
	  if (SS_n === 1) begin
		  $display ("ERROR : SS_n not 0");
		  $stop;
	  end

	  i = 0;
	  while (!done) begin
		@(negedge clk);
	        i = i+1;
		// Errors out after 300 cycls
		if (i >= 300) begin
			$display("ERROR : Too many cycles");
			$stop;
		end
	  end
	  
	  // Cross check the read data
	  if (rd_data[7:0] !== 8'h0d) begin
		$display("ERROR : wrong output read from 0x22 pitchL Register in the 2nd instance");
      		$stop;
	  end

	  else 
		$display("Test 7 : Pass ---> Correct Value read from 0x22 pitchL Register in 2nd instance");	

	  // Waiting for 2 SCLK cycles 
	  repeat (32)
	  	@(negedge clk);
	  wrt = 1;
	  wt_data = 16'hA300; // Reading into register A3

	  @(negedge clk);
	  wrt = 0;

	  @(posedge clk);
	  // Need to check whether SS_n is asserted LOW
	  if (SS_n === 1) begin
		  $display ("ERROR : SS_n not 0");
		  $stop;
	  end

	  i = 0;
	  while (!done) begin
		@(negedge clk);
	        i = i+1;
		// Error out if too many cycles for done to be asserted 
		if (i >= 300) begin
			$display("ERROR : Too many cycles");
			$stop;
		end
	  end

	  // Cross check the read data 
	  if (rd_data[7:0] !== 8'hcd) begin
		$display("ERROR : wrong output read from 0x22 pitchL Register");
      		$stop;
	  end

	  else 
		$display("Test 8 : Pass ---> Correct Value read from 0x22 pitchH Register");
	
	// Display an all pass 
	$display("YAY! ALL TEST CASES PASSED");
	$stop;

   end

endmodule
