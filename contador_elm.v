module contador_elm (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        incrementa,      // vem da MAC
    output wire [9:0]  conta_pixel,     // endereço da RAM
    output wire [6:0]  conta_neuronio,  // endereço da ROM
    output wire        fim_pixels,      // vai para a MAC (ultimo_pixel)
    output wire        fim_neuronios    // vai para a FSM (ultimo_neuronio)
);

    reg [9:0] p_reg;
    reg [6:0] n_reg;

    localparam [9:0] MAX_P = 10'd783;  
    localparam [6:0] MAX_N = 7'd127;   

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            p_reg <= 10'd0;
            n_reg <= 7'd0;
        end else if (incrementa) begin
            if (p_reg == MAX_P) begin
                p_reg <= 10'd0;
                if (n_reg == MAX_N)
                    n_reg <= 7'd0;   
                else
                    n_reg <= n_reg + 7'd1;
            end else begin
                p_reg <= p_reg + 10'd1;
            end
        end
    end

    assign conta_pixel    = p_reg;
    assign conta_neuronio = n_reg;

    assign fim_pixels   = (p_reg == MAX_P);
    assign fim_neuronios = (n_reg == MAX_N) && (p_reg == MAX_P);

endmodule