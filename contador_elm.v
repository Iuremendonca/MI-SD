module contador_elm(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        calcular,
    input  wire        calculo_saida,
    output reg [9:0]   x_addr,
    output reg [16:0]  w_addr,
    output reg         dado_valido,
    output reg         fim_neuronio,
    output reg         fim_camada,
    output reg [6:0]   neuronio
);
    reg [9:0]  cont_pi;
    reg [6:0]  cont_neu;
    reg [16:0] endereco;
    reg        atraso;

    wire ativo     = calcular || calculo_saida;
    wire [9:0] max_pi  = calcular ? 10'd783 : 10'd127;
    wire [6:0] max_neu = calcular ? 7'd127  : 7'd9;

    wire ultimo_pi  = (cont_pi  == max_pi);
    wire ultimo_neu = (cont_neu == max_neu);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cont_pi      <= 0;
            cont_neu     <= 0;
            endereco     <= 0;
            atraso       <= 0;
            dado_valido  <= 0;
            fim_neuronio <= 0;
            fim_camada   <= 0;
            x_addr       <= 0;
            w_addr       <= 0;
            neuronio     <= 0;
        end
        else if (ativo) begin
            atraso      <= 1;
            dado_valido <= atraso;

            x_addr   <= cont_pi;
            w_addr   <= endereco;
            neuronio <= cont_neu;          
            fim_neuronio <= ultimo_pi && atraso;
            fim_camada   <= ultimo_pi && ultimo_neu && atraso;

            if (ultimo_pi && ultimo_neu && atraso)
                endereco <= 0;
            else
                endereco <= endereco + 1;

            if (ultimo_pi) begin
                cont_pi  <= 0;
                cont_neu <= ultimo_neu ? 0 : cont_neu + 1;
            end else begin
                cont_pi  <= cont_pi + 1;
            end
        end
        else begin
            atraso       <= 0;
            dado_valido  <= 0;
            fim_neuronio <= 0;
            fim_camada   <= 0;
            cont_pi      <= 0;
            cont_neu     <= 0;
            endereco     <= 0;
        end
    end

endmodule