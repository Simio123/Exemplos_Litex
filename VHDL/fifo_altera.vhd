------------------------------------------------------------------------------
-- PROJECT: ParIS
-- ENTITY : fifo_altera
------------------------------------------------------------------------------
-- DESCRIPTION: A FIFO architecture based on the Altera's LPM_FIFO.
------------------------------------------------------------------------------
-- AUTHORS: Frederico G. M. do Espirito Santo 
--          Cesar Albenes Zeferino
-- CONTACT: zeferino@univali.br OR cesar.zeferino@gmail.com
------------------------------------------------------------------------------
LIBRARY ieee;
LIBRARY lpm;
USE lpm.lpm_components.all;
USE ieee.std_logic_1164.all;
---------------------
---------------------
ENTITY fifo_altera IS
---------------------
---------------------
  GENERIC (
    WIDTH      : INTEGER := 8; -- width of each position
    DEPTH      : INTEGER := 4; -- number of positions
    LOG2_DEPTH : INTEGER := 2  -- log2 of the number of positions 
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
END fifo_altera;

-------------------------------------
-------------------------------------
ARCHITECTURE arch_1 OF fifo_altera IS
-------------------------------------
-------------------------------------
signal usedw : std_logic_vector((LOG2_DEPTH)-1 DOWNTO 0);  
signal full  : std_logic;  -- status: fifo is full
signal empty : std_logic;  -- status: fifo is empty
  
------------------
COMPONENT LPM_FIFO
------------------
  GENERIC(
    LPM_WIDTH     : POSITIVE;
    LPM_WIDTHU    : POSITIVE:= 1;
    LPM_NUMWORDS  : POSITIVE;
    LPM_SHOWAHEAD : STRING  := "OFF";
    LPM_TYPE      : STRING  := "LPM_FIFO";
    LPM_HINT      : STRING  := "UNUSED");
  PORT(
    data          : IN  STD_LOGIC_VECTOR(LPM_WIDTH-1 DOWNTO 0);
    clock         : IN  STD_LOGIC;
    wrreq         : IN  STD_LOGIC;
    rdreq         : IN  STD_LOGIC;
    aclr          : IN  STD_LOGIC:= '0';
    sclr          : IN  STD_LOGIC:= '0';
    full          : OUT STD_LOGIC;
    empty         : OUT STD_LOGIC;
    usedw         : OUT STD_LOGIC_VECTOR(LPM_WIDTHU-1 DOWNTO 0);
    q             : OUT STD_LOGIC_VECTOR(LPM_WIDTH-1 DOWNTO 0));
END COMPONENT;

BEGIN
-------------
U0 : lpm_fifo
-------------
  GENERIC MAP (
    LPM_WIDTH     => WIDTH,
    LPM_NUMWORDS  => DEPTH,  
    LPM_WIDTHU    => LOG2_DEPTH,
    LPM_SHOWAHEAD => "ON"
  )
  PORT MAP (
    data   => din, 
    clock  => clk,
    wrreq  => wr,
    rdreq  => rd,
    aclr   => rst,
    sclr   => rst,
    full   => full, 
    empty  => empty,
    usedw  => usedw,
    q      => dout
  );
  
  rok <= not empty;
  wok <= not full;

END arch_1;

