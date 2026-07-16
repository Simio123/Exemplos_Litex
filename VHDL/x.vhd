------------------------------------------------------------------------------
-- PROJECT: ParIS
-- ENTITY : X (cross_point_matrix)
------------------------------------------------------------------------------
-- DESCRIPTION: Configuration matrix used to allow Quartus II to generate 
-- the desired router based on the type of routing algorithm to be used.
-- It ensures that only the components related with allowed routes will be
-- implemented.
------------------------------------------------------------------------------
-- AUTHORS: Frederico G. M. do Espirito Santo 
--          Cesar Albenes Zeferino
-- CONTACT: zeferino@univali.br OR cesar.zeferino@gmail.com
------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.STD_LOGIC_arith.all;
USE ieee.STD_LOGIC_signed.all;
USE ieee.std_logic_1164.all;
-----------
-----------
ENTITY X IS
-----------
-----------
  GENERIC (
    ROUTING_TYPE : STRING := "XY"  -- options are XY or WF
  );
  PORT (
    LreqN_in  : IN  STD_LOGIC;
    LreqE_in  : IN  STD_LOGIC;
    LreqS_in  : IN  STD_LOGIC;
    LreqW_in  : IN  STD_LOGIC;
    --------------------------
    LreqN_out : OUT STD_LOGIC;
    LreqE_out : OUT STD_LOGIC;
    LreqS_out : OUT STD_LOGIC;
    LreqW_out : OUT STD_LOGIC;
    --------------------------
    NreqL_in  : IN  STD_LOGIC;
    NreqE_in  : IN  STD_LOGIC;
    NreqS_in  : IN  STD_LOGIC;
    NreqW_in  : IN  STD_LOGIC;
    --------------------------
    NreqL_out : OUT STD_LOGIC;
    NreqE_out : OUT STD_LOGIC;
    NreqS_out : OUT STD_LOGIC;
    NreqW_out : OUT STD_LOGIC;
    --------------------------
    EreqL_in  : IN  STD_LOGIC;
    EreqN_in  : IN  STD_LOGIC;
    EreqS_in  : IN  STD_LOGIC;
    EreqW_in  : IN  STD_LOGIC;
    --------------------------
    EreqL_out : OUT STD_LOGIC;
    EreqN_out : OUT STD_LOGIC;
    EreqS_out : OUT STD_LOGIC;
    EreqW_out : OUT STD_LOGIC;
    --------------------------
    SreqL_in  : IN  STD_LOGIC;
    SreqN_in  : IN  STD_LOGIC;
    SreqE_in  : IN  STD_LOGIC;
    SreqW_in  : IN  STD_LOGIC;
    --------------------------
    SreqL_out : OUT STD_LOGIC;  
    SreqN_out : OUT STD_LOGIC;  
    SreqE_out : OUT STD_LOGIC;  
    SreqW_out : OUT STD_LOGIC;
    --------------------------
    WreqL_in  : IN  STD_LOGIC;
    WreqN_in  : IN  STD_LOGIC;
    WreqE_in  : IN  STD_LOGIC;
    WreqS_in  : IN  STD_LOGIC;
    --------------------------
    WreqL_out : OUT STD_LOGIC;
    WreqN_out : OUT STD_LOGIC;
    WreqE_out : OUT STD_LOGIC;
    WreqS_out : OUT STD_LOGIC;
    --------------------------
    --------------------------
    LgntN_in  : IN  STD_LOGIC;
    LgntE_in  : IN  STD_LOGIC;
    LgntS_in  : IN  STD_LOGIC;
    LgntW_in  : IN  STD_LOGIC;
    --------------------------
    LgntN_out : OUT STD_LOGIC;
    LgntE_out : OUT STD_LOGIC;
    LgntS_out : OUT STD_LOGIC;
    LgntW_out : OUT STD_LOGIC;
    --------------------------
    NgntL_in  : IN  STD_LOGIC;
    NgntE_in  : IN  STD_LOGIC;
    NgntS_in  : IN  STD_LOGIC;
    NgntW_in  : IN  STD_LOGIC;
    --------------------------
    NgntL_out : OUT STD_LOGIC;
    NgntE_out : OUT STD_LOGIC;
    NgntS_out : OUT STD_LOGIC;
    NgntW_out : OUT STD_LOGIC;
    --------------------------
    EgntL_in  : IN  STD_LOGIC;
    EgntN_in  : IN  STD_LOGIC;
    EgntS_in  : IN  STD_LOGIC;
    EgntW_in  : IN  STD_LOGIC;
    --------------------------
    EgntL_out : OUT STD_LOGIC;
    EgntN_out : OUT STD_LOGIC;
    EgntS_out : OUT STD_LOGIC;
    EgntW_out : OUT STD_LOGIC;
    --------------------------
    SgntL_in  : IN  STD_LOGIC;
    SgntN_in  : IN  STD_LOGIC;
    SgntE_in  : IN  STD_LOGIC;
    SgntW_in  : IN  STD_LOGIC;
    --------------------------
    SgntL_out : OUT STD_LOGIC;
    SgntN_out : OUT STD_LOGIC;
    SgntE_out : OUT STD_LOGIC;
    SgntW_out : OUT STD_LOGIC;
    --------------------------
    WgntL_in  : IN  STD_LOGIC;
    WgntN_in  : IN  STD_LOGIC;
    WgntE_in  : IN  STD_LOGIC;
    WgntS_in  : IN  STD_LOGIC;
    --------------------------
    WgntL_out : OUT STD_LOGIC;
    WgntN_out : OUT STD_LOGIC;
    WgntE_out : OUT STD_LOGIC;
    WgntS_out : OUT STD_LOGIC);
    --------------------------
