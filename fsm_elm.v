module fsm_elm (
    input  wire        clk,
    input  wire        rst_n,           
    input  wire        start,           
    input  wire        ultimo_neuronio,
    input  wire        ativacao,
	 input wire         ativacao_concluida,
	 output reg        pronto,
    output reg         calcular,
    output reg         calcula_saida,
    output reg  [2:0]  estado
);

    localparam REPOUSO     = 3'd0,
               CALC_OCULTO = 3'd1,
               ATIVACAO    = 3'd2,
               CALC_SAIDA  = 3'd3,
               FIM         = 3'd4;

    reg [2:0] proximo_estado;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            estado <= REPOUSO;
        else        
            estado <= proximo_estado;
    end
	 
	 reg foi_ultimo;
    always @(posedge clk or negedge rst_n) begin
    if (!rst_n) 
        foi_ultimo <= 1'b0;
    else if (ultimo_neuronio) 
        foi_ultimo <= 1'b1; // Captura o pulso e "trava" em 1
    else if (estado == CALC_SAIDA) 
        foi_ultimo <= 1'b0; // Destrava quando mudar de fase
end

    //ontrola estados
    always @(*) begin
        proximo_estado = estado;

        case (estado)
            REPOUSO: begin
                if (start)              
                    proximo_estado = CALC_OCULTO; 
            end

            CALC_OCULTO: begin
                if (ativacao)
                    proximo_estado = ATIVACAO;
            end

            ATIVACAO: begin
                if (ativacao_concluida) begin
                    if (foi_ultimo) proximo_estado = CALC_SAIDA;
                    else                 proximo_estado = CALC_OCULTO;
                end
            end

            CALC_SAIDA: begin
                if (ultimo_neuronio)
                    proximo_estado = FIM;
            end

            FIM: ; // aguarda reset

            default: proximo_estado = REPOUSO;
        endcase
    end

    // controla sinais
    always @(*) begin
        calcular      = 1'b0;
        calcula_saida = 1'b0;
        pronto        = 1'b0;

        case (estado)
            CALC_OCULTO: calcular      = 1'b1;
            CALC_SAIDA:  calcula_saida = 1'b1;
            FIM:         pronto        = 1'b1;
            default: ;
        endcase
    end

endmodule