//`timescale 1ns/1ps
//
//module tb_camada_oculta;
//
//    // ---------------------------------------------------------------
//    // Sinais do DUT
//    // ---------------------------------------------------------------
//    reg  clk;
//    reg  rst_n;
//    reg  start;
//    wire pronto;
//
//    // ---------------------------------------------------------------
//    // Instância do DUT
//    // ---------------------------------------------------------------
//    elm_top u_dut (
//        .clk   (clk),
//        .rst_n (rst_n),
//        .start (start),
//        .pronto(pronto)
//    );
//
//    // ---------------------------------------------------------------
//    // Clock: 10 ns → 100 MHz
//    // ---------------------------------------------------------------
//    initial clk = 0;
//    always #5 clk = ~clk;
//
//    // ---------------------------------------------------------------
//    // Tarefa de reset
//    // ---------------------------------------------------------------
//    task do_reset;
//        begin
//            rst_n = 1'b0;
//            start = 1'b0;
//            repeat(4) @(posedge clk);
//            #1;
//            rst_n = 1'b1;
//            @(posedge clk);
//        end
//    endtask
//
//    // ---------------------------------------------------------------
//    // Tarefa: pulsa start por 1 ciclo
//    // ---------------------------------------------------------------
//    task pulsa_start;
//        begin
//            @(posedge clk); #1;
//            start = 1'b1;
//            @(posedge clk); #1;
//            start = 1'b0;
//        end
//    endtask
//
//    // ---------------------------------------------------------------
//    // Tarefa: aguarda pronto com timeout
//    // ---------------------------------------------------------------
//    integer timeout;
//    task espera_pronto;
//        input integer max_ciclos;
//        begin
//            timeout = 0;
//            while (!pronto && timeout < max_ciclos) begin
//                @(posedge clk);
//                timeout = timeout + 1;
//            end
//            if (timeout >= max_ciclos)
//                $display("[ERRO] Timeout após %0d ciclos — pronto nunca subiu!", max_ciclos);
//            else
//                $display("[OK]   pronto subiu após %0d ciclos", timeout);
//        end
//    endtask
//
//    // ---------------------------------------------------------------
//    // Monitoramento dos sinais internos
//    // ---------------------------------------------------------------
//    wire        calcular      = u_dut.calcular;
//    wire        calcula_saida = u_dut.calcula_saida;
//    wire [2:0]  estado        = u_dut.estado;
//    wire        ativacao      = u_dut.ativacao;
//    wire        ultimo_neur   = u_dut.ultimo_neuronio;
//    wire [9:0]  addr_img      = u_dut.addr_img;
//    wire [16:0] addr_peso     = u_dut.addr_peso;
//    wire [6:0]  addr_bias     = u_dut.addr_bias;
//    wire [7:0]  dado_img      = u_dut.dado_img;
//    wire signed [15:0] dado_peso  = u_dut.dado_peso;
//    wire signed [15:0] dado_bias  = u_dut.dado_bias;
//    wire signed [15:0] h_saida    = u_dut.h_saida;
//    wire               h_valida   = u_dut.h_valida;
//    wire signed [15:0] h_ativado  = u_dut.h_ativado;
//
//    // ---------------------------------------------------------------
//    // Log a cada ciclo com ativacao ou h_valida ativos
//    // ---------------------------------------------------------------
//    always @(posedge clk) begin
//        if (calcular) begin
//            $display("T=%0t | estado=%0d | addr_img=%0d addr_peso=%0d addr_bias=%0d | dado_img=%0d dado_peso=%0d dado_bias=%0d | h_valida=%b h_saida=%0d | ativ=%b h_ativado=%0d | ult=%b",
//                $time, estado,
//                addr_img, addr_peso, addr_bias,
//                dado_img, dado_peso, dado_bias,
//                h_valida, h_saida,
//                ativacao, h_ativado,
//                ultimo_neur);
//        end
//    end
//
//    // ---------------------------------------------------------------
//    // Captura das saídas da camada oculta
//    // ---------------------------------------------------------------
//    integer neuronio_idx;
//    initial neuronio_idx = 0;
//
//    always @(posedge clk) begin
//        if (ativacao) begin
//            $display(">>> NEURONIO %0d: h_saida(raw)=%0d | h_ativado(sigmoid)=%0d  [Q4.12 → float≈%f]",
//                neuronio_idx,
//                h_saida,
//                h_ativado,
//                $itor(h_ativado) / 4096.0);
//            neuronio_idx = neuronio_idx + 1;
//        end
//    end
//
//    // ---------------------------------------------------------------
//    // Sequência principal de testes
//    // ---------------------------------------------------------------
//    initial begin
//        $display("======================================");
//        $display("  TESTBENCH elm_top — camada oculta  ");
//        $display("======================================");
//
//        // ----- Teste 1: operação normal -----
//        $display("\n--- Teste 1: reset + start normal ---");
//        do_reset;
//        pulsa_start;
//        espera_pronto(5000);
//
//        // verifica que pronto caiu no ciclo seguinte (FSM volta a REPOUSO)
//        @(posedge clk); #1;
//        if (!pronto)
//            $display("[OK]   pronto desceu corretamente");
//        else
//            $display("[AVISO] pronto ainda alto — verificar FSM");
//
//        // ----- Teste 2: segundo start sem reset (reuso) -----
//        $display("\n--- Teste 2: segundo start sem reset ---");
//        neuronio_idx = 0;
//        repeat(2) @(posedge clk);
//        pulsa_start;
//        espera_pronto(5000);
//
//        // ----- Teste 3: start durante execução deve ser ignorado -----
//        $display("\n--- Teste 3: start antecipado (deve ser ignorado) ---");
//        neuronio_idx = 0;
//        repeat(2) @(posedge clk);
//        @(posedge clk); #1; start = 1'b1;   // sobe start
//        repeat(3) @(posedge clk); #1;
//        start = 1'b0;                         // desce antes de pronto
//        espera_pronto(5000);
//
//        // ----- Teste 4: reset no meio da operação -----
//        $display("\n--- Teste 4: reset assíncrono durante cálculo ---");
//        neuronio_idx = 0;
//        repeat(2) @(posedge clk);
//        pulsa_start;
//        repeat(20) @(posedge clk);           // deixa rodar alguns ciclos
//        rst_n = 1'b0;
//        repeat(3) @(posedge clk);
//        rst_n = 1'b1;
//        $display("[INFO] reset aplicado — verificando recuperação");
//        // após reset, pronto não deve subir sozinho
//        repeat(10) @(posedge clk);
//        if (!pronto)
//            $display("[OK]   pronto continua baixo após reset — FSM em REPOUSO");
//        else
//            $display("[ERRO] pronto subiu sem start após reset!");
//
//        // novo start após reset
//        pulsa_start;
//        espera_pronto(5000);
//
//        $display("\n======================================");
//        $display("  Simulação encerrada                ");
//        $display("======================================");
//        $finish;
//    end
//
//    // ---------------------------------------------------------------
//    // Dump de formas de onda
//    // ---------------------------------------------------------------
//    initial begin
//        $dumpfile("tb_elm_top.vcd");
//        $dumpvars(0, tb_elm_top);
//    end
//
//endmodule