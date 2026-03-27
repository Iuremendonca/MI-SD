module contador_elm (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        calcular,
    input  wire        calculo_saida,
    output reg  [9:0]  x_addr,
    output reg  [16:0] w_addr,
    output reg         dado_valido,
    output reg         fim_neuronio,
    output reg         fim_camada,
    output reg  [6:0]  neuronio
);
    reg [9:0]  cont_pi;
    reg [6:0]  cont_neu;
    reg [16:0] endereco;

    wire ativo     = calcular || calculo_saida;
    wire [9:0] max_pi  = calcular ? 10'd783 : 10'd127;
    wire [6:0] max_neu = calcular ? 7'd127  : 7'd9;
    wire ultimo_pi  = (cont_pi  == max_pi);
    wire ultimo_neu = (cont_neu == max_neu);

    // próximos valores combinacionais
    wire [9:0]  prox_pi  = ultimo_pi  ? 10'd0 : cont_pi  + 10'd1;
    wire [6:0]  prox_neu = ultimo_neu ? 7'd0  : cont_neu + 7'd1;
    wire [16:0] prox_end = endereco + 17'd1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cont_pi      <= 10'd0;
            cont_neu     <= 7'd0;
            endereco     <= 17'd0;
            dado_valido  <= 1'b0;
            fim_neuronio <= 1'b0;
            fim_camada   <= 1'b0;
            x_addr       <= 10'd0;
            w_addr       <= 17'd0;
            neuronio     <= 7'd0;
        end
        else if (ativo) begin
            // Apresenta endereço ATUAL à BRAM
            x_addr   <= cont_pi;
            w_addr   <= endereco;
            neuronio <= cont_neu;

            // dado_valido: válido desde o primeiro ciclo ativo
            // (BRAM responde no ciclo seguinte — alinhado com x_addr/w_addr do ciclo anterior)
            dado_valido  <= ativo;   // sempre 1 enquanto ativo, sem pipeline extra

            // fim flags baseadas no endereço QUE A BRAM VAI RESPONDER
            // ou seja, do ciclo ANTERIOR — cont_pi antes do incremento
            fim_neuronio <= ultimo_pi;
            fim_camada   <= ultimo_pi && ultimo_neu;

            // Incrementa contadores para próximo ciclo
            if (ultimo_pi) begin
                cont_pi  <= 10'd0;
                cont_neu <= ultimo_neu ? 7'd0 : prox_neu;
            end else begin
                cont_pi  <= prox_pi;
            end
            endereco <= prox_end;
        end
        else begin
            dado_valido  <= 1'b0;
				fim_neuronio <= 1'b0;
            // fim_neuronio e fim_camada mantêm valor para FSM ler
        end
    end
endmodule