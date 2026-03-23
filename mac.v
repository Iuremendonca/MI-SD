module mac (
    input  wire               clk,
    input  wire               reset,         
    input  wire               calcular,      // vem da FSM
    input  wire               ultimo_pixel,  // vem do contador (fim_pixels)
    input  wire signed [15:0] pixel,         // vem da RAM 
    input  wire signed [15:0] peso,          // vem da ROM
    input  wire signed [15:0] bias,          // vem da ROM
    output reg                incrementa,    // solicita próximo endereço ao contador
    output reg                ativacao,      // sinaliza à FSM que o neurônio terminou
    output reg  signed [15:0] saida          // resultado em Q4.12 para o módulo de ativação
);

    reg  signed [31:0] acumulador;
    wire signed [31:0] produto;

    assign produto = pixel * peso;  

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            acumulador <= 32'd0;
            saida      <= 16'd0;
            incrementa <= 1'b0;
            ativacao   <= 1'b0;
        end

        else if (ultimo_pixel && calcular) begin
            saida      <= (acumulador + produto + (bias << 12)) >>> 12;
            acumulador <= 32'd0;
            incrementa <= 1'b0;   // pede pra contador incrementar
            ativacao   <= 1'b1;   // pulso para a FSM
        end

        else if (calcular) begin
            acumulador <= acumulador + produto;
            incrementa <= 1'b1;
            ativacao   <= 1'b0;
        end

        else begin
            incrementa <= 1'b0;
            ativacao   <= 1'b0;
        end
    end

endmodule