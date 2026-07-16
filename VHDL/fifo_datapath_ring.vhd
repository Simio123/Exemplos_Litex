------------------------------------------------------------------------------
-- PROJECT: ParIS
-- ENTITY : fifo_datapath_ring
------------------------------------------------------------------------------
-- DESCRIPTION: A datapath for the FIFO based on a ring of register with DEPTH
-- cells, each one with WIDTH bits. A new data is written into a position 
-- defined by a write pointer. In the same way, the cell to be accessed during 
-- a reading is defined by a read pointer. Such pointers are updated at a
-- writing or a reading. 
------------------------------------------------------------------------------
-- AUTHORS: Frederico G. M. do Espirito Santo 
--          Cesar Albenes Zeferino
-- CONTACT: zeferino@univali.br OR cesar.zeferino@gmail.com
------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_arith.all;
----------------------------
----------------------------
ENTITY fifo_datapath_ring IS
----------------------------
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
END fifo_datapath_ring;

--------------------------------------------
--------------------------------------------
ARCHITECTURE arch_1 OF fifo_datapath_ring IS
--------------------------------------------
--------------------------------------------
-- Type and signal to implement the FIFO
TYPE FIFO_TYPE IS ARRAY (DEPTH-1 DOWNTO 0) OF STD_LOGIC_VECTOR(WIDTH-1 DOWNTO 0);
SIGNAL fifo        : FIFO_TYPE;

-- Pointers
SIGNAL rd_ptr_reg  : INTEGER RANGE DEPTH-1 DOWNTO 0; -- read  pointer
SIGNAL wr_ptr_reg  : INTEGER RANGE DEPTH-1 DOWNTO 0; -- write pointer
SIGNAL next_rd_ptr : INTEGER RANGE DEPTH-1 DOWNTO 0; -- next read  pointer
SIGNAL next_wr_ptr : INTEGER RANGE DEPTH-1 DOWNTO 0; -- next write pointer

BEGIN
----------- next write pointer
PROCESS(state, wr, wr_ptr_reg)
------------------------------
  -- Determines the next write pointer, by incrementing the current one 
  -- when the FIFO is not full and there is a writing into the FIFO.
  BEGIN
    IF ((state/=DEPTH) AND (wr='1')) THEN
      IF (wr_ptr_reg=(DEPTH-1)) THEN 
        next_wr_ptr <= 0;
      ELSE
        next_wr_ptr <= wr_ptr_reg+1;
      END IF;
    ELSE
      next_wr_ptr <= wr_ptr_reg;
    END IF;
  END PROCESS p_next_wr_ptr;
 
 
----------- next read pointer
PROCESS(state, rd, rd_ptr_reg)
------------------------------
  -- Determines the next read pointer, by decrementing the current one 
  -- when the FIFO is not empty and there is a reading from the FIFO.
  BEGIN
    IF ((state/=0) AND (rd='1')) THEN
      IF (rd_ptr_reg=(DEPTH-1)) THEN 
        next_rd_ptr <= 0;
      ELSE
        next_rd_ptr <= rd_ptr_reg+1;
      END IF;
    ELSE
      next_rd_ptr <= rd_ptr_reg;
    END IF;
  END PROCESS p_next_rd_ptr;
  
------ pointers
PROCESS(clk,rst)
----------------
  -- Implements the pointer registers
  BEGIN
    IF (rst='1') THEN
      wr_ptr_reg <= 0;
      rd_ptr_reg <= 0;
    ELSIF (clk'EVENT AND clk='1') THEN
      wr_ptr_reg <= next_wr_ptr;
      rd_ptr_reg <= next_rd_ptr;
    END IF;
  END PROCESS p_reg;

---- wr2fifo
PROCESS(clk)
------------
  -- Implements the FIFO memory
  VARIABLE index  : INTEGER RANGE DEPTH-1 DOWNTO 0;
  BEGIN
     IF (clk'EVENT AND clk='1') THEN
      IF ((wr='1') AND (state/=DEPTH)) THEN
        FOR index IN 0 TO (DEPTH-1) LOOP 
          IF (index=wr_ptr_reg) THEN
            fifo(index) <= din;
          ELSE
            fifo(index) <= fifo(index);
          END IF;
        END LOOP;
      END IF;
    END IF;
  END PROCESS p_wr_fifo;

----- data
-- OUTPUTS
----------
  dout <= fifo(rd_ptr_reg);

-------- status
PROCESS (state)
---------------
  BEGIN
    IF (state=0) THEN
      rok <= '0';
      wok <= '1';
    ELSIF (state=DEPTH) THEN
      rok <= '1';    
      wok <= '0';
    ELSE
      rok <= '1';
      wok <= '1';
    END IF;
  END PROCESS;
END arch_1;

