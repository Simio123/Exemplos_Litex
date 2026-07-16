------------------------------------------------------------------------------
-- PROJECT: ParIS
-- ENTITY : irs (input_read_switch)
------------------------------------------------------------------------------
-- DESCRIPTION: Implements the read used in the input channels to select
-- a read command received from the granting output channel.
--
-- IMPLEMENTATION NOTE: This entity is basically a 4-to-1 multiplexer with 
-- selectors based in one-hot encoding. Current version includes only a VHDL
-- description writen to be implemented in ALTERA's FPGAs. Therefore, it 
-- intends a mapping onto 4-input LUTs. A TRI-based implementation is to be 
-- done.
------------------------------------------------------------------------------
-- AUTHORS: Frederico G. M. do Espirito Santo 
--          Cesar Albenes Zeferino
--
-- CONTACT: zeferino@univali.br OR cesar.zeferino@gmail.com
------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;

-------------
-------------
ENTITY irs IS
-------------
-------------
  GENERIC (
    SWITCH_TYPE : STRING  := "LOGIC"   -- options: LOGIC (to implement: TRI)
  );
  PORT(
    sel   : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);  -- input selector
    rdin  : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);  -- rd cmd from output channels
    rdout : OUT STD_LOGIC                      -- selected rd command 
  );
END irs;
	
-----------------------------
-----------------------------
ARCHITECTURE arch_1 OF irs IS
-----------------------------
-----------------------------
BEGIN 

----------
----------
IRS_LOGIC:
----------
----------
  IF (SWITCH_TYPE = "LOGIC") GENERATE

    -- OBS: Selects the read command from the granting output channel 
    -- If there is no sel, rdout must be 0.

    ------------------
    PROCESS(sel, rdin)
    ------------------
    BEGIN 
      IF    (sel(0)='1') THEN rdout <= rdin(0);
      ELSIF (sel(1)='1') THEN rdout <= rdin(1);
      ELSIF (sel(2)='1') THEN rdout <= rdin(2);
      ELSIF (sel(3)='1') THEN rdout <= rdin(3);
      ELSE                    rdout <= '0';
      END IF;
    END PROCESS;
  END GENERATE;

--------
--------
IRS_TRI:
--------
--------
  IF (SWITCH_TYPE = "TRI") GENERATE
    ------------------
    PROCESS(sel, rdin)
    ------------------
    BEGIN 

    -- OBS: A tri-state based switch is to be implemented for
    -- the synthesis in technologies offering such kind of
    -- buffer (Altera's FPGAs do not include internal TRI).
    -- It is important to ensure that rd is 0 when there is
    -- is no grant.

    END PROCESS;
  END GENERATE;

END arch_1;