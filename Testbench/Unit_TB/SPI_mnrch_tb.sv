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
		  $display("All okay at reset!\n");
	  @(negedge clk);
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
	  while (!done) begin
		@(negedge clk);
	        i = i+1;
		if (i >= 300) begin
			$display("ERROR : Too many cycles");
			$stop;
		end
	  end

	  if (rd_data[7:0] !== 8'h6A) begin
		$display("ERROR : wrong output read from WHO_AM_I register");
      		$stop;
	  end

	  else 
		$display("Correct Value read from WHO_AM_I register\n");	  

	  i = 0;
	  while (SS_n !== 1) begin
		@ (negedge clk);
      		if (i >= 8) begin
			$display ("ERROR : Back Porch is taking too many cycles to come back up");
			$stop;
		end
		i = i+1;
	  end

	  if (SCLK !== 1) begin
		$display ("ERROR : SCLK is not back up");
      		$stop;
	  end

	  @(negedge clk);
	  wrt = 1;
	  wt_data = 16'h0d02;
	
	  @(negedge clk);
	  wrt = 0;

	  if (SS_n === 1) begin
		  $display ("ERROR : SS_n not 0");
		  $stop;
	  end

	  i = 0;
	  while (driven.NEMO_setup !== 1'b1) begin
		 @(negedge clk);
		 if (i >= 300) begin
			$display("Error : Too many cycles");
			$stop;
		end

		i = i+1;
	end

	while (!INT) begin
		@(negedge clk);
	end

	$display ("INT asserted successfully \n");

	if (driven.registers[13] !== 8'h02) begin
		$display ("ERROR : Register 0X0D not written to properly");
		$stop;
	end

	

	$stop;

   end

endmodule
