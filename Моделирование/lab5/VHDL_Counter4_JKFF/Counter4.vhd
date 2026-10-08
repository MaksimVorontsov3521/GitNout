library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity Counter4 is
    Port ( CLK : in  STD_LOGIC;
           RST : in  STD_LOGIC;
           q0, q1, q2, q3 : out STD_LOGIC);
end Counter4;

architecture Behavioral of Counter4 is
    signal s0, s1, s2, s3 : STD_LOGIC := '0';
begin
    process(CLK)
        variable c : STD_LOGIC_VECTOR(3 downto 0);
    begin
        if rising_edge(CLK) then
            if RST = '1' then
                s0 <= '0'; s1 <= '0'; s2 <= '0'; s3 <= '0';
            else
                c := s3 & s2 & s1 & s0;
                c := c + 1;
                s0 <= c(0);
                s1 <= c(1);
                s2 <= c(2);
                s3 <= c(3);
            end if;
        end if;
    end process;

    q0 <= s0; q1 <= s1; q2 <= s2; q3 <= s3;
end Behavioral;