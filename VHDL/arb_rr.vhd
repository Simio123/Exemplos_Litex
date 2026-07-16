------------------------------------------------------------------------------
-- PROJECT: ParIS
-- ENTITY : arb_rr (round-robin arbiter)
------------------------------------------------------------------------------
-- DESCRIPTION: A round-robin arbiter based on a programmable priority encoder
-- and on a circular priority generator which updates the priorities order at 
-- each arbitration cycle. It ensuring that the request granted at the current 
-- arbitration cycle will have the lowest priority level at the next one.
------------------------------------------------------------------------------
-- AUTHORS: Frederico G. M. do Espirito Santo 
--          Cesar Albenes Zeferino
-- CONTACT: zeferino@univali.br OR cesar.zeferino@gmail.com
------------------------------------------------------------------------------
 
LIBRARY ieee;
USE ieee.std_logic_1164.all;

----------------
----------------
ENTITY arb_rr IS
----------------
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
END arb_rr;

--------------------------------
--------------------------------
ARCHITECTURE arch_1 OF arb_rr IS
--------------------------------
--------------------------------
-------------
COMPONENT ppe
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
END COMPONENT;

------------
COMPONENT pg
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
END COMPONENT;

SIGNAL P      : STD_LOGIC_VECTOR(N-1 DOWNTO 0);-- priorities     
SIGNAL Grant  : STD_LOGIC_VECTOR(N-1 DOWNTO 0);-- grant signals

BEGIN
  -------
  U0: ppe
  ------- 
    GENERIC MAP (
      N     => N
    )
    PORT MAP (  
      clk   => clk,
      rst   => rst,
      idle  => idle,
      R     => R,
      P     => P,
      G     => Grant
    );
  
  ------
  U1: pg
  ------
    GENERIC MAP (
      N     => N
    )
    PORT MAP (  
      clk   => clk,
      rst   => rst,
      G     => Grant,
      P     => P
    );

  ----------
  -- OUTPUTS
  ----------
  G    <= Grant;

END arch_1;