module contador_elm2 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        calcular,      // vem da fsm
    output reg [9:0]  x_addr,     // endereço da RAM de pixels
	 output reg [16:0] w_addr, //endereço da RAM pesos
	 output reg dado_valido, //verifica se os dados chegaram
	 output reg fim_neuronio,
	 output reg fim_camada,
	 output reg [6:0] neuronio
);

	reg[9:0] cont_pi;
	reg[6:0] cont_neu;
	reg pipeline;
	
	always @(posedge clk or negedge rst_n) begin
		if(!rst_n)begin
			 cont_pi  <= 0;
          cont_neu <= 0;
          pipeline  <= 0;
          dado_valido <= 0;
          fim_neuronio <= 0;
          fim_camada <= 0;
          x_addr <= 0;
          w_addr <= 0;
		end
		else if(calcular) begin
			pipeline <= 1;
			dado_valido <= pipeline;
			
			x_addr <= cont_pi;
			w_addr <= cont_neu * 784 + cont_pi;
			
			fim_neuronio <= (cont_pi == 783) && pipeline;
			neuronio <= fim_neuronio? cont_neu:7'h0;
			fim_camada <= (cont_pi == 783) && (cont_neu == 127) && pipeline;
			
			if(cont_pi == 783)begin
				cont_pi <=0;
				if(cont_neu<127)begin
					cont_neu <= cont_neu + 1;
				end
				else begin
					cont_neu <= 0;
				end
			end
			else begin
				cont_pi <= cont_pi + 1;
			end
		end
		
		else begin
			pipeline <= 0;
			dado_valido <= 0;
			fim_neuronio <= 0;
		end
	end
	
endmodule
	 