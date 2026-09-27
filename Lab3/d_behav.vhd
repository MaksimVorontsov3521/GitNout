LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY d_behav IS
    PORT (
        d : IN  std_logic;
        c : IN  std_logic;
        q : OUT std_logic
    );
END d_behav;

ARCHITECTURE behav OF d_behav IS
    SIGNAL qs : std_logic;
BEGIN
    PROCESS(c, d)
    BEGIN
        IF rising_edge(c) THEN 
            qs <= d;
        END IF;
    END PROCESS;
    q <= qs;
END behav;