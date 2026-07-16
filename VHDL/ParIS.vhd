-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- ParIS - beta distribution 1.1 
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- This code is part of the VHDL description of ParIS router, the building block
-- of SoCINfp network. It was implemented by Cesar A. Zeferino and Frederico
-- G. M. do Espirito Santo at UNIVALI (Itajai, Brazil), in cooperation with
-- Altamiro A. Susin from UFRGS (Porto Alegre, Brazil).
--
-- where:
--   ParIS   = Parameterizable Interconnect Switch
--   SoCINfp = System-on-Chip Interconnection Network - fully parameterizable
--   UNIVALI = Universidade do Vale do Itajaí
--   UFRGS   = Universidade Federal do Rio Grande do Sul
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- General features of the current version
-- They are offered the following option for synthesis:
-- a)Routing     : XY and West-First (N/S before E, or E befor N/S)
-- b)Arbitration : round-robin
-- c)Flow-control: credit-based (synchronous) and handshake (assynchronous)
-- d)Buffers FIFO: at the input and/or at the output channels, with the
--                 following implementations:
--                 - LUT/FF-based (RING and SHIFT architectures)
--                 - Embedded-RAM-based (Altera function)
--                 - no buffers (NONE)
-- e)Switches    : only LUT-based 
-- f)Physical    : some physical parameters can be customized:
--                 - channel widths (DATA_WIDTH+2) 
--                 - routing information width (RIB_WIDTH)
--                 - FIFO's depth
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Please, we ask that any publication of researches based on this code refers 
-- to the following paper:
--
-- C. A. Zeferino, F. G. M. do Espirito Santo, A. A. Susin. ParIS: A Parameteri-
-- zable Interconnect Switch for Networks-on-Chip. In: Proceedings of the 17th 
-- Symposium on Integrated Circuits and Systems (SBCCI),ACM Press, 2004.
-- pp.204-209.
--
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- VERY IMPORTANT:
-- This code was synthesized and verified only using Altera Quartus II tools.
-- Since it based on a hierarchical inheritance of parameters, from the higher
-- level entities to the lower level ones, it is possible that synthesis does
-- not work in EDA tools requiring a botton-up compilation flow, like Modelsim.
--
-- NOTE: We are not responsible for its use in real applications.
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------


LIBRARY ieee;
USE ieee.std_logic_1164.all;
---------------
---------------
ENTITY ParIS IS
---------------
---------------
  GENERIC(
    -- Address of a ParIS instance
    XID                 : INTEGER := 2;         -- x-coordinate
    YID                 : INTEGER := 2;         -- y-coordinate

    -- Usage of each communication port
    USE_LOCAL           : INTEGER := 1;         -- Local port must be implemented
    USE_NORTH           : INTEGER := 1;         -- North port must be implemented
    USE_EAST            : INTEGER := 1;         -- East  port must be implemented
    USE_SOUTH           : INTEGER := 1;         -- South port must be implemented
    USE_WEST            : INTEGER := 1;         -- West  port must be implemented

    -- Data channel and RIB widths
    DATA_WIDTH          : INTEGER := 8;         -- Width of the data channel 
    RIB_WIDTH           : INTEGER := 8;         -- Width of the RIB field in the header

    -- Parameters for the input buffers
    XIN_FIFO_TYPE       : STRING  := "NONE";   -- Options: NONE, RING, SHIFT or ALTERA
    LIN_FIFO_DEPTH      : INTEGER := 4;         -- Depth of the Local input buffer
    NIN_FIFO_DEPTH      : INTEGER := 4;         -- Depth of the North input buffer
    EIN_FIFO_DEPTH      : INTEGER := 4;         -- Depth of the East  input buffer
    SIN_FIFO_DEPTH      : INTEGER := 4;         -- Depth of the South input buffer
    WIN_FIFO_DEPTH      : INTEGER := 4;         -- Depth of the West  input buffer
    LIN_FIFO_LOG2_DEPTH : INTEGER := 2;         -- Used only for Altera type
    NIN_FIFO_LOG2_DEPTH : INTEGER := 2;         -- Used only for Altera type
    EIN_FIFO_LOG2_DEPTH : INTEGER := 2;         -- Used only for Altera type
    SIN_FIFO_LOG2_DEPTH : INTEGER := 2;         -- Used only for Altera type
    WIN_FIFO_LOG2_DEPTH : INTEGER := 2;         -- Used only for Altera type

    -- Parameters for the output buffers
    XOUT_FIFO_TYPE       : STRING  := "RING";   -- Options: NONE, RING, SHIFT or ALTERA
    LOUT_FIFO_DEPTH      : INTEGER := 4;        -- Depth of the Local input buffer
    NOUT_FIFO_DEPTH      : INTEGER := 4;        -- Depth of the North input buffer
    EOUT_FIFO_DEPTH      : INTEGER := 4;        -- Depth of the East  input buffer
    SOUT_FIFO_DEPTH      : INTEGER := 4;        -- Depth of the South input buffer
    WOUT_FIFO_DEPTH      : INTEGER := 4;        -- Depth of the West  input buffer
    LOUT_FIFO_LOG2_DEPTH : INTEGER := 2;        -- Used only for Altera type
    NOUT_FIFO_LOG2_DEPTH : INTEGER := 2;        -- Used only for Altera type
    EOUT_FIFO_LOG2_DEPTH : INTEGER := 2;        -- Used only for Altera type
    SOUT_FIFO_LOG2_DEPTH : INTEGER := 2;        -- Used only for Altera type
    WOUT_FIFO_LOG2_DEPTH : INTEGER := 2;        -- Used only for Altera type

    -- Parameters for the flow controllers 
    FC_TYPE        : STRING  := "CREDIT";      -- Options: CREDIT or HANDSHAKE
    LOUT_FC_CREDIT : INTEGER := 4;             -- Initial number of credits for Lout
    NOUT_FC_CREDIT : INTEGER := 4;             -- Initial number of credits for Nout
    EOUT_FC_CREDIT : INTEGER := 4;             -- Initial number of credits for Eout
    SOUT_FC_CREDIT : INTEGER := 4;             -- Initial number of credits for Sout
    WOUT_FC_CREDIT : INTEGER := 4;             -- Initial number of credits for Wout

    -- Parameters for routing circuits, arbiters and switches
    ROUTING_TYPE   : STRING  := "XY";          -- Options: XY or WF
    WF_TYPE        : STRING  := "Y_BEFORE_E";  -- options: E_BEFORE_Y, Y_BEFORE_E
    ARBITER_TYPE   : STRING  := "ROUND_ROBIN"; -- Options: only ROUND_ROBIN
    SWITCH_TYPE    : STRING  := "LOGIC"        -- Options: LOGIC (to be implemented: TRI)
  );
  PORT(
    clk       : IN   STD_LOGIC;
    rst       : IN   STD_LOGIC;
    -- Local Communication Port
    Lin_data  : IN   STD_LOGIC_VECTOR(DATA_WIDTH+1 DOWNTO 0);
    Lin_val   : IN   STD_LOGIC;
    Lin_ret   : OUT  STD_LOGIC;  
    Lout_data : OUT  STD_LOGIC_VECTOR(DATA_WIDTH+1 DOWNTO 0);
    Lout_val  : OUT  STD_LOGIC;
    Lout_ret  : IN   STD_LOGIC;
    -- North Communication Port
    Nin_data  : IN   STD_LOGIC_VECTOR(DATA_WIDTH+1 DOWNTO 0);
    Nin_val   : IN   STD_LOGIC;
    Nin_ret   : OUT  STD_LOGIC;  
    Nout_data : OUT  STD_LOGIC_VECTOR(DATA_WIDTH+1 DOWNTO 0);
    Nout_val  : OUT  STD_LOGIC;
    Nout_ret  : IN   STD_LOGIC;
    -- East Communication Port
    Ein_data  : IN   STD_LOGIC_VECTOR(DATA_WIDTH+1 DOWNTO 0);
    Ein_val   : IN   STD_LOGIC;
    Ein_ret   : OUT  STD_LOGIC;  
    Eout_data : OUT  STD_LOGIC_VECTOR(DATA_WIDTH+1 DOWNTO 0);
    Eout_val  : OUT  STD_LOGIC;
    Eout_ret  : IN   STD_LOGIC;
    -- South Communication Port
    Sin_data  : IN   STD_LOGIC_VECTOR(DATA_WIDTH+1 DOWNTO 0);
    Sin_val   : IN   STD_LOGIC;
    Sin_ret   : OUT  STD_LOGIC;  
    Sout_data : OUT  STD_LOGIC_VECTOR(DATA_WIDTH+1 DOWNTO 0);
    Sout_val  : OUT  STD_LOGIC;
    Sout_ret  : IN   STD_LOGIC;
    -- West Communication Port
    Win_data  : IN   STD_LOGIC_VECTOR(DATA_WIDTH+1 DOWNTO 0);
    Win_val   : IN   STD_LOGIC;
    Win_ret   : OUT  STD_LOGIC;  
    Wout_data : OUT  STD_LOGIC_VECTOR(DATA_WIDTH+1 DOWNTO 0);
    Wout_val  : OUT  STD_LOGIC;
    Wout_ret  : IN   STD_LOGIC);
