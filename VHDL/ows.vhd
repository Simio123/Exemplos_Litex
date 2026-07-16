------------------------------------------------------------------------------
-- PROJECT: ParIS
-- ENTITY : ows (output_write_switch)
------------------------------------------------------------------------------
-- DESCRIPTION: Implements the switch used in the output channels to select
-- a write command received from the granted input channel.
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
ENTITY ows IS
-------------
-------------
  GENERIC (
    SWITCH_TYPE : STRING  := "LOGIC"   -- options: LOGIC (to implement: TRI)
  );
  PORT(
    sel   : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);  -- input selector
    wrin  : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);  -- wr cmd from input channels
    wrout : OUT STD_LOGIC                      -- selected write command 
  );
END ows;
	
-----------------------------
-----------------------------
ARCHITECTURE arch_1 OF ows IS
-----------------------------
-----------------------------
BEGIN 

----------
----------
OWS_LOGIC:
----------
----------
  IF (SWITCH_TYPE = "LOGIC") GENERATE

    -- OBS: Selects the write command from the granted input channel 
    -- If there is no sel, wr must be 0.

    ------------------
    PROCESS(sel, wrin)
    ------------------
    BEGIN 
      IF    (sel(0)='1') THEN wrout <= wrin(0);
      ELSIF (sel(1)='1') THEN wrout <= wrin(1);
      ELSIF (sel(2)='1') THEN wrout <= wrin(2);
      ELSIF (sel(3)='1') THEN wrout <= wrin(3);
      ELSE                    wrout <= '0';
      END IF;
    END PROCESS;
  END GENERATE;

--------
--------
OWS_TRI:
--------
--------
  IF (SWITCH_TYPE = "TRI") GENERATE
    ------------------
    PROCESS(sel, wrin)
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