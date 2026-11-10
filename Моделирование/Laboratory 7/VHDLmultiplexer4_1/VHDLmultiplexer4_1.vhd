library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity VHDLmultiplexer4_1 is
    Port ( 
        x : in  STD_LOGIC_VECTOR (3 downto 0);
        a : in  STD_LOGIC_VECTOR (1 downto 0);
        E : in  STD_LOGIC;
        Q : out STD_LOGIC
    );
end VHDLmultiplexer4_1;

architecture Behavioral of VHDLmultiplexer4_1 is
begin
    process(x, a, E)
    begin
        if E = '1' then
            case a is
                when "00"   => Q <= x(0);
                when "01"   => Q <= x(1);
                when "10"   => Q <= x(2);
                when "11"   => Q <= x(3);
                when others => Q <= '0'; -- ????????? ?? ????????????????
            end case;
        else
            Q <= '0'; -- ??? 'Z' ??? ???????? ?????????, ???? ???? ??????? ???????
        end if;
    end process;
end Behavioral;