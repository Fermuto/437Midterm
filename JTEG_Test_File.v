`timescale 1ns / 1ps

module JTEG_Test_File(   
    output [7:0] led,
    input sys_clkn,
    input sys_clkp,  
    output ADT7420_A0,
    output ADT7420_A1,
    output I2C_SCL_0,
    inout I2C_SDA_0,
    input  [4:0] okUH,
    output [2:0] okHU,
    inout  [31:0] okUHU,
    inout  okAA      
);

    wire  ILA_Clk, ACK_bit, FSM_Clk, TrigerEvent;    
    wire [23:0] ClkDivThreshold = 1_000;   
    wire SCL, SDA; 
    wire [7:0] State;
    wire [31:0] PC_control;
    wire [15:0] Temperature;
    
    assign TrigerEvent = PC_control[0];   

    //Instantiate the module that we like to test
    I2C_Transmit I2C_Test1 (        
        .led(led),
        .sys_clkn(sys_clkn),
        .sys_clkp(sys_clkp),
        .ADT7420_A0(ADT7420_A0),
        .ADT7420_A1(ADT7420_A1),
        .I2C_SCL_0(I2C_SCL_0),
        .I2C_SDA_0(I2C_SDA_0),             
        .FSM_Clk_reg(FSM_Clk),        
        .ILA_Clk_reg(ILA_Clk),
        .ACK_bit(ACK_bit),
        .SCL(SCL),
        .SDA(SDA),
        .State(State),
        .PC_control(PC_control),
        .Temperature (Temperature),
        .okUH(okUH),
        .okHU(okHU),
        .okUHU(okUHU),
        .okAA(okAA)
        );
    
    //Instantiate the ILA module
    ila_1 ila_sample12 ( 
        .clk(ILA_Clk),
        .probe0({State, SDA, SCL, ACK_bit, Temperature}),                             
        .probe1({FSM_Clk, TrigerEvent})
        );                        
endmodule