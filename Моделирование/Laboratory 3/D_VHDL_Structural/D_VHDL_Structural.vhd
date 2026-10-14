LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY D_VHDL_Structural IS
    PORT (
        d  : IN  std_logic;
        l  : IN  std_logic;
        q  : BUFFER std_logic;
        qb : BUFFER std_logic
    );
END D_VHDL_Structural;

ARCHITECTURE structural OF D_VHDL_Structural IS
    COMPONENT notand
        PORT (
            a : IN  std_logic;
            b : IN  std_logic;
            c : OUT std_logic
        );
    END COMPONENT;

    COMPONENT RS_VHDL
        PORT (
            s  : IN  std_logic;
            r  : IN  std_logic;
            q  : BUFFER std_logic;
            qb : BUFFER std_logic
        );
    END COMPONENT;

    SIGNAL s, r : std_logic;
BEGIN
    u1: notand PORT MAP (d, l, s);
    u2: notand PORT MAP (l, s, r);
    u3: RS_VHDL   PORT MAP (s, r, q, qb);

END structural;