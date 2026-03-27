module argmax (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        pronto,
    input  wire        clear,
    input  wire signed [15:0] y_in,
    input  wire [3:0]  current_idx,
    input  wire        update_en,
    output reg  signed [3:0] saida
);
    reg signed [15:0] max_val;
    reg signed [3:0]  final_digit;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            max_val     <= 16'h8000;
            final_digit <= 4'd0;
            saida       <= 4'd0;
        end 
        else if (clear) begin
            max_val     <= 16'h8000;
            final_digit <= 4'd0;
            
        end 
        else if (update_en) begin
            if (y_in > max_val) begin
                max_val     <= y_in;
                final_digit <= current_idx;
            end
        end
        else if (pronto) begin
            saida <= final_digit;
        end
    end
endmodule