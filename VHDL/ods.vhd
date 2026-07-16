------------------------------------------------------------------------------
-- PROJECT: ParIS
-- ENTITY : ods (output_data_switch)
------------------------------------------------------------------------------
-- DESCRIPTION: Implements the switch used in the output channels to select
-- a data received from the granted input channel.
--
-- IMPLEMENTATION NOTE: This entity is based on 4-to-1 multiplexers with 
-- selectors based in one-hot encoding. Current version includes only a VHDL
-- description writen to be implemented in ALTERA's FPGAs. Therefore, it 
-- intends a mapping into 4-input LUTs. A TRI-based implementation is to be 
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
ENTITY ods IS
-------------
-------------
  GENERIC (
    SWITCH_TYPE : STRING  := "LOGIC"; -- options: LOGIC (to implement: TRI)
    WIDTH       : INTEGER := 8        -- channels width
  );
  PORT(
    sel  : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);       -- input selector 
    din0 : IN  STD_LOGIC_VECTOR(WIDTH-1 DOWNTO 0); -- data from input channel 0
    din1 : IN  STD_LOGIC_VECTOR(WIDTH-1 DOWNTO 0); -- data from input channel 1
    din2 : IN  STD_LOGIC_VECTOR(WIDTH-1 DOWNTO 0); -- data from input channel 2
    din3 : IN  STD_LOGIC_VECTOR(WIDTH-1 DOWNTO 0); -- data from input channel 3

    -- selected data channel and framing bits
    dout : OUT STD_LOGIC_VECTOR(WIDTH-1 DOWNTO 0)
  );
END ods;

-----------------------------
-----------------------------
ARCHITECTURE arch_1 OF ods IS
-----------------------------
-----------------------------
BEGIN 

----------
----------
ODS_LOGIC:
----------
----------
  IF (SWITCH_TYPE = "LOGIC") GENERATE
    ------------------------------------
    PROCESS(sel, din0, din1, din2, din3)
    ------------------------------------
    BEGIN 
      IF    (sel(0)='1') THEN dout <= din0;
      ELSIF (sel(1)='1') THEN dout <= din1;
      ELSIF (sel(2)='1') THEN dout <= din2;
      ELSIF (sel(3)='1') THEN dout <= din3;
      ELSE                    dout <= (others=>'0');
      END IF;
    END PROCESS;
  END GENERATE;

--------
--------
ODS_TRI:
--------
--------
  IF (SWITCH_TYPE = "TRI") GENERATE
    ------------------------------------
    PROCESS(sel, din0, din1, din2, din3)
    ------------------------------------
    BEGIN 

    -- OBS: A tri-state based switch is to be implemented for
    -- the synthesis in technologies offering such kind of
    -- buffer (Altera's FPGAs do not include internal TRI).
    -- It is important to ensure that eop and bop are 0.

    END PROCESS;
  END GENERATE;

END arch_1;
