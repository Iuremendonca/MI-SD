`timescale 1ns/1ps

module tb_elm_top;

    // ---------------------------------------------------------------
    // Sinais do DUT
    // ---------------------------------------------------------------
    reg  clk;
    reg  rst_n;
    reg  start;
    wire pronto;

    // ---------------------------------------------------------------
    // Instância do DUT
    // ---------------------------------------------------------------
    elm_top u_dut (
        .clk   (clk),
        .rst_n (rst_n),
        .start (start),
        .pronto(pronto)
    );

    // ---------------------------------------------------------------
    // Clock: 10 ns → 100 MHz
    // ---------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // ---------------------------------------------------------------
    // Tarefa de reset
    // ---------------------------------------------------------------
    task do_reset;
        begin
            rst_n = 1'b0;
            start = 1'b0;
            repeat(4) @(posedge clk);
            #1;
            rst_n = 1'b1;
            @(posedge clk);
        end
    endtask

    // ---------------------------------------------------------------
    // Tarefa: pulsa start por 1 ciclo
    // ---------------------------------------------------------------
    task pulsa_start;
        begin
            @(posedge clk); #1;
            start = 1'b1;
            @(posedge clk); #1;
            start = 1'b0;
        end
    endtask

    // ---------------------------------------------------------------
    // Sinais internos - FSM / camada oculta
    // ---------------------------------------------------------------
    wire        calcular      = u_dut.calcular;
    wire        calcula_saida = u_dut.calcula_saida;
    wire [2:0]  estado        = u_dut.estado;
    wire        ativacao      = u_dut.ativacao;
    wire        ultimo_neur   = u_dut.u_oculta.ultimo_neuronio;
    wire [9:0]  addr_img      = u_dut.addr_img;
    wire [16:0] addr_peso     = u_dut.addr_peso;
    wire [6:0]  addr_bias     = u_dut.addr_bias;
    wire [7:0]  dado_img      = u_dut.dado_img;
    wire signed [15:0] dado_peso  = u_dut.dado_peso;
    wire signed [15:0] dado_bias  = u_dut.dado_bias;
    wire signed [15:0] h_saida    = u_dut.h_saida;
    wire        h_valida          = u_dut.ativacao;
    wire signed [15:0] h_ativado  = u_dut.h_ativado;

    // ---------------------------------------------------------------
    // Sinais internos do MAC e pipeline da camada oculta
    // ---------------------------------------------------------------
    wire        calcular_d_sig   = u_dut.u_oculta.calcular_d;
    wire        dado_valido_mac  = u_dut.u_oculta.u_mac.dado_valido;
    wire        fim_neuronio_mac = u_dut.u_oculta.u_mac.fim_neuronio;
    wire signed [39:0] acumulador_mac = u_dut.u_oculta.u_mac.acumulador;

    // ---------------------------------------------------------------
    // Sinais internos - Camada de Saída
    // ---------------------------------------------------------------
    wire [6:0]  addr_h          = u_dut.addr_h;
    wire [10:0] addr_peso_saida = u_dut.addr_peso_saida;
    wire signed [15:0] dado_h       = u_dut.dado_neuronio;
    wire signed [15:0] dado_peso_s  = u_dut.dado_peso_s;
    wire signed [15:0] y_saida      = u_dut.y_saida;
    wire               y_valida     = u_dut.y_valida;
    wire               ult_saida    = u_dut.u_saida.ultimo_neuronio;
    wire [6:0]         cnt_h_saida  = u_dut.u_saida.cnt_h;       // ✅ 7 bits
    wire [3:0]         cnt_classe   = u_dut.u_saida.cnt_classe;
    wire        calcula_d_saida     = u_dut.u_saida.calcula_d;
    wire        fim_h_d_saida       = u_dut.u_saida.fim_h_d;
    wire        fim_ultimo_d_saida  = u_dut.u_saida.fim_ultimo_d;
    wire        dado_valido_mac_s   = u_dut.u_saida.u_mac_saida.dado_valido;
    wire        fim_neuronio_mac_s  = u_dut.u_saida.u_mac_saida.fim_neuronio;
    wire signed [39:0] acum_mac_s   = u_dut.u_saida.u_mac_saida.acumulador;
    wire [3:0]  resultado           = u_dut.resultado;

    // ---------------------------------------------------------------
    // Log ciclo a ciclo — Camada Oculta
    // ---------------------------------------------------------------
    always @(posedge clk) begin
        if (calcular) begin
            $display("T=%0t | est=%0d | img=%0d pw=%0d bs=%0d | dimg=%0d dpeso=%0d dbias=%0d | calc_d=%b dv=%b fim=%b | acum=%0d | hval=%b hsa=%0d | ativ=%b hat=%0d(%f) | ult=%b",
                $time, estado,
                addr_img, addr_peso, addr_bias,
                dado_img, dado_peso, dado_bias,
                calcular_d_sig, dado_valido_mac, fim_neuronio_mac,
                acumulador_mac,
                h_valida, h_saida,
                ativacao, h_ativado, $itor(h_ativado)/4096.0,
                ultimo_neur);
        end
    end

    // ---------------------------------------------------------------
    // Log ciclo a ciclo — Camada de Saída
    // ---------------------------------------------------------------
    always @(posedge clk) begin
        if (calcula_saida) begin
            $display("T=%0t [SAIDA] cls=%0d cnt_h=%0d | addr_h=%0d addr_pw=%0d | dh=%0d dpw=%0d | cd=%b fhd=%b fuld=%b | dv=%b fim=%b | acum=%0d | yval=%b ysa=%0d(%f) | ult=%b",
                $time,
                cnt_classe, cnt_h_saida, 
                addr_h, addr_peso_saida,
                dado_h, dado_peso_s,
                calcula_d_saida, fim_h_d_saida, fim_ultimo_d_saida,
                dado_valido_mac_s, fim_neuronio_mac_s,
                acum_mac_s,
                y_valida, y_saida, $itor(y_saida)/4096.0,
                ult_saida);
        end
    end

    // ---------------------------------------------------------------
    // Captura das saídas da camada oculta
    // ---------------------------------------------------------------
    integer neuronio_idx;
    initial neuronio_idx = 0;

    always @(posedge clk) begin
        if (ativacao) begin
            $display(">>> NEURONIO %0d: h_saida(raw)=%0d | h_ativado=%0d [≈%f]",
                neuronio_idx, h_saida, h_ativado,
                $itor(h_ativado)/4096.0);
            neuronio_idx = neuronio_idx + 1;
        end
    end

    // ---------------------------------------------------------------
    // Captura das saídas da camada de saída (y por classe)
    // ---------------------------------------------------------------
    integer classe_idx;
    initial classe_idx = 0;

    always @(posedge clk) begin
        if (y_valida) begin
            $display(">>> CLASSE %0d: y_saida(raw)=%0d [≈%f]",
                classe_idx, y_saida, $itor(y_saida)/4096.0);
            classe_idx = classe_idx + 1;
        end
    end

    // ---------------------------------------------------------------
    // Captura do resultado final (argmax)
    // ---------------------------------------------------------------
    always @(posedge clk) begin
        if (pronto) begin
            $display(">>> RESULTADO ARGMAX = %0d", resultado);
        end
    end

    // ---------------------------------------------------------------
    // Sequência principal de testes
    // ---------------------------------------------------------------
    initial begin
        $display("======================================");
        $display("  TESTBENCH elm_top                  ");
        $display("======================================");

        do_reset;
        pulsa_start;

        wait(pronto);
        $display("[OK] pronto subiu!");

        @(posedge clk); #1;
        if (!pronto)
            $display("[OK]   pronto desceu corretamente");
        else
            $display("[AVISO] pronto ainda alto — verificar FSM");

        $display("\n======================================");
        $display("  Simulação encerrada                ");
        $display("======================================");
        $finish;
    end

    // ---------------------------------------------------------------
    // Dump de formas de onda
    // ---------------------------------------------------------------
    initial begin
        $dumpfile("tb_elm_top.vcd");
        $dumpvars(0, tb_elm_top);
    end

endmodule