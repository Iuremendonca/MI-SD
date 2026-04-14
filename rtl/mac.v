module mac(
    input wire clk,
    input wire rst_n,
    input wire dado_valido, 
    input wire fim_neuronio,
    input wire ultimo_neuronio,
    input wire signed [15:0] valor, 
    input wire signed [15:0] peso,
    input wire signed [15:0] bias, 
    output reg signed [15:0] saida,
    output reg ativacao
);
    reg signed [39:0] acumulador;
    reg signed [39:0] v_soma_final;
    reg signed [39:0] v_resultado_shiftado;
    wire signed [39:0] bias_alinhado = {{12{bias[15]}}, bias, 12'd0};
    wire signed [31:0] mult_atual = valor * peso;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            acumulador           <= 40'd0;
            saida                <= 16'd0;
            ativacao             <= 1'b0;
            v_soma_final          = 40'd0;
            v_resultado_shiftado  = 40'd0;
        end
        else begin
            if(dado_valido) begin
                if(fim_neuronio) begin
                    v_soma_final         = acumulador + mult_atual + bias_alinhado;
                    v_resultado_shiftado = v_soma_final >>> 12;

                    if (v_resultado_shiftado > 40'sd32767)
                        saida <= 16'h7FFF;
                    else if (v_resultado_shiftado < -40'sd32768)
                        saida <= 16'h8000;
                    else
                        saida <= v_resultado_shiftado[15:0];

                    ativacao     <= 1'b1;
                    acumulador   <= 40'd0;
                end
                else begin
                    acumulador <= acumulador + mult_atual;
                    ativacao   <= 1'b0;
                end
            end
        end
    end
endmodule