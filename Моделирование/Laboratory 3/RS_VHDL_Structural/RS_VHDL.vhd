LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY RS_VHDL IS
    PORT (
        s  : IN  std_logic;
        r  : IN  std_logic;
        q  : BUFFER std_logic;
        qb : BUFFER std_logic
    );
END RS_VHDL;

ARCHITECTURE behav OF RS_VHDL IS
    COMPONENT notand
        PORT (
            a : IN  std_logic;
            b : IN  std_logic;
            c : OUT std_logic
        );
    END COMPONENT;
BEGIN
    u1: notand PORT MAP (s, qb, q);
    u2: notand PORT MAP (q, r, qb);
END behav;