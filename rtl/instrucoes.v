module instrucoes (
	input [2:0] opcode, // chaves para opcode da instruçao
	input [2:0] addr,  // chaves para endereço que irá gravar
	input [3:0] data, // chave para dado que irá gravar
   input in_hps_write, // botao que indica que a instrucao foi enviada pelo arm
	input in_clk,
	output [6:0] digito,
	output [6:0] status
);

//A isa consistem em 4 bits de opcode, 12 bits de endereco e 16 bits de dados, portanto será necessario o complemento dos bits das chaves 
wire [31:0] instrucao_s;

wire [3:0] opcode_completo = {1'b0,opcode};
wire [11:0] addr_completo = {9'b0, addr};
wire [15:0] data_completo = {12'b0, data};

assign instrucao_s ={opcode_completo,addr_completo,data_completo};
wire [31:0] result;
	
	ondeamagicaacontece(
	.clk(in_clk),
	.rst_n(1'b1),
	.hps_write(in_hps_write),
	.instrucao(instrucao_s),
	.hps_readdata(result)
	);

	//para inferencia
	decodificador_7seg digi(
	.in(result[7:4]),
	.sinal(1'b1),
	.seg_out(digito)
	);
	
	//status
	decodificador_7seg stat(
	.in({1'b0,result[2:0]}),
	.sinal(1'b0),
	.seg_out(status)
	);

endmodule

