`timescale 1ns / 1ps

module tb_ativacao_sigmoide;
    reg  signed [15:0] d_in;
    wire signed [15:0] d_out;

    // Instancia o seu módulo
    ativacao_sigmoid uut (
        .d_in(d_in),
        .d_out(d_out)
    );

   reg [15:0] memoria_teste [0:999]; // Array para 1000 valores
integer i;

initial begin
    // Carrega o arquivo gerado pelo Python para a memória do simulador
    $readmemh("C:/Users/iure/Documents/iure/UEFS/MI- SISTEMAS DIGITAIS/testes pbl/mac_outputs_128.txt", memoria_teste);
    
    for (i = 0; i < 1000; i = i + 1) begin
        d_in = memoria_teste[i];
        #10; // Espera o tempo de propagação
        $display("In: %h | Out: %h", d_in, d_out);
    end
    $finish;
end
endmodule