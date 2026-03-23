module fsm_elm (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire        fim_inferencia,
    input  wire        ultimo_neuronio,
    input  wire        ativacao,
    output reg         calcular,
    output reg         pronto,
    output reg  [2:0]  estado           
);
    
    localparam [2:0] REPOUSO     = 3'd0,
                     CALC_OCULTO = 3'd1,
                     ATIVACAO    = 3'd2,
                     ARGMAX      = 3'd3,
                     FIM         = 3'd4;

    reg [2:0] proximo_estado;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            estado <= REPOUSO;
        else
            estado <= proximo_estado;
    end
  
    always @(*) begin
        proximo_estado = estado;
        calcular       = 1'b0;
        pronto         = 1'b0;

        case (estado)
            REPOUSO: begin
                pronto = 1'b1;
                if (start)
                    proximo_estado = CALC_OCULTO;
            end

            CALC_OCULTO: begin
                calcular = 1'b1;
                if (ativacao)    // neurônio concluído
                    proximo_estado = ATIVACAO;
            end

            ATIVACAO: begin
                if (!ativacao) begin
                    if (ultimo_neuronio) //contador
                        proximo_estado = ARGMAX;
                    else
                        proximo_estado = CALC_OCULTO;
                end
            end

            ARGMAX: begin
                if (fim_inferencia)
                    proximo_estado = FIM;
            end

            FIM: begin
                pronto         = 1'b1;
                proximo_estado = REPOUSO;
            end

            default: proximo_estado = REPOUSO;
        endcase
    end

endmodule