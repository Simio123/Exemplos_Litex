------------------------------------------------------------------------------
-- PROJECT: ParIS
-- ENTITY : Xin (input_channel)
------------------------------------------------------------------------------
-- DESCRIPTION: Input channel module
------------------------------------------------------------------------------
-- AUTHORS: Frederico G. M. do Espirito Santo 
--          Cesar Albenes Zeferino
-- CONTACT: zeferino@univali.br OR cesar.zeferino@gmail.com
------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;
-------------
-------------
ENTITY Xin IS
-------------
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
END Xin;

-----------------------------
-----------------------------
ARCHITECTURE arch_1 OF Xin IS
-----------------------------
-----------------------------

-------------
COMPONENT ifc
-------------
  GENERIC (
    FC_TYPE   : STRING  := "HANDSHAKE"     -- options: CREDIT or HANDSHAKE
  );
  PORT(
    -- System interface
    clk   : IN  STD_LOGIC;  -- clock
    rst   : IN  STD_LOGIC;  -- reset

    -- Link interface
    val   : IN  STD_LOGIC;  -- data validation
    ret   : OUT STD_LOGIC;  -- return (credit or acknowledgement)

    -- FIFO interface
    wr    : OUT STD_LOGIC;  -- command to write a data into de FIFO
    wok   : IN  STD_LOGIC;  -- FIFO has room to be written (not full)
    rd    : IN  STD_LOGIC;  -- command to read a data from the FIFO
    rok   : IN  STD_LOGIC   -- FIFO has a data to be read  (not empty)
  );
END COMPONENT;

--------------
COMPONENT fifo
--------------
  GENERIC (
    FIFO_TYPE  : STRING  := "NONE"; -- options: NONE, SHIFT, RING and ALTERA
    WIDTH      : INTEGER := 8;       -- width of each position
    DEPTH      : INTEGER := 4;       -- number of positions
    LOG2_DEPTH : INTEGER := 2        -- log2 of the number of positions 
  );
  PORT(
    -- System signals
    clk   : IN  STD_LOGIC;  -- clock
    rst   : IN  STD_LOGIC;  -- reset

    -- FIFO interface
    rok   : OUT STD_LOGIC;  -- FIFO has a data to be read  (not empty)
    wok   : OUT STD_LOGIC;  -- FIFO has room to be written (not full)
    rd    : IN  STD_LOGIC;  -- command to read a data from the FIFO
    wr    : IN  STD_LOGIC;  -- command to write a data into de FIFO
    din   : IN  STD_LOGIC_VECTOR(WIDTH-1 DOWNTO 0);  -- input  data channel
    dout  : OUT STD_LOGIC_VECTOR(WIDTH-1 DOWNTO 0)   -- output data channel
  );
END COMPONENT;

------------
COMPONENT ic
------------
  GENERIC (
    XID          : INTEGER := 3;    -- x-coordinate  
    YID          : INTEGER := 3;    -- y-coordinate
    MODULE_ID    : STRING  := "L";  -- identifier of the port in the router
    RIB_WIDTH    : INTEGER := 8;    -- width of the RIB field in the header
    ROUTING_TYPE : STRING  := "WF"; -- type of routing algorithm
    WF_TYPE      : STRING  := "Y_BEFORE_E" -- options: E_BEFORE_Y, Y_BEFORE_E
  );
  PORT(
    -- System signals
    clk   : IN  STD_LOGIC;  -- clock
    rst   : IN  STD_LOGIC;  -- reset

    -- Coordinates of the destination node
    Xdest : IN  STD_LOGIC_VECTOR (RIB_WIDTH/2-1 DOWNTO 0); -- x-coordinate  
    Ydest : IN  STD_LOGIC_VECTOR (RIB_WIDTH/2-1 DOWNTO 0); -- y-coordinate

    -- FIFO interface
    rok   : IN  STD_LOGIC;  -- FIFO has a data to be read (not empty)
    rd    : IN  STD_LOGIC;  -- command to read a data from the FIFO

    -- Framing bits
    bop   : IN  STD_LOGIC;  -- packet framing bit: begin of packet
    eop   : IN  STD_LOGIC;  -- packet framing bit: end   of packet

    -- Status of the output channels
    Lidle : IN  STD_LOGIC;  -- Lout is idle
    Nidle : IN  STD_LOGIC;  -- Nout is idle
    Eidle : IN  STD_LOGIC;  -- Eout is idle
    Sidle : IN  STD_LOGIC;  -- Sout is idle
    Widle : IN  STD_LOGIC;  -- Wout is idle

    -- Requests
    reqL  : OUT STD_LOGIC;  -- request to Lout
    reqN  : OUT STD_LOGIC;  -- request to Nout
    reqE  : OUT STD_LOGIC;  -- request to Eout
    reqS  : OUT STD_LOGIC;  -- request to Sout
    reqW  : OUT STD_LOGIC   -- request to Wout
  );
