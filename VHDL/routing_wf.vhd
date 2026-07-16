------------------------------------------------------------------------------
-- PROJECT: ParIS
-- ENTITY : routing_wf
------------------------------------------------------------------------------
-- DESCRIPTION: Implements the West-First routing algorithm, offering two
-- alternatives the implementation when the destination is at East: 
-- (a) selects an Y port (N or S) before E port; or 
-- (b) selects E port before an Y port (N or S)
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
ENTITY routing_wf IS
--------------------
--------------------
  GENERIC(
    WF_TYPE   : STRING  := "Y_BEFORE_E";   -- options: E_BEFORE_Y, Y_BEFORE_E
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

    -- Status of the output channels
    Lidle : IN  STD_LOGIC;  -- Lout is idle
    Nidle : IN  STD_LOGIC;  -- Nout is idle
    Eidle : IN  STD_LOGIC;  -- Eout is idle
    Sidle : IN  STD_LOGIC;  -- Sout is idle
    Widle : IN  STD_LOGIC;  -- Wout is idle

    -- Requests
    reqL  : OUT STD_LOGIC;  -- request to Lout
    reqN  : OUT STD_LOGIC;  -- request to Nout
    reqE  : OUT STD_LOGIC;  -- request to Eout
    reqS  : OUT STD_LOGIC;  -- request to Sout
    reqW  : OUT STD_LOGIC   -- request to Wout
  );
END routing_wf;

------------------------------------
------------------------------------
ARCHITECTURE arch_1 OF routing_wf IS
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

-- The following signal receives the result of the routing. That is, it 
-- always equals one of the previous constants.
SIGNAL   request : STD_LOGIC_VECTOR(4 DOWNTO 0); 

BEGIN

----------------
WF_E_BEFORE_Y :
----------------
  IF (WF_TYPE = "E_BEFORE_Y") GENERATE
    ----------------------------------------------------------
    PROCESS(bop,rok,Xdest,Ydest,Lidle,Nidle,Eidle,Sidle,Widle) 
    ----------------------------------------------------------
    VARIABLE header_present : boolean; -- notifies if there is a header
    VARIABLE X : INTEGER;              -- distance to Xdest	
    VARIABLE Y : INTEGER;              -- distance to Ydest
    BEGIN
      -- Verifies if there is a header to be routed
      header_present := (bop = '1') AND (rok = '1');
    
      IF (header_present) THEN
        -- Determines the distance to the destination in X and Y axis
        X := conv_integer('0' & Xdest) - XID;
        Y := conv_integer('0' & Ydest) - YID;

        ---------------------------------------------------------------------
        -- Based on the WF routing algorithm, if the destination is at:
        -- # West , Southwest or Northwest, requests Wout
        -- # Southeast, requests Eout or Sout when the first of them is idle
        -- # Northeast, requests Eout or Nout when the first of them is idle
        -- # East  (at the same row), requests Eout
        -- # North (at the sam column), request Nout
        -- # South (at the sam column), request Sout
        -- # the same position, request Lout
        ---------------------------------------------------------------------
        ---------------
        IF (X < 0) THEN 
        ---------------
          request <= REQ_W;

        ------------------
        ELSIF (X > 0) THEN 
        ------------------
          IF (Y < 0) THEN
            IF (Eidle ='1') THEN
              request <= REQ_E;
            ELSE
              IF (Sidle = '1') THEN
                request <= REQ_S;
              ELSE  
                request <= REQ_NONE;
              END IF;
            END IF;

          ELSIF (Y > 0) THEN
            IF (Eidle ='1') THEN
              request <= REQ_E;
            ELSE
              IF (Nidle = '1') THEN
                request <= REQ_N;
              ELSE  
                request <= REQ_NONE;
              END IF;
            END IF;

          ELSE 
            request <= REQ_E;
          END IF;

        ----------------------
        ELSE --IF (X = 0) THEN
        ----------------------
          IF (Y < 0) THEN
            request <= REQ_S;
          ELSIF (Y > 0) THEN
            request <= REQ_N;
          ELSE          
            request <= REQ_L;
          END IF;          
        END IF;

      ELSE  -- header not present
        request <= REQ_NONE;
      END IF;
    END PROCESS;
  END GENERATE;


----------------
WF_Y_BEFORE_E :
----------------
  IF (WF_TYPE = "Y_BEFORE_E") GENERATE
    ----------------------------------------------
    PROCESS(bop,rok,Xdest,Ydest,Nidle,Eidle,Sidle) 
    ----------------------------------------------
    VARIABLE header_present : boolean; -- notifies if there is a header
    VARIABLE X : INTEGER;              -- distance to Xdest	
    VARIABLE Y : INTEGER;              -- distance to Ydest
  
    BEGIN
      -- Verifies if there is a header to be routed
      header_present := (bop = '1') AND (rok = '1');
    
      IF (header_present) THEN
        -- Determines the distance to the destination in X and Y axis
        X:= conv_integer('0' & Xdest) - XID;
        Y:= conv_integer('0' & Ydest) - YID;

        ---------------------------------------------------------------------
        -- If the destination is at:
        -- # West, requests Wout. 
        -- # Southeast, requests Sout or Eout when the first of them is idle
        -- # Northeast, requests Nout or Eout when the first of them is idle
        -- # East  (at the same row), requests Eout
        -- # North (at the sam column), request Nout
        -- # South (at the sam column), request Sout
        ---------------------------------------------------------------------

        ---------------
        IF (X < 0) THEN
        ---------------
          request<= REQ_W;

        ------------------
        ELSIF (X > 0) THEN 
        ------------------
          IF (Y < 0) THEN
            IF (Sidle ='1') THEN
              request <= REQ_S;
            ELSE
              IF (Eidle = '1') THEN
                request <= REQ_E;
              ELSE  
                request <= REQ_NONE;
              END IF;
            END IF;
          ELSIF (Y > 0) THEN
            IF (Nidle ='1') THEN
              request <= REQ_N;
            ELSE
              IF (Eidle = '1') THEN
                request <= REQ_E;
              ELSE  
                request <= REQ_NONE;
              END IF;
            END IF;
          ELSE
            request <= REQ_E;
          END IF;

        ----------------------
        ELSE --IF (X = 0) THEN
        ----------------------
          IF (Y < 0) THEN
            request <= REQ_S;
          ELSIF (Y > 0) THEN
            request <= REQ_N;
          ELSE          
            request <= REQ_L;
          END IF;          
        END IF;
      ELSE
        request <= REQ_NONE;
      END IF;
    END PROCESS;
  END GENERATE;


  ----------
  -- OUTPUTS
  ----------
  reqL <= request(4);
  reqN <= request(3);
  reqE <= request(2);
  reqS <= request(1);
  reqW <= request(0);

END arch_1;
