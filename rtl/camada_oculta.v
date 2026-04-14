module camada_oculta (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        calcular,
    output reg         ultimo_neuronio,
    output reg  [9:0]  addr_img,
    output reg  [16:0] addr_peso,
    output reg  [6:0]  addr_bias,
    input  wire [7:0]         dado_img,
    input  wire signed [15:0] dado_peso,
    input  wire signed [15:0] dado_bias,
    output wire signed [15:0] h_saida,
	 output wire         ativacao

);

    // ---------------------------------------------------------------
    // Normalização: uint8 → Q4.12
    // ---------------------------------------------------------------
    wire signed [15:0] dado_img_norm;
    assign dado_img_norm = {4'b0000, dado_img[7:0], 4'b0000};

    // ---------------------------------------------------------------
    // Contadores
    // ---------------------------------------------------------------
    reg [9:0]  cnt_pixel;     // 0..20  (cicla por neurônio)
    reg [6:0]  cnt_neuronio;  // 0..2
    reg [16:0] cnt_peso;      // 0..62  (nunca reseta no meio, só no fim de tudo)

    wire fim_pixel      = (cnt_pixel    == 10'd783);
    wire fim_neuronio_w = (cnt_neuronio == 7'd127);

    // ---------------------------------------------------------------
    // Pipeline de 1 ciclo
    // ---------------------------------------------------------------
    reg calcular_d;
    reg fim_pixel_d;
    reg fim_ultimo_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            calcular_d   <= 1'b0;
            fim_pixel_d  <= 1'b0;
            fim_ultimo_d <= 1'b0;
        end else begin
            calcular_d   <= calcular;
            fim_pixel_d  <= fim_pixel & calcular;
            fim_ultimo_d <= fim_pixel & fim_neuronio_w & calcular;
        end
    end

    // ---------------------------------------------------------------
    // Contadores
    // ---------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_pixel       <= 10'd0;
            cnt_neuronio    <= 7'd0;
            cnt_peso        <= 17'd0;
            ultimo_neuronio <= 1'b0;
        end else if (calcular) begin
            ultimo_neuronio <= 1'b0;
            cnt_peso        <= cnt_peso + 17'd1; // avança sempre, sem reset parcial

            if (fim_pixel) begin
                cnt_pixel <= 10'd0;
                if (fim_neuronio_w) begin
                    cnt_neuronio    <= 7'd0;
                    cnt_peso        <= 17'd0;    // reseta só quando termina tudo
                    ultimo_neuronio <= 1'b1;
                end else begin
                    cnt_neuronio <= cnt_neuronio + 7'd1;
                end
            end else begin
                cnt_pixel <= cnt_pixel + 10'd1;
            end
        end else begin
            cnt_pixel       <= 10'd0;
            cnt_neuronio    <= 7'd0;
            cnt_peso        <= 17'd0;
            ultimo_neuronio <= 1'b0;
        end
    end

    // ---------------------------------------------------------------
    // Endereços — peso direto do contador acumulado
    // ---------------------------------------------------------------
    always @(*) begin
        addr_img   = cnt_pixel;
        addr_bias  = cnt_neuronio;
        addr_peso  = cnt_peso;      // ← simplesmente o contador, sem conta nenhuma
    end

    

    // ---------------------------------------------------------------
    // MAC
    // ---------------------------------------------------------------
    mac u_mac (
        .clk         (clk),
        .rst_n       (rst_n),
        .dado_valido (calcular_d),
        .fim_neuronio(fim_pixel_d),
		  .ultimo_neuronio(fim_ultimo_d),   // ← conecta aqui
        .valor       (dado_img_norm),
        .peso        (dado_peso),
        .bias        (dado_bias),
        .saida       (h_saida),
		  .ativacao    (ativacao)
    );

endmodule