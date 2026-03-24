`timescale 1ns / 1ps

module tb_contador_elm2();
    reg clk, rst_n, calcular;
    wire [9:0] x_addr;
    wire [16:0] w_addr;
    wire [6:0] neu;
    wire dado_valido, fim_neuronio, fim_camada;

    // Instância do módulo [cite: 1]
    contador_elm2 uut (
        .clk(clk), .rst_n(rst_n), .calcular(calcular),
        .x_addr(x_addr), .w_addr(w_addr),
        .dado_valido(dado_valido), .fim_neuronio(fim_neuronio), .fim_camada(fim_camada), .neuronio(neu)
    );

    always #10 clk = ~clk;

    initial begin
        clk = 0; rst_n = 0; calcular = 0;
        #45 rst_n = 1;
        #20 calcular = 1; // Começa a contar [cite: 4]
        
        // Espera chegar perto do fim do primeiro neurônio (784 pixels)
        repeat (780) @(posedge clk);
        
        // Aqui você observa se fim_neuronio sobe no pixel 783 [cite: 5]
        @(posedge fim_neuronio);
        $display("Neuronio 0 finalizado no tempo ");
        
        // Espera processar mais alguns e para
        repeat (1000) @(posedge clk);
        $stop;
    end
endmodule