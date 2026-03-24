`timescale 1ns / 1ps

module tb_elm_file();
    reg clk;
    reg rst_n;
    reg calcular;

    // Conexões internas
    wire [9:0]  x_addr;
    wire [16:0] w_addr;
    wire [6:0]  cont_neu;
    wire        dado_valido, fim_neuronio, fim_camada;
    wire signed [15:0] saida_mac;
    wire        saida_valida;

    // Memórias de Simulação (Arrays)
    reg [15:0] ram_pixels [0:1023];   // Para os 784 pixels
    reg [15:0] ram_pesos  [0:131071]; // Para pesos (784 * 128)
    reg [15:0] ram_bias   [0:127];    // Memória para os BIAS

    // 1. Instância do Contador
    contador_elm2 u_contador (
        .clk(clk),
        .rst_n(rst_n),
        .calcular(calcular),
        .x_addr(x_addr),
        .w_addr(w_addr),
        .dado_valido(dado_valido),
        .fim_neuronio(fim_neuronio),
        .fim_camada(fim_camada), .neuronio(cont_neu)
    );

    // 2. Instância do MAC
    // O bias agora é injetado dinamicamente baseado no neurónio atual (cont_neu)
    mac2 u_mac (
        .clk(clk),
        .rst_n(rst_n),
        .dado_valido(dado_valido),
        .fim_neuronio(fim_neuronio),
        .pixel(ram_pixels[x_addr]),
        .peso(ram_pesos[w_addr]),
        .bias(ram_bias[cont_neu]), // <--- BIAS DINÂMICO AQUI
        .saida(saida_mac),
        .saida_valida(saida_valida)
    );

    // Gerador de Clock (50MHz)
    always #10 clk = ~clk;

    initial begin
        // Carregar dados dos ficheiros
        $readmemh("C:/Users/iure/Documents/iure/UEFS/MI- SISTEMAS DIGITAIS/testes pbl/pixels.txt", ram_pixels);
        $readmemh("C:/Users/iure/Documents/iure/UEFS/MI- SISTEMAS DIGITAIS/testes pbl/pesos.txt",  ram_pesos);
        $readmemh("C:/Users/iure/Documents/iure/UEFS/MI- SISTEMAS DIGITAIS/testes pbl/bias.txt",   ram_bias);

        // Inicialização
        clk = 0;
        rst_n = 0;
        calcular = 0;

        #50 rst_n = 1;
        #20 calcular = 1;

        // Monitor de resultados
        $display("Iniciando processamento da camada ELM...");
        
        forever begin
            @(posedge clk);
            if (saida_valida) begin
                $display("Neuronio %d | Saida: %h", cont_neu, saida_mac);
            end
            
            if (fim_camada) begin
                $display("Processamento da camada concluído!");
                #100 $stop;
            end
        end
    end

endmodule