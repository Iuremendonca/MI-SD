module mac2(
	input wire clk,
	input wire rst_n,
	input wire dado_valido, // vem do contador para acumular
	input wire fim_neuronio, // coontador avisa: salva e zera
	input wire signed [15:0] pixel,
	input wire signed [15:0] peso,
	input wire signed [15:0] bias,
	output reg signed [15:0] saida, 
	output reg saida_valida
);
	reg signed [31:0] acumulador;

	always @(posedge clk or negedge rst_n)begin
		if(!rst_n)begin
			acumulador <= 0;
			saida <= 0;
			saida_valida <=0;
		end
		else begin
			saida_valida <= 0;
			
			if(dado_valido) begin
				if(fim_neuronio) begin
						saida <= (acumulador + (pixel*peso) + (bias)) >>> 12;
						saida_valida <= 1;
						acumulador <= 0;
						
				end
				else begin
					acumulador <= acumulador + (pixel* peso); 
				end
			end
		end
	end
	
endmodule