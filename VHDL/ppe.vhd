------------------------------------------------------------------------------
-- PROJECT: ParIS
-- ENTITY : ppe (programmable priority encoder)
------------------------------------------------------------------------------
-- DESCRIPTION: Programmable priority encoder that receives a set of requests 
-- and priorities, and, based on the current priorities, schedules one of the 
-- pending requests by giving it a grant. It is composed by "N" arbitration  
-- cells interconnected in a ripple loop (wrap-around connection), implemented 
-- by signals which notify the next cell if some of the previous cells has 
-- already granted a request. This entity also include a register which holds
-- the last granting until the granted request return to 0. A new grant can
-- only be given after the arbiter returns to the idle state.
------------------------------------------------------------------------------
-- AUTHORS: Frederico G. M. do Espirito Santo 
--          Cesar Albenes Zeferino
-- CONTACT: zeferino@univali.br OR cesar.zeferino@gmail.com
------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
-------------
-------------
ENTITY ppe IS
-------------
-------------
  GENERIC (
    N    : INTEGER := 4    -- number of requests
  );
  PORT (
    -- System signals
    clk  : IN  STD_LOGIC;  -- clock
    rst  : IN  STD_LOGIC;  -- reset
      
    -- Arbitration signals
    R    : IN  STD_LOGIC_VECTOR(N-1 DOWNTO 0); -- requests
    P    : IN  STD_LOGIC_VECTOR(N-1 DOWNTO 0); -- priorities
    G    : OUT STD_LOGIC_VECTOR(N-1 DOWNTO 0); -- grants
    idle : OUT STD_LOGIC                       -- status
);
END ppe;

-----------------------------
-----------------------------
ARCHITECTURE arch_1 OF ppe IS
-----------------------------
-----------------------------
SIGNAL Imed_in   : STD_LOGIC_VECTOR(N-1 DOWNTO 0); -- some of the previous cell granted a request
SIGNAL Imed_out  : STD_LOGIC_VECTOR(N-1 DOWNTO 0); -- a grant was already given
SIGNAL i         : INTEGER RANGE N-1 downto 0;     -- for-generate index
SIGNAL Grant     : STD_LOGIC_VECTOR(N-1 DOWNTO 0); -- grant signals  
SIGNAL Grant_reg : STD_LOGIC_VECTOR(N-1 DOWNTO 0); -- registered grant signals
SIGNAL s_idle    : STD_LOGIC;                      -- signal for the idle output

BEGIN
  --------------- arbitration cells
  F0:FOR i IN N-1 DOWNTO 0 GENERATE
  ---------------------------------
    -- Status from the previous arbitration cell 
    Imed_in(i)   <= Imed_out((i-1) mod N);
 
    -- Grant signal sent to the requesting block
    Grant(i)     <= R(i) and (not (Imed_in(i) and (not P(i)))); 

    -- Status to the next arbitration cell 
    Imed_out(i)  <= R(i) or (Imed_in(i) and (not P(i))); 
  END GENERATE;

  ------------------- grant register
  F1: FOR i IN N-1 DOWNTO 0 GENERATE
  ----------------------------------
    ----------------
    PROCESS(clk,rst)
    ----------------
    BEGIN
      IF (rst='1') THEN
        Grant_reg(i) <= '0';
      ELSIF (clk'EVENT and CLK='1') THEN
        -- A register bit can be updated when the arbiter is idle
        IF (s_idle='1') THEN
          Grant_reg(i) <= Grant(i);
        -- Or when a request is low, specially whena granted request is reset
        ELSIF (R(i)='0') THEN
          Grant_reg(i) <= '0';
        END IF;
      END IF;
    END PROCESS;
  END GENERATE;

  ------------- idle
  PROCESS(Grant_reg)
  ------------------
  VARIABLE tmp : STD_LOGIC;
  BEGIN    
    -- It just implements a parameterizable NOR
    tmp:='0';
    FOR i IN (N-1) DOWNTO 0  LOOP
      tmp:= tmp or Grant_reg(i);
    END LOOP;
    s_idle <= not tmp;
  END PROCESS;

  ----------
  -- OUTPUTS
  ----------
  idle   <= s_idle;
  G      <= Grant_reg;

END arch_1;