END ParIS;

-------------------------------
-------------------------------
ARCHITECTURE arch_1 OF ParIS IS
-------------------------------
-------------------------------

-------------
COMPONENT Xin 
-------------
  GENERIC(
    XID             : INTEGER:= 2;      -- x-coordinate  
    YID             : INTEGER:= 2;      -- y-coordinate
    USE_THIS        : INTEGER:= 1;      -- defines if the module must be used
    MODULE_ID       : STRING := "L";    -- identifier of the port in the router
    DATA_WIDTH      : INTEGER:= 8;      -- width of data channel 
    RIB_WIDTH       : INTEGER:= 8;      -- width of the RIB field in the header
    ROUTING_TYPE    : STRING := "XY";   -- type of routing algorithm
    WF_TYPE         : STRING := "Y_BEFORE_E";-- options: E_BEFORE_Y, Y_BEFORE_E
    FC_TYPE         : STRING := "CREDIT";    -- options: CREDIT or HANDSHAKE
    FIFO_TYPE       : STRING := "SHIFT";-- options: NONE, SHIFT, RING & ALTERA
    FIFO_DEPTH      : INTEGER:= 4;      -- number of positions
    FIFO_LOG2_DEPTH : INTEGER:= 2;      -- log2 of the number of positions 
    SWITCH_TYPE     : STRING := "LOGIC" -- options: LOGIC (to implement: TRI)
  );
  PORT(
    -- System interface
    clk   : IN  STD_LOGIC;                         -- clock
    rst   : IN  STD_LOGIC;                         -- reset

    -- Link signals
    in_data : IN STD_LOGIC_VECTOR(DATA_WIDTH+1 DOWNTO 0); -- input channel
    in_val  : IN  STD_LOGIC;                       -- data validation
    in_ret  : OUT STD_LOGIC;                       -- return (cr/ack)

    -- Commands and status signals interconnecting input and output channels
    x_reqL  : OUT STD_LOGIC;                       -- request to Lout
    x_reqN  : OUT STD_LOGIC;                       -- request to Nout
    x_reqE  : OUT STD_LOGIC;                       -- request to Eout
    x_reqS  : OUT STD_LOGIC;                       -- request to Sout
    x_reqW  : OUT STD_LOGIC;                       -- request to Wout
    x_rok   : OUT STD_LOGIC;                       -- rok to the outputs
    x_rd    : IN  STD_LOGIC_VECTOR (3 DOWNTO 0);   -- rd cmd. from the outputs
    x_gnt   : IN  STD_LOGIC_VECTOR (3 DOWNTO 0);   -- grant from the outputs
    x_Lidle : IN  STD_LOGIC;                       -- status from Lout
    x_Nidle : IN  STD_LOGIC;                       -- status from Nout
    x_Eidle : IN  STD_LOGIC;                       -- status from Eout
    x_Sidle : IN  STD_LOGIC;                       -- status from Sout
    x_Widle : IN  STD_LOGIC;                       -- status from Wout

    -- Data to the output channels
    x_dout  : OUT STD_LOGIC_VECTOR(DATA_WIDTH+1 DOWNTO 0) -- output data bus
  );
