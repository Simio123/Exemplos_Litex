------------------------------------------------------------------------------
-- PROJECT: ParIS
-- ENTITY : ofc (output_flow_controller)
------------------------------------------------------------------------------
-- DESCRIPTION: Controller responsible to regulate the flow of flits at the 
-- output channels. It makes the adapting between the the internal flow 
-- control protocol (FIFO) and the link flow control protocol (eg.credit-based, 
-- handshake).
------------------------------------------------------------------------------
-- AUTHORS: Frederico G. M. do Espirito Santo 
--          Cesar Albenes Zeferino
--
-- CONTACT: zeferino@univali.br OR cesar.zeferino@gmail.com
------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_arith.all;

-------------
-------------
ENTITY ofc IS
-------------
-------------
  GENERIC (
    FC_TYPE   : STRING  := "CREDIT";    -- options: CREDIT or HANDSHAKE
    CREDIT    : INTEGER := 4            -- maximum number of credits
  );
  PORT(
    -- System interface
    rst : IN  STD_LOGIC;  -- reset        
    clk : IN  STD_LOGIC;  -- clock  

    -- Link interface
    val : OUT STD_LOGIC;  -- data validation
    ret : IN  STD_LOGIC;  -- return (credit or acknowledgement)

    -- FIFO interface
    rd  : OUT STD_LOGIC;  -- read comand 
    rok : IN  STD_LOGIC   -- FIFO not empty (it is able to be read)
  );
END ofc;

-----------------------------
-----------------------------
ARCHITECTURE arch_1 OF ofc IS
-----------------------------
-----------------------------
-- Data type and signals for handshake flow-control
TYPE   STATE IS (S0,S1,S2); -- states of the handshake SFM
SIGNAL state_reg  : STATE;  -- current state of the handshake SFM
SIGNAL next_state : STATE;  -- next state of the handshake SFM

-- Signal for credit-based flow control
SIGNAL counter : INTEGER RANGE CREDIT DOWNTO 0; -- credit counter
SIGNAL move    : STD_LOGIC; -- command to move a data from the input
                            -- to the output 

BEGIN
  --------------
  --------------
  OFC_HANDSHAKE:
  --------------
  --------------
    IF (FC_TYPE = "HANDSHAKE") GENERATE
      --------------- next state
      PROCESS(state_reg,ret,rok)
      --------------------------
      BEGIN
        CASE state_reg IS

          -- If there is a data to be sent in the selected input channel (rok=1)
          -- and the receiver is not busy (ret=0), goes to the S1 state in order 
          -- to send the data.
          WHEN S0 =>
                    IF (rok='1') AND (ret='0') THEN
                      next_state <= S1;
                    ELSE
                      next_state <= S0;
                    END IF;
          
          -- Sends the data and, when the data is received (ret=1), goes to the 
          -- state S2 in order to notify the sender that the data was delivered.
          WHEN S1 =>
                    IF (ret='1') THEN
                      next_state <= S2;
                    ELSE
                      next_state <= S1;
                    END IF;

          -- It notifies the sender that the data was delivered and returns to 
          -- S0 or S1 (under the same conditions used in S0).
          WHEN S2 =>
                    IF (rok='1') AND (ret='0') THEN
                      next_state <= S1;
                    ELSE
                      next_state <= S0;
                    END IF;
  
          WHEN OTHERS =>
                    next_state <= S0;
        END CASE;
      END PROCESS p_next_state;

      ---------- outputs 
      PROCESS(state_reg)
      ------------------
      BEGIN
        CASE state_reg IS

          -- Do nothing.
          WHEN S0 => 
                    val <= '0';
                    rd  <= '0';

          -- Validates the outgoing data.
          WHEN S1 =>
                    val <= '1';
                    rd  <= '0';

          -- Notifies the sender that the data was sent.
          WHEN S2 =>
                    val <= '0';
                    rd  <= '1';

          WHEN OTHERS =>
                    val <= '0';
                    rd  <= '0'; 
        END CASE; 
      END PROCESS;

  
      -- current state
      PROCESS(clk,rst)
      ----------------
      BEGIN
        IF (rst='1') THEN
          state_reg <= S0;
        ELSIF (clk'EVENT AND clk='1') THEN
          state_reg  <= next_state;
        END IF;
      END PROCESS p_state_reg;
    END GENERATE;


  -----------------
  -----------------
  OFC_CREDIT_BASED:
  -----------------
  -----------------
    IF (FC_TYPE = "CREDIT") GENERATE

      -- credit counter
      PROCESS(rst,clk)
      ----------------
      BEGIN
        -- Counter is intialized with a CREDIT (eg. 4)
        IF (rst='1') THEN
          counter <= CREDIT;

        ELSIF (clk'event AND clk='1') THEN
          -- If there is no data to be sent (rok=0) and a credit is 
          -- received (ret=1), it increments the number of credits.
          -- On the other hand, if it is sending a data and no
          -- credit is being received, decrements the number of
          -- credits. Otherwise, the number of credits doesn't change.  

          IF (rok='0') THEN
            IF ((ret='1') AND (counter/=(CREDIT))) THEN
               counter <= counter+1;
            END IF;
          ELSE
            IF ((ret='0') AND (counter/=0)) THEN
              counter <= counter-1;          
            END IF;
          END IF;
        END IF;
      END PROCESS;
  
      ---------------- outputs
      PROCESS(rok,counter,ret)
      ------------------------
      -- If there is a flit to be sent (rok=1) and the sender still has
      -- at least one credit, the data is sent (val=rd=1). If there is
      -- no credit, but the receiver is returning a new credit (ret=1),
      -- then, it can also send the data, because there is room in the
      -- receiver.
      BEGIN
        IF (rok='1') THEN
          IF (counter=0) THEN
            IF (ret='1') THEN
              move <= '1';
            ELSE
              move <= '0';
            END IF;
          ELSE
            move <= '1';
          END IF;
        ELSE
          move <= '0';
        END IF;
      END PROCESS;

      val <= move;
      rd  <= move;
    END GENERATE;
END arch_1;


