------------------------------------------------------------------------------
-- PROJECT: ParIS
-- ENTITY : fifo
------------------------------------------------------------------------------
-- DESCRIPTION: A FIFO entity offering for alternatives of implementation:
-- (a) NONE:   to be used when the goal is not implement the FIFO, just wires
-- (b) RING:   a ring  FIFO architecture based on logic and flip-flops
-- (c) SHIFT:  a shift FIFO architecture based on logic and flip-flops
-- (d) ALTERA: a FIFO architecture based on an Altera's LPM which is mapped 
--             onto embedded SRAM bits (it saves logic and registers)
------------------------------------------------------------------------------
-- AUTHORS: Frederico G. M. do Espirito Santo 
--          Cesar Albenes Zeferino
-- CONTACT: zeferino@univali.br OR cesar.zeferino@gmail.com
------------------------------------------------------------------------------
LIBRARY ieee;
LIBRARY lpm;
USE lpm.lpm_components.all;
USE ieee.std_logic_1164.all;
--------------
--------------
ENTITY fifo IS
--------------
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
END fifo;

------------------------------
------------------------------
ARCHITECTURE arch_1 OF fifo IS
------------------------------
------------------------------
SIGNAL state : INTEGER RANGE DEPTH DOWNTO 0;         -- current FIFO state 

-------------------------
COMPONENT fifo_controller
-------------------------
  GENERIC (
    WIDTH : INTEGER := 8;   -- width of each position
    DEPTH : INTEGER := 4    -- number of positions
  );
  PORT(
    -- System signals
    clk   : IN  STD_LOGIC;  -- clock
    rst   : IN  STD_LOGIC;  -- reset

    -- FIFO interface
    rd    : IN  STD_LOGIC;  -- command to read  a data from the FIFO
    wr    : IN  STD_LOGIC;  -- command to write a data into the FIFO

    -- Control interface
    state : OUT INTEGER RANGE DEPTH DOWNTO 0      -- current FIFO state    
  );
END COMPONENT;

-----------------------------
COMPONENT fifo_datapath_shift
-----------------------------
  GENERIC (
    WIDTH : INTEGER := 8;   -- width of each position
    DEPTH : INTEGER := 4    -- number of positions
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
    dout  : OUT STD_LOGIC_VECTOR(WIDTH-1 DOWNTO 0);  -- output data channel

    -- Control-to-datapath interface
    state : IN  INTEGER RANGE DEPTH DOWNTO 0         -- current FIFO state    
  );
END COMPONENT;

----------------------------
COMPONENT fifo_datapath_ring
----------------------------
  GENERIC (
    WIDTH : INTEGER := 8;   -- width of each position
    DEPTH : INTEGER := 4    -- number of positions
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
    dout  : OUT STD_LOGIC_VECTOR(WIDTH-1 DOWNTO 0);  -- output data channel

    -- Control to datapath interface
    state : IN  INTEGER RANGE DEPTH DOWNTO 0);  -- current FIFO state    
END COMPONENT;

---------------------
COMPONENT fifo_altera
---------------------
  GENERIC (
    WIDTH      : INTEGER := 8; -- width of each position
    DEPTH      : INTEGER := 4; -- number of positions
    LOG2_DEPTH : INTEGER := 1  -- log2 of the number of positions 
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
END component;

BEGIN
---------
---------
no_fifo :
---------
---------
  IF (FIFO_TYPE="NONE") GENERATE
    rok  <= wr;
    wok  <= rd;
    dout <= din;
  END GENERATE;

------------
------------
fifo_shift :
------------
------------
  IF (FIFO_TYPE="SHIFT") GENERATE
    --------------------
    U0 : fifo_controller
    --------------------
      GENERIC MAP (
        DEPTH => DEPTH
      )
      PORT MAP(
        rst   => rst,
        clk   => clk,
        wr    => wr,
        rd    => rd,
        state => state
      );
    
    ------------------------
    U1 : fifo_datapath_shift
    ------------------------
      GENERIC MAP (
        WIDTH => WIDTH,
        DEPTH => DEPTH
      )
      PORT MAP(
        rst   => rst,
        clk   => clk,
        wr    => wr,
        rd    => rd,
        din   => din,
        dout  => dout,
        wok   => wok,
        rok   => rok,
        state => state
      );
  END GENERATE;

-----------
-----------
fifo_ring :
-----------
-----------
  IF (FIFO_TYPE="RING") GENERATE
    -------------------
    U2: fifo_controller
    -------------------
      GENERIC MAP (
        DEPTH => DEPTH
      )
      PORT MAP(
        rst   => rst,
        clk   => clk,
        wr    => wr,
        rd    => rd,
        state => state
      );
    
    -----------------------
    U3 : fifo_datapath_ring
    -----------------------
      GENERIC MAP (
        WIDTH => WIDTH,
        DEPTH => DEPTH
      )
      PORT MAP(
        clk   => clk,
        rst   => rst,
        wr    => wr,
        rd    => rd,
        din   => din,
        dout  => dout,
        wok   => wok,
        rok   => rok,
        state => state
      );
  END GENERATE;

-----------------
-----------------
fifo_lpm_altera :
-----------------
-----------------
  IF (FIFO_TYPE="ALTERA") GENERATE
    ----------------
    U4 : fifo_altera
    ----------------
    GENERIC MAP(
      WIDTH      => WIDTH,
      DEPTH      => DEPTH,
      LOG2_DEPTH => LOG2_DEPTH
    )
    PORT MAP(
      clk   => clk,
      rst   => rst,
      wr    => wr,
      rd    => rd,
      din   => din,
      dout  => dout,
      wok   => wok,
      rok   => rok
    );  
  END GENERATE;
    
END arch_1;

