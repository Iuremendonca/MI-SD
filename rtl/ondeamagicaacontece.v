module ondeamagicaacontece(
    input  wire clk,
    input  wire rst_n,
	 input wire [31:0] instrucao,
    input wire        hps_write,
    output [31:0] hps_readdata
);


    // ---------------------------------------------------------------
    // Sinais internos - FSM
    // ---------------------------------------------------------------
    wire        calcular;
    wire        calcula_saida;
    wire [2:0]  estado;
	 wire pronto;
    // ---------------------------------------------------------------
    // Sinais internos - Camada Oculta
    // ---------------------------------------------------------------
    wire        ultimo_neuronio;
    wire        ativacao;
    wire [9:0]  addr_img;
    wire [16:0] addr_peso;
    wire [6:0]  addr_bias;
    wire signed [15:0] h_saida;
    wire               h_valida;
    // ---------------------------------------------------------------
    // Sinais internos - RAMs
    // ---------------------------------------------------------------
    wire [7:0]         dado_img;
    wire signed [15:0] dado_peso;
    wire signed [15:0] dado_bias;
    wire signed [15:0] dado_neuronio;
	 
	 // ---------------------------------------------------------------
    // Sinais internos - Camada Saída
    // ---------------------------------------------------------------
    wire        ultimo_neuronio_saida;
    wire        y_valida;
    wire signed [15:0] y_saida;
    wire [6:0]  addr_h;
    wire [10:0] addr_peso_saida;
    wire signed [15:0] dado_peso_s;
    wire [3:0]  resultado;
	 
	  // ---------------------------------------------------------------
    // Ativação Sigmoid
    // ---------------------------------------------------------------
    wire signed [15:0] h_ativado;
    wire [6:0]         addr_neur;
	 
	 // ---------------------------------------------------------------
    // Sinais internos - ISA
    // ---------------------------------------------------------------	 

	 wire [31:0] hps_data;
	 assign hps_readdata = hps_data;
	 wire start;
	 
	 wire wren_w, wren_img, wren_bias, wren_beta;
	 wire [16:0] w_addr;
    wire [9:0]  img_addr;
    wire [6:0]  bias_addr;
    wire [10:0] beta_addr;
	 wire signed [15:0] data_to_mem;
	 
    // ---------------------------------------------------------------
    // Controle ISA
    // ---------------------------------------------------------------	 
	 isa isa (
		 .clk(clk),
		 .rst_n(rst_n),
		 
		 // Interface com o HPS (ARM)
		 .instrucao(instrucao),
		 .hps_write(hps_write),
		 .hps_readdata(hps_data),
		 
		 // Interface com a FSM
		 .fsm_busy(estado != 1'b0 ? 1'b1: 1'b0),
		 .fsm_done(pronto),
		 .fsm_error(1'b0),
		 .elm_result(resultado),
		 .start_pulse(start),
		 
		 // Interface com Memórias
		 .w_addr(w_addr),
		 .img_addr(img_addr),
		 .bias_addr(bias_addr),
		 .beta_addr(beta_addr),
		 .data_to_mem(data_to_mem),
		 .wren_w(wren_w),
		 .wren_img(wren_img),
		 .wren_bias(wren_bias),
		 .wren_beta(wren_beta)
	 );
	 
	 
	 
    // ---------------------------------------------------------------
    // FSM
    // ---------------------------------------------------------------
    fsm_elm u_fsm (
        .clk             (clk),
        .rst_n           (rst_n),
        .start           (start),
        .ultimo_neuronio (ultimo_neuronio),
		  .ultimo_neuronio_saida (ultimo_neuronio_saida),
        .ativacao        (ativacao),
        .pronto          (pronto),
        .calcular        (calcular),
        .calcula_saida   (calcula_saida),
        .estado          (estado)
    );
    // ---------------------------------------------------------------
    // Camada Oculta
    // ---------------------------------------------------------------
    camada_oculta u_oculta (
        .clk            (clk),
        .rst_n          (rst_n),
        .calcular       (calcular),
        .ultimo_neuronio(ultimo_neuronio),
        .addr_img       (addr_img),
        .addr_peso      (addr_peso),
        .addr_bias      (addr_bias),
        .dado_img       (dado_img),
        .dado_peso      (dado_peso),
        .dado_bias      (dado_bias),
        .h_saida        (h_saida),
        .ativacao       (ativacao)
    );


    ativacao_sigmoid u_sigmoid (
        .clk      (clk),
        .rst_n    (rst_n),
        .d_in     (h_saida),
        .ativacao (ativacao),
        .d_out    (h_ativado),
        .addr_out (addr_neur)
    );
    
    // ---------------------------------------------------------------
    // Camada Saída
    // ---------------------------------------------------------------
    camada_saida u_saida (
        .clk            (clk),
        .rst_n          (rst_n),
        .calcula_saida  (calcula_saida),
        .ultimo_neuronio(ultimo_neuronio_saida),
        .addr_h         (addr_h),
        .addr_peso_saida(addr_peso_saida),
        .dado_h         (dado_neuronio),
        .dado_peso_s    (dado_peso_s),
        .y_saida        (y_saida),
        .y_valida       (y_valida)
    );
    // ---------------------------------------------------------------
    // Argmax
    // ---------------------------------------------------------------
    argmax u_argmax (
        .clk      (clk),
        .rst_n    (rst_n),
        .pronto   (pronto),
        .clear    (start),
        .y_in     (y_saida),
        .update_en(y_valida),
        .saida    (resultado)
    );
    // ---------------------------------------------------------------
    // RAMs
    // ---------------------------------------------------------------
    ram_img u_ram_img (
        .clock   (clk),
        .address (estado != 1'b0 ? addr_img: img_addr),
        .data    (data_to_mem[7:0]),
        .rden    (calcular),
        .wren    (wren_img),
        .q       (dado_img)
    );
    ram_pesos u_ram_pesos (
        .clock   (clk),
        .address (estado != 1'b0 ? addr_peso: w_addr),
        .data    (data_to_mem),
        .rden    (calcular),
        .wren    (wren_w),
        .q       (dado_peso)
    );
    ram_bias u_ram_bias (
        .clock   (clk),
        .address (estado != 1'b0 ? addr_bias: bias_addr),
        .data    (data_to_mem),
        .rden    (calcular),
        .wren    (wren_bias),
        .q       (dado_bias)
    );
    ram_neuroniosativos u_ram_neur (
        .clock   (clk),
        .address (calcula_saida ? addr_h : addr_neur),
        .data    (h_ativado),
        .rden    (calcula_saida),
        .wren    (ativacao && (estado == 3'd1)),
        .q       (dado_neuronio)
    );
    ram_beta u_ram_beta (
        .clock   (clk),
        .address (estado != 1'b0 ? addr_peso_saida: beta_addr),
        .data    (data_to_mem),
        .rden    (calcula_saida),
        .wren    (wren_beta),
        .q       (dado_peso_s)
    );

endmodule