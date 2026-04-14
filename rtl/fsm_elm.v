module fsm_elm (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire        ultimo_neuronio,
	 input  wire        ultimo_neuronio_saida,
    input  wire        ativacao,
    output reg         pronto,
    output reg         calcular,
    output reg         calcula_saida,
    output reg  [2:0]  estado
);
    localparam REPOUSO     = 3'd0,
               CALC_OCULTO = 3'd1,
               CALC_SAIDA  = 3'd2,
               FIM         = 3'd3;

    reg [2:0] proximo_estado;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) estado <= REPOUSO;
        else        estado <= proximo_estado;
    end

    // ---------------------------------------------------------------
    // foi_ultimo_oculto: captura ultimo_neuronio em CALC_OCULTO
    // ---------------------------------------------------------------
    reg foi_ultimo_oculto;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            foi_ultimo_oculto <= 1'b0;
        else if (ultimo_neuronio && (estado == CALC_OCULTO))
            foi_ultimo_oculto <= 1'b1;
        else if (estado == CALC_SAIDA)
            foi_ultimo_oculto <= 1'b0;
    end

    // ---------------------------------------------------------------
    // foi_ultimo_saida: captura ultimo_neuronio em CALC_SAIDA
    // ---------------------------------------------------------------
    reg foi_ultimo_saida;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            foi_ultimo_saida <= 1'b0;
        else if (ultimo_neuronio_saida && (estado == CALC_SAIDA))
            foi_ultimo_saida <= 1'b1;
        else if (estado == FIM)
            foi_ultimo_saida <= 1'b0;
    end

    always @(*) begin
        proximo_estado = estado;
        case (estado)
            REPOUSO: begin
                if (start) proximo_estado = CALC_OCULTO;
            end
            CALC_OCULTO: begin
                if (ativacao) begin
                    if (foi_ultimo_oculto) proximo_estado = CALC_SAIDA;
                    else                   proximo_estado = CALC_OCULTO;
                end
            end
            CALC_SAIDA: begin
                if (foi_ultimo_saida) proximo_estado = FIM;
            end
            FIM: begin
                proximo_estado = REPOUSO;
            end
            default: proximo_estado = REPOUSO;
        endcase
    end

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