


// Re-customize supported parameters
`define Tm                              8
`define Tn                              4
`define FEATURE_WIDTH                   16
`define BIAS_WIDTH                      8
`define SCALER_WIDTH                    16
`define KERNEL_WIDTH                    2
`define KERNEL_SIZE                     5

// Unsupported parameters -- fixed to exact number

`define FEATURE_IN_MEM_READ_WIDTH_COF   8
`define WEIGHT_MEM_READ_WIDTH_COF       2

`define DATA_BUS_WIDTH   128
`define INSTR_BUS_WIDTH  64


//`define cpu_width Tm*Scaler*