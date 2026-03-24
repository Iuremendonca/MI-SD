module fsm_elm (
    input  wire        clk,
    input  wire        rst_n,           
    input  wire        start,           
    input  wire        ultimo_neuronio,
    input  wire        ativacao,
    input  wire        ultimo_argmax,
    output reg         calcular,
    output reg         calcula_saida,
    output reg         pronto,
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

    //ontrola estados
    always @(*) begin
        proximo_estado = estado;

        case (estado)
            REPOUSO: begin
                if (!start)              
                    proximo_estado = CALC_OCULTO;
            end

            CALC_OCULTO: begin
                if (ativacao)
                    proximo_estado = ATIVACAO;
            end

            ATIVACAO: begin
                if (!ativacao) begin
                    if (ultimo_neuronio) proximo_estado = CALC_SAIDA;
                    else                 proximo_estado = CALC_OCULTO;
                end
            end

            CALC_SAIDA: begin
                if (ultimo_argmax)
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