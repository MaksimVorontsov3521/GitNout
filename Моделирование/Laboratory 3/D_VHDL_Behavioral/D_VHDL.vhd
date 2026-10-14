LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY D_VHDL IS
    PORT (
        d  : IN  std_logic;
        l  : IN  std_logic;
        q  : OUT std_logic;
        qb : OUT std_logic
    );
END D_VHDL;

ARCHITECTURE behav OF D_VHDL IS
    SIGNAL qs : std_logic := '0';
BEGIN
    PROCESS(d, l)
    BEGIN
        IF l = '1' THEN
            qs <= d;
        END IF;
    END PROCESS;

    q  <= qs;
    qb <= NOT qs;
END behav;