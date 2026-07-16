------------------------------------------------------------------------------
-- PROJECT: ParIS
-- ENTITY : ic (input_controller)
------------------------------------------------------------------------------
-- DESCRIPTION: Controller responsible to detect the header of an incoming
-- packet, schedule an output channel to be requested (routing), and hold the
-- request until the packet trailer is delivered.
------------------------------------------------------------------------------
-- AUTHORS: Frederico G. M. do Espirito Santo 
--          Cesar Albenes Zeferino
-- CONTACT: zeferino@univali.br OR cesar.zeferino@gmail.com
------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.STD_LOGIC_1164.all;

------------
------------
ENTITY ic IS
------------
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
END ic;

----------------------------
----------------------------
ARCHITECTURE arch_1 OF ic IS
----------------------------
----------------------------
-- Signals to connect the routing function to the request register.
SIGNAL s_reqL : STD_LOGIC;  -- request to Lout
SIGNAL s_reqN : STD_LOGIC;  -- request to Nout
SIGNAL s_reqE : STD_LOGIC;  -- request to Eout
SIGNAL s_reqS : STD_LOGIC;  -- request to Sout
SIGNAL s_reqW : STD_LOGIC;  -- request to Wout

--------------------
COMPONENT routing_wf
--------------------
  GENERIC(
    WF_TYPE   : STRING  := "Y_BEFORE_E";   -- options: E_BEFORE_Y, Y_BEFORE_E
    RIB_WIDTH : INTEGER := 8; -- width of the RIB field in the header
    XID       : INTEGER := 3; -- x-coordinate  
    YID       : INTEGER := 3  -- y-coordinate
  );
  PORT (
    -- Coordinates of the destination node
    Xdest : IN  STD_LOGIC_VECTOR (RIB_WIDTH/2-1 DOWNTO 0); -- x-coordinate  
    Ydest : IN  STD_LOGIC_VECTOR (RIB_WIDTH/2-1 DOWNTO 0); -- y-coordinate

    -- Framing bits
    bop   : IN  STD_LOGIC;  -- packet framing bit: begin of packet

    -- FIFO interface
    rok   : IN  STD_LOGIC;  -- FIFO has a data to be read  (not empty)

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

--------------------
COMPONENT routing_xy
--------------------
  GENERIC(
    RIB_WIDTH : INTEGER := 8; -- width of the RIB field in the header
    XID       : INTEGER := 3; -- x-coordinate  
    YID       : INTEGER := 3  -- y-coordinate
  );
  PORT (
    -- Coordinates of the destination node
    Xdest : IN  STD_LOGIC_VECTOR (RIB_WIDTH/2-1 DOWNTO 0); -- x-coordinate  
    Ydest : IN  STD_LOGIC_VECTOR (RIB_WIDTH/2-1 DOWNTO 0); -- y-coordinate

    -- Framing bits
    bop   : IN  STD_LOGIC;  -- packet framing bit: begin of packet

    -- FIFO interface
    rok   : IN  STD_LOGIC;  -- FIFO has a data to be read  (not empty)

    -- Requests
    reqL  : OUT STD_LOGIC;  -- request to Lout
    reqN  : OUT STD_LOGIC;  -- request to Nout
    reqE  : OUT STD_LOGIC;  -- request to Eout
    reqS  : OUT STD_LOGIC;  -- request to Sout
    reqW  : OUT STD_LOGIC   -- request to Wout
  );
END COMPONENT;

-----------------
COMPONENT req_reg
-----------------
  GENERIC (
    MODULE_ID    : STRING := "L";  -- identifier of the port in the router
    ROUTING_TYPE : STRING := "WF"  -- type of routing algorithm
  );
  PORT(
    -- System signals
    clk      : IN  STD_LOGIC;  -- clock
    rst      : IN  STD_LOGIC;  -- reset

    -- FIFO interface
    rok      : IN  STD_LOGIC;  -- FIFO has a data to be read (not empty)
    rd       : IN  STD_LOGIC;  -- command to read a data from the FIFO

    -- Framing bits
    bop      : IN  STD_LOGIC;  -- packet framing bit: begin of packet
    eop      : IN  STD_LOGIC;  -- packet framing bit: end   of packet

    -- Requests
    in_reqL  : IN  STD_LOGIC;  -- request to Lout (input)
    in_reqN  : IN  STD_LOGIC;  -- request to Nout (input)
    in_reqE  : IN  STD_LOGIC;  -- request to Eout (input)
    in_reqS  : IN  STD_LOGIC;  -- request to Sout (input)
    in_reqW  : IN  STD_LOGIC;  -- request to Wout (input)
    out_reqL : OUT STD_LOGIC;  -- request to Lout (output)
    out_reqN : OUT STD_LOGIC;  -- request to Nout (output)
    out_reqE : OUT STD_LOGIC;  -- request to Eout (output)
    out_reqS : OUT STD_LOGIC;  -- request to Sout (output)
    out_reqW : OUT STD_LOGIC   -- request to Wout (output)
  );
END COMPONENT;


BEGIN
  -------
  IC_XY :
  -------
  IF (ROUTING_TYPE = "XY") GENERATE
    ---------------
    U0 : routing_xy
    ---------------
      GENERIC MAP (
        RIB_WIDTH => RIB_WIDTH,
        XID       => XID,
        YID       => YID
      )  
      PORT MAP(
        Xdest => Xdest,
        Ydest => Ydest,
        bop   => bop,
        rok   => rok,
        reqL  => s_reqL,
        reqN  => s_reqN,
        reqE  => s_reqE,
        reqS  => s_reqS,
        reqW  => s_reqW
      );
    END GENERATE;

  -------
  IC_WF :
  -------
  IF (ROUTING_TYPE = "WF") GENERATE
    ---------------
    U1 : routing_wf
    ---------------
      GENERIC MAP (
        WF_TYPE   => WF_TYPE,
        RIB_WIDTH => RIB_WIDTH,
        XID       => XID,
        YID       => YID
    )  
    PORT MAP(
      Xdest => Xdest,
      Ydest => Ydest,
      bop   => bop,
      rok   => rok,
      Lidle => Lidle,
      Nidle => Nidle,
      Eidle => Eidle,
      Sidle => Sidle,
      Widle => Widle,
      reqL  => s_reqL,
      reqN  => s_reqN,
      reqE  => s_reqE,
      reqS  => s_reqS,
      reqW  => s_reqW
    );
  END GENERATE;

  ------------
  U2 : req_reg
  ------------
    GENERIC MAP(
      MODULE_ID    => MODULE_ID,
      ROUTING_TYPE => ROUTING_TYPE
    )
    PORT MAP(
      clk      => clk,
      rst      => rst,
      rok      => rok,
      rd       => rd,
      bop      => bop,
      eop      => eop,
      in_reqL  => s_reqL,
      in_reqN  => s_reqN,
      in_reqE  => s_reqE,
      in_reqS  => s_reqS,
      in_reqW  => s_reqW,
      out_reqL => reqL,
      out_reqN => reqN,
      out_reqE => reqE,
      out_reqS => reqS,
      out_reqW => reqW
    );
END arch_1;

