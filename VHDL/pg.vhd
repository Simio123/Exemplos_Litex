------------------------------------------------------------------------------
-- PROJECT: ParIS
-- ENTITY : pg (priority_generator)
------------------------------------------------------------------------------
-- DESCRIPTION: That is a function which determines the next priority levels
-- by implementing a round-robin algorithm. At each clock cycle, defined by
-- a new grant to a pending request, it rotates left the current granting
-- status and ensures that the request being granted will have the lowest
-- priority level at the next arbitration cycle.
------------------------------------------------------------------------------
-- AUTHORS: Frederico G. M. do Espirito Santo 
--          Cesar Albenes Zeferino
-- CONTACT: zeferino@univali.br OR cesar.zeferino@gmail.com
------------------------------------------------------------------------------
 
LIBRARY ieee;
USE ieee.std_logic_1164.all;
------------
------------
ENTITY pg IS
------------
------------
  GENERIC (
    N    : INTEGER := 4    -- number of requests
  );
  PORT (
    -- System signals
    clk  : IN  STD_LOGIC;  -- clock
    rst  : IN  STD_LOGIC;  -- reset
      
    -- Arbitration signals
    G    : IN  STD_LOGIC_VECTOR(N-1 DOWNTO 0); -- grants
    P    : OUT STD_LOGIC_VECTOR(N-1 DOWNTO 0)  -- priorities
);
END pg;

----------------------------
----------------------------
ARCHITECTURE arch_1 OF pg IS
----------------------------
----------------------------
SIGNAL update_register : STD_LOGIC;
SIGNAL granting : STD_LOGIC_VECTOR(N-1 DOWNTO 0); -- a request was granted
SIGNAL Gdelayed : STD_LOGIC_VECTOR(N-1 DOWNTO 0); -- G delayed in 1 cycle 
SIGNAL nextP    : STD_LOGIC_VECTOR(N-1 DOWNTO 0); -- next priorities values     
SIGNAL Preg     : STD_LOGIC_VECTOR(N-1 DOWNTO 0); -- priorities register 
SIGNAL i        : INTEGER RANGE N-1 downto 0;     -- for-generate index

BEGIN

  -----------------
  PROCESS (clk,rst)
  -----------------
  -- It is just a flip-flop always enabled to hold the state of G for one 
  -- clock cycle.
  VARIABLE i: INTEGER RANGE N-1 downto 0;
  BEGIN 
    IF (rst='1') THEN
      Gdelayed <= (others => '0');
    ELSIF (clk'EVENT and clk='1') THEN
      Gdelayed <= G;
    END IF;
  END PROCESS;

  -- It determines if there exists any request that was granted in the last 
  -- cycle. This occurs when G(i)= 1 and Gdelayed(i) = 0, for any i.
  ---------------------------------
  granting <= G and (not Gdelayed);
  ---------------------------------

  -----------------
  PROCESS(granting)
  -----------------
  VARIABLE tmp : STD_LOGIC;
  BEGIN
    -- It just implements a parameterizable OR which detect if any request
    -- was granted in the last cycle. In this case, it enables the priority 
    -- register to update its state.
    tmp:='0';
    FOR i IN (N-1) DOWNTO 0  LOOP
      tmp:= tmp or granting(i);
    END LOOP;
      update_register <= tmp;
  END PROCESS;


  -- It determines the next priority order by rotating 1x left the current 
  -- granting status. Ex. If G="0001", then, nextP="0010". Such rotation
  -- will ensure that the current granted request (e.g. R(0)) will have the 
  -- lowest priority level at the next arbitration cycle (e.g. P(1)>P(2)>
  -- P(3)>P(0)).

  F: FOR i IN N-1 DOWNTO 0 GENERATE
       nextP(i) <= G((i-1) mod N);
     END GENERATE;

  --- priority reg
  PROCESS(clk,rst)
  ----------------
  BEGIN
    -- It is reset with bit 0 in 1 and the others in 0, and is updated at each
    -- arbitration cycle (after a request is grant) with the value determined
    -- for nextP. 
    IF (rst='1') THEN
      Preg(0)            <= '1';
      Preg(N-1 DOWNTO 1) <= (others => '0');

    ELSIF (clk'EVENT and clk='1') THEN
      IF (update_register = '1') THEN
        Preg <= nextP;  
      END IF;
    END IF;
  END PROCESS;

  ----------
  -- OUTPUTS
  ----------
  P <= Preg;

END arch_1;
