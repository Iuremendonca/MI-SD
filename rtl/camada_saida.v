module camada_saida (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        calcula_saida,
    output reg         ultimo_neuronio,
    // Endereços para as RAMs
    output reg  [6:0]  addr_h,
    output reg  [10:0] addr_peso_saida,
    // Dados das RAMs
    input  wire signed [15:0] dado_h,
    input  wire signed [15:0] dado_peso_s,
    // Saída para argmax
    output wire signed [15:0] y_saida,
    output wire               y_valida    // pulso: y_saida pronto → argmax
);
    // ---------------------------------------------------------------
    // Contadores
    // ---------------------------------------------------------------
    reg [6:0]  cnt_h;
    reg [3:0]  cnt_classe;

    wire fim_h      = (cnt_h     == 7'd127);
    wire fim_classe = (cnt_classe == 4'd9);

    // ---------------------------------------------------------------
    // Pipeline de 1 ciclo
    // ---------------------------------------------------------------
    reg calcula_d;
    reg fim_h_d;
    reg fim_ultimo_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            calcula_d    <= 1'b0;
            fim_h_d      <= 1'b0;
            fim_ultimo_d <= 1'b0;
        end else begin
            calcula_d    <= calcula_saida;
            fim_h_d      <= fim_h & calcula_saida;
            fim_ultimo_d <= fim_h & fim_classe & calcula_saida;
        end
    end

    // ---------------------------------------------------------------
    // Contadores
    // ---------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_h           <= 7'd0;
            cnt_classe      <= 4'd0;
            ultimo_neuronio <= 1'b0;
        end else if (calcula_saida) begin
            ultimo_neuronio <= 1'b0;
            if (fim_h) begin
                cnt_h <= 7'd0;
                if (fim_classe) begin
                    cnt_classe      <= 4'd0;
                    ultimo_neuronio <= 1'b1;
                end else begin
                    cnt_classe <= cnt_classe + 4'd1;
                end
            end else begin
                cnt_h <= cnt_h + 7'd1;
            end
        end else begin
            cnt_h           <= 7'd0;
            cnt_classe      <= 4'd0;
            ultimo_neuronio <= 1'b0;
        end
    end

    // ---------------------------------------------------------------
    // Endereços (combinacional)
    // ---------------------------------------------------------------
    always @(*) begin
        addr_h          = cnt_h;
        addr_peso_saida = (cnt_h * 10) + cnt_classe;
    end

    // ---------------------------------------------------------------
    // MAC — bias = 0, y_valida pulsa quando classe pronta
    // y_saida vai direto pro argmax, sem sigmoid
    // ---------------------------------------------------------------
    mac u_mac_saida (
        .clk            (clk),
        .rst_n          (rst_n),
        .dado_valido    (calcula_d),
        .fim_neuronio   (fim_h_d),
        .ultimo_neuronio(fim_ultimo_d),
        .valor          (dado_h),
        .peso           (dado_peso_s),
        .bias           (16'sd0),
        .saida          (y_saida),   // Q4.12 → argmax
        .ativacao       (y_valida)   // pulso por classe → argmax
    );

endmodule