END COMPONENT;

--------------
COMPONENT Xout
--------------
  GENERIC(
    USE_THIS        : INTEGER := 1;        -- defines if the module must be used
    DATA_WIDTH      : INTEGER := 8;        -- width of data channel 
    FC_TYPE         : STRING  := "CREDIT"; -- options: CREDIT or HANDSHAKE
    FC_CREDIT       : INTEGER := 4;        -- maximum number of credits
    FIFO_TYPE       : STRING  := "SHIFT";  -- options: NONE, SHIFT, RING & ALTERA
    FIFO_DEPTH      : INTEGER := 4;        -- number of positions
    FIFO_LOG2_DEPTH : INTEGER := 2;        -- log2 of the number of positions 
    ARBITER_TYPE    : STRING  := "ROUND_ROBIN";-- options: ROUND_ROBIN
    SWITCH_TYPE     : STRING  := "LOGIC"   -- options: LOGIC (to implement: TRI)
  );
  PORT(
    -- System signals
    clk  : IN  STD_LOGIC;  -- clock
    rst  : IN  STD_LOGIC;  -- reset
      
    -- Link signals
    out_data  : OUT STD_LOGIC_VECTOR(DATA_WIDTH+1 DOWNTO 0); -- output channel
    out_val   : OUT STD_LOGIC;                        -- data validation
    out_ret   : IN  STD_LOGIC;                        -- return (cr/ack) 

    -- Commands and status signals interconnecting input and output channels
    x_req     : IN  STD_LOGIC_VECTOR (3 DOWNTO 0);    -- reqs. from the inputs
    x_rok     : IN  STD_LOGIC_VECTOR (3 DOWNTO 0);    -- rok from   the inputs
    x_rd      : OUT STD_LOGIC;                        -- rd cmd. to the inputs
    x_gnt     : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);    -- grant from the outputs
    x_idle    : OUT STD_LOGIC;                        -- status to  the inputs

    -- Data from the input channels
    x_din0    : IN  STD_LOGIC_VECTOR(DATA_WIDTH+1 DOWNTO 0); -- channel 0 
    x_din1    : IN  STD_LOGIC_VECTOR(DATA_WIDTH+1 DOWNTO 0); -- channel 1
    x_din2    : IN  STD_LOGIC_VECTOR(DATA_WIDTH+1 DOWNTO 0); -- channel 2
    x_din3    : IN  STD_LOGIC_VECTOR(DATA_WIDTH+1 DOWNTO 0)  -- channel 3
  );
END COMPONENT;

-----------
COMPONENT X
-----------
  GENERIC (
    ROUTING_TYPE : STRING := "XY"  -- options are XY or WF
  );
  PORT (
    LreqN_in  : IN  STD_LOGIC;
    LreqE_in  : IN  STD_LOGIC;
    LreqS_in  : IN  STD_LOGIC;
    LreqW_in  : IN  STD_LOGIC;
    --------------------------
    LreqN_out : OUT STD_LOGIC;
    LreqE_out : OUT STD_LOGIC;
    LreqS_out : OUT STD_LOGIC;
    LreqW_out : OUT STD_LOGIC;
    --------------------------
    NreqL_in  : IN  STD_LOGIC;
    NreqE_in  : IN  STD_LOGIC;
    NreqS_in  : IN  STD_LOGIC;
    NreqW_in  : IN  STD_LOGIC;
    --------------------------
    NreqL_out : OUT STD_LOGIC;
    NreqE_out : OUT STD_LOGIC;
    NreqS_out : OUT STD_LOGIC;
    NreqW_out : OUT STD_LOGIC;
    --------------------------
    EreqL_in  : IN  STD_LOGIC;
    EreqN_in  : IN  STD_LOGIC;
    EreqS_in  : IN  STD_LOGIC;
    EreqW_in  : IN  STD_LOGIC;
    --------------------------
    EreqL_out : OUT STD_LOGIC;
    EreqN_out : OUT STD_LOGIC;
    EreqS_out : OUT STD_LOGIC;
    EreqW_out : OUT STD_LOGIC;
    --------------------------
    SreqL_in  : IN  STD_LOGIC;
    SreqN_in  : IN  STD_LOGIC;
    SreqE_in  : IN  STD_LOGIC;
    SreqW_in  : IN  STD_LOGIC;
    --------------------------
    SreqL_out : OUT STD_LOGIC;  
    SreqN_out : OUT STD_LOGIC;  
    SreqE_out : OUT STD_LOGIC;  
    SreqW_out : OUT STD_LOGIC;
    --------------------------
    WreqL_in  : IN  STD_LOGIC;
    WreqN_in  : IN  STD_LOGIC;
    WreqE_in  : IN  STD_LOGIC;
    WreqS_in  : IN  STD_LOGIC;
    --------------------------
    WreqL_out : OUT STD_LOGIC;
    WreqN_out : OUT STD_LOGIC;
    WreqE_out : OUT STD_LOGIC;
    WreqS_out : OUT STD_LOGIC;
    --------------------------
    --------------------------
    LgntN_in  : IN  STD_LOGIC;
    LgntE_in  : IN  STD_LOGIC;
    LgntS_in  : IN  STD_LOGIC;
    LgntW_in  : IN  STD_LOGIC;
    --------------------------
    LgntN_out : OUT STD_LOGIC;
    LgntE_out : OUT STD_LOGIC;
    LgntS_out : OUT STD_LOGIC;
    LgntW_out : OUT STD_LOGIC;
    --------------------------
    NgntL_in  : IN  STD_LOGIC;
    NgntE_in  : IN  STD_LOGIC;
    NgntS_in  : IN  STD_LOGIC;
    NgntW_in  : IN  STD_LOGIC;
    --------------------------
    NgntL_out : OUT STD_LOGIC;
    NgntE_out : OUT STD_LOGIC;
    NgntS_out : OUT STD_LOGIC;
    NgntW_out : OUT STD_LOGIC;
    --------------------------
    EgntL_in  : IN  STD_LOGIC;
    EgntN_in  : IN  STD_LOGIC;
    EgntS_in  : IN  STD_LOGIC;
    EgntW_in  : IN  STD_LOGIC;
    --------------------------
    EgntL_out : OUT STD_LOGIC;
    EgntN_out : OUT STD_LOGIC;
    EgntS_out : OUT STD_LOGIC;
    EgntW_out : OUT STD_LOGIC;
    --------------------------
    SgntL_in  : IN  STD_LOGIC;
    SgntN_in  : IN  STD_LOGIC;
    SgntE_in  : IN  STD_LOGIC;
    SgntW_in  : IN  STD_LOGIC;
    --------------------------
    SgntL_out : OUT STD_LOGIC;
    SgntN_out : OUT STD_LOGIC;
    SgntE_out : OUT STD_LOGIC;
    SgntW_out : OUT STD_LOGIC;
    --------------------------
    WgntL_in  : IN  STD_LOGIC;
    WgntN_in  : IN  STD_LOGIC;
    WgntE_in  : IN  STD_LOGIC;
    WgntS_in  : IN  STD_LOGIC;
    --------------------------
    WgntL_out : OUT STD_LOGIC;
    WgntN_out : OUT STD_LOGIC;
    WgntE_out : OUT STD_LOGIC;
    WgntS_out : OUT STD_LOGIC);
    --------------------------
