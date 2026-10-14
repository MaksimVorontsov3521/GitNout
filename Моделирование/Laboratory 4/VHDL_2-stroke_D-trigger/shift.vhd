library IEEE;
use IEEE.std_logic_1164.all;

entity shift is
    port (
        D  : in  std_logic;
        C1 : in  std_logic;
        C2 : in  std_logic;
        R  : in  std_logic;
        Q1 : out std_logic;
        Q2 : out std_logic
    );
end shift;

architecture beh of shift is
    signal m1, s1, m2, s2 : std_logic := '0';
begin
    process (C1, R)
    begin
        if R = '0' then
            m1 <= '0';
            m2 <= '0';
        elsif rising_edge(C1) then
            m1 <= D;
            m2 <= s1;
        end if;
    end process;

    process (C2, R)
    begin
        if R = '0' then
            s1 <= '0';
            s2 <= '0';
        elsif rising_edge(C2) then
            s1 <= m1;
            s2 <= m2;
        end if;
    end process;

    Q1 <= s1;
    Q2 <= s2;
end beh;