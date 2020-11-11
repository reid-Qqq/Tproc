// configurable adder path
// CONV/DWCONV/PWCONV are achieved with different data path configuration
// Tm should always larger than Tn

`include "network_para.vh"

module configurable_data_path #(
    parameter Tn = `Tn,
    parameter FEATURE_WIDTH = `FEATURE_WIDTH,
    parameter KERNEL_SIZE = `KERNEL_SIZE,
    parameter KERNEL_WIDTH = `KERNEL_WIDTH,
    parameter SCALER_WIDTH = `SCALER_WIDTH,
    parameter Tm = `Tm
) (
    input wire clk,
    input wire rst,
    input wire [7:0] com_type,
    input wire [7:0] kernel_size,

    input wire virtical_reg_shift,
    input wire virreg_input_sel, // from instruction decoder
    output wire virreg_to_fmem_0, 
    output wire virreg_to_fmem_1,
    input wire [Tn*FEATURE_WIDTH*KERNEL_SIZE*KERNEL_SIZE - 1 : 0] feature_mem_read_data_0,
    input wire [Tn*FEATURE_WIDTH*KERNEL_SIZE*KERNEL_SIZE - 1 : 0] feature_mem_read_data_1,
    output wire shift_done_from_virreg,

    input wire [Tn*KERNEL_SIZE*KERNEL_SIZE*KERNEL_WIDTH-1 : 0] weight_wire,
    output wire weight_read_en,
    
    input wire [15 : 0] scaler_data,
    output wire [Tm* FEATURE_WIDTH + SCALER_WIDTH-1 : 0] scaled_feature_output
);

// wire shift_done_from_virreg;
// assign shift_done_from_virreg = shift_done_from_virreg;

genvar i, j;

wire virreg_to_fmem_0;
wire virreg_to_fmem_1;
wire [Tn*FEATURE_WIDTH*KERNEL_SIZE*KERNEL_SIZE - 1 : 0] virtical_reg_to_select_array;
wire [Tm*FEATURE_WIDTH - 1 : 0] scaled_feature;

virtical_reg i_virtical_reg(
    .clk(clk),
    .rst(rst),
    .com_type(),
    .kernel_size(),
    .enable(virtical_reg_shift),
    .in_select(virreg_input_sel),
    .feature_en_0(virreg_to_fmem_0),
    .feature_en_1(virreg_to_fmem_1),
    .dia_0(feature_mem_read_data_0),
    .dia_1(feature_mem_read_data_1),
    .doa(virtical_reg_to_select_array),
    .shift_done(shift_done_from_virreg)
);

// virtical_reg w_virtical_reg();
reg [4:0] out_channel_counter;
always@(posedge clk)begin
    if(rst)begin
        out_channel_counter <= 5'h00;
    end
    else begin
        case(com_type)
        CONV: begin
            if(virtical_reg_shift)begin
                
            end
        end
        DWCONV: begin
            
        end
        PWCONV: begin
            
        end
        end
    end
end

wire [Tn*KERNEL_SIZE*KERNEL_SIZE*FEATURE_WIDTH - 1 : 0] ternary_com_out;
TnKK_select_array ternary_com_array(
    .clk(clk),
    .rst(rst),
    .feature_in(virtical_reg_to_select_array),
    .weight_in(weight_wire),
    .enable(shift_done_from_virreg),
    .temp_feature_out(ternary_com_out)
);

wire [Tn*FEATURE_WIDTH - 1 : 0] tn_kernel_out;
wire tn_kernel_done;
adder_tree_Tn_kernel kernel_adder_tree(
    .fast_clk(clk),
    .rst(rst),
    .enable(shift_done_from_virreg),
    .ternery_res_tn(ternary_com_out),
    .kernel_sum_tn(tn_kernel_out),
    .adder_done(tn_kernel_done)
);

wire [FEATURE_WIDTH-1 : 0] feature_temp;
wire tn_channel_done;
adder_tree_tn channel_adder_tree(
    .fast_clk(clk),
    .rst(rst),
    .enable(tn_kernel_done),
    .tn_input(tn_kernel_out),
    .out(feature_temp),
    .adder_done(tn_channel_done)
);

scaler_multiply_unit #(.FEATURE_WIDTH(FEATURE_WIDTH), .SCALER_WIDTH(16)) single_feature_scaling_unit (
    .clk(clk),
    .rst(rst),
    .enable(1'b1),
    .data_in(feature_temp),
    .scaler_in(scaler_data[15 : 0]),
    .data_o(scaled_feature)
);

generate
    for(i=0; i<Tm; i=i+1)begin
        scaler_multiply_unit #(.FEATURE_WIDTH(FEATURE_WIDTH), .SCALER_WIDTH(16)) tn_feature_scaling_unit(
            .clk(clk),
            .rst(rst),
            .enable(1'b1),
            .data_in(tn_kernel_out[(i+1)*FEATURE_WIDTH - 1 : i*FEATURE_WIDTH]),
            .scaler_in(scaler_reg[(i+1)*SCALER_WIDTH-1 : i*SCALER_WIDTH]),
            .data_o(scaled_feature[(i+1)*FEATURE_WIDTH-1 : i*FEATURE_WIDTH])
        );
    end
endgenerate

assign scaled_feature_output[Tm*FEATURE_WIDTH-1 : 0] = scaled_feature[Tm*FEATURE_WIDTH-1 : 0];

endmodule