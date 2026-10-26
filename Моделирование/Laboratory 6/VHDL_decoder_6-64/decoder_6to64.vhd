library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity decoder_6to64 is
    port (
        a : in  std_logic_vector(5 downto 0);
        q : out std_logic_vector(63 downto 0)
    );
end decoder_6to64;

architecture behav of decoder_6to64 is
begin
    process (a)
        variable idx : integer range 0 to 63;
        variable tmp : std_logic_vector(63 downto 0);
    begin
        idx := to_integer(unsigned(a));
        tmp := (others => '0');
        tmp(idx) := '1';       
        q <= tmp;
    end process;
end behav;