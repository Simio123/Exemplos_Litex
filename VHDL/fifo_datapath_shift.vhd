------------------------------------------------------------------------------
-- PROJECT: ParIS
-- ENTITY : fifo_datapath_shift
------------------------------------------------------------------------------
-- DESCRIPTION: A datapath for the FIFO based on a shift register with DEPTH
-- cells, each one with WIDTH bits. A new data is always written into cell 0
-- and the old ones are shifted to right. The cell to be accessed during a 
-- reading is defined by a pointer, derived from the state provided by the
-- control block.
------------------------------------------------------------------------------
-- AUTHORS: Frederico G. M. do Espirito Santo 
--          Cesar Albenes Zeferino
-- CONTACT: zeferino@univali.br OR cesar.zeferino@gmail.com
------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_arith.all;
-----------------------------
-----------------------------
ENTITY fifo_datapath_shift IS
-----------------------------
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
END fifo_datapath_shift;

---------------------------------------------
---------------------------------------------
ARCHITECTURE arch_1 OF fifo_datapath_shift IS
---------------------------------------------
---------------------------------------------
-- Type and signal to implement the FIFO
TYPE FIFO_TYPE IS ARRAY (DEPTH-1 DOWNTO 0) OF STD_LOGIC_VECTOR(WIDTH-1 DOWNTO 0);
SIGNAL fifo   : FIFO_TYPE;

SIGNAL rd_ptr : INTEGER RANGE DEPTH-1 DOWNTO 0; -- read pointer
SIGNAL s_wok  : STD_LOGIC;                      -- a temporary signal for wok


BEGIN
---------------
-- Read pointer
---------------
  -- The read pointer is derived from the FIFO state (defined by the control).  
  WITH state SELECT
    rd_ptr  <=  0 WHEN 0,
             state-1 WHEN OTHERS;

-------------- wok
PROCESS(state, rd)
------------------
  -- wok equals 1 when FIFO is not full
  BEGIN
    IF (state/=DEPTH) THEN
      s_wok <= '1';
    ELSE
      s_wok <= '0';      
    END IF;
  END PROCESS p_wok;

------ write
PROCESS(clk)
------------
  -- If the FIFO is not full, a new data is written into FIFO(0), and the old
  -- ones are shifted to right.
  VARIABLE index  : INTEGER RANGE DEPTH-1 DOWNTO 0;
  BEGIN
     IF (clk'EVENT AND clk='1') THEN
      IF (wr='1' AND s_wok='1') THEN
        fifo(0) <= din;
        FOR index IN 1 TO (DEPTH-1) LOOP 
          fifo(index) <= fifo(index-1);
        END LOOP;
      END IF;
    END IF;
  END PROCESS p_wr_fifo;

  ----------
  -- Outputs
  ----------
  wok <= s_wok;
  
  WITH state SELECT
    rok  <= '0' WHEN 0,
            '1' WHEN OTHERS;

  dout <= fifo(rd_ptr); 

END arch_1;

