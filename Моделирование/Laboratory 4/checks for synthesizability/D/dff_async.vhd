library IEEE;
use IEEE.std_logic_1164.all;

entity dff_async is
    port (
        data, clk, reset, preset : in  std_logic;
        q                        : out std_logic
    );
end dff_async;

architecture beh of dff_async is
begin
    process (clk, reset, preset)
    begin
        if reset = '0' then
            q <= '0';
        elsif preset = '0' then
            q <= '1';
        elsif rising_edge(clk) then
            q <= data;
        end if;
    end process;
end beh;