END COMPONENT;

---------
--SIGNALS
---------
-- Requests from L
SIGNAL  Lunused   : STD_LOGIC;
SIGNAL  LreqN_Xin : STD_LOGIC;
SIGNAL  LreqN_Xout: STD_LOGIC;
SIGNAL  LreqE_Xin : STD_LOGIC;
SIGNAL  LreqE_Xout: STD_LOGIC;
SIGNAL  LreqS_Xin : STD_LOGIC;
SIGNAL  LreqS_Xout: STD_LOGIC;
SIGNAL  LreqW_Xin : STD_LOGIC;
SIGNAL  LreqW_Xout: STD_LOGIC;
-- Requests from N
SIGNAL  Nunused   : STD_LOGIC;
SIGNAL  NreqL_Xin : STD_LOGIC;
SIGNAL  NreqL_Xout: STD_LOGIC;
SIGNAL  NreqE_Xin : STD_LOGIC;
SIGNAL  NreqE_Xout: STD_LOGIC;
SIGNAL  NreqS_Xin : STD_LOGIC;
SIGNAL  NreqS_Xout: STD_LOGIC;
SIGNAL  NreqW_Xin : STD_LOGIC;
SIGNAL  NreqW_Xout: STD_LOGIC;
-- Requests from E
SIGNAL  Eunused   : STD_LOGIC;
SIGNAL  EreqL_Xin : STD_LOGIC;
SIGNAL  EreqL_Xout: STD_LOGIC;
SIGNAL  EreqN_Xin : STD_LOGIC;
SIGNAL  EreqN_Xout: STD_LOGIC;
SIGNAL  EreqS_Xin : STD_LOGIC;
SIGNAL  EreqS_Xout: STD_LOGIC;
SIGNAL  EreqW_Xin : STD_LOGIC;
SIGNAL  EreqW_Xout: STD_LOGIC;
-- Requests from S
SIGNAL  Sunused   : STD_LOGIC;
SIGNAL  SreqL_Xin : STD_LOGIC;
SIGNAL  SreqL_Xout: STD_LOGIC;
SIGNAL  SreqN_Xin : STD_LOGIC;
SIGNAL  SreqN_Xout: STD_LOGIC;
SIGNAL  SreqE_Xin : STD_LOGIC;
SIGNAL  SreqE_Xout: STD_LOGIC;
SIGNAL  SreqW_Xin : STD_LOGIC;
SIGNAL  SreqW_Xout: STD_LOGIC;
-- Requests from W
SIGNAL  Wunused : STD_LOGIC;
SIGNAL  WreqL_Xin : STD_LOGIC;
SIGNAL  WreqL_Xout: STD_LOGIC;
SIGNAL  WreqN_Xin : STD_LOGIC;
SIGNAL  WreqN_Xout: STD_LOGIC;
SIGNAL  WreqE_Xin : STD_LOGIC;
SIGNAL  WreqE_Xout: STD_LOGIC;
SIGNAL  WreqS_Xin : STD_LOGIC;
SIGNAL  WreqS_Xout: STD_LOGIC;
-- Grants from L
SIGNAL  LgntN_Xin : STD_LOGIC;
SIGNAL  LgntN_Xout: STD_LOGIC;
SIGNAL  LgntE_Xin : STD_LOGIC;
SIGNAL  LgntE_Xout: STD_LOGIC;
SIGNAL  LgntS_Xin : STD_LOGIC;
SIGNAL  LgntS_Xout: STD_LOGIC;
SIGNAL  LgntW_Xin : STD_LOGIC;
SIGNAL  LgntW_Xout: STD_LOGIC;
-- Grants from N
SIGNAL  NgntL_Xin : STD_LOGIC;
SIGNAL  NgntL_Xout: STD_LOGIC;
SIGNAL  NgntE_Xin : STD_LOGIC;
SIGNAL  NgntE_Xout: STD_LOGIC;
SIGNAL  NgntS_Xin : STD_LOGIC;
SIGNAL  NgntS_Xout: STD_LOGIC;
SIGNAL  NgntW_Xin : STD_LOGIC;
SIGNAL  NgntW_Xout: STD_LOGIC;
-- Grants from E
SIGNAL  EgntL_Xin : STD_LOGIC;
SIGNAL  EgntL_Xout: STD_LOGIC;
SIGNAL  EgntN_Xin : STD_LOGIC;
SIGNAL  EgntN_Xout: STD_LOGIC;
SIGNAL  EgntS_Xin : STD_LOGIC;
SIGNAL  EgntS_Xout: STD_LOGIC;
SIGNAL  EgntW_Xin : STD_LOGIC;
SIGNAL  EgntW_Xout: STD_LOGIC;
-- Grants from S
SIGNAL  SgntL_Xin : STD_LOGIC;
SIGNAL  SgntL_Xout: STD_LOGIC;
SIGNAL  SgntN_Xin : STD_LOGIC;
SIGNAL  SgntN_Xout: STD_LOGIC;
SIGNAL  SgntE_Xin : STD_LOGIC;
SIGNAL  SgntE_Xout: STD_LOGIC;
SIGNAL  SgntW_Xin : STD_LOGIC;
SIGNAL  SgntW_Xout: STD_LOGIC;
-- Grants from W
SIGNAL  WgntL_Xin : STD_LOGIC;
SIGNAL  WgntL_Xout: STD_LOGIC;
SIGNAL  WgntN_Xin : STD_LOGIC;
SIGNAL  WgntN_Xout: STD_LOGIC;
SIGNAL  WgntE_Xin : STD_LOGIC;
SIGNAL  WgntE_Xout: STD_LOGIC;
SIGNAL  WgntS_Xin : STD_LOGIC;
SIGNAL  WgntS_Xout: STD_LOGIC;
-- Data buses
SIGNAL  Ldata     : STD_LOGIC_VECTOR(DATA_WIDTH+1 DOWNTO 0);
SIGNAL  Ndata     : STD_LOGIC_VECTOR(DATA_WIDTH+1 DOWNTO 0);
SIGNAL  Edata     : STD_LOGIC_VECTOR(DATA_WIDTH+1 DOWNTO 0);
SIGNAL  Sdata     : STD_LOGIC_VECTOR(DATA_WIDTH+1 DOWNTO 0);
SIGNAL  Wdata     : STD_LOGIC_VECTOR(DATA_WIDTH+1 DOWNTO 0);
-- Read Status
SIGNAL  Lrok      : STD_LOGIC;
SIGNAL  Nrok      : STD_LOGIC;
SIGNAL  Erok      : STD_LOGIC;
SIGNAL  Srok      : STD_LOGIC;
SIGNAL  Wrok      : STD_LOGIC;
-- Read Command
SIGNAL  Lrd       : STD_LOGIC;
SIGNAL  Nrd       : STD_LOGIC;
SIGNAL  Erd       : STD_LOGIC;
SIGNAL  Srd       : STD_LOGIC;
SIGNAL  Wrd       : STD_LOGIC;
-- idle
SIGNAL  Lidle     : STD_LOGIC;
SIGNAL  Nidle     : STD_LOGIC;
SIGNAL  Eidle     : STD_LOGIC;
SIGNAL  Sidle     : STD_LOGIC;
SIGNAL  Widle     : STD_LOGIC;

