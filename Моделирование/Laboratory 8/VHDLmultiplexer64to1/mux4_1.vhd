library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity mux4_1 is
    Port ( 
        x   : in  STD_LOGIC_VECTOR(3 downto 0);
        a   : in  STD_LOGIC_VECTOR(1 downto 0);
        E   : in  STD_LOGIC;
        Q   : out STD_LOGIC;
        Q_n : out STD_LOGIC
    );
end mux4_1;

architecture Behavioral of mux4_1 is
begin
    process(x, a, E)
        variable selected : STD_LOGIC;
    begin
        if E = '1' then
            case a is
                when "00"   => selected := x(0);
                when "01"   => selected := x(1);
                when "10"   => selected := x(2);
                when "11"   => selected := x(3);
                when others => selected := '0';
            end case;
            Q   <= selected;
            Q_n <= not selected;
        else
            Q   <= '0';
            Q_n <= '1';
        end if;
    end process;
end Behavioral;