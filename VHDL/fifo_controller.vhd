------------------------------------------------------------------------------
-- PROJECT: ParIS
-- ENTITY : fifo_controller
------------------------------------------------------------------------------
-- DESCRIPTION: Control unit responsible to update the state of the FIFO at
-- each read or write operation. 
------------------------------------------------------------------------------
-- AUTHORS: Frederico G. M. do Espirito Santo 
--          Cesar Albenes Zeferino
-- CONTACT: zeferino@univali.br OR cesar.zeferino@gmail.com
------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_arith.all;
-------------------------
-------------------------
ENTITY fifo_controller IS
-------------------------
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
END fifo_controller;

-----------------------------------------
-----------------------------------------
ARCHITECTURE arch_1 OF fifo_controller IS
-----------------------------------------
-----------------------------------------
SIGNAL state_reg   : INTEGER RANGE DEPTH DOWNTO 0; -- current state
SIGNAL next_state  : INTEGER RANGE DEPTH DOWNTO 0; -- next state
BEGIN
  ------------- next state
  PROCESS(state_reg,wr,rd)
  ------------------------
  -- This process determines the next state of the FIFO taking into account
  -- the current state and the write and read commands, as follows:
  BEGIN
    -- FIFO EMPTY
    IF (state_reg = 0) THEN
      IF (wr='1') THEN
        next_state <= state_reg+1;
      ELSE
        next_state <= state_reg;
      END IF;

    -- FIFO FULL
    ELSIF (state_reg = DEPTH) THEN
      IF (rd='1') THEN
        next_state <= state_reg-1;
      ELSE
        next_state <= state_reg;
      END IF;

    -- FIFO NEITHER EMPTY, NEITHER FULL
    ELSE  
      IF (wr='1') THEN
        IF (rd='1') THEN
          next_state <= state_reg;    --  rd &  wr
        ELSE
          next_state <= state_reg+1;  -- /rd &  wr
        END IF;
      ELSIF (rd='1') THEN
        next_state <= state_reg-1;    --  rd & /wr
      ELSE
        next_state <= state_reg;      -- /rd & /wr
      END IF;
    END IF;
  END PROCESS p_next_state;

  -- current state
  PROCESS(clk,rst)
  ----------------
  BEGIN
    IF (rst='1') THEN
      state_reg  <= 0;
    ELSIF (clk'EVENT AND clk='1') THEN
      state_reg  <= next_state;
    END IF;
  END PROCESS p_state_reg;

  ---------
  -- OUTPUT
  ---------
  state <= state_reg;
END arch_1;

