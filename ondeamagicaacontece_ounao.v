module ondeamagicaacontece_ounao (
    input  wire        clk, rst_n, start,
    input  [2:0]       estado,
    output [3:0]       saida 
);

    // --- DECLARAÇÕES DE FIOS ---
    wire wfim_camada;
    wire wfim_pixel;
    wire wativacao_valida;
    wire wativacao_concluida;
    wire wcalcula;
    wire wcalcula_saida;
    wire [2:0]  westado;
    wire [9:0]  wpixel;
    wire [16:0] wpeso;
    wire        wdado_val;
    wire [15:0] wsomabruta;
    wire [15:0] wsaida_mac;
    wire [15:0] wscore;
    wire [6:0]  windice_classe;
    wire        wpronto;
    
    // endereços vindos do contador
    wire [9:0]  wx_addr;   // endereço da imagem  
    wire [16:0] ww_addr;   // endereço dos pesos 

    // dados lidos das memórias
    wire [15:0] wpixel_data;   // imagem - mac
    wire [15:0] wpeso_data;    // rom_pesos - mac
    wire [15:0] wbias_data;    // bias - mac
    wire [15:0] wativacao_data;// neurônios ativos - mac (camada de saída)

    // Nova fiação para os pesos
    wire [15:0] wbeta_data;
    wire [15:0] wpeso_final;

    // RAM Neurônios Ativos  (escrita pela ativação, leitura pelo mac)
    wire wativacao_wren;                     // escrita quando ativação conclui
    wire [6:0] wativacao_waddr;              // endereço de escrita = neurônio que acabou
    wire [15:0] wativacao_dout;              // dado saindo do bloco de ativação

    // --- ATRIBUIÇÕES (LOGICA COMBINACIONAL) ---
    // endereço de bias: índice do neurônio atual
    wire [6:0]  wbias_addr    = windice_classe;          
    wire [6:0]  wneuronio_addr = windice_classe;
     
    // dado que entra no mac:
    wire [15:0] wentrada_mac = (westado == 3'd1) ? wpixel_data : wativacao_data;
     
    // mux saída do mac
    assign wsomabruta = (westado == 3'd1) ? wsaida_mac : 16'b0;
    assign wscore     = (westado == 3'd3) ? wsaida_mac : 16'b0;

    // update_en e clear do argmax
    wire w_argmax_update_en = wativacao_valida && (westado == 3'd3);
    wire w_clear_argmax     = (wfim_camada    && (westado == 3'd1));

    // MUX para decidir qual peso o MAC vai usar
    assign wpeso_final = (westado == 3'd3) ? wbeta_data : wpeso_data;

    assign wativacao_wren  = wativacao_concluida && (westado == 3'd1);
    assign wativacao_waddr = windice_classe;

    // --- INSTANCIAÇÕES ---

    // Instância da nova ROM
    rom_beta beta_inst (
        .address (ww_addr[10:0]), // O endereço de Beta é menor (1280 posições)
        .clock   (clk),
        .rden    (westado == 3'd3),
        .q       (wbeta_data)
    );

    // FSM
    fsm_elm fsm_inst (
        .clk                (clk),
        .rst_n              (rst_n),
        .start              (start),
        .ultimo_neuronio    (wfim_camada),
        .ativacao           (wativacao_valida),
        .ativacao_concluida (wativacao_concluida),
        .pronto             (wpronto),
        .calcular           (wcalcula),
        .calcula_saida      (wcalcula_saida),
        .estado             (westado)
    );

    // Contador
    contador_elm cont_inst (
        .clk           (clk),
        .rst_n         (rst_n),
        .calcular      (wcalcula),
        .calculo_saida (wcalcula_saida),
        .x_addr        (wx_addr),       //  ram imagem
        .w_addr        (ww_addr),       //  rom pesos
        .dado_valido   (wdado_val),
        .fim_neuronio  (wfim_pixel),
        .fim_camada    (wfim_camada),
        .neuronio      (windice_classe)
    );

    // ROM Pesos 
    rom_pesos rom_pesos_inst (
        .address (ww_addr),
        .clock   (clk),
        .rden    (1'b1),
        .q       (wpeso_data)
    );

    // ROM Bias  
    rom_bias bias_inst (
        .address (wbias_addr),
        .clock   (clk),
        .rden    (westado == 3'd1 ? 1'b1:1'b0),
        .q       (wbias_data)
    );

    // RAM Imagem  
    ram_imagem imagem_inst (
        .address (wx_addr),
        .clock   (clk),
        .data    (16'b0),   
        .rden    (1'b1),
        .wren    (1'b0),
        .q       (wpixel_data)
    );

    ram_neuronios_ativos neuronio_ram_inst (
        .address (westado == 3'd1 ? wativacao_waddr  // escrita: índice do neurônio oculto
                                  : wneuronio_addr), // leitura: índice do neurônio de saída
        .clock   (clk),
        .data    (wativacao_dout),  // dado vindo do sigmoid
        .rden    (westado == 3'd3), // lê só na camada de saída
        .wren    (wativacao_wren),  // escreve só na camada oculta
        .q       (wativacao_data)   //  mac na camada de saída
    );

    // Ativação Sigmoid
    ativacao_sigmoid sigmoid_inst (
           .clk           (clk),
        .rst_n         (rst_n),
        .d_in               (wsomabruta),
        .ativacao           (wativacao_valida),
        .d_out              (wativacao_dout),       // am neurônios ativos
        .ativacao_concluida (wativacao_concluida)
    );

    // MAC atualizado
    mac mac_inst (
        .clk          (clk),
        .rst_n        (rst_n),
        .dado_valido  (wdado_val),
        .fim_neuronio (wfim_pixel),
        .pixel        (wentrada_mac), 
        .peso         (wpeso_final),  // <-- Agora usa o peso correto por estado
        .bias         (westado == 3'd1 ? wbias_data : 16'b0), 
        .saida        (wsaida_mac),
        .saida_valida (wativacao_valida)
    );

    // Argmax
    argmax argmax_inst (
        .clk         (clk),
        .rst_n       (rst_n),
        .pronto      (wpronto),
        .clear       (w_clear_argmax),
        .y_in        (wscore),
        .current_idx (windice_classe[3:0]),
        .update_en   (w_argmax_update_en),
        .saida       (saida)
    );

endmodule