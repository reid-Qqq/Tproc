`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ADSC_DSC
// Engineer: Yao Chen
// 
// Create Date: 07/28/2018 10:45:54 PM
// Design Name: t-dla-instr-acc
// Module Name: top
// Project Name: t-dla
// Target Devices: Zedboard
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 1.0 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "network_para.vh"

module top#(
        parameter Tn = `Tn,
        parameter Tm = `Tm,
        parameter KERNEL_SIZE = `KERNEL_SIZE,
        parameter KERNEL_WIDTH = `KERNEL_WIDTH,
        parameter FEATURE_WIDTH = `FEATURE_WIDTH,
        parameter SCALER_WIDTH = `SCALER_WIDTH,
        parameter BIAS_WIDTH = `BIAS_WIDTH,
        parameter DATA_BUS_WIDTH = `DATA_BUS_WIDTH
)(
        input   wire                 clk,
        input   wire                 fast_clk,
        input   wire                 rst,
  
        input   wire  [127 : 0]      i_data_bus_port,
        output  wire  [15:0]         i_feature_addr,
        output  wire                 i_feature_rd_en,

        input   wire  [63:0]         i_w_bus_port,
        output  wire  [15:0]         i_w_addr,
        output  wire                 i_w_enable,
        
        // input instr_mem_enable,
//        input [9:0] instr_mem_addr,
        input   wire [63:0] instr_port,
        output  wire [15:0]  instr_fetch_addr,
        output  wire        instr_rd_en,

        output wire [FEATURE_WIDTH + SCALER_WIDTH-1 : 0] scaled_feature,
        input   wire                 acc_enable
        );


wire     [9:0]      i_mem_addr;
wire     [63:0]     i_mem_dout;
wire                i_mem_rd_enable;
wire                CLP_enable;
wire     [63:0]     ctr;
wire fetch_instruction_from_ddr;
wire instr_mem_enable;
wire [63:0] fetcher_to_imem;
wire [4:0]  i_mem_addr_in;
wire i_mem_empty;
wire i_mem_full;

instr_fetch instruction_fetcher(
.clk(clk),
.rst(rst),

.fetch_addr(), // todo: first address from config, then from instruction
.fetcher_enable(fetch_instruction_from_ddr),
.mem_fifo_full(i_mem_full),
.mem_fifo_empty(i_mem_empty),

.i_instr(instr_port),
.i_instr_addr(instr_fetch_addr),
.i_instr_rd_en(instr_rd_en),

.o_instr(fetcher_to_imem),
.o_instr_addr(i_mem_addr_in),
.o_instr_enable(instr_mem_wr_enable),
.fetch_flag()
);

/*
dp_ram instruction_mem(
    .clk(clk),
    .ena(instr_mem_wr_enable),
    .enb(i_mem_rd_enable),
    .wea(1'b1),
    .addra(i_mem_addr_in),
    .addrb(i_mem_addr),
    .dia(fetcher_to_imem),
    .dob(i_mem_dout));
*/

// use sync fifo instead of the bram for the instructions
syn_fifo instruction_mem(
    .clk(clk),
    .rst(rst),
    .wr_cs(instr_mem_wr_enable),
    .rd_cs(i_mem_rd_enable),
    .data_in(fetcher_to_imem),
    .rd_en(i_mem_rd_enable),
    .wr_en(instr_mem_wr_enable),
    .data_out(i_mem_dout),
    .empty(i_mem_empty),
    .full(i_mem_full)
);

wire  [3:0]state;

wire instruction_enable;
wire fetch_done_wire;
 
top_fsm CLP_fsm(
            .clk(clk),
            .rst(rst), 
            .acc_enable(acc_enable),
            .i_mem_empty(i_mem_empty),
            .i_mem_full(i_mem_full),
            .instr_exe_state(fetch_done_wire),
            .i_mem_din(i_mem_dout),
            .i_mem_addr(i_mem_addr),
            .i_mem_rd_enable(i_mem_rd_enable), 
            .fetch_instruction_from_ddr(fetch_instruction_from_ddr),   
            .instruction_enable(instruction_enable),
            .ctr(ctr)
            ); 
 

wire     [3:0]           CLP_type;
wire     [7:0]           scaler_mem_addr;
wire     [15:0]          weight_mem_init_addr;
wire                     feature_out_select;
wire CLP_output_flag;
wire  [ Tm * FEATURE_WIDTH - 1 : 0 ]        CLP_output;
wire     [15:0]          CLP_work_time;
wire     [7:0]           feature_size;
wire  CLP_data_ready;

wire feature_fetch_enable;
wire weight_fetch_enable;
wire bias_fetch_enable;
wire scaler_fetch_enable;
wire instr_fetch_enable;
wire [7:0] fetch_type;
wire [15:0] src_addr;
wire [7:0]  dst_addr;
wire [7:0]  mem_sel;
wire [7:0]  fetch_counter;


wire fetch_done_from_i;
wire fetch_done_from_w;
wire shift_done_from_virreg;

assign fetch_done_wire = fetch_done_from_i | fetch_done_from_w | shift_done_from_virreg | test_exe_done | compute_done;

wire [3:0] current_kernel_size;
wire [7:0] com_type_wire;
wire [7:0] current_feature_size;
wire line_buffer_enable;
wire feature_in_select;
wire line_buffer_mod;
wire virtical_reg_shift;
wire virreg_input_sel;
wire test_exe_done;

wire config_clp;

instruction_decode instruction_decoder(
                      .clk(clk),
                      .rst(rst),
                      .instruction(ctr),
                      .instr_enable(instruction_enable),
                      
                      .feature_fetch_enable(feature_fetch_enable),
                      .weight_fetch_enable(weight_fetch_enable),
                      .bias_fetch_enable(bias_fetch_enable),
                      .scaler_fetch_enable(scaler_fetch_enable),
                      .instr_fetch_enable(instr_fetch_enable),
                      .reg_enable(virtical_reg_shift),
                      .vreg_input_select(virreg_input_sel),
                      .test_exe_done(test_exe_done),

                      .fetch_type(fetch_type),
                      .src_addr(src_addr),
                      .dst_addr(dst_addr),
                      .mem_sel(mem_sel),
                      .fetch_counter(fetch_counter),

// interface group to weight fetcher                
                    //   .CLP_type(CLP_type),
                    //   .weight_mem_init_addr(weight_mem_init_addr),
                    //   .scaler_mem_addr(scaler_mem_addr),
                    //   .CLP_work_time(CLP_work_time),

// the following ports are idle for now, TODO: delete or use in the other operations
                      .current_kernel_size(current_kernel_size),
                      .com_type(com_type_wire),
                      .config_enable(config_clp),
                      .current_feature_size(current_feature_size),
                      .line_buffer_enable(line_buffer_enable),
                      .feature_in_select(feature_in_select), // 0 :  CLP read feature from feature buffer 0   1:  CLP read feature from ram1
                      .line_buffer_mod(line_buffer_mod),
                      .feature_out_select(feature_out_select)
                    );     
                    
wire                                     feature_mem_enable;
wire  [7:0]                              feature_mem_wr_addr;
wire                                        mem_select;
wire  [127:0]                                feature_mem_wr_data;
                                   
i_feature_fetch input_fetch(
                       .clk(clk),
                       .rst(rst),
                       .i_data(i_data_bus_port),
                       .fetch_addr(i_feature_addr),
                       .read_data(i_feature_rd_en),

                       .feature_fetch_enable(feature_fetch_enable),
                       .fetch_type(fetch_type),
                       .src_addr(src_addr),
                       .dst_addr(dst_addr),
                       .mem_sel(mem_sel),
                       .feature_size(current_feature_size),
                       .fetch_counter(fetch_counter),
                    //    .feature_in_select(feature_in_select),
                       .wr_addr(feature_mem_wr_addr),
                       .wr_data(feature_mem_wr_data),
                       .wr_en(feature_mem_enable),
                       .i_mem_select(mem_select),
                       .fetch_done(fetch_done_from_i) );

wire f_mem_enable_0;
wire [7:0]  f_mem_addr_0;
wire [DATA_BUS_WIDTH - 1 : 0]      f_mem_data_0;
wire f_mem_enable_1;
wire [7:0]  f_mem_addr_1;
wire [DATA_BUS_WIDTH - 1 : 0]      f_mem_data_1; 

wire feature_mem_read_enable_0;
wire [7:0] feature_mem_read_addr_0;
wire [Tn*FEATURE_WIDTH*KERNEL_SIZE-1 : 0] feature_mem_read_data_0;

wire feature_mem_read_enable_1;
wire [7:0] feature_mem_read_addr_1;
wire [Tn*FEATURE_WIDTH*KERNEL_SIZE-1 : 0] feature_mem_read_data_1;




feature_load i_feature_switch(
  .clk(clk),
  .rst(rst),
  .fetcher_to_mem(feature_mem_enable),
  .wr_feature_addr(feature_mem_wr_addr),
  .wr_feature_data(feature_mem_wr_data),
  .wr_feature_sel(mem_select),
  .fetcher_to_mem_0(f_mem_enable_0),
  .wr_feature_addr_0(f_mem_addr_0),
  .wr_feature_data_0(f_mem_data_0),
  .fetcher_to_mem_1(f_mem_enable_1),
  .wr_feature_addr_1(f_mem_addr_1),
  .wr_feature_data_1(f_mem_data_1)
);

/*
dp_ram#(16, 4, 128) feature_in_memory_0 (
              .clk(clk),                           // input wire clka
              .ena(f_mem_enable_0),       // input wire ena
              .enb(feature_mem_read_enable_0),
              .wea(1'b1),                              // input wire [0 : 0] wea
              .addra(f_mem_addr_0),       // input wire [12 : 0] addra
              .addrb(feature_mem_read_addr_0),        // input wire [8 : 0] addrb
              .dia(f_mem_data_0),        // input wire [23 : 0] dina
              .dob(feature_mem_read_data_0)         // output wire [383 : 0] doutb
            );

dp_ram#(16, 4, 128) feature_in_memory_1 (
              .clk(clk),                             // input wire clka
              .ena(f_mem_enable_1),       // input wire ena
              .enb(feature_mem_read_enable_1),        // input wire enb
              .wea(1'b1),                             // input wire [0 : 0] wea
              .addra(f_mem_addr_1),       // input wire [12 : 0] addra
              .addrb(feature_mem_read_addr_1),        // input wire [8 : 0] addrb
              .dia(f_mem_data_1),        // input wire [23 : 0] dina
              .dob(feature_mem_read_data_1)         // output wire [383 : 0] doutb
            );
*/

wire virreg_to_fmem_0, virreg_to_fmem_1;

scratchpad_feature_mem #(Tn, KERNEL_SIZE, FEATURE_WIDTH, DATA_BUS_WIDTH) feature_mem_group_0(
    .clk(clk),
    .rst(rst),
    .wr_en(f_mem_enable_0),
    .rd_en(virreg_to_fmem_0),
    .wr_mem_group(f_mem_addr_0[7:4]),
    .wr_mem_line(f_mem_addr_0[3:0]),
    .rd_mem_group(),
    .rd_mem_line(),

    .i_port(f_mem_data_0),
    .data_out(feature_mem_read_data_0)
);

scratchpad_feature_mem #(Tn, KERNEL_SIZE, FEATURE_WIDTH, DATA_BUS_WIDTH) feature_mem_group_1(
    .clk(clk),
    .rst(rst),
    .wr_en(f_mem_enable_1),
    .rd_en(virreg_to_fmem_1),
    .wr_mem_group(f_mem_addr_1[7:4]),
    .wr_mem_line(f_mem_addr_1[3:0]),
    .rd_mem_group(),
    .rd_mem_line(),

    .i_port(f_mem_data_1),
    .data_out(feature_mem_read_data_1)
);

wire  [ Tn * KERNEL_SIZE * KERNEL_SIZE * FEATURE_WIDTH - 1 : 0 ]                   feature_wire;    
/*
line_buffer_array line_buf_array_instance(
           .clk(clk),
           .rst(rst),
           .current_kernel_size(current_kernel_size),
           .feature_size(current_feature_size),
           .line_buffer_enable(line_buffer_enable),
           .input_buffer_select(feature_in_select),

            .src_buffer_empty(), // constraint signal to make sure correct execution, from feature buffer, not instr_analysis
            .src_buffer_full(),  // constraint signal to make sure correct execution, from feature buffer, not instr_analysis
            .line_buffer_mod(line_buffer_mod),

            .feature_mem_read_data_0(feature_mem_read_data_0),
            .feature_mem_read_data_1(feature_mem_read_data_1),
            .output_valid(),
           .feature_wire(feature_wire)
    );
*/    

wire w_wr_en;
wire [15:0] w_wr_addr;
wire [63:0] w_wr_data;
wire wr_cs_weight;
wire wr_cs_scaler;
wire wr_cs_bias;

i_weight_fetch weight_fetcher(
    .clk(clk),
    .rst(rst),

    .weight_fetch_enable(weight_fetch_enable),
    .scaler_fetch_enable(scaler_fetch_enable),
    .bias_fetch_enable(bias_fetch_enable),
    .fetch_type(fetch_type),
    .src_addr(src_addr),
    .dst_addr(dst_addr),
    .fetch_counter(fetch_counter),
    .w_data(i_w_bus_port),
    .rd_addr(i_w_addr),
    .rd_en(i_w_enable),
    .wr_addr(w_wr_addr),
    .wr_data(w_wr_data),
    .wr_en(w_wr_en),
    .wr_cs_weight(wr_cs_weight),
    .wr_cs_scaler(wr_cs_scaler),
    .wr_cs_bias(wr_cs_bias),
    .fetch_done(fetch_done_from_w)
);

wire clp_to_weight_buffer_enable, clp_to_bias_buffer_enable;
wire [15:0] clp_to_weight_buffer_addr, clp_to_bias_buffer_addr;
wire [Tn*64 - 1 : 0] weight_wire;
weight_buffer_array #(16, 4, 64, 3) weight_buffer(
    .clk(clk),
    .ena(wr_cs_weight),
    .enb(clp_to_weight_buffer_enable),
    .wea(w_wr_en),
    .addra(w_wr_addr),
    .addrb(clp_to_weight_buffer_addr),
    .dia(w_wr_data),
    .weight_buffer_out(weight_wire)
);

wire [FEATURE_WIDTH - 1:0] bias_wire_CLP;
dp_ram #(16, 4, 64) bias_buffer(
    .clk(clk),
    .ena(wr_cs_bias),
    .enb(clp_to_bias_buffer_enable),
    .wea(w_wr_en),
    .addra(w_wr_addr),
    .addrb(clp_to_bias_buffer_addr),
    .dia(w_wr_data),
    .dob(bias_wire_CLP)
    );

// wire [15:0] s_wr_addr;
// wire [63:0] s_wr_data;
// wire s_wr_en;
wire [63:0] scaler_data;
wire scaler_buffer_rd_en;
syn_fifo_dpram #(.DATA_WIDTH(64), .ADDR_WIDTH(8), .RAM_DEPTH(256)) scaler_buffer(
    .clk(clk),
    .rst(rst),
    .wr_cs(wr_cs_scaler),
    .rd_cs(scaler_buffer_rd_en),
    .data_in(w_wr_data),
    .rd_en(scaler_buffer_rd_en),
    .wr_en(wr_cs_scaler),
    .data_out(scaler_data),
    .empty(),
    .full()
);

/*
syn_fifo instruction_mem(
    .clk(clk),
    .rst(rst),
    .wr_cs(instr_mem_wr_enable),
    .rd_cs(i_mem_rd_enable),
    .data_in(fetcher_to_imem),
    .rd_en(i_mem_rd_enable),
    .wr_en(instr_mem_wr_enable),
    .data_out(i_mem_dout),
    .empty(i_mem_empty),
    .full(i_mem_full)
);
*/

wire [Tn*KERNEL_SIZE*KERNEL_SIZE*KERNEL_WIDTH - 1:0] weight_wire_CLP;

genvar i;
generate
  for (i = 0; i < Tn; i = i+1) begin
    assign weight_wire_CLP[(i+1)*KERNEL_SIZE*KERNEL_SIZE*KERNEL_WIDTH - 1 : i*KERNEL_SIZE*KERNEL_SIZE*KERNEL_WIDTH] = weight_wire[i*64 + KERNEL_SIZE*KERNEL_SIZE*KERNEL_WIDTH - 1 : i*64];
  end
endgenerate
//assign weight_wire_CLP = {weight_wire[3*64 + KERNEL_SIZE*KERNEL_SIZE*KERNEL_WIDTH - 1 : 3*64],
//                          weight_wire[2*64 + KERNEL_SIZE*KERNEL_SIZE*KERNEL_WIDTH - 1 : 2*64],
//                          weight_wire[1*64 + KERNEL_SIZE*KERNEL_SIZE*KERNEL_WIDTH - 1 : 1*64],
//                          weight_wire[0*64 + KERNEL_SIZE*KERNEL_SIZE*KERNEL_WIDTH - 1 : 0*64]
//                          };

configurable_data_path #(
    .Tn(Tn),
    .FEATURE_WIDTH(FEATURE_WIDTH), 
    .KERNEL_SIZE(KERNEL_SIZE),
    .KERNEL_WIDTH(KERNEL_WIDTH),
    .SCALER_WIDTH(SCALER_WIDTH),
    .Tm(Tm)
    ) CLP (
        .clk(clk),
        .rst(rst),

        .config_enable(config_clp),
        .config_clear(),
        .com_type(com_type_wire),
        .kernel_size(current_kernel_size),
    
        .vertical_shift_mod(line_buffer_mod),
        .virtical_reg_shift(virtical_reg_shift),
        .virreg_input_sel(virreg_input_sel),
        .virreg_to_fmem_0(virreg_to_fmem_0),
        .virreg_to_fmem_1(virreg_to_fmem_1),
        .feature_mem_read_data_0(feature_mem_read_data_0),
        .feature_mem_read_data_1(feature_mem_read_data_1),
        .shift_done_from_virreg(shift_done_from_virreg),

        .weight_wire(weight_wire_CLP),
        .weight_addr(clp_to_weight_buffer_addr),
        .weight_read_en(clp_to_weight_buffer_enable),

        .scaler_data(scaler_data),
        .scaler_buffer_rd_en(scaler_buffer_rd_en),
        .scaled_feature_output(scaled_feature),

        .bias_data              (bias_wire_CLP),
        .bias_addr              (clp_to_bias_buffer_addr),
        .bias_buffer_rd_en      (clp_to_bias_buffer_enable),

        .compute_done(compute_done)
);


/*
o_feature_reg #(.Tm(Tm), .FEATURE_WIDTH(FEATURE_WIDTH)) o_feature_buffer(
    .clk(clk),
    .rst(rst),
    .wr_feature_in(scaled_feature),
    .wr_feature_enable(),
    .rd_feature_out(),
    .rd_feature_enable()
);
*/





endmodule


/*
CLP CLP0( 
        .clk(clk),
        .fast_clk(fast_clk),
        .rst(rst),
        .feature_in(feature_wire),
        .weight_in(weight_wire),
        .weight_scaler(scaler_wire),
        .bias_in({Tm * BIAS_WIDTH{1'b0}}),
        .ctr(CLP_type),
        .addr_clear(CLP_data_ready),
        .enable(CLP_enable),
        .out_valid(CLP_output_flag),
        .feature_out(CLP_output)
    );
*/
/*
o_f_unit output_feature_unit(
    .clk(clk),
    .rst(rst),

    .feature_out_select(feature_out_select),
    .CLP_output_flag(CLP_output_flag),
    .feature_i(CLP_output),
    
    .arm_read_feature_enable(arm_read_feature_enable),
    .arm_read_feature_addr(arm_read_feature_addr[17:2]),
    .arm_read_feature_data(arm_read_feature_data),
    .arm_read_feature_select(arm_read_feature_select),
    .state(CLP_state)
);
*/
        
 /*
// only enable this part of code during cycle counting test, either for the component sync or performance measurement        
wire [12:0] cnt_for_test;
counter test_cnt(
.clk(clk),
.rst(rst),
.cnt(cnt_for_test));
*/
