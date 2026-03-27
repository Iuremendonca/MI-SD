`timescale 1ns/1ps

// =============================================================
//  RAMs e ROMs FICTÍCIAS — latência 1 ciclo (comportamento BRAM)
//  Valores constantes para simplificar verificação
// =============================================================

// ROM Pesos: retorna sempre 0x0100 (= 1.0 em Q4.12)
module rom_pesos (
    input  wire [16:0] address,
    input  wire        clock,
    input  wire        rden,
    output reg  [15:0] q
);
    always @(posedge clock)
        q <= rden ? 16'h0100 : 16'h0000;
endmodule

// ROM Bias: retorna sempre 0x0000
module rom_bias (
    input  wire [6:0]  address,
    input  wire        clock,
    input  wire        rden,
    output reg  [15:0] q
);
    always @(posedge clock)
        q <= rden ? 16'h0000 : 16'h0000;
endmodule

// ROM Beta (pesos camada de saída): retorna sempre 0x0100
module rom_beta (
    input  wire [10:0] address,
    input  wire        clock,
    input  wire        rden,
    output reg  [15:0] q
);
    always @(posedge clock)
        q <= rden ? 16'h0100 : 16'h0000;
endmodule

// RAM Imagem: todos os pixels = 0x0800 (0.5 em Q4.12)
module ram_imagem (
    input  wire [9:0]  address,
    input  wire        clock,
    input  wire [15:0] data,
    input  wire        rden,
    input  wire        wren,
    output reg  [15:0] q
);
    always @(posedge clock)
        q <= rden ? 16'h0800 : 16'h0000;
endmodule

// RAM Neurônios Ativos: escrita real, leitura com 1 ciclo de latência
module ram_neuronios_ativos (
    input  wire [6:0]  address,
    input  wire        clock,
    input  wire [15:0] data,
    input  wire        rden,
    input  wire        wren,
    output reg  [15:0] q
);
    reg [15:0] mem [0:127];
    integer i;
    initial for (i = 0; i < 128; i = i + 1) mem[i] = 16'h0000;

    always @(posedge clock) begin
        if (wren) mem[address] <= data;
        if (rden) q <= mem[address];
    end
endmodule

// =============================================================
//  TESTBENCH PRINCIPAL
// =============================================================
module top_pbl_tb;

// ----- Clock e reset -----
reg clk, rst_n, start;
initial clk = 0;
always #5 clk = ~clk;  // período = 10 ns

// ----- Saída final -----
wire [3:0] saida;

// ----- Instância do top level -----
ondeamagicaacontece_ounao dut (
    .clk   (clk),
    .rst_n (rst_n),
    .start (start),
    .estado(3'b0),   // não usado pelo DUT (internal wire westado)
    .saida (saida)
);

// ----- Acesso interno para monitoramento (hierarquia de sinais) -----
// Verilog permite $monitor em sinais internos via nome hierárquico
wire [2:0] st          = dut.westado;
wire       calcular    = dut.wcalcula;
wire       calcula_s   = dut.wcalcula_saida;
wire       pronto      = dut.wpronto;
wire [6:0] neuronio    = dut.windice_classe;
wire       fim_camada  = dut.wfim_camada;
wire       fim_pixel   = dut.wfim_pixel;
wire       atv_valida  = dut.wativacao_valida;
wire       atv_conc    = dut.wativacao_concluida;
wire [9:0] x_addr      = dut.wx_addr;
wire [16:0] w_addr     = dut.ww_addr;
wire       dado_val    = dut.wdado_val;

// ----- Nomes de estado -----
function [127:0] nome_st;
    input [2:0] s;
    begin
        case (s)
            3'd0: nome_st = "REPOUSO    ";
            3'd1: nome_st = "CALC_OCULTO";
            3'd2: nome_st = "ATIVACAO   ";
            3'd3: nome_st = "CALC_SAIDA ";
            3'd4: nome_st = "FIM        ";
            default: nome_st = "???        ";
        endcase
    end
endfunction

// ----- Contadores de verificação -----
integer ciclos_oculto, ciclos_saida;
integer neu_oculto_cnt, neu_saida_cnt;
integer erros;

// ----- Monitor de mudança de estado -----
reg [2:0] st_ant;
initial st_ant = 3'bx;
always @(posedge clk)
    if (st !== st_ant) begin
        $display("[%8t ns]  Estado: %-11s → %-11s",
                 $time, nome_st(st_ant), nome_st(st));
        st_ant <= st;
    end

// ----- Contador de ciclos ativos -----
always @(posedge clk) begin
    if (calcular)  ciclos_oculto = ciclos_oculto + 1;
    if (calcula_s) ciclos_saida  = ciclos_saida  + 1;
end

// ----- Monitor: fim de neurônio -----
always @(posedge clk) begin
    if (dado_val && fim_pixel) begin
        if (calcular) begin
            neu_oculto_cnt = neu_oculto_cnt + 1;
            if (neuronio % 32 == 0)  // imprime a cada 32 para não encher o log
                $display("[%8t ns]  [OCULTO] neurônio %0d/127 concluído",
                         $time, neuronio);
        end else if (calcula_s) begin
            neu_saida_cnt = neu_saida_cnt + 1;
            $display("[%8t ns]  [SAIDA ] neurônio %0d/9 concluído",
                     $time, neuronio);
        end
    end
end

// ----- Monitor: ativacao_concluida -----
always @(posedge clk)
    if (atv_conc)
        $display("[%8t ns]  [SIGM  ] ativacao_concluida=1 (neurônio %0d)",
                 $time, neuronio);

// ----- Monitor: fim de camada -----
always @(posedge clk)
    if (dado_val && fim_camada)
        $display("[%8t ns]  *** FIM CAMADA (st=%0d) ***", $time, st);

// ----- Monitor: pronto -----
always @(posedge clk)
    if (pronto)
        $display("[%8t ns]  *** PRONTO — saida=%0d ***", $time, saida);

// =============================================================
//  FLUXO PRINCIPAL
// =============================================================
initial begin
    $display("=============================================================");
    $display("  TESTBENCH INTEGRADO — RAMs/ROMs fictícias c/ latência 1 clk");
    $display("=============================================================\n");

    ciclos_oculto  = 0;
    ciclos_saida   = 0;
    neu_oculto_cnt = 0;
    neu_saida_cnt  = 0;
    erros          = 0;
    rst_n = 0;
    start = 0;

    // Reset ativo por 4 ciclos
    repeat(4) @(posedge clk);
    rst_n = 1;
    repeat(2) @(posedge clk);

    // Pulso de start (1 ciclo)
    $display("[%8t ns]  → START\n", $time);
    start = 1;
    @(posedge clk);
    start = 0;

    // Aguarda inferência completar
    // O sigmoid interno (ativacao_sigmoid) já produz ativacao_concluida
    // automaticamente 1 ciclo após ativacao — sem intervenção do TB.
    wait (pronto === 1'b1);
    repeat(5) @(posedge clk);

    // =============================================================
    //  RELATÓRIO
    // =============================================================
    $display("\n=============================================================");
    $display("  RELATÓRIO FINAL");
    $display("=============================================================");
    $display("  Neurônios ocultos  concluídos : %0d  (esperado: 128)", neu_oculto_cnt);
    $display("  Neurônios de saída concluídos : %0d  (esperado:  10)", neu_saida_cnt);
    $display("  Ciclos ativos  camada oculta  : %0d  (esperado: %0d)", ciclos_oculto, 128*784);
    $display("  Ciclos ativos  camada saída   : %0d  (esperado: %0d)", ciclos_saida,  10*128);

    if (neu_oculto_cnt !== 128) begin
        $display("  [ERRO] Neurônios ocultos incorretos!");
        erros = erros + 1;
    end
    if (neu_saida_cnt !== 10) begin
        $display("  [ERRO] Neurônios de saída incorretos!");
        erros = erros + 1;
    end
    if (ciclos_oculto !== 128*784) begin
        $display("  [AVISO] Ciclos oculto divergem do esperado.");
        erros = erros + 1;
    end
    if (ciclos_saida !== 10*128) begin
        $display("  [AVISO] Ciclos saída divergem do esperado.");
        erros = erros + 1;
    end

    if (erros == 0)
        $display("\n  [OK] Todos os checks passaram. Saída classificada: %0d", saida);
    else
        $display("\n  [FALHA] %0d erro(s) encontrado(s).", erros);

    $display("=============================================================\n");
    $finish;
end

// Timeout de segurança
initial begin
    #500_000_000;  // 500 ms simulados
    $display("[TIMEOUT] Simulação excedeu o limite!");
    $finish;
end

endmodule