library IEEE;
use IEEE.std_logic_1164.all;

entity mem_reg is
    port (
        x     : in  std_logic_vector(3 downto 0);
        write : in  std_logic;
        reset : in  std_logic;
        read  : in  std_logic;
        q     : out std_logic_vector(3 downto 0)
    );
end mem_reg;

architecture behav of mem_reg is
    signal reg : std_logic_vector(3 downto 0);
begin
    process(write, reset)
    begin
        if reset = '0' then
            reg <= "0000";
        elsif rising_edge(write) then
            reg <= x;
        end if;
    end process;

    q <= reg when read = '1' else (others => '0');
end behav;