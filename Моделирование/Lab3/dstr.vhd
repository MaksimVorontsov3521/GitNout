LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY dstr IS
    PORT (
        d : IN  std_logic;
        c : IN  std_logic;
        q : BUFFER std_logic;
        qb: BUFFER std_logic
    );
END dstr;

ARCHITECTURE behav OF dstr IS
    COMPONENT notand
        PORT (
            a : IN  std_logic;
            b : IN  std_logic;
            c : OUT std_logic
        );
    END COMPONENT;
    
    SIGNAL s_int, r_int : std_logic;
BEGIN
    s_int <= NOT (d AND c);
    r_int <= NOT ((NOT d) AND c);

    u1: notand PORT MAP (s_int, qb, q);
    u2: notand PORT MAP (q, r_int, qb);
END behav;

CONFIGURATION con_d OF dstr IS
    FOR behav
        FOR u1, u2: notand
            USE ENTITY work.notand(behavior);
        END FOR;
    END FOR;
END con_d;