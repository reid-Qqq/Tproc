// dummy input feature fetch module

module i_feature_fetch(
input wire clk,
input wire rst,

input wire [127:0] i_data,
output reg [15:0] fetch_addr,
output reg read_data,

input wire feature_fetch_enable,
input wire [7:0] fetch_type,
input [15:0] src_addr,
input [7:0]  dst_addr,
input [7:0]  mem_sel,

input wire [7:0] feature_size,
// input wire feature_in_select,

output reg [14:0] wr_addr,
output wire [127:0] wr_data,
output wire wr_en,
output reg i_mem_select,
output reg fetch_done // this signal is used to inform the top_fsm for the accomplishment of data fetch
);      

// this module reads data from external memory to the on chip feature_in_memory  
// testing format for input fetch
// opcode | reg_1 | reg_2 | reg_3 | reg_4 | reg_5 | reg_6| reg_7|
// code   | f_type| saddrh| saddrl| daddrh| daddrl|memsel| null | 

reg [14:0] wr_addr_tmp;
reg i_mem_select_tmp;

always@(posedge clk) begin
    if(rst) begin
        i_mem_select <= 1'b0; 
        wr_addr <= 0;
    end
    else begin
        i_mem_select_tmp <= mem_sel[0];
        i_mem_select <= i_mem_select_tmp;
        wr_addr_tmp <= dst_addr;
        wr_addr <= wr_addr_tmp;
    end
end

/*
always@(posedge clk) begin
    if(rst) begin
        fetch_done <= 1'b0;
    end
    else begin
        if(wr_addr_tmp == 1) begin
            fetch_done <= 1'b1;
        end else begin
            fetch_done <= 1'b0;
        end
    end
end
*/

always@(posedge clk) begin
    if(rst) begin
        read_data <= 1'b0;
        fetch_addr <= 16'h0000;
    end else begin
        if (feature_fetch_enable) begin
            read_data <= 1'b1;
            fetch_addr <= src_addr;
        end
        else begin
            read_data <= 1'b0;
            fetch_addr <= 16'h0000;
        end
    end
end

reg feature_fetch_flag;
reg feature_fetch_tmp;
always@(posedge clk) begin
    feature_fetch_tmp <= feature_fetch_enable;
    feature_fetch_flag <= feature_fetch_tmp;
    fetch_done <= feature_fetch_flag; // TODO: improve with data ensure mechanism, make sure the feature data is access with ack signal
end

assign wr_data = i_data;
// assign wr_addr = dst_addr_reg;
assign wr_en = feature_fetch_flag;

endmodule


module i_weight_fetch #(
    parameter WEIGHT_BUFFER_DEPTH = 16,
    parameter WEIGHT_ADDR_OFFSET = 0
)(
    input wire clk,
    input wire rst,

    // instruction interface group
    input weight_fetch_enable,
    input scaler_fetch_enable,
    input [7:0] fetch_type,
    input [15:0] src_addr, // this will be defined by the parser, 
                                // which is the relative address of the weight data
    input [7:0]  dst_addr, // select destination buffer, optional for now

    // weight data input from DDR interface group
    input wire [63:0] w_data,
    output reg [31:0] rd_addr,
    output reg rd_en,

    // weight data output to on-chip buffer group
    output reg [7:0] wr_addr,
    output reg [63:0] wr_data,
    output wire wr_en,
    output wire wr_cs_weight,
    output wire wr_cs_scaler,

    output reg fetch_done  // execution ACK
);

reg [7:0] wr_addr_tmp;

always@(posedge clk) begin
    if(rst) begin
        wr_addr <= 8'h00;
    end
    else begin
        wr_addr_tmp <= dst_addr;
        wr_addr <= wr_addr_tmp;
    end
end

always@(posedge clk) begin
    if(rst) begin
        rd_en <= 1'b0;
        rd_addr <= 16'h0000;
    end else begin
        // if (weight_fetch_enable | scaler_fetch_enable) begin
        if (weight_fetch_enable | scaler_fetch_enable) begin            
            rd_en <= 1'b1;
            rd_addr <= src_addr + WEIGHT_ADDR_OFFSET;
        end
        else begin
            rd_en <= 1'b0;
            rd_addr <= 16'h0000;
        end
    end
end

reg weight_fetch_flag;
reg weight_fetch_tmp;
reg scaler_fetch_flag;
reg scaler_fetch_tmp;

always@(posedge clk) begin
    weight_fetch_tmp <= weight_fetch_enable;
    weight_fetch_flag <= weight_fetch_tmp;
    fetch_done <= weight_fetch_flag; // TODO: improve with data ensure mechanism, make sure the feature data is access with ack signal
    scaler_fetch_tmp <= scaler_fetch_enable;
    scaler_fetch_flag <= scaler_fetch_tmp;    
end

// assign wr_data = w_data;
always@(posedge clk) begin
    if(rst)begin
        wr_data <= 64'h0;
    end
    else begin
        wr_data <= w_data;
    end
end

assign wr_en = weight_fetch_flag | scaler_fetch_flag;
assign wr_cs_scaler = scaler_fetch_flag;
assign wr_cs_weight = weight_fetch_flag;

endmodule