------------------------------------------------------------------------------
-- PROJECT: ParIS
-- ENTITY : ifc (input_flow_controller)
------------------------------------------------------------------------------
-- DESCRIPTION: Controller responsible to regulate the flow of flits at the 
-- input channels. It makes the adapting between the link flow control 
-- protocol (eg.credit-based, handshake) and the internal flow control protocol 
-- (FIFO).
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
ENTITY ifc IS
-------------
-------------
  GENERIC (
    FC_TYPE   : STRING  := "HANDSHAKE"     -- options: CREDIT or HANDSHAKE
  );
  PORT(
    -- System interface
    clk   : IN  STD_LOGIC;  -- clock
    rst   : IN  STD_LOGIC;  -- reset

    -- Link interface
    val   : IN  STD_LOGIC;  -- data validation
    ret   : OUT STD_LOGIC;  -- return (credit or acknowledgement)

    -- FIFO interface
    wr    : OUT STD_LOGIC;  -- command to write a data into de FIFO
    wok   : IN  STD_LOGIC;  -- FIFO has room to be written (not full)
    rd    : IN  STD_LOGIC;  -- command to read a data from the FIFO
    rok   : IN  STD_LOGIC   -- FIFO has a data to be read  (not empty)
  );
END ifc;

-----------------------------
-----------------------------
ARCHITECTURE arch_1 OF ifc IS
-----------------------------
-----------------------------
-- Data type and signals for handshake flow-control
TYPE   STATE IS (S0,S1,S2); -- states of the handshake FSM
SIGNAL state_reg  : STATE;  -- current state of the handshake FSM
SIGNAL next_state : STATE;  -- next state of the handshake FSM

BEGIN
  --------------
  --------------
  IFC_HANDSHAKE:
  --------------
  --------------
    IF (FC_TYPE = "HANDSHAKE") GENERATE
      ----------------next state
      PROCESS(state_reg,val,wok)
      --------------------------
      BEGIN
        CASE state_reg IS

          -- Waits a new incoming data (val=1) and, if the FIFO is not full 
          -- (wok=1), goes to the S1 state in order to receive the data.
          WHEN S0 => 
                    IF (val='1') AND (wok='1') THEN
                      next_state <= S1;
                    ELSE
                      next_state <= S0;
                    END IF;
                    
          -- Writes the data into the FIFO and goes back to the S0 state 
          -- if val=0, or, if not, goes to S2 state.
          WHEN S1 =>
                    IF (val='0') THEN
                      next_state <= S0;
                    ELSE
                      next_state <= S2;
                    END IF;

          -- Waits val goes to 0 to complete the data tranfer.
          WHEN S2 =>
                    IF (val='0') THEN
                      next_state <= S0;
                    ELSE
                      next_state <= S2;
                    END IF; 

          WHEN OTHERS =>
                    next_state <= S0;
        END CASE;
      END PROCESS;


      ---------- outputs
      PROCESS(state_reg)
      ------------------
      BEGIN
        CASE state_reg IS
  
          -- Do nothing.
          WHEN S0 =>
                    ret <= '0';
                    wr  <= '0';

          -- Acknowledges the data and writes it into the FIFO.
          WHEN S1 =>
                    ret <= '1'; 
                    wr  <= '1'; 

          -- Remains the acknowledge high while valid is not low.
          WHEN S2 =>
                    ret <= '1';  
                    wr  <= '0';

          WHEN OTHERS  =>
                    ret <= '0';
                    wr  <= '0';
        END CASE;
      END PROCESS;


      -- current state
      PROCESS(clk,rst)
      ----------------
      BEGIN
        IF (rst='1') THEN
          state_reg  <= S0;
        ELSIF (clk'EVENT AND clk='1') THEN
          state_reg  <= next_state;
        END IF;
      END PROCESS;

    END GENERATE;


  -----------------
  -----------------
  IFC_CREDIT_BASED:
  -----------------
  -----------------
    IF (FC_TYPE = "CREDIT") GENERATE
      wr     <= val; 

      ----------------
      PROCESS(rst,clk)
      ----------------
      BEGIN
        -- Returns a credit always that a data is read from the FIFO.
        IF (rst='1') THEN
          ret <= '0';
        ELSIF (clk'event AND clk='1') THEN
          ret <= rd and rok;
        END IF;
      END PROCESS;
    END GENERATE;


END arch_1;
