module isa (
    input clk,
    input rst_n,
    
    // Interface com o HPS (ARM)
    input [31:0] instrucao,
    input         hps_write,
    output reg [31:0] hps_readdata,
    
    // Interface com a FSM
    input         fsm_busy,
    input         fsm_done,
    input         fsm_error,
    input  [3:0]  elm_result,
    output reg    start_pulse,
    
    // Interface com Memórias
    output reg [16:0] w_addr,
    output reg [9:0]  img_addr,
    output reg [6:0]  bias_addr,
    output reg [10:0] beta_addr,
    output reg signed [15:0] data_to_mem,
    output reg wren_w, wren_img, wren_bias, wren_beta
);

	reg [31:0] save_instrucao;

    // Decodificação da instrução
    wire [3:0]  opcode  = save_instrucao[31:28];
    wire [11:0] addr_in = save_instrucao[27:16];
    wire [15:0] data_in = save_instrucao[15:0];
	 
	 wire [16:0] addr_win = save_instrucao[16:0];

	// Registrador para w_addr
    reg [16:0] temp_w_addr;

    // Lógica principal
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset geral
            w_addr     <= 0;
            img_addr   <= 0;
            bias_addr  <= 0;
            beta_addr  <= 0;
            temp_w_addr <= 0;
            data_to_mem    <= 0;
            
            {wren_w, wren_img, wren_bias, wren_beta, start_pulse} <= 5'b0;
        end else begin
            // Pulsos duram apenas 1 ciclo
            {wren_w, wren_img, wren_bias, wren_beta, start_pulse} <= 5'b0;

            if (!hps_write && !fsm_busy) begin
                case (opcode)

                    // STORE IMG
                    4'h1: begin
                        img_addr <= addr_in[9:0];
                        data_to_mem  <= data_in;
								wren_img     <= 1'b1;
                    end
					
                    // STORE W 
                    4'h2: begin
								w_addr  <= temp_w_addr;
								data_to_mem <= data_in;
								wren_w      <= 1'b1;
                    end

                    // STORE B
                    4'h3: begin
                        bias_addr <= addr_in[6:0];
                        data_to_mem   <= data_in;
                        wren_bias     <= 1'b1;
                    end
					
                    // STORE BETA
                    4'h4: begin
								 beta_addr <= addr_in[10:0];
								 data_to_mem   <= data_in;
								 wren_beta     <= 1'b1;
                    end

                    // START
                    4'h5: begin
                        start_pulse <= 1'b1;
                    end
						  
						  // STORE W ADDR
                    4'h7: begin
								 temp_w_addr  <= addr_win;
                    end

                    // DEFAULT
                    default: begin
                        // nenhuma ação
                    end

                endcase
            end
        end
    end

    // STATUS (leitura pelo HPS)
    // [0] busy
    // [1] done
    // [2] error
    // [7:4] resultado (dígito)
	 always @(posedge clk) begin
		save_instrucao <= instrucao;
		hps_readdata = {
			  24'b0,
			  elm_result,
			  1'b0,
			  fsm_error,
			  fsm_done,
			  fsm_busy
		 };
	end
endmodule