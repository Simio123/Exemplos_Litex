------------------------------------------------------------------------------
-- PROJECT: ParIS
-- ENTITY : Xout (output_channel)
------------------------------------------------------------------------------
-- DESCRIPTION: Output channel module
------------------------------------------------------------------------------
-- AUTHORS: Frederico G. M. do Espirito Santo 
--          Cesar Albenes Zeferino
-- CONTACT: zeferino@univali.br OR cesar.zeferino@gmail.com
------------------------------------------------------------------------------
 
LIBRARY ieee;
USE ieee.std_logic_1164.all; LIBRARY ieee;
USE ieee.STD_LOGIC_arith.all;
USE ieee.STD_LOGIC_signed.all;
USE ieee.std_logic_1164.all;
--------------
--------------
ENTITY Xout IS
--------------
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
    x_gnt     : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);    -- grant to the inputs
    x_idle    : OUT STD_LOGIC;                        -- status to  the inputs

    -- Data from the input channels
    x_din0    : IN  STD_LOGIC_VECTOR(DATA_WIDTH+1 DOWNTO 0); -- channel 0 
    x_din1    : IN  STD_LOGIC_VECTOR(DATA_WIDTH+1 DOWNTO 0); -- channel 1
    x_din2    : IN  STD_LOGIC_VECTOR(DATA_WIDTH+1 DOWNTO 0); -- channel 2
    x_din3    : IN  STD_LOGIC_VECTOR(DATA_WIDTH+1 DOWNTO 0)  -- channel 3
  );
END Xout;

------------------------------
------------------------------
ARCHITECTURE arch_1 OF Xout IS
------------------------------
------------------------------

------------
COMPONENT oc
------------
  GENERIC (
    ARBITER_TYPE : STRING  := "ROUND_ROBIN"; -- options: "ROUND_ROBIN"
    N            : INTEGER := 4              -- number of requests
  );
  PORT (
    -- System signals
    clk  : IN  STD_LOGIC;  -- clock
    rst  : IN  STD_LOGIC;  -- reset
      
    -- Arbitration signals
    R    : IN  STD_LOGIC_VECTOR(N-1 DOWNTO 0); -- request
    G    : OUT STD_LOGIC_VECTOR(N-1 DOWNTO 0); -- grants
    idle : OUT STD_LOGIC                       -- status
);
END COMPONENT;

-------------
COMPONENT ods
-------------
  GENERIC (
    SWITCH_TYPE : STRING  := "LOGIC"; -- options: LOGIC (to implement: TRI)
    WIDTH       : INTEGER := 8        -- channels width
  );
  PORT(
    sel  : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);       -- input selector 
    din0 : IN  STD_LOGIC_VECTOR(WIDTH-1 DOWNTO 0); -- data from input channel 0
    din1 : IN  STD_LOGIC_VECTOR(WIDTH-1 DOWNTO 0); -- data from input channel 1
    din2 : IN  STD_LOGIC_VECTOR(WIDTH-1 DOWNTO 0); -- data from input channel 2
    din3 : IN  STD_LOGIC_VECTOR(WIDTH-1 DOWNTO 0); -- data from input channel 3

    -- selected data channel and framing bits
    dout : OUT STD_LOGIC_VECTOR(WIDTH-1 DOWNTO 0)
  );
END COMPONENT;

-------------
COMPONENT ows
-------------
  GENERIC (
    SWITCH_TYPE : STRING  := "LOGIC"   -- options: LOGIC (to implement: TRI)
  );
  PORT(
    sel   : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);  -- input selector
    wrin  : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);  -- wr cmd from input channels
    wrout : OUT STD_LOGIC                      -- selected write command 
  );
END COMPONENT;

-------------
COMPONENT ofc
-------------
  GENERIC (
    FC_TYPE   : STRING  := "CREDIT";    -- options: CREDIT or HANDSHAKE
    CREDIT    : INTEGER := 4            -- maximum number of credits
  );
  PORT(
    -- System interface
    rst : IN  STD_LOGIC;  -- reset        
    clk : IN  STD_LOGIC;  -- clock  

    -- Link interface
    val : OUT STD_LOGIC;  -- data validation
    ret : IN  STD_LOGIC;  -- return (credit or acknowledgement)

    -- FIFO interface
    rd  : OUT STD_LOGIC;  -- read comand 
    rok : IN  STD_LOGIC   -- FIFO not empty (it is able to be read)
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

----------
-- SIGNALS
----------
SIGNAL gnt   : STD_LOGIC_VECTOR(3 downto 0);
SIGNAL val   : STD_LOGIC;
SIGNAL ret   : STD_LOGIC;
SIGNAL rd    : STD_LOGIC;
SIGNAL rok   : STD_LOGIC;
SIGNAL idle  : STD_LOGIC;
SIGNAL din   : STD_LOGIC_VECTOR(DATA_WIDTH+1 DOWNTO 0);
SIGNAL dout  : STD_LOGIC_VECTOR(DATA_WIDTH+1 DOWNTO 0);
SIGNAL wr    : STD_LOGIC;
SIGNAL wok   : STD_LOGIC;

BEGIN

  ---------------
  empty_channel :
  ---------------
    IF (USE_THIS=0) GENERATE
      out_val  <= '0';
      out_data <= (others => '0');
      x_rd     <= '0';
      x_gnt    <= (others => '0');
      x_idle   <= '0';
    END GENERATE;

  --------------
  full_channel :
  --------------
    IF (USE_THIS/=0) GENERATE
      ------
      U0: oc
      ------
        GENERIC MAP (
          ARBITER_TYPE => ARBITER_TYPE,
          N            => 4             
        )
        PORT MAP(
          rst   => rst,
          clk   => clk,
          R     => x_req,
          G     => gnt,
          idle  => idle
        );
    
    -------
    U1: ods
    -------
      GENERIC MAP(
        SWITCH_TYPE => SWITCH_TYPE,
        WIDTH       => DATA_WIDTH+2
      )
      PORT MAP(
        sel  => gnt,
        din0 => x_din0,
        din1 => x_din1,
        din2 => x_din2,
        din3 => x_din3,  
        dout => din
      );      
      
    -------
    U2: ows
    -------
      GENERIC MAP(
        SWITCH_TYPE => SWITCH_TYPE
      )
      PORT MAP(
        sel   => gnt,
        wrin  => x_rok,
        wrout => wr  
      );
    
    --------
    U3: fifo
    --------
      GENERIC MAP (
        FIFO_TYPE  => FIFO_TYPE,
        WIDTH      => DATA_WIDTH+2,
        DEPTH      => FIFO_DEPTH,
        LOG2_DEPTH => FIFO_LOG2_DEPTH  
      )
      PORT MAP (
        rst  => rst,
        clk  => clk,
        wr   => wr,
        rd   => rd,
        din  => din,
        dout => dout,
        wok  => wok,
        rok  => rok
      );
    
    -------
    U4: ofc
    -------
      GENERIC MAP (
        FC_TYPE => FC_TYPE,
        CREDIT  => FC_CREDIT
      )  
      PORT MAP(
        rst   => rst, 
        clk   => clk,
        val   => out_val,
        ret   => out_ret,
        rd    => rd,
        rok   => rok
      );

    ----------
    -- OUTPUTS
    ----------
    out_data <= dout;
    x_rd     <= wok;    
    x_gnt    <= gnt;
    x_idle   <= idle;

  END GENERATE;

END arch_1;
