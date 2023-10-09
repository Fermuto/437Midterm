`timescale 1ns / 1ps

module MidtermTopLevel(   
    output [7:0] led,
    input        sys_clkn,
    input  sys_clkp,  
    output I2C_SCL_0,
    inout I2C_SDA_0,
    input  [4:0] okUH,
    output [2:0] okHU,
    inout  [31:0] okUHU,
    inout  okAA      
);

    ///////////////////////////////////////////////////////////////////////////////////////////////////////
    // I2C Interface FSM + OK connections
    wire ILA_Clk, FSM_Clk;
    wire PCControl;
    
    wire [6:0] SlaveAddress, SubAddress;
    wire ReadWrite;
    wire [7:0] WriteData, BytesToRead;
    wire [31:0] ReadData;

    wire ACK_bit, SCL, SDA;
    wire [7:0] UpperState, LowerState;
    wire [31:0] Telemetry;
    
    wire [31:0] PCControlRaw, InputVector;
    
    assign PCControl = PCControlRaw[0];   
        
    
    // Chop up input vector
    assign SlaveAddress = InputVector[30:24];
    assign SubAddress   = InputVector[23:17];
    assign ReadWrite    = InputVector[16];
    assign WriteData    = InputVector[15:8];
    assign BytesToRead  = InputVector[7:0];
    
    ///////////////////////////////////////////////////////////////////////////////////////////////////////
    // OK Interface
    wire [112:0] okHE;  //These are FrontPanel wires needed to IO communication    
    wire [64:0]  okEH;  //These are FrontPanel wires needed to IO communication 
    
    // Depending on the number of outgoing endpoints, adjust endPt_count accordingly.
    localparam  endPt_count = 1;
    wire [endPt_count*65-1:0] okEHx;  
    okWireOR # (.N(endPt_count)) wireOR (okEH, okEHx);
    
    //This is the OK host that allows data to be sent or recived    
    okHost hostIF (
        .okUH(okUH),
        .okHU(okHU),
        .okUHU(okUHU),
        .okClk(okClk),
        .okAA(okAA),
        .okHE(okHE),
        .okEH(okEH)
    );
    
    // The input data is received as a vector via memory location 0x00
    okWireIn wire00 (   .okHE(okHE), 
                        .ep_addr(8'h00), 
                        .ep_dataout(PCControlRaw));      
    
    okWireIn wire01 (   .okHE(okHE), 
                        .ep_addr(8'h00), 
                        .ep_dataout(InputVector));      
                                
                        
    // TemperatureWire is transmited to the PC via address 0x20   
    okWireOut wire20 (  .okHE(okHE), 
                        .okEH(okEHx[ 0*65 +: 65 ]),
                        .ep_addr(8'h20), 
                        .ep_datain(ReadData));     
                        

    ///////////////////////////////////////////////////////////////////////////////////////////////////////
    // I2C Interface FSM
    I2CInterface LSM303I2C (.led(led),
                    .sys_clkn(sys_clkn),
                    .sys_clkp(sys_clkp),
                    .I2C_SCL_0(I2C_SCL_0),
                    .I2C_SDA_0(I2C_SDA_0),
                    .FSM_Clk_reg(FSM_Clk_reg),
                    .ILA_Clk_reg(ILA_Clk_reg),
                    .PCControl(PCControl),
                    .SlaveAddress(SlaveAddress),
                    .SubAddress(SubAddress),
                    .ReadWrite(ReadWrite),
                    .WriteData(WriteData),
                    .BytesToRead(BytesToRead),
                    .ReadData(ReadData),
                    .ACK_bit(ACK_bit),
                    .SCL(SCL),
                    .SDA(SDA),
                    .UpperState(UpperState),
                    .LowerState(LowerState),
                    .Telemetry(Telemetry)
                    );
    
    //Instantiate the ILA module
    ila_i2c0 ila_sample ( 
        .clk(ILA_Clk),
        .probe0({ReadWrite, SlaveAddress, SubAddress, WriteData, BytesToRead}),    
        .probe1({ACK_bit, SCL, SDA, UpperState, LowerState}), 
        .probe2({ReadData}), 
        .probe3({Telemetry}),                           
        .probe4({FSM_Clk, PCControl})
        );  
        
                        
endmodule
