module argmax (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        pronto,
    input  wire        clear,
    input  wire signed [15:0] y_in,
    input  wire        update_en,
    output reg  [3:0]  saida
);
    reg signed [15:0] max_val;
    reg [3:0]         final_digit;
    reg [3:0]         current_idx;     // ← contador interno

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            max_val     <= 16'h8000;
            final_digit <= 4'd0;
            saida       <= 4'd0;
            current_idx <= 4'd0;
        end
        else if (clear) begin
            max_val     <= 16'h8000;
            final_digit <= 4'd0;
            current_idx <= 4'd0;
        end
        else begin
            if (update_en) begin
                if (y_in > max_val) begin
                    max_val     <= y_in;
                    final_digit <= current_idx;
                end
                current_idx <= current_idx + 4'd1;  // incrementa a cada y válido
            end
            else if (pronto) begin
                saida <= final_digit;
            end
        end
    end

endmodule