END COMPONENT;


-------------
COMPONENT irs
-------------
  GENERIC (
    SWITCH_TYPE : STRING  := "LOGIC"   -- options: LOGIC (to implement: TRI)
  );
  PORT(
    sel   : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);  -- input selector
    rdin  : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);  -- rd cmd from output channels
    rdout : OUT STD_LOGIC                      -- selected rd command 
  );
END COMPONENT;


----------
-- SIGNALS
----------
SIGNAL wr   : STD_LOGIC;  
SIGNAL wok  : STD_LOGIC;  
SIGNAL rd   : STD_LOGIC;  
SIGNAL rok  : STD_LOGIC;  
SIGNAL sel  : STD_LOGIC_VECTOR(3 DOWNTO 0); 
SIGNAL dout : STD_LOGIC_VECTOR(DATA_WIDTH+1 DOWNTO 0);

BEGIN

---------------
empty_channel :
---------------
  IF (USE_THIS=0) GENERATE
    in_ret <= '0';
    x_dout <= (others => '0');
    x_reqL <= '0';
    x_reqN <= '0';
    x_reqE <= '0';
    x_reqS <= '0';
    x_reqW <= '0';
    x_rok  <= '0';
  END GENERATE;

--------------
full_channel :
--------------
  IF (USE_THIS/=0) GENERATE
    --------
    U0 : ifc
    --------
      GENERIC MAP (
        FC_TYPE => FC_TYPE
      )
      PORT MAP (
        clk => clk,
        rst => rst,
        val => in_val,
        ret => in_ret,
        wr  => wr,
        wok => wok,
        rd  => rd,
        rok => rok
      );

    ---------
    U1 : fifo
    ---------
      GENERIC MAP (
        FIFO_TYPE  => FIFO_TYPE,
        WIDTH      => DATA_WIDTH+2,
        DEPTH      => FIFO_DEPTH,
        LOG2_DEPTH => FIFO_LOG2_DEPTH 
      )
      PORT MAP (
        clk  => clk,
        rst  => rst,
        wok  => wok,
        rok  => rok,
        rd   => rd,
        wr   => wr,
        din  => in_data,
        dout => dout
      );

    -------
    U2 : ic
    -------
      GENERIC MAP(
        XID          => XID,
        YID          => YID,
        MODULE_ID    => MODULE_ID,
        RIB_WIDTH    => RIB_WIDTH,
        ROUTING_TYPE => ROUTING_TYPE,
        WF_TYPE      => WF_TYPE
      )
      PORT MAP(
        clk   => clk,
        rst   => rst,
        Xdest => dout(RIB_WIDTH-1 DOWNTO RIB_WIDTH/2),
        Ydest => dout(RIB_WIDTH/2-1 DOWNTO 0),
        rok   => rok,
        rd    => rd,
        bop   => dout(DATA_WIDTH),
        eop   => dout(DATA_WIDTH+1),
        Lidle => x_Lidle,
        Nidle => x_Nidle,
        Eidle => x_Eidle,
        Sidle => x_Sidle,
        Widle => x_Widle,
        reqL  => x_reqL,
        reqN  => x_reqN,
        reqE  => x_reqE,
        reqS  => x_reqS,
        reqW  => x_reqW
      );

    --------
    U3 : irs
    --------
      GENERIC MAP (
        SWITCH_TYPE => SWITCH_TYPE 
      )
      PORT MAP(
        sel   => x_gnt,
        rdin  => x_rd,
        rdout => rd  
     );

    ----------
    -- OUTPUTS
    ----------
    x_rok  <= rok;
    x_dout <= dout;
  END GENERATE;

END arch_1;


