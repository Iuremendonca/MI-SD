//`timescale 1ns/1ps
//
//module tb_camada_saida;
//
//    // -----------------------------------------------------------
//    // Sinais do DUT
//    // -----------------------------------------------------------
//    reg         clk;
//    reg         rst_n;
//    reg         calcula_saida;
//    wire        ultimo_neuronio;
//    wire [6:0]  addr_h;
//    wire [10:0] addr_peso_saida;
//    wire signed [15:0] y_saida;
//    wire               y_valida;
//
//    // -----------------------------------------------------------
//    // RAMs emuladas — Q4.12
//    //   h[0..2]       : neurônios ocultos
//    //   pesos[0..29]  : pesos da camada de saída
//    // -----------------------------------------------------------
//    reg signed [15:0] ram_h     [0:127];   // 7 bits de endereço
//    reg signed [15:0] ram_pesos [0:2047];  // 11 bits de endereço
//
//    reg signed [15:0] dado_h;
//    reg signed [15:0] dado_peso_s;
//
//    // Leitura combinacional com proteção de bounds
//    always @(*) begin
//        dado_h      = (addr_h < 7'd3)          ? ram_h[addr_h]           : 16'sd0;
//        dado_peso_s = (addr_peso_saida < 11'd30) ? ram_pesos[addr_peso_saida] : 16'sd0;
//    end
//
//    // -----------------------------------------------------------
//    // DUT
//    // -----------------------------------------------------------
//    camada_saida u_dut (
//        .clk            (clk),
//        .rst_n          (rst_n),
//        .calcula_saida  (calcula_saida),
//        .ultimo_neuronio(ultimo_neuronio),
//        .addr_h         (addr_h),
//        .addr_peso_saida(addr_peso_saida),
//        .dado_h         (dado_h),
//        .dado_peso_s    (dado_peso_s),
//        .y_saida        (y_saida),
//        .y_valida       (y_valida)
//    );
//
//    // -----------------------------------------------------------
//    // Sinais internos expostos para o ModelSim
//    // -----------------------------------------------------------
//    wire [1:0]  cnt_h        = u_dut.cnt_h;
//    wire [3:0]  cnt_classe   = u_dut.cnt_classe;
//    wire [10:0] cnt_peso     = u_dut.cnt_peso;
//    wire        calcula_d    = u_dut.calcula_d;
//    wire        fim_h_d      = u_dut.fim_h_d;
//    wire        fim_ultimo_d = u_dut.fim_ultimo_d;
//    wire signed [39:0] acumulador = u_dut.u_mac_saida.acumulador;
//
//    // -----------------------------------------------------------
//    // Clock 100 MHz
//    // -----------------------------------------------------------
//    initial clk = 0;
//    always #5 clk = ~clk;
//
//    // -----------------------------------------------------------
//    // Captura de saídas no $display
//    // -----------------------------------------------------------
//    integer classe_idx;
//    initial classe_idx = 0;
//
//    always @(posedge clk) begin
//        if (y_valida) begin
//            $display("[SAIDA] classe=%0d  raw=%0d  float=%f",
//                classe_idx, y_saida, $itor(y_saida)/4096.0);
//            classe_idx = classe_idx + 1;
//        end
//    end
//
//    // -----------------------------------------------------------
//    // Teste único: h={1.0, 2.0, 3.0}, pesos=0.5
//    //   Q4.12 → 1.0=4096, 2.0=8192, 3.0=12288, 0.5=2048
//    //   Esperado por classe: (1+2+3)*0.5 = 3.0 → raw=12288
//    // -----------------------------------------------------------
//    integer i;
//
//    initial begin
//        // Inicializa RAMs
//        for (i = 0; i < 128;  i = i+1) ram_h[i]     = 16'sd0;
//        for (i = 0; i < 2048; i = i+1) ram_pesos[i]  = 16'sd0;
//
//        // Carrega valores do teste
//        ram_h[0] = 16'sd4096;   // 1.0
//        ram_h[1] = 16'sd8192;   // 2.0
//        ram_h[2] = 16'sd12288;  // 3.0
//        for (i = 0; i < 30; i = i+1)
//            ram_pesos[i] = 16'sd2048;  // 0.5
//
//        // Reset
//        rst_n         = 1'b0;
//        calcula_saida = 1'b0;
//        repeat(4) @(posedge clk); #1;
//        rst_n = 1'b1;
//        @(posedge clk);
//
//        // Dispara cálculo
//        $display("[INFO] Iniciando calculo — esperado: 3.0 (12288) por classe");
//        calcula_saida = 1'b1;
//
//        // Aguarda ultimo_neuronio com timeout de 500 ciclos
//        begin : wait_fim
//            integer t;
//            for (t = 0; t < 500; t = t+1) begin
//                @(posedge clk);
//                if (ultimo_neuronio) begin
//                    $display("[OK] ultimo_neuronio subiu apos %0d ciclos", t+1);
//                    disable wait_fim;
//                end
//            end
//            $display("[ERRO] Timeout — ultimo_neuronio nao subiu!");
//        end
//
//        @(posedge clk); #1;
//        calcula_saida = 1'b0;
//        repeat(5) @(posedge clk);
//
//        $display("[INFO] Simulacao encerrada — %0d classes capturadas", classe_idx);
//        $finish;
//    end
//
//    // -----------------------------------------------------------
//    // Dump VCD
//    // -----------------------------------------------------------
//    initial begin
//        $dumpfile("tb_camada_saida.vcd");
//        $dumpvars(0, tb_camada_saida);
//    end
//
//endmodule