END X;

---------------------------
---------------------------
ARCHITECTURE arch_1 OF X IS
---------------------------
---------------------------
BEGIN

  ------------
  XY_ROUTING :
  ------------
    IF (ROUTING_TYPE = "XY") GENERATE
      LreqN_out <= LreqN_in;
      LreqE_out <= LreqE_in;
      LreqS_out <= LreqS_in;
      LreqW_out <= LreqW_in;
      ----------------------
      NreqL_out <= NreqL_in;
      NreqE_out <= '0';
      NreqS_out <= NreqS_in;
      NreqW_out <= '0';
      ----------------------
      EreqL_out <= EreqL_in;
      EreqN_out <= Ereqn_in;
      EreqS_out <= Ereqs_in;
      EreqW_out <= Ereqw_in;
      ----------------------
      SreqL_out <= SreqL_in;
      SreqN_out <= SreqN_in;
      SreqE_out <= '0';
      SreqW_out <= '0';
      ----------------------
      WreqL_out <= WreqL_in;
      WreqN_out <= WreqN_in;
      WreqE_out <= WreqE_in;
      WreqS_out <= WreqS_in;
      ----------------------
      LgntN_out <= LgntN_in;
      LgntE_out <= LgntE_in;
      LgntS_out <= LgntS_in;
      LgntW_out <= LgntW_in;
      ----------------------
      NgntL_out <= NgntL_in;
      NgntE_out <= NgntE_in;
      NgntS_out <= NgntS_in;
      NgntW_out <= NgntW_in;
      ----------------------
      EgntL_out <= EgntL_in; 
      EgntN_out <= '0';
      EgntS_out <= '0';
      EgntW_out <= EgntW_in;
      ----------------------
      SgntL_out <= SgntL_in;
      SgntN_out <= SgntN_in;
      SgntE_out <= SgntE_in;
      SgntW_out <= SgntW_in;
      ----------------------
      WgntL_out <= WgntL_in;
      WgntN_out <= '0';
      WgntE_out <= WgntE_in;
      WgntS_out <= '0';
    END GENERATE;

  ------------
  WF_ROUTING :
  ------------
    IF (ROUTING_TYPE = "WF") GENERATE
      LreqN_out <= LreqN_in;
      LreqE_out <= LreqE_in;
      LreqS_out <= LreqS_in;
      LreqW_out <= LreqW_in;
      ----------------------
      NreqL_out <= NreqL_in;
      NreqE_out <= NreqE_in;
      NreqS_out <= NreqS_in;
      NreqW_out <= '0';
      ----------------------
      EreqL_out <= EreqL_in;
      EreqN_out <= Ereqn_in;
      EreqS_out <= Ereqs_in;
      EreqW_out <= Ereqw_in;
      ----------------------
      SreqL_out <= SreqL_in;
      SreqN_out <= SreqN_in;
      SreqE_out <= SreqE_in;
      SreqW_out <= '0';
      ----------------------
      WreqL_out <= WreqL_in;
      WreqN_out <= WreqN_in;
      WreqE_out <= WreqE_in;
      WreqS_out <= WreqS_in;
      ----------------------
      LgntN_out <= LgntN_in;
      LgntE_out <= LgntE_in;
      LgntS_out <= LgntS_in;
      LgntW_out <= LgntW_in;
      ----------------------
      NgntL_out <= NgntL_in;
      NgntE_out <= NgntE_in;
      NgntS_out <= NgntS_in;
      NgntW_out <= NgntW_in;
      ----------------------
      EgntL_out <= EgntL_in; 
      EgntN_out <= EgntN_in; 
      EgntS_out <= EgntS_in; 
      EgntW_out <= EgntW_in;
      ----------------------
      SgntL_out <= SgntL_in;
      SgntN_out <= SgntN_in;
      SgntE_out <= SgntE_in;
      SgntW_out <= SgntW_in;
      ----------------------
      WgntL_out <= WgntL_in;
      WgntN_out <= '0';
      WgntE_out <= WgntE_in;
      WgntS_out <= '0';
    END GENERATE;

END arch_1;
