module ativacao_sigmoid (
    input  wire        clk,              
    input  wire        rst_n,            
    input  wire [15:0] d_in,
    input  wire        ativacao,
    output reg  signed [15:0] d_out,
    output reg         ativacao_concluida
);
    localparam V_0_5      = 16'h0800;
    localparam V_0_625    = 16'h0a00;
    localparam V_0859375  = 16'h0DC0;
    localparam V_1_0      = 16'h1000;
    localparam LIMIT_1_0  = 16'h1000; 
    localparam LIMIT_2_5  = 16'h2800; 
    localparam LIMIT_4_5  = 16'h4800;

    // cálculo combinacional separado (sem latch)
    reg signed [15:0] d_out_comb;
    reg e_negativo;
    reg [15:0] valor_absoluto;

    always @(*) begin
        e_negativo     = d_in[15];
        valor_absoluto = e_negativo ? (~d_in + 1'b1) : d_in;
        
        // default explícito elimina latch
        d_out_comb = V_1_0;

        if (valor_absoluto < LIMIT_1_0)
            d_out_comb = (valor_absoluto >> 2) + V_0_5;
        else if (valor_absoluto < LIMIT_2_5)
            d_out_comb = (valor_absoluto >> 3) + V_0_625;
        else if (valor_absoluto < LIMIT_4_5)
            d_out_comb = (valor_absoluto >> 5) + V_0859375;
        else
            d_out_comb = V_1_0;

        if (e_negativo)
            d_out_comb = V_1_0 - d_out_comb;
    end

    // registra saída e ativacao_concluida — atrasa 1 ciclo
    // garante que FSM não pula estado ATIVACAO
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            d_out              <= 16'b0;
            ativacao_concluida <= 1'b0;
        end else begin
            ativacao_concluida <= ativacao;       // 1 ciclo depois de ativacao
            if (ativacao)
                d_out <= d_out_comb;              // captura resultado estável
            else
                d_out <= d_out;                   // mantém último valor válido
        end
    end
endmodule
    