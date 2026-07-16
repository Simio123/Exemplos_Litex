------------------------------------------------------------------------------
-- PROJECT: ParIS
-- ENTITY : oc (output_controller)
------------------------------------------------------------------------------
-- DESCRIPTION: Controller responsible to schedule the use of the associated
-- output channel. It is based on an arbiter that receives requests and based
-- on an arbitration algorithm selects one request to be granted. A grant is
-- held at the high level while the request equals 1. 
------------------------------------------------------------------------------
-- AUTHORS: Frederico G. M. do Espirito Santo 
--          Cesar Albenes Zeferino
-- CONTACT: zeferino@univali.br OR cesar.zeferino@gmail.com
------------------------------------------------------------------------------
 
LIBRARY ieee;
USE ieee.std_logic_1164.all;

------------
------------
ENTITY oc IS
------------
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
END oc;

----------------------------
----------------------------
ARCHITECTURE arch_1 OF oc IS
----------------------------
----------------------------

----------------
COMPONENT arb_rr 
----------------
  GENERIC (
    N    : INTEGER := 4    -- number of requests
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

SIGNAL Grant : STD_LOGIC_VECTOR(N-1 DOWNTO 0);  -- grant signals  


BEGIN
  ----
  ----
  RR :
  ----
  ----
  IF (ARBITER_TYPE="ROUND_ROBIN") GENERATE
    ----------
    U0: arb_rr
    ----------
      GENERIC MAP (
        N     => N
      )
      PORT MAP(
         R    => R,
         clk  => clk,
         rst  => rst,
         G    => Grant,
         idle => idle
      );
  END GENERATE;

  G <= Grant AND R;   
  
END arch_1;

