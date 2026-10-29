library ieee;
use ieee.std_logic_1164.all;

entity encoder8_3 is
    port(
        r0, r1, r2, r3 : in std_logic;
        r4, r5, r6, r7 : in std_logic;
        EI : in std_logic;
        a0, a1, a2 : out std_logic;
        G, EO : out std_logic
    );
end encoder8_3;

architecture behavior of encoder8_3 is
begin
    process(r0, r1, r2, r3, r4, r5, r6, r7, EI)
    begin
        a0 <= '0'; a1 <= '0'; a2 <= '0'; 
        G  <= '0'; EO <= '0';
        
        if EI = '1' then
            if r7 = '1' then
                a2 <= '1'; a1 <= '1'; a0 <= '1'; G <= '1';
            elsif r6 = '1' then
                a2 <= '1'; a1 <= '1'; a0 <= '0'; G <= '1';
            elsif r5 = '1' then
                a2 <= '1'; a1 <= '0'; a0 <= '1'; G <= '1';
            elsif r4 = '1' then
                a2 <= '1'; a1 <= '0'; a0 <= '0'; G <= '1';
            elsif r3 = '1' then
                a2 <= '0'; a1 <= '1'; a0 <= '1'; G <= '1';
            elsif r2 = '1' then
                a2 <= '0'; a1 <= '1'; a0 <= '0'; G <= '1';
            elsif r1 = '1' then
                a2 <= '0'; a1 <= '0'; a0 <= '1'; G <= '1';
            elsif r0 = '1' then
                a2 <= '0'; a1 <= '0'; a0 <= '0'; G <= '1';
            else
                EO <= '1';
            end if;
        end if;
    end process;
end behavior;