BEGIN

  --------
  Lin: Xin
  --------
  GENERIC MAP(
    XID             => XID,
    YID             => YID,
    USE_THIS        => USE_LOCAL,    
    MODULE_ID       => "L",
    DATA_WIDTH      => DATA_WIDTH,
    RIB_WIDTH       => RIB_WIDTH,
    ROUTING_TYPE    => ROUTING_TYPE,
    WF_TYPE         => WF_TYPE,
    FC_TYPE         => FC_TYPE,
    FIFO_TYPE       => XIN_FIFO_TYPE,
    FIFO_DEPTH      => LIN_FIFO_DEPTH,
    FIFO_LOG2_DEPTH => LIN_FIFO_LOG2_DEPTH,
    SWITCH_TYPE     => SWITCH_TYPE
  )
  PORT MAP(
    clk     => clk,
    rst     => rst,
    in_data => Lin_data,
    in_val  => Lin_val,
    in_ret  => Lin_ret,
    x_reqL  => Lunused,
    x_reqN  => LreqN_Xin,
    x_reqE  => LreqE_Xin,
    x_reqS  => LreqS_Xin,
    x_reqW  => LreqW_Xin,
    x_rok   => Lrok,
    x_rd(0) => Nrd,
    x_rd(1) => Erd,
    x_rd(2) => Srd,
    x_rd(3) => Wrd,
    x_gnt(0)=> NgntL_Xin,
    x_gnt(1)=> EgntL_Xin,
    x_gnt(2)=> SgntL_Xin,
    x_gnt(3)=> WgntL_Xin,
    x_Lidle => Lidle,
    x_Nidle => Nidle,
    x_Eidle => Eidle,
    x_Sidle => Sidle,
    x_Widle => Widle,
    x_dout  => Ldata  
  );
  
  
  --------
  Nin: Xin
  --------
  GENERIC MAP(
    XID             => XID,
    YID             => YID,
    USE_THIS        => USE_LOCAL,    
    MODULE_ID       => "N",
    DATA_WIDTH      => DATA_WIDTH,
    RIB_WIDTH       => RIB_WIDTH,
    ROUTING_TYPE    => ROUTING_TYPE,
    WF_TYPE         => WF_TYPE,
    FC_TYPE         => FC_TYPE,
    FIFO_TYPE       => XIN_FIFO_TYPE,
    FIFO_DEPTH      => NIN_FIFO_DEPTH,
    FIFO_LOG2_DEPTH => NIN_FIFO_LOG2_DEPTH,
    SWITCH_TYPE     => SWITCH_TYPE
  )
  PORT MAP(
    clk     => clk,
    rst     => rst,
    in_data => Nin_data,
    in_val  => Nin_val,
    in_ret  => Nin_ret,
    x_reqL  => NreqL_Xin,
    x_reqN  => Nunused,
    x_reqE  => NreqE_Xin,
    x_reqS  => NreqS_Xin,
    x_reqW  => NreqW_Xin,
    x_rok   => Nrok,
    x_rd(0) => Lrd,
    x_rd(1) => Erd,
    x_rd(2) => Srd,
    x_rd(3) => Wrd,
    x_gnt(0)=> LgntN_Xin,
    x_gnt(1)=> EgntN_Xin,
    x_gnt(2)=> SgntN_Xin,
    x_gnt(3)=> WgntN_Xin, 
    x_Lidle => Lidle,
    x_Nidle => Nidle,
    x_Eidle => Eidle,
    x_Sidle => Sidle,
    x_Widle => Widle,
    x_dout  => Ndata  
  );
    

  --------
  Ein: Xin
  --------
  GENERIC MAP(
    XID             => XID,
    YID             => YID,
    USE_THIS        => USE_LOCAL,    
    MODULE_ID       => "E",
    DATA_WIDTH      => DATA_WIDTH,
    RIB_WIDTH       => RIB_WIDTH,
    ROUTING_TYPE    => ROUTING_TYPE,
    WF_TYPE         => WF_TYPE,
    FC_TYPE         => FC_TYPE,
    FIFO_TYPE       => XIN_FIFO_TYPE,
    FIFO_DEPTH      => EIN_FIFO_DEPTH,
    FIFO_LOG2_DEPTH => EIN_FIFO_LOG2_DEPTH,
    SWITCH_TYPE     => SWITCH_TYPE
  )
  PORT MAP(
    clk     => clk,
    rst     => rst,
    in_data => Ein_data,
    in_val  => Ein_val,
    in_ret  => Ein_ret,
    x_gnt(0)=> LgntE_Xin,
    x_gnt(1)=> NgntE_Xin,
    x_gnt(2)=> SgntE_Xin,
    x_gnt(3)=> WgntE_Xin,
    x_rd(0) => Lrd,
    x_rd(1) => Nrd,
    x_rd(2) => Srd,
    x_rd(3) => Wrd,
    x_Lidle => Lidle,
    x_Nidle => Nidle,
    x_Eidle => Eidle,
    x_Sidle => Sidle,
    x_Widle => Widle,
    x_dout  => Edata,  
    x_reqL  => EreqL_Xin,
    x_reqN  => EreqN_Xin,
    x_reqE  => Eunused,
    x_reqS  => EreqS_Xin,
    x_reqW  => EreqW_Xin,
    x_rok   => Erok
  );
    
  --------
  Sin: Xin
  --------
  GENERIC MAP(
    XID             => XID,
    YID             => YID,
    USE_THIS        => USE_LOCAL,    
    MODULE_ID       => "S",
    DATA_WIDTH      => DATA_WIDTH,
    RIB_WIDTH       => RIB_WIDTH,
    ROUTING_TYPE    => ROUTING_TYPE,
    WF_TYPE         => WF_TYPE,
    FC_TYPE         => FC_TYPE,
    FIFO_TYPE       => XIN_FIFO_TYPE,
    FIFO_DEPTH      => SIN_FIFO_DEPTH,
    FIFO_LOG2_DEPTH => SIN_FIFO_LOG2_DEPTH,
    SWITCH_TYPE     => SWITCH_TYPE
  )
  PORT MAP(
    clk     => clk,
    rst     => rst,
    in_data => Sin_data,
    in_val  => Sin_val,
    in_ret  => Sin_ret,
    x_reqL  => SreqL_Xin,
    x_reqN  => SreqN_Xin,
    x_reqE  => SreqE_Xin,
    x_reqS  => Sunused,
    x_reqW  => SreqW_Xin,
    x_rok   => Srok,
    x_rd(0) => Lrd,
    x_rd(1) => Nrd,
    x_rd(2) => Erd,
    x_rd(3) => Wrd,
    x_gnt(0)=> LgntS_Xin,
    x_gnt(1)=> NgntS_Xin,
    x_gnt(2)=> EgntS_Xin,
    x_gnt(3)=> WgntS_Xin,
    x_Lidle => Lidle,
    x_Nidle => Nidle,
    x_Eidle => Eidle,
    x_Sidle => Sidle,
    x_Widle => Widle,
    x_dout  => Sdata
  );

  --------
  Win: Xin
  --------
  GENERIC MAP(
    XID             => XID,
    YID             => YID,
    USE_THIS        => USE_LOCAL,    
    MODULE_ID       => "W",
    DATA_WIDTH      => DATA_WIDTH,
    RIB_WIDTH       => RIB_WIDTH,
    ROUTING_TYPE    => ROUTING_TYPE,
    WF_TYPE         => WF_TYPE,
    FC_TYPE         => FC_TYPE,
    FIFO_TYPE       => XIN_FIFO_TYPE,
    FIFO_DEPTH      => WIN_FIFO_DEPTH,
    FIFO_LOG2_DEPTH => WIN_FIFO_LOG2_DEPTH,
    SWITCH_TYPE     => SWITCH_TYPE
  )
  PORT MAP(
    clk     => clk,
    rst     => rst,
    in_data => Win_data,
    in_val  => Win_val,
    in_ret  => Win_ret,
    x_reqL  => WreqL_Xin,
    x_reqN  => WreqN_Xin,
    x_reqE  => WreqE_Xin,
    x_reqS  => WreqS_Xin,
    x_reqW  => Wunused,
    x_rok   => Wrok,
    x_rd(0) => Lrd,
    x_rd(1) => Nrd,
    x_rd(2) => Erd,
    x_rd(3) => Srd,
    x_gnt(0)=> LgntW_Xin,
    x_gnt(1)=> NgntW_Xin,
    x_gnt(2)=> EgntW_Xin,
    x_gnt(3)=> SgntW_Xin,
    x_Lidle => Lidle,
    x_Nidle => Nidle,
    x_Eidle => Eidle,
    x_Sidle => Sidle,
    x_Widle => Widle,
    x_dout  => Wdata  
  );

  ----------
  Lout: Xout
  ----------
  GENERIC MAP(
    USE_THIS        => USE_LOCAL,    
    DATA_WIDTH      => DATA_WIDTH,
    FC_TYPE         => FC_TYPE,  
    FC_CREDIT       => LOUT_FC_CREDIT,
    FIFO_TYPE       => XOUT_FIFO_TYPE,
    FIFO_DEPTH      => LOUT_FIFO_DEPTH,
    FIFO_LOG2_DEPTH => LOUT_FIFO_LOG2_DEPTH,
    ARBITER_TYPE    => ARBITER_TYPE,
    SWITCH_TYPE     => SWITCH_TYPE
  )
  PORT MAP(
    clk      => clk,  
    rst      => rst,    
    out_data => Lout_data,    
    out_val  => Lout_val,
    out_ret  => Lout_ret,   
    x_req(0) => NreqL_Xout,   
    x_req(1) => EreqL_Xout,     
    x_req(2) => SreqL_Xout,     
    x_req(3) => WreqL_Xout,     
    x_rok(0) => Nrok,  
    x_rok(1) => Erok,    
    x_rok(2) => Srok,    
    x_rok(3) => Wrok,    
    x_rd     => Lrd,
    x_gnt(0) => LgntN_Xout,    
    x_gnt(1) => LgntE_Xout,    
    x_gnt(2) => LgntS_Xout,    
    x_gnt(3) => LgntW_Xout,
    x_idle   => Lidle,
    x_din0   => Ndata,
    x_din1   => Edata,
    x_din2   => Sdata,
    x_din3   => Wdata
  );    
    
  ----------
  Nout: Xout
  ----------
  GENERIC MAP(
    USE_THIS        => USE_NORTH,    
    DATA_WIDTH      => DATA_WIDTH,
    FC_TYPE         => FC_TYPE,  
    FC_CREDIT       => NOUT_FC_CREDIT,
    FIFO_TYPE       => XOUT_FIFO_TYPE,
    FIFO_DEPTH      => NOUT_FIFO_DEPTH,
    FIFO_LOG2_DEPTH => NOUT_FIFO_LOG2_DEPTH,
    ARBITER_TYPE    => ARBITER_TYPE,
    SWITCH_TYPE     => SWITCH_TYPE
   )
  PORT MAP(
    clk      => clk,  
    rst      => rst,    
    out_data => Nout_data,    
    out_val  => Nout_val,
    out_ret  => Nout_ret,   
    x_req(0) => LreqN_Xout,   
    x_req(1) => EreqN_Xout,     
    x_req(2) => SreqN_Xout,     
    x_req(3) => WreqN_Xout,     
    x_rok(0) => Lrok,  
    x_rok(1) => Erok,    
    x_rok(2) => Srok,    
    x_rok(3) => Wrok,    
    x_rd     => Nrd,
    x_gnt(0) => NgntL_Xout,    
    x_gnt(1) => NgntE_Xout,    
    x_gnt(2) => NgntS_Xout,    
    x_gnt(3) => NgntW_Xout,
    x_idle   => Nidle,
    x_din0   => Ldata,
    x_din1   => Edata,
    x_din2   => Sdata,
    x_din3   => Wdata
  );    
     
  ----------
  Eout: Xout
  ----------
  GENERIC MAP(
    USE_THIS        => USE_EAST,    
    DATA_WIDTH      => DATA_WIDTH,
    FC_TYPE         => FC_TYPE,  
    FC_CREDIT       => EOUT_FC_CREDIT,
    FIFO_TYPE       => XOUT_FIFO_TYPE,
    FIFO_DEPTH      => EOUT_FIFO_DEPTH,
    FIFO_LOG2_DEPTH => EOUT_FIFO_LOG2_DEPTH,
    ARBITER_TYPE    => ARBITER_TYPE,
    SWITCH_TYPE     => SWITCH_TYPE
  )
  PORT MAP(
    clk      => clk,  
    rst      => rst,    
    out_data => Eout_data,    
    out_val  => Eout_val,
    out_ret  => Eout_ret,   
    x_req(0) => LreqE_Xout,   
    x_req(1) => NreqE_Xout,     
    x_req(2) => SreqE_Xout,     
    x_req(3) => WreqE_Xout,     
    x_rok(0) => Lrok,  
    x_rok(1) => Nrok,    
    x_rok(2) => Srok,    
    x_rok(3) => Wrok,    
    x_rd     => Erd,  
    x_gnt(0) => EgntL_Xout,    
    x_gnt(1) => EgntN_Xout,    
    x_gnt(2) => EgntS_Xout,    
    x_gnt(3) => EgntW_Xout,
    x_idle   => Eidle,   
    x_din0   => Ldata,
    x_din1   => Ndata,
    x_din2   => Sdata,
    x_din3   => Wdata
  );      
     
  ----------
  Sout: Xout
  ----------
  GENERIC MAP(
    USE_THIS        => USE_SOUTH,    
    DATA_WIDTH      => DATA_WIDTH,
    FC_TYPE         => FC_TYPE,  
    FC_CREDIT       => SOUT_FC_CREDIT,
    FIFO_TYPE       => XOUT_FIFO_TYPE,
    FIFO_DEPTH      => SOUT_FIFO_DEPTH,
    FIFO_LOG2_DEPTH => SOUT_FIFO_LOG2_DEPTH,
    ARBITER_TYPE    => ARBITER_TYPE,
    SWITCH_TYPE     => SWITCH_TYPE 
  ) 
  PORT MAP(
    clk      => clk,  
    rst      => rst,    
    out_data => Sout_data,    
    out_val  => Sout_val,
    out_ret  => Sout_ret,   
    x_req(0) => LreqS_Xout,   
    x_req(1) => NreqS_Xout,     
    x_req(2) => EreqS_Xout,     
    x_req(3) => WreqS_Xout,     
    x_rok(0) => Lrok,  
    x_rok(1) => Nrok,    
    x_rok(2) => Erok,    
    x_rok(3) => Wrok,    
    x_rd     => Srd,
    x_gnt(0) => SgntL_Xout,    
    x_gnt(1) => SgntN_Xout,    
    x_gnt(2) => SgntE_Xout,    
    x_gnt(3) => SgntW_Xout,
    x_idle   => Sidle,
    x_din0   => Ldata,
    x_din1   => Ndata,
    x_din2   => Edata,
    x_din3   => Wdata  
  );    

  ----------
  Wout: Xout
  ----------
  GENERIC MAP(
    USE_THIS        => USE_WEST,    
    DATA_WIDTH      => DATA_WIDTH,
    FC_TYPE         => FC_TYPE,  
    FC_CREDIT       => WOUT_FC_CREDIT,
    FIFO_TYPE       => XOUT_FIFO_TYPE,
    FIFO_DEPTH      => WOUT_FIFO_DEPTH,
    FIFO_LOG2_DEPTH => WOUT_FIFO_LOG2_DEPTH,
    ARBITER_TYPE    => ARBITER_TYPE,
    SWITCH_TYPE     => SWITCH_TYPE
  )
  PORT MAP(
    clk      => clk,  
    rst      => rst,    
    out_data => Wout_data,    
    out_val  => Wout_val,
    out_ret  => Wout_ret,   
    x_req(0) => LreqW_Xout,   
    x_req(1) => NreqW_Xout,     
    x_req(2) => EreqW_Xout,     
    x_req(3) => SreqW_Xout,     
    x_rok(0) => Lrok,  
    x_rok(1) => Nrok,    
    x_rok(2) => Erok,    
    x_rok(3) => Srok,
    x_rd     => Wrd,  
    x_gnt(0) => WgntL_Xout,    
    x_gnt(1) => WgntN_Xout,    
    x_gnt(2) => WgntE_Xout,    
    x_gnt(3) => WgntS_Xout,
    x_idle   => Widle,
    x_din0   => Ldata,
    x_din1   => Ndata,
    x_din2   => Edata,
    x_din3   => Sdata 
  );  
    
    
  -----
  X0: X
  -----
  GENERIC MAP(
    ROUTING_TYPE => ROUTING_TYPE
  )
  PORT MAP(
    LreqN_in  => LreqN_Xin,
    LreqE_in  => LreqE_Xin,
    LreqS_in  => LreqS_Xin,
    LreqW_in  => LreqW_Xin,
    ------------------------
    LreqN_out => LreqN_Xout,
    LreqE_out => LreqE_Xout,
    LreqS_out => LreqS_Xout,
    LreqW_out => LreqW_Xout,
    ------------------------
    NreqL_in  => NreqL_Xin,
    NreqE_in  => NreqE_Xin,
    NreqS_in  => NreqS_Xin,
    NreqW_in  => NreqW_Xin,
    ------------------------
    NreqL_out => NreqL_Xout,
    NreqE_out => NreqE_Xout,
    NreqS_out => NreqS_Xout,
    NreqW_out => NreqW_Xout,
    ------------------------
    EreqL_in  => EreqL_Xin,
    EreqN_in  => EreqN_Xin,
    EreqS_in  => EreqS_Xin,
    EreqW_in  => EreqW_Xin,
    ------------------------
    EreqL_out => EreqL_Xout,
    EreqN_out => EreqN_Xout,
    EreqS_out => EreqS_Xout,
    EreqW_out => EreqW_Xout,
    ------------------------
    SreqL_in  => SreqL_Xin,
    SreqN_in  => SreqN_Xin,
    SreqE_in  => SreqE_Xin,
    SreqW_in  => SreqW_Xin,
    ------------------------
    SreqL_out => SreqL_Xout,
    SreqN_out => SreqN_Xout,
    SreqE_out => SreqE_Xout,
    SreqW_out => SreqW_Xout,
    ------------------------
    WreqL_in  => WreqL_Xin,
    WreqN_in  => WreqN_Xin,
    WreqE_in  => WreqE_Xin,
    WreqS_in  => WreqS_Xin,
    ------------------------
    WreqL_out => WreqL_Xout,
    WreqN_out => WreqN_Xout,
    WreqE_out => WreqE_Xout,
    WreqS_out => WreqS_Xout,
    ------------------------

    LgntN_in  => LgntN_Xout,
    LgntE_in  => LgntE_Xout,
    LgntS_in  => LgntS_Xout,
    LgntW_in  => LgntW_Xout,
    ------------------------
    LgntN_out => LgntN_Xin,
    LgntE_out => LgntE_Xin,
    LgntS_out => LgntS_Xin,
    LgntW_out => LgntW_Xin,
    ------------------------
    NgntL_in  => NgntL_Xout,
    NgntE_in  => NgntE_Xout,
    NgntS_in  => NgntS_Xout,
    NgntW_in  => NgntW_Xout,  
    ------------------------
    NgntL_out => NgntL_Xin,
    NgntE_out => NgntE_Xin,
    NgntS_out => NgntS_Xin,
    NgntW_out => NgntW_Xin,
    ------------------------
    EgntL_in  => EgntL_Xout,
    EgntN_in  => EgntN_Xout,
    EgntS_in  => EgntS_Xout,
    EgntW_in  => EgntW_Xout,
    ------------------------
    EgntL_out => EgntL_Xin,
    EgntN_out => EgntN_Xin,
    EgntS_out => EgntS_Xin,
    EgntW_out => EgntW_Xin,
    ------------------------
    SgntL_in  => SgntL_Xout,
    SgntN_in  => SgntN_Xout,
    SgntE_in  => SgntE_Xout,
    SgntW_in  => SgntW_Xout,
    ------------------------
    SgntL_out => SgntL_Xin,
    SgntN_out => SgntN_Xin,
    SgntE_out => SgntE_Xin,
    SgntW_out => SgntW_Xin,
    ------------------------
    WgntL_in  => WgntL_Xout,
    WgntN_in  => WgntN_Xout,
    WgntE_in  => WgntE_Xout, 
    WgntS_in  => WgntS_Xout,
    ------------------------
    WgntL_out => WgntL_Xin,
    WgntN_out => WgntN_Xin,
    WgntE_out => WgntE_Xin,
    WgntS_out => WgntS_Xin);

END arch_1;  
