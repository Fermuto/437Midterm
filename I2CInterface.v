module I2CInterface(
    output wire [7:0]  led,
    input  wire        sys_clkn,
    input  wire        sys_clkp,
    output wire        I2C_SCL_0,
    inout  wire        I2C_SDA_0,
    output reg         FSM_Clk_reg,
    output reg         ILA_Clk_reg,
    input  wire [4:0]  okUH,
    output wire [2:0]  okHU,
    inout  wire [31:0] okUHU,
    inout  wire        okAA,
    output reg         ACK_bit,
    output reg         SCL,
    output reg         SDA,
    output reg  [7:0]  State,
    output wire [31:0] PC_control
    );

    // Instantiate the ClockGenerator module, where three signals are generate:
    // High speed CLK signal, Low speed FSM_Clk signal
    wire [23:0] ClkDivThreshold = 100;
    wire FSM_Clk, ILA_Clk;
    ClockGenerator ClockGenerator1 (  .sys_clkn(sys_clkn),
                                      .sys_clkp(sys_clkp),
                                      .ClkDivThreshold(ClkDivThreshold),
                                      .FSM_Clk(FSM_Clk),
                                      .ILA_Clk(ILA_Clk) );

    reg error_bit = 1'b1;

    localparam STATE_INIT       = 8'd0;
    assign led[7] = ACK_bit;
    assign led[6] = error_bit;
    assign led[5:0] = 1'b1;
    assign I2C_SCL_0 = SCL;
    assign I2C_SDA_0 = SDA;

    assign TemperatureWire = {16'd0, TemperatureReg};
    assign Temperature = TemperatureWire;

    initial  begin
        SCL = 1'b1;
        SDA = 1'b1;
        ACK_bit = 1'b1;
        State = 8'd0;
    end

    always @(*) begin
        FSM_Clk_reg = FSM_Clk;
        ILA_Clk_reg = ILA_Clk;
    end



endmodule