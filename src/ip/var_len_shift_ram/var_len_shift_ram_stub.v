// Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2019.1 (win64) Build 2552052 Fri May 24 14:49:42 MDT 2019
// Date        : Mon Apr 20 11:52:11 2020
// Host        : User2-ADSC running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               C:/Users/User2/Desktop/VivadoProjects/TDLA-i7server/T-DLA/t_dla_ip/lab40.srcs/sources_1/ip/var_len_shift_ram/var_len_shift_ram_stub.v
// Design      : var_len_shift_ram
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7z020clg484-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "c_shift_ram_v12_0_13,Vivado 2019.1" *)
module var_len_shift_ram(A, D, CLK, CE, Q)
/* synthesis syn_black_box black_box_pad_pin="A[7:0],D[7:0],CLK,CE,Q[7:0]" */;
  input [7:0]A;
  input [7:0]D;
  input CLK;
  input CE;
  output [7:0]Q;
endmodule
