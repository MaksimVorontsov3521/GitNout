library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity T_trigger is
    Port ( T   : in  STD_LOGIC;
           CLK : in  STD_LOGIC;
           Q   : out STD_LOGIC;
           Qn  : out STD_LOGIC);
end T_trigger;

architecture behavioral of T_trigger is
    signal state : STD_LOGIC := '0';
begin
    process(CLK)
    begin
        if rising_edge(CLK) then
            if T = '1' then
                state <= not state;
            end if;
        end if;
    end process;

    Q  <= state;
    Qn <= not state;
end behavioral;