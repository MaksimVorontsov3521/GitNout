LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY RS_VHDL IS
    PORT (
        s  : IN  std_logic;
        r  : IN  std_logic;
        q  : OUT std_logic;
        qb : OUT std_logic
    );
END RS_VHDL;

ARCHITECTURE behav OF RS_VHDL IS
    SIGNAL qs : std_logic := '0';
BEGIN
    PROCESS(s, r)
    BEGIN
        IF s = '0' AND r = '1' THEN
            qs <= '1';
        ELSIF s = '1' AND r = '0' THEN
            qs <= '0';
        ELSIF s = '0' AND r = '0' THEN
            qs <= '1';
        END IF;
    END PROCESS;

    q  <= qs;
    qb <= NOT qs;
END behav;