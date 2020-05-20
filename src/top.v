`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ADSC
// Engineer: Yao Chen, Kai Zhang
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
         
        input   wire                 arm_read_feature_enable,
        input   wire  [15+2:0]       arm_read_feature_addr,
        output  wire  [FEATURE_WIDTH*2 - 1 : 0]             arm_read_feature_data,
        input   wire                 arm_read_feature_select,
        
        // input instr_mem_enable,
//        input [9:0] instr_mem_addr,
        input [63:0] instr_port,
        
        input   wire                 acc_enable
        // output  wire                 CLP_state      //0 CLP idle    1 CLP busy        
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

instr_fetch instruction_fetcher(
.clk(clk),
.rst(rst),
.i_instr(instr_port),
.fetch_addr(), // todo: first address from config, then from instruction
.fetch_enable(fetch_instruction_from_ddr),
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
    .full()
);

wire  [3:0]state;

wire instruction_enable;
wire i_mem_empty;
 
top_fsm CLP_fsm(
            .clk(clk),
            .rst(rst), 
            .acc_enable(acc_enable),
            .i_mem_empty(i_mem_empty),
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
wire                     feature_in_select; 
wire                     feature_out_select;
wire CLP_output_flag;
wire  [ Tm * FEATURE_WIDTH - 1 : 0 ]        CLP_output;
wire     [15:0]          CLP_work_time;
wire     [2:0]           current_kernel_size;
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
wire fetch_done_wire;


instruction_decode instruction_decode_0(
                      .clk(clk),
                      .rst(rst),
                      .instruction(ctr),
                      .instr_enable(instruction_enable),
                      
                      .feature_fetch_enable(feature_fetch_enable),
                      .weight_fetch_enable(weight_fetch_enable),
                      .bias_fetch_enable(bias_fetch_enable),
                      .scaler_fetch_enable(scaler_fetch_enable),
                      .instr_fetch_enable(instr_fetch_enable),

                      .fetch_type(fetch_type),
                      .src_addr(src_addr),
                      .dst_addr(dst_addr),
                      .mem_sel(mem_sel),
                      .fetch_counter(fetch_counter),

// the following ports are idle for now, TODO: delete or use in the other operations
                      .feature_size(feature_size),
                      .feature_out_select(feature_out_select),
                      .feature_in_select(feature_in_select),       //   0 :  CLP read feature from ram0          1:  CLP read feature from ram1
                      .weight_mem_init_addr(weight_mem_init_addr),
                      .scaler_mem_addr(scaler_mem_addr),
                      .CLP_work_time(CLP_work_time),
                      .current_kernel_size(current_kernel_size),
                      .CLP_type(CLP_type)
                    );     
                    
               
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
                       .feature_size(feature_size),
                    //    .feature_in_select(feature_in_select),
                       .wr_addr(feature_mem_wr_addr),
                       .wr_data(feature_mem_wr_data),
                       .wr_en(feature_mem_enable),
                       .i_mem_select(mem_select),
                       .fetch_done(fetch_done_wire) );

wire f_mem_enable_0;
wire [7:0]  f_mem_addr_0;
wire [DATA_BUS_WIDTH - 1 : 0]      f_mem_data_0;
wire f_mem_enable_1;
wire [7:0]  f_mem_addr_1;
wire [DATA_BUS_WIDTH - 1 : 0]      f_mem_data_1; 

wire feature_mem_read_enable_0;
wire [7:0] feature_mem_read_addr_0;
wire [127:0] feature_mem_read_data_0;

wire feature_mem_read_enable_1;
wire [7:0] feature_mem_read_addr_1;
wire [127:0] feature_mem_read_data_1;

wire                                        feature_mem_enable;
wire  [7:0]                              feature_mem_wr_addr;
wire                                        mem_select;
wire  [127:0]                                feature_mem_wr_data;


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

scratchpad_feature_mem #(Tn, KERNEL_SIZE, FEATURE_WIDTH, DATA_BUS_WIDTH) feature_mem_group_0(
    .clk(clk),
    .rst(rst),
    .wr_en(f_mem_enable_0),
    .rd_en(feature_mem_read_enable_0),
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
    .rd_en(feature_mem_read_enable_1),
    .wr_mem_group(f_mem_addr_1[7:4]),
    .wr_mem_line(f_mem_addr_1[3:0]),
    .rd_mem_group(),
    .rd_mem_line(),

    .i_port(f_mem_data_1),
    .data_out(feature_mem_read_data_1)
);

/*                 
//wire CLP_enable;
wire CLP_data_delay; 

clp_state_control clp_state_unit(
.clk(clk),
.rst(rst),
.enable(acc_enable),
.current_kernel_size(current_kernel_size),
//.CLP_ctr_cnt(CLP_ctr_cnt),
.CLP_work_time(CLP_work_time),
.feature_size(feature_size),
.CLP_enable(CLP_enable),
.CLP_data_ready(CLP_data_ready),
.state(state)
);
                    
wire  [ SCALER_WIDTH - 1:0  ]                                                      scaler_wire;
wire  [ Tn * Tm * KERNEL_SIZE * KERNEL_SIZE * KERNEL_WIDTH - 1 : 0 ]               weight_wire;
*/   

wire  [ Tn * KERNEL_SIZE * KERNEL_SIZE * FEATURE_WIDTH - 1 : 0 ]                   feature_wire;    

line_buffer_array line_buf_array_instance(
           .clk(clk),
           .rst(rst),
           .current_kernel_size(current_kernel_size),
           .feature_size(feature_size),
           .line_buffer_enable(),
           .input_buffer_select(),

            .src_buffer_empty(),
            .src_buffer_full(),
            .initial_lines_of_feature(),

            .feature_mem_read_data_0(),
            .feature_mem_read_data_1(),
           .feature_wire(feature_wire)
    );
/*    
weight_mem_ctr weight_mem_ctr0(
        .clk(clk),
        .rst(rst),
        .state(state),
        .weight_mem_init_addr(weight_mem_init_addr),
        .weight_wire(weight_wire)
    );
scaler_ctr scaler_ctr0(
        .clk(clk),
        .rst(rst),
        .state(state),
        .scaler_mem_addr(scaler_mem_addr),
        .scaler_wire(scaler_wire)
        );
*/
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

endmodule