library IEEE;
use IEEE.std_logic_1164.all;

entity shift_reg is
    port (
        clk   : in  std_logic;
        data  : in  std_logic;
        reset : in  std_logic;
        q     : out std_logic
    );
end shift_reg;

architecture beh of shift_reg is
    signal rs : std_logic_vector(3 downto 0);
begin
    process (clk, reset)
    begin
        if reset = '0' then
            rs <= "0000";
        elsif rising_edge(clk) then
            rs <= data & rs(3 downto 1);
        end if;
    end process;

    q <= rs(0);
end beh;