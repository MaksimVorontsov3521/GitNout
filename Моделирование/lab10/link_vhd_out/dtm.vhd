library ieee;
use ieee.std_logic_1164.all;

entity dtm is
    port (
        W   : in  std_logic_vector(8 downto 0);
        ERR : in  std_logic_vector(8 downto 0);
        Y   : out std_logic_vector(8 downto 0)
    );
end dtm;

architecture rtl of dtm is
begin
    Y <= W xor ERR;
end rtl;
