------------------------------------------------------------------------------
-- PROJECT: ParIS
-- ENTITY : routing_xy
------------------------------------------------------------------------------
-- DESCRIPTION: Implements the XY routing algorithm
------------------------------------------------------------------------------
-- AUTHORS: Frederico G. M. do Espirito Santo 
--          Cesar Albenes Zeferino
-- CONTACT: zeferino@univali.br OR cesar.zeferino@gmail.com
------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.STD_LOGIC_1164.all;
USE ieee.STD_LOGIC_arith.all;
USE ieee.STD_LOGIC_signed.all;

--------------------
--------------------
ENTITY routing_xy IS
--------------------
--------------------
  GENERIC(
    RIB_WIDTH : INTEGER := 8; -- width of the RIB field in the header
    XID       : INTEGER := 3; -- x-coordinate  
    YID       : INTEGER := 3  -- y-coordinate
  );
  PORT (
    -- Coordinates of the destination node
    Xdest : IN  STD_LOGIC_VECTOR (RIB_WIDTH/2-1 DOWNTO 0); -- x-coordinate  
    Ydest : IN  STD_LOGIC_VECTOR (RIB_WIDTH/2-1 DOWNTO 0); -- y-coordinate

    -- Framing bits
    bop   : IN  STD_LOGIC;  -- packet framing bit: begin of packet

    -- FIFO interface
    rok   : IN  STD_LOGIC;  -- FIFO has a data to be read  (not empty)

    -- Requests
    reqL  : OUT STD_LOGIC;  -- request to Lout
    reqN  : OUT STD_LOGIC;  -- request to Nout
    reqE  : OUT STD_LOGIC;  -- request to Eout
    reqS  : OUT STD_LOGIC;  -- request to Sout
    reqW  : OUT STD_LOGIC   -- request to Wout
  );
END routing_xy;

------------------------------------
------------------------------------
ARCHITECTURE arch_1 OF routing_xy IS
------------------------------------
------------------------------------
-- The following constants defines one-hot codes for the the possible 
-- requests. It is allowed to request only one output channel (Lout,
-- Nout, Eout, Sout or Wout), or none. 
CONSTANT REQ_L   : STD_LOGIC_VECTOR(4 downto 0) := "10000"; -- Request Lout 
CONSTANT REQ_N   : STD_LOGIC_VECTOR(4 downto 0) := "01000"; -- Request Nout 
CONSTANT REQ_E   : STD_LOGIC_VECTOR(4 downto 0) := "00100"; -- Request Eout 
CONSTANT REQ_S   : STD_LOGIC_VECTOR(4 downto 0) := "00010"; -- Request Sout 
CONSTANT REQ_W   : STD_LOGIC_VECTOR(4 downto 0) := "00001"; -- Request Wout 
CONSTANT REQ_NONE: STD_LOGIC_VECTOR(4 downto 0) := "00000"; -- Request nothing  

-- The following signal receives the result of the routing.
-- That is, it always equals one of the previous constants.
SIGNAL   request : STD_LOGIC_VECTOR(4 DOWNTO 0);

BEGIN
  -----------------------------------
  p_req: PROCESS(bop,rok,Xdest,Ydest) 
  -----------------------------------
  VARIABLE header_present : boolean;
  VARIABLE X         : INTEGER;
  VARIABLE Y         : INTEGER;
  
  BEGIN
    header_present := (bop = '1') AND (rok = '1');
    
    IF (header_present) THEN
      X := conv_integer('0' & Xdest) - XID;
      Y := conv_integer('0' & Ydest) - YID;

      ---------------------------------------------------------------------
      -- Based on the XY routing algorithm, if the destination is at:
      -- # East , Southeast or Northwest, requests Eout
      -- # West , Southwest or Northwest, requests Wout
      -- # North, request Nout
      -- # South, request Sout
      -- # the same position, request Lout
      ---------------------------------------------------------------------

      ----------------
      IF (X /= 0) THEN
      ----------------
        IF (X >0) THEN
          request <= REQ_E;
        ELSE
          request <= REQ_W;
        END IF;

      -------------------
      ELSIF (Y /= 0) THEN
      -------------------
        IF (Y > 0) THEN
          request <= REQ_N;
        ELSE
          request <= REQ_S;
        END IF;

      ------------------
      ELSE  -- X = Y = 0
      ------------------
          request <= REQ_L;
      END IF;

    ELSE
      request <= REQ_NONE; 
    END IF;
  END PROCESS; 

  ----------
  -- OUTPUTS
  ----------
  reqL <= request(4);
  reqN <= request(3);
  reqE <= request(2);
  reqS <= request(1);
  reqW <= request(0);

END arch_1;
