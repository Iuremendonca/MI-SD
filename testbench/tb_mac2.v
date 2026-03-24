`timescale 1ns / 1ps

module tb_mac2();
    reg clk, rst_n, dado_valido, fim_neuronio;
    reg signed [15:0] pixel, peso, bias;
    wire signed [15:0] saida;
    wire dispositivo_pronto;

    // Instância do módulo [cite: 8]
    mac2 uut (
        .clk(clk), .rst_n(rst_n), .dado_valido(dado_valido),
        .fim_neuronio(fim_neuronio), .pixel(pixel), .peso(peso),
        .bias(bias), .saida(saida), .saida_valida(saida_valida)
    );

    always #10 clk = ~clk;

    initial begin
        // Reset inicial [cite: 9]
        clk = 0; rst_n = 0; dado_valido = 0; fim_neuronio = 0;
        pixel = 0; peso = 0; bias = 16'h1000; // Bias = 1.0 em Q4.12 (1 << 12)
        
        #45 rst_n = 1;

        // --- Teste 1: Acumular 2 valores ---
        // Pixel=2 * Peso=3 (6) + Pixel=4 * Peso=2 (8) = 14
        @(posedge clk);
        dado_valido = 1; pixel = 2; peso = 3;
        @(posedge clk);
        pixel = 4; peso = 2;
        
        // Finaliza neurônio e soma Bias
        @(posedge clk);
        fim_neuronio = 1; // No seu código, ele soma o último mult + bias aqui 
        pixel = 0; peso = 0; 
        
        @(posedge clk);
        dado_valido = 0; fim_neuronio = 0;
        
        #100;
        $display("Saida obtida: %h", saida);
        $stop;
    end
endmodule